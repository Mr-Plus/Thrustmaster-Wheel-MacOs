#import <Foundation/Foundation.h>
#import <IOKit/IOKitLib.h>
#import <IOKit/IOCFPlugIn.h>
#import <IOKit/usb/IOUSBLib.h>
#import <IOKit/usb/USBSpec.h>
#import <IOKit/hid/IOHIDManager.h>
#import <IOKit/hid/IOHIDKeys.h>
#import <pthread.h>
#import <sys/socket.h>
#import <netinet/in.h>
#import <arpa/inet.h>
#import <unistd.h>

#import "TSPCBridge.h"

static IOHIDManagerRef s_hidManager = NULL;
static IOHIDDeviceRef s_activeDevice = NULL;
static TSPCTelemetry s_telemetry;
static TSPCTelemetryCallback s_telemCallback = NULL;
static TSPCConnectionCallback s_connCallback = NULL;
static void *s_callbackContext = NULL;
static uint16_t s_currentRange = 900;
static bool s_pedalsInverted = true;
static NSTimer *s_pollTimer = NULL;

static volatile bool s_httpRunning = false;
static pthread_t s_httpThread;
static int s_httpServerFd = -1;
static uint16_t s_httpPort = 8765;
static pthread_mutex_t s_telemetryLock = PTHREAD_MUTEX_INITIALIZER;

static void notify_connection(TSPCConnectionStatus status, const char *msg) {
    s_telemetry.status = status;
    s_telemetry.isConnected = (status != TSPC_STATUS_DISCONNECTED);
    if (s_connCallback) {
        s_connCallback(status, msg, s_callbackContext);
    }
}

static void notify_telemetry(void) {
    if (s_telemCallback) {
        s_telemCallback(&s_telemetry, s_callbackContext);
    }
}

int tspc_init(void) {
    memset(&s_telemetry, 0, sizeof(s_telemetry));
    s_telemetry.wheelRaw = 32768;
    s_telemetry.hat = -1;
    s_telemetry.status = TSPC_STATUS_DISCONNECTED;
    s_currentRange = 900;
    s_pedalsInverted = true;
    return 0;
}

void tspc_cleanup(void) {
    tspc_stop_http_server();
    tspc_stop_listening();
}

uint16_t tspc_get_current_range(void) {
    return s_currentRange;
}

void tspc_set_pedals_inverted(bool inverted) {
    s_pedalsInverted = inverted;
}

bool tspc_get_pedals_inverted(void) {
    return s_pedalsInverted;
}

static io_service_t find_usb_device(SInt32 vid, SInt32 pid) {
    CFMutableDictionaryRef match = IOServiceMatching(kIOUSBDeviceClassName);
    if (!match) return IO_OBJECT_NULL;

    CFNumberRef v = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &vid);
    CFNumberRef p = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &pid);
    CFDictionarySetValue(match, CFSTR(kUSBVendorID), v);
    CFDictionarySetValue(match, CFSTR(kUSBProductID), p);
    CFRelease(v); CFRelease(p);

    io_iterator_t iter;
    if (IOServiceGetMatchingServices(kIOMainPortDefault, match, &iter) != KERN_SUCCESS) {
        return IO_OBJECT_NULL;
    }
    io_service_t service = IOIteratorNext(iter);
    IOObjectRelease(iter);
    return service;
}

TSPCConnectionStatus tspc_get_connection_status(char *outDesc, int maxLen) {
    io_service_t activeSvc = find_usb_device(TSPC_VID, TSPC_PID_ACTIVE);
    if (activeSvc != IO_OBJECT_NULL) {
        IOObjectRelease(activeSvc);
        if (outDesc && maxLen > 0) {
            snprintf(outDesc, maxLen, "TS-PC Racer Actif (0x%04x:0x%04x) - Prêt", TSPC_VID, TSPC_PID_ACTIVE);
        }
        return TSPC_STATUS_ACTIVE;
    }

    io_service_t bootSvc = find_usb_device(TSPC_VID, TSPC_PID_BOOT);
    if (bootSvc != IO_OBJECT_NULL) {
        IOObjectRelease(bootSvc);
        if (outDesc && maxLen > 0) {
            snprintf(outDesc, maxLen, "Thrustmaster FFB Wheel en mode démarrage (0x%04x:0x%04x)", TSPC_VID, TSPC_PID_BOOT);
        }
        return TSPC_STATUS_BOOT_MODE;
    }

    if (outDesc && maxLen > 0) {
        snprintf(outDesc, maxLen, "Volant non détecté");
    }
    return TSPC_STATUS_DISCONNECTED;
}

int tspc_unlock_device(void) {
    io_service_t service = find_usb_device(TSPC_VID, TSPC_PID_BOOT);
    if (service == IO_OBJECT_NULL) {
        // Maybe already in active mode?
        if (find_usb_device(TSPC_VID, TSPC_PID_ACTIVE) != IO_OBJECT_NULL) {
            return 0; // Already unlocked
        }
        return -1;
    }

    IOCFPlugInInterface **plug = NULL;
    SInt32 score = 0;
    kern_return_t kr = IOCreatePlugInInterfaceForService(service, kIOUSBDeviceUserClientTypeID,
                                                         kIOCFPlugInInterfaceID, &plug, &score);
    IOObjectRelease(service);
    if (kr != KERN_SUCCESS || !plug) {
        return -2;
    }

    IOUSBDeviceInterface500 **dev = NULL;
    HRESULT hr = (*plug)->QueryInterface(plug, CFUUIDGetUUIDBytes(kIOUSBDeviceInterfaceID500), (LPVOID *)&dev);
    (*plug)->Release(plug);
    if (hr != S_OK || !dev) {
        return -3;
    }

    IOUSBDevRequestTO req;
    memset(&req, 0, sizeof(req));
    req.bmRequestType = 0x41; // Host-to-Device | Vendor | Interface
    req.bRequest = 83;
    req.wValue = 0x0009; // TS-PC Racer switch value
    req.wIndex = 0;
    req.wLength = 0;
    req.noDataTimeout = 2000;
    req.completionTimeout = 2000;

    IOReturn r = (*dev)->DeviceRequestTO(dev, &req);
    (*dev)->Release(dev);

    // Pipe stalled or success indicates the device has reset and will re-enumerate
    return (r == kIOReturnSuccess || r == kIOUSBPipeStalled || r == kIOReturnNotResponding) ? 0 : (int)r;
}

static void on_hid_input_value(void *context, IOReturn result, void *sender, IOHIDValueRef value) {
    IOHIDElementRef elem = IOHIDValueGetElement(value);
    uint32_t page = IOHIDElementGetUsagePage(elem);
    uint32_t usage = IOHIDElementGetUsage(elem);
    CFIndex val = IOHIDValueGetIntegerValue(value);

    bool changed = false;

    if (page == 0x01) { // Generic Desktop
        if (usage == 0x30) { // Wheel axis (X)
            s_telemetry.wheelRaw = (uint16_t)val;
            double norm = ((double)val - 32768.0) / 32768.0;
            s_telemetry.wheelAngleDeg = norm * ((double)s_currentRange / 2.0);
            changed = true;
        } else if (usage == 0x35) { // Physical Accelerator
            s_telemetry.gasRaw = (int)val;
            float pct = s_pedalsInverted ? (float)(1023 - val) / 10.23f : (float)val / 10.23f;
            if (pct < 0.0f) pct = 0.0f;
            if (pct > 100.0f) pct = 100.0f;
            s_telemetry.gasPercent = pct;
            changed = true;
        } else if (usage == 0x31) { // Physical Brake
            s_telemetry.brakeRaw = (int)val;
            float pct = s_pedalsInverted ? (float)(1023 - val) / 10.23f : (float)val / 10.23f;
            if (pct < 0.0f) pct = 0.0f;
            if (pct > 100.0f) pct = 100.0f;
            s_telemetry.brakePercent = pct;
            changed = true;
        } else if (usage == 0x36) { // Physical Clutch
            s_telemetry.clutchRaw = (int)val;
            float pct = s_pedalsInverted ? (float)(1023 - val) / 10.23f : (float)val / 10.23f;
            if (pct < 0.0f) pct = 0.0f;
            if (pct > 100.0f) pct = 100.0f;
            s_telemetry.clutchPercent = pct;
            changed = true;
        } else if (usage == 0x39) { // Hat switch (D-Pad)
            s_telemetry.hat = (val >= 0 && val <= 7) ? (int)val : -1;
            changed = true;
        }
    } else if (page == 0x09) { // Buttons
        if (usage >= 1 && usage <= 16) {
            if (val != 0) {
                s_telemetry.buttons |= (1 << (usage - 1));
            } else {
                s_telemetry.buttons &= ~(1 << (usage - 1));
            }
            changed = true;
        }
    }

    if (changed) {
        notify_telemetry();
    }
}

static void on_device_matched(void *context, IOReturn result, void *sender, IOHIDDeviceRef device) {
    s_activeDevice = device;
    notify_connection(TSPC_STATUS_ACTIVE, "TS-PC Racer connecté et actif");

    // Query initial state of elements
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
                    if (usage == 0x30) {
                        s_telemetry.wheelRaw = (uint16_t)val;
                        double norm = ((double)val - 32768.0) / 32768.0;
                        s_telemetry.wheelAngleDeg = norm * ((double)s_currentRange / 2.0);
                    } else if (usage == 0x35) { // Physical Accelerator
                        s_telemetry.gasRaw = (int)val;
                        float pct = s_pedalsInverted ? (float)(1023 - val) / 10.23f : (float)val / 10.23f;
                        s_telemetry.gasPercent = pct < 0 ? 0 : (pct > 100 ? 100 : pct);
                    } else if (usage == 0x31) { // Physical Brake
                        s_telemetry.brakeRaw = (int)val;
                        float pct = s_pedalsInverted ? (float)(1023 - val) / 10.23f : (float)val / 10.23f;
                        s_telemetry.brakePercent = pct < 0 ? 0 : (pct > 100 ? 100 : pct);
                    } else if (usage == 0x36) { // Physical Clutch
                        s_telemetry.clutchRaw = (int)val;
                        float pct = s_pedalsInverted ? (float)(1023 - val) / 10.23f : (float)val / 10.23f;
                        s_telemetry.clutchPercent = pct < 0 ? 0 : (pct > 100 ? 100 : pct);
                    } else if (usage == 0x39) {
                        s_telemetry.hat = (val >= 0 && val <= 7) ? (int)val : -1;
                    }
                }
            }
        }
        CFRelease(elements);
    }
    notify_telemetry();
}

static void on_device_removed(void *context, IOReturn result, void *sender, IOHIDDeviceRef device) {
    if (s_activeDevice == device) {
        s_activeDevice = NULL;
    }
    TSPCConnectionStatus st = tspc_get_connection_status(NULL, 0);
    notify_connection(st, (st == TSPC_STATUS_BOOT_MODE) ? "Volant en attente de déblocage" : "Volant déconnecté");
}

static void check_hardware_state(void) {
    char desc[128];
    TSPCConnectionStatus st = tspc_get_connection_status(desc, sizeof(desc));
    if (st == TSPC_STATUS_BOOT_MODE) {
        notify_connection(TSPC_STATUS_BOOT_MODE, "Mode Démarrage détecté (0xb65d) - Déblocage automatique...");
        tspc_unlock_device();
    } else if (st == TSPC_STATUS_DISCONNECTED && s_telemetry.status != TSPC_STATUS_DISCONNECTED) {
        notify_connection(TSPC_STATUS_DISCONNECTED, "Volant déconnecté");
    }
}

int tspc_start_listening(TSPCTelemetryCallback telemCb, TSPCConnectionCallback connCb, void *context) {
    s_telemCallback = telemCb;
    s_connCallback = connCb;
    s_callbackContext = context;

    if (!s_hidManager) {
        s_hidManager = IOHIDManagerCreate(kCFAllocatorDefault, kIOHIDOptionsTypeNone);
        if (!s_hidManager) return -1;

        CFMutableDictionaryRef match = CFDictionaryCreateMutable(kCFAllocatorDefault, 0,
                                                                &kCFTypeDictionaryKeyCallBacks,
                                                                &kCFTypeDictionaryValueCallBacks);
        int vid = TSPC_VID, pid = TSPC_PID_ACTIVE;
        CFNumberRef v = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &vid);
        CFNumberRef p = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &pid);
        CFDictionarySetValue(match, CFSTR(kIOHIDVendorIDKey), v);
        CFDictionarySetValue(match, CFSTR(kIOHIDProductIDKey), p);
        CFRelease(v); CFRelease(p);

        IOHIDManagerSetDeviceMatching(s_hidManager, match);
        CFRelease(match);

        IOHIDManagerRegisterDeviceMatchingCallback(s_hidManager, on_device_matched, NULL);
        IOHIDManagerRegisterDeviceRemovalCallback(s_hidManager, on_device_removed, NULL);
        IOHIDManagerRegisterInputValueCallback(s_hidManager, on_hid_input_value, NULL);
        IOHIDManagerScheduleWithRunLoop(s_hidManager, CFRunLoopGetMain(), kCFRunLoopDefaultMode);

        IOReturn kr = IOHIDManagerOpen(s_hidManager, kIOHIDOptionsTypeNone);
        if (kr != kIOReturnSuccess) {
            CFRelease(s_hidManager);
            s_hidManager = NULL;
            return -2;
        }
    }

    // Check if device is already active or in boot mode
    check_hardware_state();

    return 0;
}

void tspc_stop_listening(void) {
    if (s_pollTimer) {
        [s_pollTimer invalidate];
        s_pollTimer = NULL;
    }
    if (s_hidManager) {
        IOHIDManagerClose(s_hidManager, kIOHIDOptionsTypeNone);
        IOHIDManagerUnscheduleFromRunLoop(s_hidManager, CFRunLoopGetMain(), kCFRunLoopDefaultMode);
        CFRelease(s_hidManager);
        s_hidManager = NULL;
    }
    s_activeDevice = NULL;
}

static IOReturn send_output_report(const uint8_t *payload, size_t len) {
    if (!s_hidManager) return kIOReturnNotOpen;

    CFSetRef devSet = IOHIDManagerCopyDevices(s_hidManager);
    if (!devSet || CFSetGetCount(devSet) == 0) {
        if (devSet) CFRelease(devSet);
        return kIOReturnNoDevice;
    }

    CFIndex count = CFSetGetCount(devSet);
    const void *devices[count];
    CFSetGetValues(devSet, devices);

    uint8_t buffer[63];
    memset(buffer, 0, sizeof(buffer));
    size_t copyLen = len < sizeof(buffer) ? len : sizeof(buffer);
    memcpy(buffer, payload, copyLen);

    IOReturn lastErr = kIOReturnSuccess;
    for (CFIndex i = 0; i < count; i++) {
        IOHIDDeviceRef dev = (IOHIDDeviceRef)devices[i];
        // Send with report ID 0
        IOReturn r0 = IOHIDDeviceSetReport(dev, kIOHIDReportTypeOutput, 0, buffer, sizeof(buffer));
        // And with report ID 0x0A
        IOReturn r10 = IOHIDDeviceSetReport(dev, kIOHIDReportTypeOutput, 0x0a, buffer, sizeof(buffer));
        lastErr = (r0 == kIOReturnSuccess || r10 == kIOReturnSuccess) ? kIOReturnSuccess : r0;
    }

    CFRelease(devSet);
    return lastErr;
}

int tspc_set_rotation_range(uint16_t degrees) {
    if (degrees < 140) degrees = 140;
    if (degrees > 1080) degrees = 1080;
    s_currentRange = degrees;

    uint16_t scaled = degrees * 0x3c;
    uint8_t buf[4];
    buf[0] = 0x08;
    buf[1] = 0x11;
    buf[2] = (uint8_t)(scaled & 0xff);
    buf[3] = (uint8_t)(scaled >> 8);

    IOReturn r = send_output_report(buf, sizeof(buf));

    // Also send legacy 0x40 opcode for firmware variants
    uint8_t buf2[4];
    buf2[0] = 0x40;
    buf2[1] = 0x11;
    buf2[2] = (uint8_t)(scaled & 0xff);
    buf2[3] = (uint8_t)(scaled >> 8);
    send_output_report(buf2, sizeof(buf2));

    // Recompute current angle with new range
    double norm = ((double)s_telemetry.wheelRaw - 32768.0) / 32768.0;
    s_telemetry.wheelAngleDeg = norm * ((double)s_currentRange / 2.0);
    notify_telemetry();

    return (r == kIOReturnSuccess) ? 0 : -1;
}

int tspc_set_autocenter(int forcePercent, bool enabled) {
    if (!enabled || forcePercent <= 0) {
        // Disable internal centering spring completely (0 magnitude + disabled)
        uint8_t enBuf[4] = { 0x08, 0x04, 0x00, 0x00 };
        send_output_report(enBuf, sizeof(enBuf));
        uint8_t forceBuf[4] = { 0x08, 0x03, 0x00, 0x00 };
        IOReturn r = send_output_report(forceBuf, sizeof(forceBuf));
        uint8_t enBuf2[4] = { 0x40, 0x04, 0x00, 0x00 };
        send_output_report(enBuf2, sizeof(enBuf2));
        uint8_t forceBuf2[4] = { 0x40, 0x03, 0x00, 0x00 };
        send_output_report(forceBuf2, sizeof(forceBuf2));
        return (r == kIOReturnSuccess) ? 0 : -1;
    }

    if (forcePercent > 100) forcePercent = 100;
    uint16_t mag = (uint16_t)(((uint32_t)forcePercent * 65535) / 100);

    // Enable command
    uint8_t enBuf[4] = { 0x08, 0x04, 0x01, 0x00 };
    send_output_report(enBuf, sizeof(enBuf));

    // Force magnitude command (16-bit little endian)
    uint8_t forceBuf[4] = { 0x08, 0x03, (uint8_t)(mag & 0xff), (uint8_t)(mag >> 8) };
    IOReturn r = send_output_report(forceBuf, sizeof(forceBuf));

    // Also send dual-firmware 0x40 opcodes
    uint8_t enBuf2[4] = { 0x40, 0x04, 0x01, 0x00 };
    send_output_report(enBuf2, sizeof(enBuf2));
    uint8_t forceBuf2[4] = { 0x40, 0x03, (uint8_t)(mag & 0xff), (uint8_t)(mag >> 8) };
    send_output_report(forceBuf2, sizeof(forceBuf2));

    return (r == kIOReturnSuccess) ? 0 : -1;
}

int tspc_set_gain(int gainPercent) {
    if (gainPercent < 0) gainPercent = 0;
    if (gainPercent > 100) gainPercent = 100;

    uint8_t val = (uint8_t)(gainPercent * 255 / 100);
    uint8_t buf[2] = { 0x02, val };
    IOReturn r = send_output_report(buf, sizeof(buf));

    uint8_t buf2[2] = { 0x43, (uint8_t)(gainPercent * 128 / 100) };
    send_output_report(buf2, sizeof(buf2));

    return (r == kIOReturnSuccess) ? 0 : -1;
}

int tspc_test_pulse(int direction) {
    if (direction == 0) {
        // Test rumble/shake effect: brief rapid changes in centering
        tspc_set_autocenter(100, true);
        usleep(80000);
        tspc_set_autocenter(10, true);
        usleep(80000);
        tspc_set_autocenter(90, true);
        usleep(80000);
        tspc_set_autocenter(50, true);
    } else if (direction < 0) {
        // Pull left
        tspc_set_autocenter(85, true);
        usleep(250000);
        tspc_set_autocenter(40, true);
    } else {
        // Pull right
        tspc_set_autocenter(85, true);
        usleep(250000);
        tspc_set_autocenter(40, true);
    }
    return 0;
}

void tspc_get_telemetry_snapshot(TSPCTelemetry *outTelem) {
    if (!outTelem) return;
    pthread_mutex_lock(&s_telemetryLock);
    *outTelem = s_telemetry;
    pthread_mutex_unlock(&s_telemetryLock);
}

static void *http_server_thread(void *arg) {
    s_httpServerFd = socket(AF_INET, SOCK_STREAM, 0);
    if (s_httpServerFd < 0) {
        s_httpRunning = false;
        return NULL;
    }

    int opt = 1;
    setsockopt(s_httpServerFd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));

    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_port = htons(s_httpPort);
    addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK); // 127.0.0.1

    if (bind(s_httpServerFd, (struct sockaddr *)&addr, sizeof(addr)) != 0) {
        close(s_httpServerFd);
        s_httpServerFd = -1;
        s_httpRunning = false;
        return NULL;
    }

    if (listen(s_httpServerFd, 16) != 0) {
        close(s_httpServerFd);
        s_httpServerFd = -1;
        s_httpRunning = false;
        return NULL;
    }

    while (s_httpRunning) {
        fd_set fds;
        FD_ZERO(&fds);
        FD_SET(s_httpServerFd, &fds);
        struct timeval tv = {0, 100000}; // 100ms timeout

        int r = select(s_httpServerFd + 1, &fds, NULL, NULL, &tv);
        if (r > 0 && FD_ISSET(s_httpServerFd, &fds)) {
            int clientFd = accept(s_httpServerFd, NULL, NULL);
            if (clientFd >= 0) {
                char reqBuf[1024];
                memset(reqBuf, 0, sizeof(reqBuf));
                ssize_t n = read(clientFd, reqBuf, sizeof(reqBuf) - 1);
                if (n > 0) {
                    if (strncmp(reqBuf, "OPTIONS", 7) == 0) {
                        const char *corsResp = 
                            "HTTP/1.1 204 No Content\r\n"
                            "Access-Control-Allow-Origin: *\r\n"
                            "Access-Control-Allow-Methods: GET, POST, OPTIONS\r\n"
                            "Access-Control-Allow-Headers: *\r\n"
                            "Connection: close\r\n\r\n";
                        write(clientFd, corsResp, strlen(corsResp));
                    } else {
                        // Check for parameters in query: ?range=540
                        char *rangeParam = strstr(reqBuf, "range=");
                        if (rangeParam) {
                            int rVal = atoi(rangeParam + 6);
                            if (rVal >= 140 && rVal <= 1080) {
                                tspc_set_rotation_range((uint16_t)rVal);
                            }
                        }
                        char *centerParam = strstr(reqBuf, "autocenter=");
                        if (centerParam) {
                            int cVal = atoi(centerParam + 11);
                            if (cVal >= 0 && cVal <= 100) {
                                tspc_set_autocenter(cVal, cVal > 0);
                            }
                        }

                        TSPCTelemetry snap;
                        tspc_get_telemetry_snapshot(&snap);

                        char jsonBody[512];
                        snprintf(jsonBody, sizeof(jsonBody),
                            "{\"connected\":%s,\"status\":%d,\"wheelRaw\":%u,"
                            "\"wheelAngleDeg\":%.2f,\"gasPercent\":%.2f,\"brakePercent\":%.2f,"
                            "\"clutchPercent\":%.2f,\"buttons\":%u,\"hat\":%d,\"range\":%u}\n",
                            snap.isConnected ? "true" : "false",
                            (int)snap.status,
                            snap.wheelRaw,
                            snap.wheelAngleDeg,
                            snap.gasPercent,
                            snap.brakePercent,
                            snap.clutchPercent,
                            snap.buttons,
                            snap.hat,
                            (unsigned int)s_currentRange);

                        char httpResp[1024];
                        snprintf(httpResp, sizeof(httpResp),
                            "HTTP/1.1 200 OK\r\n"
                            "Content-Type: application/json\r\n"
                            "Access-Control-Allow-Origin: *\r\n"
                            "Content-Length: %zu\r\n"
                            "Connection: close\r\n\r\n%s",
                            strlen(jsonBody), jsonBody);

                        write(clientFd, httpResp, strlen(httpResp));
                    }
                }
                close(clientFd);
            }
        }
    }

    if (s_httpServerFd >= 0) {
        close(s_httpServerFd);
        s_httpServerFd = -1;
    }
    return NULL;
}

int tspc_start_http_server(uint16_t port) {
    if (s_httpRunning) return 0;
    s_httpPort = port > 0 ? port : 8765;
    s_httpRunning = true;
    if (pthread_create(&s_httpThread, NULL, http_server_thread, NULL) != 0) {
        s_httpRunning = false;
        return -1;
    }
    return 0;
}

void tspc_stop_http_server(void) {
    if (!s_httpRunning) return;
    s_httpRunning = false;
    pthread_join(s_httpThread, NULL);
}

bool tspc_is_http_server_running(void) {
    return s_httpRunning;
}

