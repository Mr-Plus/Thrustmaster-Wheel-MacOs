import Foundation
import SwiftUI
import Combine
import GameController

public enum TabSelection: String, CaseIterable, Identifiable {
    case dashboard = "Télémétrie"
    case settings = "Réglages & FFB"
    case geforceNow = "GeForce NOW (Forza)"
    case games = "Jeux & Profils"
    
    public var id: String { self.rawValue }
    
    public var icon: String {
        switch self {
        case .dashboard: return "gauge.with.needle"
        case .settings: return "slider.horizontal.3"
        case .geforceNow: return "cloud.fill"
        case .games: return "gamecontroller"
        }
    }
}

public class TSPCManager: ObservableObject {
    @Published public var connectionStatus: TSPCConnectionStatus = .init(rawValue: 0)
    @Published public var statusMessage: String = "Recherche du volant..."
    @Published public var isConnected: Bool = false
    @Published public var isBootMode: Bool = false
    @Published public var selectedTab: TabSelection = .dashboard
    
    // Telemetry
    @Published public var wheelAngle: Double = 0.0
    @Published public var wheelRaw: UInt16 = 32768
    @Published public var gasPercent: Double = 0.0
    @Published public var brakePercent: Double = 0.0
    @Published public var clutchPercent: Double = 0.0
    @Published public var hatDirection: Int = -1
    @Published public var pressedButtons: Set<Int> = []
    
    // Hardware configuration
    @Published public var currentRange: Double = 900.0 {
        didSet {
            if currentRange != oldValue {
                _ = tspc_set_rotation_range(UInt16(currentRange))
            }
        }
    }
    @Published public var masterGain: Double = 80.0 {
        didSet {
            if masterGain != oldValue {
                _ = tspc_set_gain(Int32(masterGain))
            }
        }
    }
    @Published public var autocenterForce: Double = 50.0 {
        didSet {
            if autocenterForce != oldValue {
                _ = tspc_set_autocenter(Int32(autocenterForce), autocenterEnabled)
            }
        }
    }
    @Published public var autocenterEnabled: Bool = true {
        didSet {
            if autocenterEnabled != oldValue {
                _ = tspc_set_autocenter(Int32(autocenterForce), autocenterEnabled)
            }
        }
    }
    @Published public var pedalsInverted: Bool = true {
        didSet {
            tspc_set_pedals_inverted(pedalsInverted)
        }
    }
    
    @Published public var autoUnlockEnabled: Bool = true
    
    // GeForce NOW / Xbox Controller Emulation
    @Published public var isHttpBridgeRunning: Bool = false
    @Published public var virtualXboxControllerActive: Bool = false
    @Published public var gfnSteeringLinearity: Double = 1.2
    @Published public var gfnDeadzone: Double = 0.02
    @Published public var gfnTargetRange: Double = 540.0
    @Published public var copiedScriptAlert: Bool = false
    
    // Computed Xbox Controller State (for real-time preview)
    public var xboxStickX: Double {
        let norm = (Double(wheelRaw) - 32768.0) / 32768.0
        if abs(norm) < gfnDeadzone { return 0.0 }
        let sign = norm >= 0 ? 1.0 : -1.0
        let val = pow(abs(norm), gfnSteeringLinearity) * sign
        return max(-1.0, min(1.0, val))
    }
    
    public var xboxRT: Double {
        return max(0.0, min(1.0, gasPercent / 100.0))
    }
    
    public var xboxLT: Double {
        return max(0.0, min(1.0, brakePercent / 100.0))
    }
    
    public var xboxLB: Bool { pressedButtons.contains(5) } // Palette Gauche
    public var xboxRB: Bool { pressedButtons.contains(6) } // Palette Droite
    public var xboxA: Bool { pressedButtons.contains(1) }
    public var xboxB: Bool { pressedButtons.contains(2) }
    public var xboxX: Bool { pressedButtons.contains(3) }
    public var xboxY: Bool { pressedButtons.contains(4) }
    public var xboxBack: Bool { pressedButtons.contains(9) }
    public var xboxStart: Bool { pressedButtons.contains(10) }
    
    private var pollTimer: Timer?
    
    public init() {
        tspc_init()
        currentRange = Double(tspc_get_current_range())
        pedalsInverted = tspc_get_pedals_inverted()
        
        // Auto-start local HTTP telemetry bridge for GeForce NOW / Chrome
        _ = tspc_start_http_server(8765)
        isHttpBridgeRunning = tspc_is_http_server_running()
        
        setupCallbacks()
        refreshStatus()
        
        // Background watch timer for hotplug / bootloader
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            self?.checkHardware()
        }
    }
    
    deinit {
        pollTimer?.invalidate()
        tspc_stop_http_server()
        tspc_stop_listening()
        tspc_cleanup()
    }
    
    private func setupCallbacks() {
        let telemCallback: TSPCTelemetryCallback = { telemPtr, context in
            guard let telem = telemPtr?.pointee, let ctx = context else { return }
            let manager = Unmanaged<TSPCManager>.fromOpaque(ctx).takeUnretainedValue()
            
            DispatchQueue.main.async {
                manager.wheelRaw = telem.wheelRaw
                manager.wheelAngle = telem.wheelAngleDeg
                manager.gasPercent = Double(telem.gasPercent)
                manager.brakePercent = Double(telem.brakePercent)
                manager.clutchPercent = Double(telem.clutchPercent)
                manager.hatDirection = Int(telem.hat)
                
                var buttons = Set<Int>()
                for b in 1...16 {
                    if (telem.buttons & (1 << (b - 1))) != 0 {
                        buttons.insert(b)
                    }
                }
                manager.pressedButtons = buttons
            }
        }
        
        let connCallback: TSPCConnectionCallback = { status, infoPtr, context in
            guard let ctx = context else { return }
            let manager = Unmanaged<TSPCManager>.fromOpaque(ctx).takeUnretainedValue()
            let msg = infoPtr != nil ? String(cString: infoPtr!) : ""
            
            DispatchQueue.main.async {
                manager.connectionStatus = status
                manager.isConnected = (status.rawValue != 0)
                manager.isBootMode = (status.rawValue == 1)
                manager.statusMessage = msg
            }
        }
        
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        _ = tspc_start_listening(telemCallback, connCallback, selfPtr)
        
        NotificationCenter.default.addObserver(forName: .GCControllerDidConnect, object: nil, queue: .main) { [weak self] _ in
            self?.checkVirtualXboxController()
        }
        NotificationCenter.default.addObserver(forName: .GCControllerDidDisconnect, object: nil, queue: .main) { [weak self] _ in
            self?.checkVirtualXboxController()
        }
        checkVirtualXboxController()
    }
    
    public func checkVirtualXboxController() {
        let controllers = GCController.controllers()
        self.virtualXboxControllerActive = controllers.contains {
            ($0.vendorName ?? "").localizedCaseInsensitiveContains("Xbox") || $0.extendedGamepad != nil
        }
    }
    
    public func ensureVirtualXboxController() {
        DispatchQueue.global(qos: .userInitiated).async {
            let task = Process()
            task.launchPath = "/bin/sh"
            task.arguments = ["-c", "/Applications/OpenJoystickDriver.app/Contents/MacOS/OpenJoystickDriver --headless compat set apple-gamecontroller"]
            try? task.run()
            task.waitUntilExit()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.checkVirtualXboxController()
            }
        }
    }
    
    public func refreshStatus() {
        var desc = [CChar](repeating: 0, count: 256)
        let st = tspc_get_connection_status(&desc, 256)
        let msg = String(cString: desc)
        
        DispatchQueue.main.async {
            self.connectionStatus = st
            self.isConnected = (st.rawValue != 0)
            self.isBootMode = (st.rawValue == 1)
            self.statusMessage = msg
            
            if self.isBootMode && self.autoUnlockEnabled {
                self.unlock()
            }
        }
    }
    
    private func checkHardware() {
        var desc = [CChar](repeating: 0, count: 256)
        let st = tspc_get_connection_status(&desc, 256)
        if st != connectionStatus {
            refreshStatus()
        }
    }
    
    public func unlock() {
        statusMessage = "Envoi de la séquence de déblocage 1080°..."
        DispatchQueue.global(qos: .userInitiated).async {
            let res = tspc_unlock_device()
            DispatchQueue.main.async {
                if res == 0 {
                    self.statusMessage = "Déblocage envoyé ! Réinitialisation en cours..."
                } else {
                    self.statusMessage = "Erreur lors du déblocage (\(res))"
                }
            }
            Thread.sleep(forTimeInterval: 2.5)
            DispatchQueue.main.async {
                self.refreshStatus()
            }
        }
    }
    
    public func applyPreset(degrees: Double) {
        currentRange = degrees
    }
    
    public func toggleHttpBridge() {
        if isHttpBridgeRunning {
            tspc_stop_http_server()
        } else {
            _ = tspc_start_http_server(8765)
        }
        isHttpBridgeRunning = tspc_is_http_server_running()
    }
    
    public func applyGfnPreset(_ preset: String) {
        switch preset {
        case "arcade":
            currentRange = 360.0
            gfnTargetRange = 360.0
            gfnSteeringLinearity = 1.0
            gfnDeadzone = 0.02
            autocenterForce = 60.0
            autocenterEnabled = true
        case "balanced":
            currentRange = 540.0
            gfnTargetRange = 540.0
            gfnSteeringLinearity = 1.2
            gfnDeadzone = 0.02
            autocenterForce = 55.0
            autocenterEnabled = true
        case "sim":
            currentRange = 900.0
            gfnTargetRange = 900.0
            gfnSteeringLinearity = 1.35
            gfnDeadzone = 0.01
            autocenterForce = 50.0
            autocenterEnabled = true
        default:
            break
        }
    }
    
    public func testFFB(_ type: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            if type == "left" {
                tspc_test_pulse(-1)
            } else if type == "right" {
                tspc_test_pulse(1)
            } else if type == "rumble" {
                tspc_test_pulse(0)
            } else if type == "center" {
                _ = tspc_set_autocenter(100, true)
                Thread.sleep(forTimeInterval: 0.5)
                _ = tspc_set_autocenter(Int32(self.autocenterForce), self.autocenterEnabled)
            }
        }
    }
    
    public func launchGeForceNowApp() {
        let mapping = "030040694f04000089b6000000070000,Thrustmaster TS-PC Racer,platform:Mac OS X,a:b0,b:b1,x:b2,y:b3,leftshoulder:b4,rightshoulder:b5,back:b8,start:b9,leftx:a0,lefttrigger:a2~,righttrigger:a3~,dpup:h0.1,dpright:h0.2,dpdown:h0.4,dpleft:h0.8,"
        
        ensureVirtualXboxController()
        
        let task = Process()
        task.launchPath = "/bin/sh"
        task.arguments = ["-c", """
            /Applications/OpenJoystickDriver.app/Contents/MacOS/OpenJoystickDriver --headless compat set apple-gamecontroller 2>/dev/null
            launchctl unsetenv SDL_JOYSTICK_MFI
            launchctl unsetenv SDL_JOYSTICK_HIDAPI
            launchctl setenv SDL_GAMECONTROLLERCONFIG "\(mapping)"
            
            if pgrep -x "GeForceNOW" >/dev/null; then
                killall "GeForceNOW" 2>/dev/null
                sleep 1.5
            fi
            
            open -a "/Applications/GeForceNOW.app" \
                --env SDL_GAMECONTROLLERCONFIG="\(mapping)"
        """]
        try? task.run()
    }
}
