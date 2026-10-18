#import <Foundation/Foundation.h>
#import <IOKit/IOKitLib.h>
#import <IOKit/hid/IOHIDManager.h>
#import <IOKit/hid/IOHIDKeys.h>
#import <pthread.h>
#import <stdio.h>
#import <stdarg.h>
#import <time.h>
#import <math.h>

#import "TSPCBridge.h"

// ==============================================================================
// Log file helper
// ==============================================================================
static FILE *s_logFile = NULL;
static pthread_mutex_t s_logLock = PTHREAD_MUTEX_INITIALIZER;

static void bridge_log(const char *fmt, ...) {
    pthread_mutex_lock(&s_logLock);
    if (!s_logFile) {
        s_logFile = fopen("/tmp/tspc_g29_bridge.log", "a");
        if (s_logFile) {
            setlinebuf(s_logFile);
        }
    }
    if (s_logFile) {
        time_t now = time(NULL);
        struct tm tm_buf;
        localtime_r(&now, &tm_buf);
        char time_str[32];
        strftime(time_str, sizeof(time_str), "%H:%M:%S", &tm_buf);

        fprintf(s_logFile, "[%s][TSPC-G29] ", time_str);
        va_list args;
        va_start(args, fmt);
        vfprintf(s_logFile, fmt, args);
        va_end(args);
        fprintf(s_logFile, "\n");
        fflush(s_logFile);
    }
    pthread_mutex_unlock(&s_logLock);
}

// ==============================================================================
// Interpose Macro for macOS dyld
// ==============================================================================
typedef struct interpose_s {
    const void *replacement;
    const void *original;
} interpose_t;

#define INTERPOSE(_replacement, _original) \
    __attribute__((used)) static const interpose_t interpose_##_original \
    __attribute__((section("__DATA,__interpose"))) = { \
        (const void *)(uintptr_t)&_replacement, \
        (const void *)(uintptr_t)&_original \
    }

// Logitech G29 Spoof Identifiers
#define LOGI_VID          0x046d
#define G29_PID           0xc24f
#define G29_VERSION       0x8900
#define G29_REPORT_SIZE   12

// Forward declarations of original IOKit symbols
void IOHIDManagerSetDeviceMatchingMultiple(IOHIDManagerRef manager, CFArrayRef multiple);
CFTypeRef IOHIDDeviceGetProperty(IOHIDDeviceRef device, CFStringRef key);
void IOHIDDeviceRegisterInputReportCallback(IOHIDDeviceRef device, uint8_t *report, CFIndex reportLength, IOHIDReportCallback callback, void *context);
IOReturn IOHIDDeviceSetReport(IOHIDDeviceRef device, IOHIDReportType type, CFIndex reportID, const uint8_t *report, CFIndex reportLength);
IOReturn IOHIDDeviceGetReport(IOHIDDeviceRef device, IOHIDReportType type, CFIndex reportID, uint8_t *report, CFIndex *reportLength);

static void send_tspc_raw_command(IOHIDDeviceRef dev, const uint8_t *cmd, size_t len);
static void send_tspc_autocenter(IOHIDDeviceRef dev, int forcePercent, bool enabled);
static void send_tspc_range(IOHIDDeviceRef dev, uint16_t degrees);
static void send_tspc_gain(IOHIDDeviceRef dev, int gainPercent);

// Set of active TS-PC Racer device references
static CFMutableSetRef s_tspcDevices = NULL;
static pthread_mutex_t s_deviceSetLock = PTHREAD_MUTEX_INITIALIZER;

// State structure for intercepted reports
typedef struct {
    IOHIDDeviceRef device;
    IOHIDReportCallback originalCallback;
    void *originalContext;
    uint8_t *reportBuffer;
    CFIndex reportBufferSize;
    
    // Telemetry state
    uint16_t wheelRaw;       // 0..65535, center 32768
    int gasRaw;              // 0..1023 (1023 = released, 0 = pressed)
    int brakeRaw;            // 0..1023 (1023 = released, 0 = pressed)
    int clutchRaw;           // 0..1023 (1023 = released, 0 = pressed)
    int hat;                 // 0..7 (-1 = center)
    uint32_t buttons;        // bitmask 1..16
    
    pthread_t streamThread;
    volatile bool streamRunning;
} TSPCBridgeContext;

static TSPCBridgeContext *s_activeBridge = NULL;
static pthread_mutex_t s_bridgeLock = PTHREAD_MUTEX_INITIALIZER;

static bool is_tspc_device(IOHIDDeviceRef device) {
    if (!device) return false;
    pthread_mutex_lock(&s_deviceSetLock);
    bool contained = s_tspcDevices && CFSetContainsValue(s_tspcDevices, device);
    pthread_mutex_unlock(&s_deviceSetLock);
    if (contained) return true;

    // Not yet in set: probe real VendorID / ProductID via original IOHIDDeviceGetProperty
    CFTypeRef vidRef = IOHIDDeviceGetProperty(device, CFSTR(kIOHIDVendorIDKey));
    CFTypeRef pidRef = IOHIDDeviceGetProperty(device, CFSTR(kIOHIDProductIDKey));
    if (vidRef && pidRef && CFGetTypeID(vidRef) == CFNumberGetTypeID() && CFGetTypeID(pidRef) == CFNumberGetTypeID()) {
        int vid = 0, pid = 0;
        CFNumberGetValue((CFNumberRef)vidRef, kCFNumberIntType, &vid);
        CFNumberGetValue((CFNumberRef)pidRef, kCFNumberIntType, &pid);
        if (vid == TSPC_VID && (pid == TSPC_PID_ACTIVE || pid == TSPC_PID_BOOT)) {
            pthread_mutex_lock(&s_deviceSetLock);
            if (!s_tspcDevices) {
                s_tspcDevices = CFSetCreateMutable(kCFAllocatorDefault, 0, &kCFTypeSetCallBacks);
            }
            CFSetAddValue(s_tspcDevices, device);
            pthread_mutex_unlock(&s_deviceSetLock);
            bridge_log("Detected and registered TS-PC Racer device ref %p (VID=0x%04x, PID=0x%04x) for G29 spoofing!", device, vid, pid);
            return true;
        }
    }
    return false;
}

typedef struct {
    int shift_up;
    int shift_down;
    int btn_a;
    int btn_b;
    int btn_x;
    int btn_y;
    int btn_l2;
    int btn_r2;
    int btn_select;
    int btn_start;
    int btn_l3;
    int btn_r3;
    int btn_home;
    double steering_ratio;
    double ffb_gain;
    int master_gain;
    int gain_constant;
    int gain_periodic;
    int gain_spring;
    int gain_damper;
    int boost_enabled;
    int autocenter_mode; // 0 = via le jeu (Recommandé), 1 = via le volant
    int autocenter_wheel_force;
} TSPCButtonMapping;

static TSPCButtonMapping s_btnMap = {
    .shift_up = 2,
    .shift_down = 1,
    .btn_a = 6,
    .btn_b = 5,
    .btn_x = 4,
    .btn_y = 3,
    .btn_l2 = 10,
    .btn_r2 = 9,
    .btn_select = 7,
    .btn_start = 8,
    .btn_l3 = 11,
    .btn_r3 = 12,
    .btn_home = 13,
    .steering_ratio = 0.5,
    .ffb_gain = 1.2,
    .master_gain = 75,
    .gain_constant = 100,
    .gain_periodic = 100,
    .gain_spring = 100,
    .gain_damper = 100,
    .boost_enabled = 0,
    .autocenter_mode = 0, // 0 = via le jeu (Recommandé)
    .autocenter_wheel_force = 50
};

static void load_button_mapping(void) {
    const char *paths[] = {
        "/Users/matthieu.verpillier/Documents/Thrustmaster/buttons_mapping.conf",
        "/tmp/tspc_buttons_mapping.conf"
    };
    FILE *f = NULL;
    for (int i = 0; i < 2; i++) {
        f = fopen(paths[i], "r");
        if (f) break;
    }
    if (!f) return;

    char line[128];
    while (fgets(line, sizeof(line), f)) {
        if (line[0] == '#' || line[0] == '\n') continue;
        char key[64];
        char strval[64];
        if (sscanf(line, "%63[^=]=%63s", key, strval) == 2) {
            double fval = atof(strval);
            int val = atoi(strval);
            if (strcmp(key, "shift_up") == 0) s_btnMap.shift_up = val;
            else if (strcmp(key, "shift_down") == 0) s_btnMap.shift_down = val;
            else if (strcmp(key, "btn_a") == 0) s_btnMap.btn_a = val;
            else if (strcmp(key, "btn_b") == 0) s_btnMap.btn_b = val;
            else if (strcmp(key, "btn_x") == 0) s_btnMap.btn_x = val;
            else if (strcmp(key, "btn_y") == 0) s_btnMap.btn_y = val;
            else if (strcmp(key, "btn_l2") == 0) s_btnMap.btn_l2 = val;
            else if (strcmp(key, "btn_r2") == 0) s_btnMap.btn_r2 = val;
            else if (strcmp(key, "btn_select") == 0) s_btnMap.btn_select = val;
            else if (strcmp(key, "btn_start") == 0) s_btnMap.btn_start = val;
            else if (strcmp(key, "btn_l3") == 0) s_btnMap.btn_l3 = val;
            else if (strcmp(key, "btn_r3") == 0) s_btnMap.btn_r3 = val;
            else if (strcmp(key, "btn_home") == 0) s_btnMap.btn_home = val;
            else if (strcmp(key, "steering_ratio") == 0) s_btnMap.steering_ratio = fval;
            else if (strcmp(key, "ffb_gain") == 0) s_btnMap.ffb_gain = fval;
            else if (strcmp(key, "master_gain") == 0) s_btnMap.master_gain = val;
            else if (strcmp(key, "gain_constant") == 0) s_btnMap.gain_constant = val;
            else if (strcmp(key, "gain_periodic") == 0) s_btnMap.gain_periodic = val;
            else if (strcmp(key, "gain_spring") == 0) s_btnMap.gain_spring = val;
            else if (strcmp(key, "gain_damper") == 0) s_btnMap.gain_damper = val;
            else if (strcmp(key, "boost_enabled") == 0) s_btnMap.boost_enabled = val;
            else if (strcmp(key, "autocenter_wheel_force") == 0) s_btnMap.autocenter_wheel_force = val;
            else if (strcmp(key, "autocenter_mode") == 0) {
                if (strcmp(strval, "wheel") == 0 || val == 1) {
                    s_btnMap.autocenter_mode = 1;
                } else {
                    s_btnMap.autocenter_mode = 0; // game
                }
            }
        }
    }
    fclose(f);
    bridge_log("Settings loaded: ratio=%.2f, ffb_gain=%.2f, master_gain=%d%%, autocenter_mode=%s (%d%%)",
               s_btnMap.steering_ratio, s_btnMap.ffb_gain, s_btnMap.master_gain,
               s_btnMap.autocenter_mode == 0 ? "via le jeu (Recommandé)" : "via le volant",
               s_btnMap.autocenter_wheel_force);
}

#define IS_BTN(b) ((b) >= 1 && (b) <= 32 && (ctx->buttons & (1 << ((b) - 1))))

// Generate the exact 12-byte Logitech G29 input report (PS3 Mode)
static void build_g29_report(TSPCBridgeContext *ctx, uint8_t *outReport) {
    memset(outReport, 0, G29_REPORT_SIZE);

    // Byte 0:
    // Low nibble (bits 0..3): D-Pad / Hat (0=N, 1=NE, 2=E, 3=SE, 4=S, 5=SW, 6=W, 7=NW, 8=Centered)
    // High nibble (bits 4..7): Cross (0x10), Square (0x20), Circle (0x40), Triangle (0x80)
    uint8_t dpad = (ctx->hat >= 0 && ctx->hat <= 7) ? (uint8_t)ctx->hat : 0x08;
    if (IS_BTN(s_btnMap.btn_a)) dpad |= 0x10; // Cross (X / A Xbox)
    if (IS_BTN(s_btnMap.btn_x)) dpad |= 0x20; // Square ([] / X Xbox)
    if (IS_BTN(s_btnMap.btn_b)) dpad |= 0x40; // Circle (O / B Xbox)
    if (IS_BTN(s_btnMap.btn_y)) dpad |= 0x80; // Triangle (^ / Y Xbox)
    outReport[0] = dpad;

    // Byte 1: Buttons 5..12
    // R1 (bit 0), L1 (bit 1), R2 (bit 2), L2 (bit 3), Share (bit 4), Option (bit 5), R3 (bit 6), L3 (bit 7)
    uint8_t b1 = 0;
    if (IS_BTN(s_btnMap.shift_up))   b1 |= 0x01; // R1 (Shift Up)
    if (IS_BTN(s_btnMap.shift_down)) b1 |= 0x02; // L1 (Shift Down)
    if (IS_BTN(s_btnMap.btn_r2))     b1 |= 0x04; // R2
    if (IS_BTN(s_btnMap.btn_l2))     b1 |= 0x08; // L2
    if (IS_BTN(s_btnMap.btn_select)) b1 |= 0x10; // Share / View
    if (IS_BTN(s_btnMap.btn_start))  b1 |= 0x20; // Options / Menu
    if (IS_BTN(s_btnMap.btn_r3))     b1 |= 0x40; // R3
    if (IS_BTN(s_btnMap.btn_l3))     b1 |= 0x80; // L3
    outReport[1] = b1;

    // Byte 2: Buttons 13..20
    // Bits 0..6: H-Shifter Gears 1..6 + Reverse (0 = neutral). Never bind wheel buttons here!
    outReport[2] = 0x00;

    // Byte 3: Buttons 21..28 (21..25 used, 26..28 padding)
    uint8_t b3 = 0;
    if (IS_BTN(s_btnMap.btn_home)) b3 |= 0x10; // PS / Xbox Home
    outReport[3] = b3;

    // Bytes 4..5: Steering wheel (16-bit little-endian: 0x0000 full left, 0x8000 center, 0xFFFF full right)
    // Scale delta from center (32768) by steering_ratio to synchronize physical angle with Forza (1:1)
    int32_t delta = (int32_t)ctx->wheelRaw - 32768;
    int32_t scaledDelta = (int32_t)((double)delta * s_btnMap.steering_ratio);
    int32_t finalWheel = 32768 + scaledDelta;
    if (finalWheel < 0) finalWheel = 0;
    if (finalWheel > 65535) finalWheel = 65535;
    uint16_t w = (uint16_t)finalWheel;
    outReport[4] = (uint8_t)(w & 0xff);
    outReport[5] = (uint8_t)((w >> 8) & 0xff);

    // Bytes 6..8: Pedals in G29 (0xFF = released, 0x00 = fully pressed)
    // DirectInput / Windows Logitech G29 driver maps:
    // Byte 6 (Usage Z) -> Clutch
    // Byte 7 (Usage Rz) -> Brake
    // Byte 8 (Usage Y) -> Throttle / Accelerator
    int gasVal = ctx->gasRaw;
    if (gasVal < 0) gasVal = 0;
    if (gasVal > 1023) gasVal = 1023;

    int brakeVal = ctx->brakeRaw;
    if (brakeVal < 0) brakeVal = 0;
    if (brakeVal > 1023) brakeVal = 1023;

    int clutchVal = ctx->clutchRaw;
    if (clutchVal < 0) clutchVal = 0;
    if (clutchVal > 1023) clutchVal = 1023;

    outReport[6] = (uint8_t)(gasVal >> 2);    // Throttle / Accelerator
    outReport[7] = (uint8_t)(brakeVal >> 2);  // Brake
    outReport[8] = (uint8_t)(clutchVal >> 2); // Clutch

    // Bytes 9..10: Shifter X/Y (centered at 0x80)
    outReport[9] = 0x80;
    outReport[10] = 0x80;

    // Byte 11: Status flags (0 = pedals connected, shifter disconnected)
    outReport[11] = 0x00;

    static int s_logCounter = 0;
    if (++s_logCounter >= 400) { // Log every ~2 seconds
        s_logCounter = 0;
        bridge_log("Report: Wheel=%5u (0x%04x), Gas=%3u (raw=%4d), Brake=%3u (raw=%4d), Clutch=%3u (raw=%4d), Btn=0x%04x",
                   w, w, outReport[6], ctx->gasRaw, outReport[7], ctx->brakeRaw, outReport[8], ctx->clutchRaw, ctx->buttons);
    }
}

// Background streaming thread (delivers steady 200 Hz updates to GeForce NOW read loop)
static void *stream_loop(void *arg) {
    TSPCBridgeContext *ctx = (TSPCBridgeContext *)arg;
    bridge_log("Input report streaming thread started at 200 Hz (every 5ms)");
    
    uint8_t g29Buf[G29_REPORT_SIZE];
    
    while (ctx->streamRunning) {
        if (ctx->originalCallback && ctx->device) {
            pthread_mutex_lock(&s_bridgeLock);
            build_g29_report(ctx, g29Buf);
            IOHIDReportCallback cb = ctx->originalCallback;
            void *cbCtx = ctx->originalContext;
            IOHIDDeviceRef dev = ctx->device;
            pthread_mutex_unlock(&s_bridgeLock);
            
            cb(cbCtx, kIOReturnSuccess, dev, kIOHIDReportTypeInput, 0, g29Buf, G29_REPORT_SIZE);
        }
        usleep(5000); // 5ms = 200 Hz
    }
    bridge_log("Input report streaming thread ended");
    return NULL;
}

// IOHIDInputValueCallback listening to genuine hardware element events
static void on_tspc_element_value(void *context, IOReturn result, void *sender, IOHIDValueRef value) {
    TSPCBridgeContext *ctx = (TSPCBridgeContext *)context;
    if (!ctx) return;

    IOHIDElementRef elem = IOHIDValueGetElement(value);
    uint32_t page = IOHIDElementGetUsagePage(elem);
    uint32_t usage = IOHIDElementGetUsage(elem);
    CFIndex val = IOHIDValueGetIntegerValue(value);

    pthread_mutex_lock(&s_bridgeLock);
    if (page == 0x01) { // Generic Desktop
        if (usage == 0x30) { // Wheel axis (X)
            ctx->wheelRaw = (uint16_t)val;
        } else if (usage == 0x35) { // Physical Accelerator
            ctx->gasRaw = (int)val;
        } else if (usage == 0x31) { // Physical Brake
            ctx->brakeRaw = (int)val;
        } else if (usage == 0x36) { // Physical Clutch
            ctx->clutchRaw = (int)val;
        } else if (usage == 0x39) { // Hat switch (D-Pad)
            ctx->hat = (val >= 0 && val <= 7) ? (int)val : -1;
        }
    } else if (page == 0x09) { // Buttons
        if (usage >= 1 && usage <= 16) {
            uint32_t prev = ctx->buttons;
            if (val != 0) {
                ctx->buttons |= (1 << (usage - 1));
            } else {
                ctx->buttons &= ~(1 << (usage - 1));
            }
            if (ctx->buttons != prev) {
                bridge_log("Button Event: Hardware Button %u %s -> Bitmask 0x%04x",
                           usage, val ? "PRESSED" : "RELEASED", ctx->buttons);
            }
        }
    }
    pthread_mutex_unlock(&s_bridgeLock);
}

// ==============================================================================
// Hook 1: IOHIDManagerSetDeviceMatchingMultiple
// Intercepts the whitelist matching array and injects TS-PC Racer
// ==============================================================================
void hooked_IOHIDManagerSetDeviceMatchingMultiple(IOHIDManagerRef manager, CFArrayRef multiple) {
    bridge_log("IOHIDManagerSetDeviceMatchingMultiple called with %ld matching dicts", multiple ? CFArrayGetCount(multiple) : 0);
    
    CFMutableArrayRef expanded = NULL;
    if (multiple) {
        expanded = CFArrayCreateMutableCopy(kCFAllocatorDefault, 0, multiple);
    } else {
        expanded = CFArrayCreateMutable(kCFAllocatorDefault, 0, &kCFTypeArrayCallBacks);
    }

    // Add TS-PC Racer Active Mode (0x044f:0xb689)
    int vid = TSPC_VID;
    int pid_active = TSPC_PID_ACTIVE;
    CFNumberRef vNum = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &vid);
    CFNumberRef pActiveNum = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &pid_active);

    CFMutableDictionaryRef matchActive = CFDictionaryCreateMutable(kCFAllocatorDefault, 2,
                                                                   &kCFTypeDictionaryKeyCallBacks,
                                                                   &kCFTypeDictionaryValueCallBacks);
    CFDictionarySetValue(matchActive, CFSTR(kIOHIDVendorIDKey), vNum);
    CFDictionarySetValue(matchActive, CFSTR(kIOHIDProductIDKey), pActiveNum);
    CFArrayAppendValue(expanded, matchActive);
    CFRelease(matchActive);

    // Add TS-PC Racer Boot Mode (0x044f:0xb65d) so we can auto-unlock
    int pid_boot = TSPC_PID_BOOT;
    CFNumberRef pBootNum = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &pid_boot);
    CFMutableDictionaryRef matchBoot = CFDictionaryCreateMutable(kCFAllocatorDefault, 2,
                                                                 &kCFTypeDictionaryKeyCallBacks,
                                                                 &kCFTypeDictionaryValueCallBacks);
    CFDictionarySetValue(matchBoot, CFSTR(kIOHIDVendorIDKey), vNum);
    CFDictionarySetValue(matchBoot, CFSTR(kIOHIDProductIDKey), pBootNum);
    CFArrayAppendValue(expanded, matchBoot);
    CFRelease(matchBoot);

    CFRelease(vNum);
    CFRelease(pActiveNum);
    CFRelease(pBootNum);

    bridge_log("Injected TS-PC Racer (0x044f:0xb689 & 0x044f:0xb65d) into IOHIDManager whitelist (total: %ld)", CFArrayGetCount(expanded));

    IOHIDManagerSetDeviceMatchingMultiple(manager, expanded);
    CFRelease(expanded);
}
INTERPOSE(hooked_IOHIDManagerSetDeviceMatchingMultiple, IOHIDManagerSetDeviceMatchingMultiple);

// ==============================================================================
// Hook 2: IOHIDDeviceGetProperty
// Spoofs G29 properties for the physical TS-PC Racer
// ==============================================================================
CFTypeRef hooked_IOHIDDeviceGetProperty(IOHIDDeviceRef device, CFStringRef key) {
    if (is_tspc_device(device)) {
        if (CFEqual(key, CFSTR(kIOHIDVendorIDKey))) {
            int v = LOGI_VID;
            return CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &v);
        }
        if (CFEqual(key, CFSTR(kIOHIDProductIDKey))) {
            int p = G29_PID;
            return CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &p);
        }
        if (CFEqual(key, CFSTR(kIOHIDVersionNumberKey))) {
            int ver = G29_VERSION;
            return CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &ver);
        }
        if (CFEqual(key, CFSTR(kIOHIDManufacturerKey))) {
            return CFSTR("Logitech");
        }
        if (CFEqual(key, CFSTR(kIOHIDProductKey))) {
            return CFSTR("G29 Driving Force Racing Wheel");
        }
        if (CFEqual(key, CFSTR(kIOHIDTransportKey))) {
            return CFSTR("USB");
        }
        if (CFEqual(key, CFSTR("bInterfaceNumber"))) {
            int iface = 0;
            return CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &iface);
        }
        if (CFEqual(key, CFSTR(kIOHIDPrimaryUsagePageKey))) {
            int up = 1; // Generic Desktop
            return CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &up);
        }
        if (CFEqual(key, CFSTR(kIOHIDPrimaryUsageKey))) {
            int u = 4; // Joystick
            return CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &u);
        }
        if (CFEqual(key, CFSTR(kIOHIDMaxInputReportSizeKey))) {
            int sz = 64;
            return CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &sz);
        }
        if (CFEqual(key, CFSTR("ReportDescriptor"))) {
            // Authentic Logitech G29 (0x046d:0xc24f) Input Report Descriptor (12 bytes total, no Report ID)
            static const uint8_t g29_desc[] = {
                0x05, 0x01,        // Usage Page (Generic Desktop)
                0x09, 0x04,        // Usage (Joystick)
                0xa1, 0x01,        // Collection (Application)
                
                // Byte 0 (bits 0..3): D-Pad / Hat Switch
                0x09, 0x39,        //   Usage (Hat switch)
                0x15, 0x00,        //   Logical Minimum (0)
                0x25, 0x07,        //   Logical Maximum (7)
                0x35, 0x00,        //   Physical Minimum (0)
                0x46, 0x3b, 0x01,  //   Physical Maximum (315)
                0x65, 0x14,        //   Unit (English Rotation: Degrees)
                0x75, 0x04,        //   Report Size (4 bits)
                0x95, 0x01,        //   Report Count (1)
                0x81, 0x42,        //   Input (Data, Variable, Absolute, Null State)
                
                // Bytes 0 (bits 4..7), 1, 2, 3 (bits 0..4): Buttons 1..25 (25 bits)
                0x05, 0x09,        //   Usage Page (Button)
                0x19, 0x01,        //   Usage Minimum (Button 1)
                0x29, 0x19,        //   Usage Maximum (Button 25)
                0x65, 0x00,        //   Unit (None)
                0x15, 0x00,        //   Logical Minimum (0)
                0x25, 0x01,        //   Logical Maximum (1)
                0x75, 0x01,        //   Report Size (1 bit)
                0x95, 0x19,        //   Report Count (25)
                0x81, 0x02,        //   Input (Data, Variable, Absolute)
                
                // Byte 3 (bits 5..7): Constant Padding (3 bits)
                0x75, 0x01,        //   Report Size (1 bit)
                0x95, 0x03,        //   Report Count (3)
                0x81, 0x03,        //   Input (Constant, Variable, Absolute)
                
                // Bytes 4..5: Steering Wheel (Usage X, 16-bit 0..65534, center 32768)
                0x05, 0x01,        //   Usage Page (Generic Desktop)
                0x09, 0x30,        //   Usage (X)
                0x27, 0xff, 0xff, 0x00, 0x00, // Logical Maximum (65534)
                0x47, 0xff, 0xff, 0x00, 0x00, // Physical Maximum (65534)
                0x75, 0x10,        //   Report Size (16 bits)
                0x95, 0x01,        //   Report Count (1)
                0x81, 0x02,        //   Input (Data, Variable, Absolute)
                
                // Bytes 6..8: Pedals (Throttle Z, Brake Rz, Clutch Y, 3x 8-bit 0..255)
                0x09, 0x32,        //   Usage (Z - Throttle)
                0x09, 0x35,        //   Usage (Rz - Brake)
                0x09, 0x31,        //   Usage (Y - Clutch)
                0x26, 0xff, 0x00,  //   Logical Maximum (255)
                0x46, 0xff, 0x00,  //   Physical Maximum (255)
                0x75, 0x08,        //   Report Size (8 bits)
                0x95, 0x03,        //   Report Count (3)
                0x81, 0x02,        //   Input (Data, Variable, Absolute)
                
                // Bytes 9..10: Vendor Defined (Shifter X/Y, 2x 8-bit)
                0x06, 0x00, 0xff,  //   Usage Page (Vendor Defined 0xFF00)
                0x09, 0x01,        //   Usage (0x01)
                0x95, 0x02,        //   Report Count (2)
                0x81, 0x02,        //   Input (Data, Variable, Absolute)
                
                // Byte 11: Status Byte (Vendor Defined, 1x 8-bit)
                0x06, 0x00, 0xff,  //   Usage Page (Vendor Defined 0xFF00)
                0x09, 0x01,        //   Usage (0x01)
                0x75, 0x08,        //   Report Size (8 bits)
                0x95, 0x01,        //   Report Count (1)
                0x81, 0x02,        //   Input (Data, Variable, Absolute)
                
                // Force Feedback Output Report (16 bytes)
                0x06, 0x00, 0xff,  //   Usage Page (Vendor Defined 0xFF00)
                0x09, 0x02,        //   Usage (0x02)
                0x26, 0xff, 0x00,  //   Logical Maximum (255)
                0x46, 0xff, 0x00,  //   Physical Maximum (255)
                0x95, 0x10,        //   Report Count (16)
                0x75, 0x08,        //   Report Size (8 bits)
                0x91, 0x02,        //   Output (Data, Variable, Absolute)
                
                0xc0               // End Collection
            };
            return CFDataCreate(kCFAllocatorDefault, g29_desc, sizeof(g29_desc));
        }
    }
    return IOHIDDeviceGetProperty(device, key);
}
INTERPOSE(hooked_IOHIDDeviceGetProperty, IOHIDDeviceGetProperty);

static void send_tspc_raw_command(IOHIDDeviceRef dev, const uint8_t *cmd, size_t len);
static void send_tspc_open_ffb(IOHIDDeviceRef dev);
static void send_tspc_autocenter(IOHIDDeviceRef dev, int forcePercent, bool enabled);
static void send_tspc_gain(IOHIDDeviceRef dev, int gainPercent);
static void send_tspc_init_ffb(IOHIDDeviceRef dev);
static void send_tspc_constant_force(IOHIDDeviceRef dev, int16_t level);

// ==============================================================================
// Hook 3: IOHIDDeviceRegisterInputReportCallback
// Intercepts input reports and supplies G29 translated reports
// ==============================================================================
void hooked_IOHIDDeviceRegisterInputReportCallback(IOHIDDeviceRef device, uint8_t *report,
                                                  CFIndex reportLength, IOHIDReportCallback callback,
                                                  void *context) {
    if (is_tspc_device(device)) {
        bridge_log("IOHIDDeviceRegisterInputReportCallback intercepted for TS-PC! Callback=%p, Context=%p, BufferLen=%ld",
                   callback, context, reportLength);
        
        pthread_mutex_lock(&s_bridgeLock);
        if (!s_activeBridge) {
            s_activeBridge = (TSPCBridgeContext *)calloc(1, sizeof(TSPCBridgeContext));
            s_activeBridge->wheelRaw = 32768;
            s_activeBridge->hat = -1;
            s_activeBridge->gasRaw = 1023;
            s_activeBridge->brakeRaw = 1023;
            s_activeBridge->clutchRaw = 1023;
        }
        s_activeBridge->device = device;
        s_activeBridge->originalCallback = callback;
        s_activeBridge->originalContext = context;
        s_activeBridge->reportBuffer = report;
        s_activeBridge->reportBufferSize = reportLength;
        
        // Listen to native hardware values via IOKit
        IOHIDDeviceRegisterInputValueCallback(device, on_tspc_element_value, s_activeBridge);

        // Query initial state of hardware elements so wheel and pedals are accurate immediately
        CFArrayRef elements = IOHIDDeviceCopyMatchingElements(device, NULL, kIOHIDOptionsTypeNone);
        if (elements) {
            CFIndex count = CFArrayGetCount(elements);
            for (CFIndex i = 0; i < count; i++) {
                IOHIDElementRef elem = (IOHIDElementRef)CFArrayGetValueAtIndex(elements, i);
                uint32_t page = IOHIDElementGetUsagePage(elem);
                uint32_t usage = IOHIDElementGetUsage(elem);
                IOHIDValueRef valRef = NULL;
                if (IOHIDDeviceGetValue(device, elem, &valRef) == kIOReturnSuccess && valRef) {
                    CFIndex val = IOHIDValueGetIntegerValue(valRef);
                    if (page == 0x01) {
                        if (usage == 0x30) s_activeBridge->wheelRaw = (uint16_t)val;
                        else if (usage == 0x36) s_activeBridge->gasRaw = (int)val;
                        else if (usage == 0x35) s_activeBridge->brakeRaw = (int)val;
                        else if (usage == 0x31) s_activeBridge->clutchRaw = (int)val;
                        else if (usage == 0x39) s_activeBridge->hat = (val >= 0 && val <= 7) ? (int)val : -1;
                    } else if (page == 0x09) {
                        if (usage >= 1 && usage <= 16 && val != 0) {
                            s_activeBridge->buttons |= (1 << (usage - 1));
                        }
                    }
                }
            }
            CFRelease(elements);
            bridge_log("Initial hardware state queried: Wheel=%u, GasRaw=%d, BrakeRaw=%d, ClutchRaw=%d, Hat=%d, Btn=0x%x",
                       s_activeBridge->wheelRaw, s_activeBridge->gasRaw, s_activeBridge->brakeRaw,
                       s_activeBridge->clutchRaw, s_activeBridge->hat, s_activeBridge->buttons);
        }

        if (callback && !s_activeBridge->streamRunning) {
            s_activeBridge->streamRunning = true;
            pthread_create(&s_activeBridge->streamThread, NULL, stream_loop, s_activeBridge);
            // Refresh settings from conf file
            load_button_mapping();
            // Open FFB channels on wheel
            send_tspc_open_ffb(device);
            // Apply Master Gain
            send_tspc_gain(device, s_btnMap.master_gain);
            // Autocenter Mode: Game (Recommended) vs Wheel
            if (s_btnMap.autocenter_mode == 1) {
                bridge_log("Centering mode: VIA LE VOLANT (%d%%)", s_btnMap.autocenter_wheel_force);
                send_tspc_autocenter(device, s_btnMap.autocenter_wheel_force, true);
            } else {
                bridge_log("Centering mode: VIA LE JEU (Recommandé) -> Initializing FFB physics engine");
                send_tspc_init_ffb(device);
            }
        } else if (!callback && s_activeBridge->streamRunning) {
            s_activeBridge->streamRunning = false;
            pthread_join(s_activeBridge->streamThread, NULL);
        }
        pthread_mutex_unlock(&s_bridgeLock);
        return;
    }

    IOHIDDeviceRegisterInputReportCallback(device, report, reportLength, callback, context);
}
INTERPOSE(hooked_IOHIDDeviceRegisterInputReportCallback, IOHIDDeviceRegisterInputReportCallback);

static void send_tspc_raw_command(IOHIDDeviceRef dev, const uint8_t *cmd, size_t len) {
    if (!dev || !cmd || len == 0) return;
    uint8_t buf[63];
    memset(buf, 0, sizeof(buf));
    size_t copyLen = len < sizeof(buf) ? len : sizeof(buf);
    memcpy(buf, cmd, copyLen);
    IOReturn r = IOHIDDeviceSetReport(dev, kIOHIDReportTypeOutput, 0, buf, sizeof(buf));
    if (r != kIOReturnSuccess) {
        IOHIDDeviceSetReport(dev, kIOHIDReportTypeOutput, 0x0a, buf, sizeof(buf));
    }
}

static void send_tspc_open_ffb(IOHIDDeviceRef dev) {
    uint8_t op1[2] = { 0x01, 0x04 };
    send_tspc_raw_command(dev, op1, sizeof(op1));
    uint8_t op2[2] = { 0x01, 0x05 };
    send_tspc_raw_command(dev, op2, sizeof(op2));
}

static void send_tspc_autocenter(IOHIDDeviceRef dev, int forcePercent, bool enabled) {
    if (!enabled || forcePercent <= 0) {
        // Disable internal centering spring completely (0 magnitude + disabled)
        uint8_t enBuf[4] = { 0x08, 0x04, 0x00, 0x00 };
        send_tspc_raw_command(dev, enBuf, sizeof(enBuf));
        uint8_t forceBuf[4] = { 0x08, 0x03, 0x00, 0x00 };
        send_tspc_raw_command(dev, forceBuf, sizeof(forceBuf));
        uint8_t enBuf2[4] = { 0x40, 0x04, 0x00, 0x00 };
        send_tspc_raw_command(dev, enBuf2, sizeof(enBuf2));
        uint8_t forceBuf2[4] = { 0x40, 0x03, 0x00, 0x00 };
        send_tspc_raw_command(dev, forceBuf2, sizeof(forceBuf2));
        return;
    }

    if (forcePercent > 100) forcePercent = 100;

    // Apply configurable ffb_gain
    int eff = (int)((double)forcePercent * s_btnMap.ffb_gain);
    if (eff < 0) eff = 0;
    if (eff > 100) eff = 100;

    // Scale to full 16-bit unsigned range (0..65535) for Thrustmaster 40W brushless motor controller
    uint16_t mag = (uint16_t)(((uint32_t)eff * 65535) / 100);

    // Enable internal spring
    uint8_t enBuf[4] = { 0x08, 0x04, 0x01, 0x00 };
    send_tspc_raw_command(dev, enBuf, sizeof(enBuf));

    // Force magnitude (16-bit little-endian: 0x0000 to 0xFFFF)
    uint8_t forceBuf[4] = { 0x08, 0x03, (uint8_t)(mag & 0xff), (uint8_t)(mag >> 8) };
    send_tspc_raw_command(dev, forceBuf, sizeof(forceBuf));

    // 0x40 opcodes for dual-firmware compatibility
    uint8_t enBuf2[4] = { 0x40, 0x04, 0x01, 0x00 };
    send_tspc_raw_command(dev, enBuf2, sizeof(enBuf2));

    uint8_t forceBuf2[4] = { 0x40, 0x03, (uint8_t)(mag & 0xff), (uint8_t)(mag >> 8) };
    send_tspc_raw_command(dev, forceBuf2, sizeof(forceBuf2));
}

static void send_tspc_init_ffb(IOHIDDeviceRef dev) {
    // 1. Open FFB channels
    send_tspc_open_ffb(dev);

    // 2. Kill hardware autocenter spring (0 magnitude + disabled)
    send_tspc_autocenter(dev, 0, false);

    // 3. Upload initial Constant Force effect (Effect 0, Code 0x6a, Level 0)
    uint8_t up_pkt[24];
    memset(up_pkt, 0, sizeof(up_pkt));
    up_pkt[0] = 0x00;
    up_pkt[1] = 0x01; // ID 1
    up_pkt[2] = 0x6a; // Constant Force upload
    up_pkt[3] = 0x00; // Level 0
    up_pkt[4] = 0x00;
    up_pkt[13] = 0x00; // zero
    up_pkt[14] = 0x4f; // start_marker
    up_pkt[15] = 0xff; // duration infinite
    up_pkt[16] = 0xff;
    up_pkt[22] = 0xff; // end_marker
    up_pkt[23] = 0xff;
    send_tspc_raw_command(dev, up_pkt, sizeof(up_pkt));

    // 4. Start playback of Constant Force effect (ID 1, Code 0x89, Play 0x41)
    uint8_t play_pkt[6];
    memset(play_pkt, 0, sizeof(play_pkt));
    play_pkt[0] = 0x00;
    play_pkt[1] = 0x01; // ID 1
    play_pkt[2] = 0x89; // Play/Stop header
    play_pkt[3] = 0x41; // Play opcode
    send_tspc_raw_command(dev, play_pkt, sizeof(play_pkt));

    bridge_log("TS-PC FFB Engine initialized: Hardware spring disabled, Constant Force slot ready.");
}

static void send_tspc_constant_force(IOHIDDeviceRef dev, int16_t level) {
    if (!dev) return;

    // t300rs_update_constant: packet ID 1, code 0x6a, update_type 0x45
    uint8_t mod_pkt[19];
    memset(mod_pkt, 0, sizeof(mod_pkt));
    mod_pkt[0] = 0x00;
    mod_pkt[1] = 0x01; // ID 1
    mod_pkt[2] = 0x6a; // Constant Force command
    mod_pkt[3] = (uint8_t)(level & 0xff);
    mod_pkt[4] = (uint8_t)((level >> 8) & 0xff);
    mod_pkt[13] = 0x00; // effect_type
    mod_pkt[14] = 0x45; // update_type
    mod_pkt[15] = 0xff; // duration infinite
    mod_pkt[16] = 0xff;

    send_tspc_raw_command(dev, mod_pkt, sizeof(mod_pkt));
}

static void send_tspc_range(IOHIDDeviceRef dev, uint16_t degrees) {
    if (degrees < 140) degrees = 140;
    if (degrees > 1080) degrees = 1080;
    uint16_t scaled = degrees * 0x3c;
    uint8_t buf[4] = { 0x08, 0x11, (uint8_t)(scaled & 0xff), (uint8_t)(scaled >> 8) };
    send_tspc_raw_command(dev, buf, sizeof(buf));

    uint8_t buf2[4] = { 0x40, 0x11, (uint8_t)(scaled & 0xff), (uint8_t)(scaled >> 8) };
    send_tspc_raw_command(dev, buf2, sizeof(buf2));
}

static void send_tspc_gain(IOHIDDeviceRef dev, int gainPercent) {
    if (gainPercent < 0) gainPercent = 0;
    if (gainPercent > 100) gainPercent = 100;
    uint8_t val = (uint8_t)(gainPercent * 255 / 100);
    uint8_t buf[2] = { 0x02, val };
    send_tspc_raw_command(dev, buf, sizeof(buf));

    uint8_t buf2[2] = { 0x43, (uint8_t)(gainPercent * 128 / 100) };
    send_tspc_raw_command(dev, buf2, sizeof(buf2));
}

// ==============================================================================
// Hook 4: IOHIDDeviceSetReport
// Intercepts cloud commands (Rotation Range, Autocentering, FFB) and translates to TS-PC
// ==============================================================================
IOReturn hooked_IOHIDDeviceSetReport(IOHIDDeviceRef device, IOHIDReportType type,
                                    CFIndex reportID, const uint8_t *report,
                                    CFIndex reportLength) {
    if (is_tspc_device(device)) {
        if (report && reportLength >= 4) {
            int offset = 0;
            if (report[0] == 0x00 || report[0] == 0x01) {
                offset = 1;
            }
            
            // 1. Check for Logitech Range Command: 0xf8 0x81 <deg_lo> <deg_hi>
            if ((reportLength >= offset + 4) && report[offset] == 0xf8 && report[offset + 1] == 0x81) {
                uint16_t deg = (uint16_t)report[offset + 2] | ((uint16_t)report[offset + 3] << 8);
                bridge_log("G29 Output: Wheel Range set to %u° from cloud! Applying to TS-PC...", deg);
                send_tspc_range(device, deg);
                tspc_set_rotation_range(deg);
                return kIOReturnSuccess;
            }
            
            // 2. Check for Logitech Force Feedback Command: 0x11 0x08 <force> 0x80 ...
            if ((reportLength >= offset + 2) && (report[offset] == 0x11 || report[offset] == 0x08)) {
                uint8_t rawForce = 0x80;
                if (report[offset] == 0x11 && reportLength >= offset + 3) {
                    rawForce = report[offset + 2];
                } else if (report[offset] == 0x08 && reportLength >= offset + 2) {
                    rawForce = report[offset + 1];
                }
                
                if (s_btnMap.autocenter_mode == 1) {
                    // Wheel mode: static user-configured return-to-center spring
                    send_tspc_autocenter(device, s_btnMap.autocenter_wheel_force, true);
                } else {
                    // Game mode (Recommended): Continuous torque directly driven by game physics!
                    // Logitech protocol: 128 (0x80) is neutral / point zero (0 torque: stopped car, straight line).
                    int g29_force = (int)rawForce - 128; // -128 to +127
                    if (abs(g29_force) <= 2) {
                        g29_force = 0; // Neutral deadband
                    }
                    
                    // Map -128..+127 to Thrustmaster native 16-bit range (-16384 .. +16384)
                    int32_t scaled = ((int32_t)g29_force * 16384) / 127;
                    scaled = (int32_t)((double)scaled * s_btnMap.ffb_gain);
                    if (scaled < -16384) scaled = -16384;
                    if (scaled > 16384) scaled = 16384;
                    
                    static int16_t s_lastLevel = 0;
                    int16_t level = (int16_t)scaled;
                    
                    if (level != s_lastLevel) {
                        s_lastLevel = level;
                        send_tspc_constant_force(device, level);
                    }
                    
                    static int s_ffbLogCount = 0;
                    if (++s_ffbLogCount % 150 == 1) {
                        bridge_log("G29 FFB: Cloud raw=0x%02X (delta=%d) -> TS-PC Constant Force=%d (gain=%.2fx)",
                                   rawForce, g29_force, level, s_btnMap.ffb_gain);
                    }
                }
                return kIOReturnSuccess;
            }
        }
        return kIOReturnSuccess;
    }

    return IOHIDDeviceSetReport(device, type, reportID, report, reportLength);
}
INTERPOSE(hooked_IOHIDDeviceSetReport, IOHIDDeviceSetReport);

// ==============================================================================
// Hook 5: IOHIDDeviceGetReport
// ==============================================================================
IOReturn hooked_IOHIDDeviceGetReport(IOHIDDeviceRef device, IOHIDReportType type,
                                    CFIndex reportID, uint8_t *report,
                                    CFIndex *reportLength) {
    if (is_tspc_device(device)) {
        bridge_log("IOHIDDeviceGetReport intercepted for TS-PC (type=%d, id=%ld, maxLen=%ld)",
                   type, reportID, reportLength ? *reportLength : 0);
        if (report && reportLength && *reportLength >= G29_REPORT_SIZE && s_activeBridge) {
            pthread_mutex_lock(&s_bridgeLock);
            build_g29_report(s_activeBridge, report);
            pthread_mutex_unlock(&s_bridgeLock);
            *reportLength = G29_REPORT_SIZE;
            return kIOReturnSuccess;
        }
        return kIOReturnSuccess;
    }

    return IOHIDDeviceGetReport(device, type, reportID, report, reportLength);
}
INTERPOSE(hooked_IOHIDDeviceGetReport, IOHIDDeviceGetReport);

// ==============================================================================
// Background Unlock Thread
// If TS-PC is connected in boot mode (0xb65d), unlock it automatically
// ==============================================================================
static void *auto_unlock_thread(void *arg) {
    (void)arg;
    char desc[128];
    TSPCConnectionStatus st = tspc_get_connection_status(desc, sizeof(desc));
    if (st == TSPC_STATUS_BOOT_MODE) {
        bridge_log("TS-PC Racer detected in bootloader mode (0xb65d). Sending unlock command...");
        int r = tspc_unlock_device();
        bridge_log("Unlock command returned %d. Waiting for device re-enumeration...", r);
    } else if (st == TSPC_STATUS_ACTIVE) {
        bridge_log("TS-PC Racer already active in 1080° mode (0xb689).");
    } else {
        bridge_log("TS-PC Racer not currently plugged in.");
    }
    return NULL;
}

// ==============================================================================
// Dylib Constructor
// ==============================================================================
__attribute__((constructor))
static void tspc_g29_bridge_init(void) {
    bridge_log("=======================================================");
    bridge_log("libTSPCG29Bridge loaded into PID %d (%s)", getpid(), getprogname());
    bridge_log("Thrustmaster TS-PC Racer -> Logitech G29 Emulation Ready");
    bridge_log("=======================================================");

    tspc_init();
    load_button_mapping();

    pthread_t th;
    pthread_create(&th, NULL, auto_unlock_thread, NULL);
    pthread_detach(th);
}

__attribute__((destructor))
static void tspc_g29_bridge_deinit(void) {
    bridge_log("libTSPCG29Bridge unloaded from PID %d", getpid());
    if (s_activeBridge) {
        s_activeBridge->streamRunning = false;
    }
    if (s_logFile) {
        fclose(s_logFile);
        s_logFile = NULL;
    }
}
