import Foundation
import SwiftUI
import Combine
import AppKit

// ==============================================================================
// TS2GFN — Gestionnaire Matériel IOKit & État Applicatif
// ==============================================================================

public class TSPCManager: ObservableObject {
    // --------------------------------------------------------------------------
    // Statut Matériel & Connexion
    // --------------------------------------------------------------------------
    @Published public var connectionStatus: TSPCConnectionStatus = .init(rawValue: 0)
    @Published public var statusMessage: String = "Recherche du volant..."
    @Published public var isConnected: Bool = false
    @Published public var isBootMode: Bool = false
    @Published public var autoUnlockEnabled: Bool = true
    @Published public var isGfnRunning: Bool = false
    
    // --------------------------------------------------------------------------
    // Télémétrie en direct (affichée dans la modale Télémétrie)
    // --------------------------------------------------------------------------
    @Published public var wheelAngle: Double = 0.0
    @Published public var wheelRaw: UInt16 = 32768
    @Published public var gasPercent: Double = 0.0
    @Published public var brakePercent: Double = 0.0
    @Published public var clutchPercent: Double = 0.0
    @Published public var hatDirection: Int = -1
    @Published public var pressedButtons: Set<Int> = []
    
    // --------------------------------------------------------------------------
    // Réglages Volant & Retour de Force
    // --------------------------------------------------------------------------
    @Published public var currentRange: Double = 1080.0 {
        didSet {
            if currentRange != oldValue {
                _ = tspc_set_rotation_range(UInt16(currentRange))
            }
        }
    }
    
    @Published public var masterGain: Double = 100.0 {
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
    
    // Étalonnage Dynamique Passerelle GFN / Cloud
    @Published public var steeringRatio: Double = 0.5 {
        didSet {
            saveConfig()
        }
    }
    
    @Published public var ffbGain: Double = 1.5 {
        didSet {
            saveConfig()
        }
    }
    
    // État d'ouverture des fenêtres modales
    @Published public var showTelemetryModal: Bool = false
    @Published public var showHelpModal: Bool = false

    // --------------------------------------------------------------------------
    // Mappage des Boutons Volant GT (buttons_mapping.conf)
    // --------------------------------------------------------------------------
    @Published public var btnShiftUp: Int = 2
    @Published public var btnShiftDown: Int = 1
    @Published public var btnA: Int = 6
    @Published public var btnB: Int = 5
    @Published public var btnX: Int = 4
    @Published public var btnY: Int = 3
    @Published public var btnL2: Int = 10
    @Published public var btnR2: Int = 9
    @Published public var btnSelect: Int = 7
    @Published public var btnStart: Int = 8
    @Published public var btnL3: Int = 11
    @Published public var btnR3: Int = 12
    @Published public var btnHome: Int = 13

    public func buttonLabel(for index: Int) -> String {
        if index == btnShiftDown { return "\(index) (Pal. G)" }
        if index == btnShiftUp { return "\(index) (Pal. D)" }
        if index == btnY { return "\(index) (△ Triangle)" }
        if index == btnX { return "\(index) (□ Carré)" }
        if index == btnB { return "\(index) (○ Rond)" }
        if index == btnA { return "\(index) (✕ Croix)" }
        if index == btnSelect { return "\(index) (SE / View)" }
        if index == btnStart { return "\(index) (ST / Menu)" }
        if index == btnR2 { return "\(index) (R2)" }
        if index == btnL2 { return "\(index) (L2)" }
        if index == btnL3 { return "\(index) (11 / L3)" }
        if index == btnR3 { return "\(index) (12 / R3)" }
        if index == btnHome { return "\(index) (PS / Home)" }
        return "Bouton \(index)"
    }

    // --------------------------------------------------------------------------
    // Persistance Configuration (buttons_mapping.conf)
    // --------------------------------------------------------------------------
    public func loadButtonMapping() {
        let paths = [
            "/Users/matthieu.verpillier/Documents/Thrustmaster/buttons_mapping.conf",
            "buttons_mapping.conf",
            "/tmp/tspc_buttons_mapping.conf"
        ]
        for path in paths {
            if let content = try? String(contentsOfFile: path, encoding: .utf8) {
                for line in content.components(separatedBy: .newlines) {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
                    let parts = trimmed.components(separatedBy: "=")
                    if parts.count == 2 {
                        let key = parts[0].trimmingCharacters(in: .whitespaces)
                        let valStr = parts[1].trimmingCharacters(in: .whitespaces)
                        if let dVal = Double(valStr) {
                            if key == "steering_ratio" { steeringRatio = dVal }
                            else if key == "ffb_gain" { ffbGain = dVal }
                        }
                        if let val = Int(valStr) {
                            switch key {
                            case "shift_up": btnShiftUp = val
                            case "shift_down": btnShiftDown = val
                            case "btn_a": btnA = val
                            case "btn_b": btnB = val
                            case "btn_x": btnX = val
                            case "btn_y": btnY = val
                            case "btn_l2": btnL2 = val
                            case "btn_r2": btnR2 = val
                            case "btn_select": btnSelect = val
                            case "btn_start": btnStart = val
                            case "btn_l3": btnL3 = val
                            case "btn_r3": btnR3 = val
                            case "btn_home": btnHome = val
                            default: break
                            }
                        }
                    }
                }
                break
            }
        }
    }

    public func saveConfig() {
        let content = """
        # Configuration du mappage des boutons Thrustmaster TS-PC Racer -> Logitech G29
        # Volant GT / Open Wheel
        shift_up=\(btnShiftUp)
        shift_down=\(btnShiftDown)
        btn_a=\(btnA)
        btn_b=\(btnB)
        btn_x=\(btnX)
        btn_y=\(btnY)
        btn_l2=\(btnL2)
        btn_r2=\(btnR2)
        btn_select=\(btnSelect)
        btn_start=\(btnStart)
        btn_l3=\(btnL3)
        btn_r3=\(btnR3)
        btn_home=\(btnHome)

        # Calibration Angle & FFB
        steering_ratio=\(String(format: "%.2f", steeringRatio))
        ffb_gain=\(String(format: "%.2f", ffbGain))
        \n
        """
        let paths = [
            "/Users/matthieu.verpillier/Documents/Thrustmaster/buttons_mapping.conf",
            "/tmp/tspc_buttons_mapping.conf"
        ]
        for p in paths {
            try? content.write(toFile: p, atomically: true, encoding: .utf8)
        }
    }

    public func launchCalibrationAssistant() {
        let script = """
        tell application "Terminal"
            activate
            do script "cd '/Users/matthieu.verpillier/Documents/Thrustmaster' && ./tspc-cli calibrate-buttons"
        end tell
        """
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
        }
    }

    // --------------------------------------------------------------------------
    // Cycle de vie & Initialisation IOKit
    // --------------------------------------------------------------------------
    private var pollTimer: Timer?

    public init() {
        tspc_init()
        let r = tspc_get_current_range()
        currentRange = (r >= 140 && r <= 1080) ? Double(r) : 1080.0
        pedalsInverted = tspc_get_pedals_inverted()
        loadButtonMapping()
        
        setupCallbacks()
        refreshStatus()
        
        // Surveillance matérielle et processus en arrière-plan
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            self?.checkHardware()
        }
    }

    deinit {
        pollTimer?.invalidate()
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
        
        let connCallback: TSPCConnectionCallback = { status, descPtr, context in
            guard let ctx = context else { return }
            let manager = Unmanaged<TSPCManager>.fromOpaque(ctx).takeUnretainedValue()
            let msg = descPtr != nil ? String(cString: descPtr!) : ""
            
            DispatchQueue.main.async {
                manager.connectionStatus = status
                manager.isConnected = (status.rawValue != 0)
                manager.isBootMode = (status.rawValue == 1)
                manager.statusMessage = msg
                
                if manager.isBootMode && manager.autoUnlockEnabled {
                    manager.unlock()
                }
            }
        }
        
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        tspc_start_listening(telemCallback, connCallback, selfPtr)
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
        
        // Détection instantanée et légère en mémoire de GeForce NOW (zéro sous-processus/fork)
        let running = NSWorkspace.shared.runningApplications.contains { app in
            if let bid = app.bundleIdentifier, bid.contains("com.nvidia.gfnpc") { return true }
            if let name = app.localizedName, name.contains("GeForce NOW") || name.contains("GeForceNOW") { return true }
            return false
        }
        if isGfnRunning != running {
            isGfnRunning = running
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

    // --------------------------------------------------------------------------
    // Lancement de GeForce NOW
    // --------------------------------------------------------------------------
    public func launchGeForceNowApp() {
        let defaultScript = "/Users/matthieu.verpillier/Documents/Thrustmaster/Lancer GeForce NOW (Volant).command"
        let scriptPath: String
        if FileManager.default.fileExists(atPath: defaultScript) {
            scriptPath = defaultScript
        } else if let bundleScript = Bundle.main.path(forResource: "Lancer GeForce NOW (Volant)", ofType: "command") {
            scriptPath = bundleScript
        } else {
            scriptPath = defaultScript
        }
        let task = Process()
        task.launchPath = "/bin/bash"
        task.arguments = [scriptPath]
        try? task.run()
    }
}
