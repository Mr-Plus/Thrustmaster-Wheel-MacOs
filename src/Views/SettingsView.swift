import SwiftUI

struct SettingsView: View {
    @ObservedObject var manager: TSPCManager
    
    var body: some View {
        VStack(spacing: 20) {
            // Section 1: Plage de Rotation
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: "steeringwheel")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.red)
                    Text("ANGLE DE ROTATION (PLAGE DE BRAQUAGE)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                    Text(String(format: "%.0f°", manager.currentRange))
                        .font(.system(size: 18, weight: .black, design: .monospaced))
                        .foregroundColor(.cyan)
                }
                
                Slider(value: $manager.currentRange, in: 140...1080, step: 10)
                    .accentColor(.cyan)
                
                // Presets
                HStack(spacing: 10) {
                    PresetButton(title: "Kart / F1", degrees: 360, current: manager.currentRange) {
                        manager.applyPreset(degrees: 360)
                    }
                    PresetButton(title: "Rallye", degrees: 540, current: manager.currentRange) {
                        manager.applyPreset(degrees: 540)
                    }
                    PresetButton(title: "GT3 / GT4", degrees: 900, current: manager.currentRange) {
                        manager.applyPreset(degrees: 900)
                    }
                    PresetButton(title: "Drift / Route", degrees: 1080, current: manager.currentRange) {
                        manager.applyPreset(degrees: 1080)
                    }
                }
            }
            .padding(18)
            .background(Color(red: 0.13, green: 0.15, blue: 0.18))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            
            // Section 2: Force Feedback & Centrage
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.yellow)
                    Text("RETOUR DE FORCE & RAPPEL AU CENTRE")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                }
                
                // Autocenter toggle & slider
                VStack(spacing: 8) {
                    HStack {
                        Toggle(isOn: $manager.autocenterEnabled) {
                            Text("Ressort de rappel au centre (Autocentrage matériel)")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .toggleStyle(SwitchToggleStyle(tint: .red))
                        Spacer()
                        Text(String(format: "%.0f%%", manager.autocenterForce))
                            .font(.system(size: 15, weight: .bold, design: .monospaced))
                            .foregroundColor(manager.autocenterEnabled ? .white : Color(white: 0.6))
                    }
                    
                    Slider(value: $manager.autocenterForce, in: 0...100, step: 1)
                        .disabled(!manager.autocenterEnabled)
                        .accentColor(.red)
                }
                
                Divider().background(Color.white.opacity(0.15))
                
                // Master Gain
                VStack(spacing: 8) {
                    HStack {
                        Text("Gain global du volant (Master FFB Gain)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                        Spacer()
                        Text(String(format: "%.0f%%", manager.masterGain))
                            .font(.system(size: 15, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    
                    Slider(value: $manager.masterGain, in: 0...100, step: 1)
                        .accentColor(.orange)
                }
            }
            .padding(18)
            .background(Color(red: 0.13, green: 0.15, blue: 0.18))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            
            // Section 3: Tests FFB
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.green)
                    Text("TESTS DU RETOUR DE FORCE (DIAGNOSTIC)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                }
                
                HStack(spacing: 12) {
                    Button(action: { manager.testFFB("center") }) {
                        Label("Test Centrage", systemImage: "arrow.triangle.merge")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(FFBTestButtonStyle())
                    
                    Button(action: { manager.testFFB("left") }) {
                        Label("Traction Gauche", systemImage: "arrow.left")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(FFBTestButtonStyle())
                    
                    Button(action: { manager.testFFB("right") }) {
                        Label("Traction Droite", systemImage: "arrow.right")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(FFBTestButtonStyle())
                    
                    Button(action: { manager.testFFB("rumble") }) {
                        Label("Vibreurs", systemImage: "waveform.path")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(FFBTestButtonStyle())
                }
            }
            .padding(18)
            .background(Color(red: 0.13, green: 0.15, blue: 0.18))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
        }
    }
}

struct PresetButton: View {
    let title: String
    let degrees: Double
    let current: Double
    let action: () -> Void
    
    var isSelected: Bool {
        abs(current - degrees) < 1.0
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                Text(String(format: "%.0f°", degrees))
                    .font(.system(size: 14, weight: .heavy, design: .monospaced))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isSelected ? Color.cyan.opacity(0.3) : Color(white: 0.22))
            .foregroundColor(isSelected ? .cyan : .white)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.cyan : Color.white.opacity(0.18), lineWidth: 1.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct FFBTestButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .bold))
            .padding(.vertical, 11)
            .padding(.horizontal, 10)
            .background(configuration.isPressed ? Color.red.opacity(0.5) : Color(white: 0.22))
            .foregroundColor(.white)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.16), lineWidth: 1)
            )
    }
}
