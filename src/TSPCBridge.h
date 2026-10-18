#ifndef TSPC_BRIDGE_H
#define TSPC_BRIDGE_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

#define TSPC_VID          0x044f
#define TSPC_PID_BOOT     0xb65d
#define TSPC_PID_ACTIVE   0xb689

typedef enum {
    TSPC_STATUS_DISCONNECTED = 0,
    TSPC_STATUS_BOOT_MODE    = 1, // 0xb65d: waiting for unlock command
    TSPC_STATUS_ACTIVE       = 2  // 0xb689: active high-res mode
} TSPCConnectionStatus;

typedef struct {
    bool isConnected;
    TSPCConnectionStatus status;
    uint16_t wheelRaw;       // 0..65535, center ~32768
    double wheelAngleDeg;    // Computed based on current configured range
    int gasRaw;              // 0..1023
    float gasPercent;        // 0..100%
    int brakeRaw;            // 0..1023
    float brakePercent;      // 0..100%
    int clutchRaw;           // 0..1023
    float clutchPercent;     // 0..100%
    int hat;                 // 0..7 (-1 = centered)
    uint32_t buttons;        // bitmask for buttons 1 to 16
} TSPCTelemetry;

typedef void (*TSPCTelemetryCallback)(const TSPCTelemetry *telemetry, void *context);
typedef void (*TSPCConnectionCallback)(TSPCConnectionStatus status, const char *info, void *context);

// Initialize / cleanup driver subsystem
int tspc_init(void);
void tspc_cleanup(void);

// Query current device status
TSPCConnectionStatus tspc_get_connection_status(char *outDesc, int maxLen);

// Unlock bootloader mode into full 1080 active mode
int tspc_unlock_device(void);

// Listen to HID inputs
int tspc_start_listening(TSPCTelemetryCallback telemCb, TSPCConnectionCallback connCb, void *context);
void tspc_stop_listening(void);

// Hardware configuration
int tspc_set_rotation_range(uint16_t degrees);
int tspc_set_autocenter(int forcePercent, bool enabled);
int tspc_set_gain(int gainPercent);

// FFB diagnostic / tests
int tspc_test_pulse(int direction); // -1 = left, +1 = right, 0 = rumble

// Configure pedal inversion (default: true for Thrustmaster standard pedals)
void tspc_set_pedals_inverted(bool inverted);
bool tspc_get_pedals_inverted(void);

// Get/Set current range setting
uint16_t tspc_get_current_range(void);

// Local HTTP Telemetry Bridge (for GeForce NOW / Chrome / Web emulation)
int tspc_start_http_server(uint16_t port);
void tspc_stop_http_server(void);
bool tspc_is_http_server_running(void);
void tspc_get_telemetry_snapshot(TSPCTelemetry *outTelem);

// ==============================================================================
// Live FFB Debugger Telemetry (GeForce NOW -> G29 -> TS-PC Racer)
// ==============================================================================
#define TSPC_FFB_DEBUG_FILE "/tmp/tspc_ffb_debug.dat"
#define TSPC_FFB_DEBUG_MAGIC 0x54534642 // 'TSFB'

typedef struct {
    uint64_t timestamp_ms;
    uint8_t g29_raw;
    int16_t g29_delta;
    int16_t tspc_level;
    char note[48];
} TSPCFfbHistoryItem;

typedef struct {
    uint32_t magic;
    uint32_t seq;
    uint64_t timestamp_ms;
    
    // G29 Input from Cloud
    uint8_t g29_cmd_type;
    uint8_t g29_raw_force;
    int16_t g29_delta;
    char g29_desc[48];
    
    // TS-PC Translation to Base
    int16_t tspc_level;
    float tspc_percent;
    uint8_t tspc_packet[24];
    uint32_t tspc_packet_len;
    
    // Active Settings
    float ffb_gain;
    int ffb_invert;
    int autocenter_mode;
    int master_gain;
    uint16_t wheel_range;
    
    // History ring
    TSPCFfbHistoryItem history[16];
    uint32_t history_head;
    uint32_t history_count;
} TSPCFfbDebugData;

void tspc_ffb_debug_update(const TSPCFfbDebugData *data);
bool tspc_ffb_debug_read(TSPCFfbDebugData *outData);

#ifdef __cplusplus
}
#endif

#endif /* TSPC_BRIDGE_H */
