import SwiftUI

struct PedalsVisualView: View {
    @ObservedObject var manager: TSPCManager
    
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                // Clutch (Embrayage)
                PedalBarView(
                    title: "EMBRAYAGE",
                    subtitle: "CLUTCH",
                    percent: manager.clutchPercent,
                    barColor: Color.blue,
                    glowColor: Color.cyan
                )
                
                // Brake (Frein)
                PedalBarView(
                    title: "FREIN",
                    subtitle: "BRAKE",
                    percent: manager.brakePercent,
                    barColor: Color.red,
                    glowColor: Color.orange
                )
                
                // Gas (Accélérateur)
                PedalBarView(
                    title: "ACCÉLÉRATEUR",
                    subtitle: "THROTTLE",
                    percent: manager.gasPercent,
                    barColor: Color.green,
                    glowColor: Color.mint
                )
            }
            .frame(maxWidth: .infinity)
            
            // Inversion Toggle
            HStack(spacing: 10) {
                Toggle(isOn: Binding(
                    get: { manager.pedalsInverted },
                    set: { manager.pedalsInverted = $0 }
                )) {
                    Text("Inverser axes pédalier (Standard Thrustmaster)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(white: 0.95))
                }
                .toggleStyle(CheckboxToggleStyle())
            }
            .padding(.horizontal, 10)
            .padding(.top, 4)
        }
    }
}

struct PedalBarView: View {
    let title: String
    let subtitle: String
    let percent: Double
    let barColor: Color
    let glowColor: Color
    
    var body: some View {
        VStack(spacing: 10) {
            // Label
            VStack(spacing: 2) {
                Text(title)
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Color(white: 0.70))
            }
            
            // Value Readout
            Text(String(format: "%.0f%%", percent))
                .font(.system(size: 15, weight: .heavy, design: .monospaced))
                .foregroundColor(percent > 1.0 ? barColor : Color(white: 0.95))
            
            // Gauge Bar
            ZStack(alignment: .bottom) {
                // Background Track
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(white: 0.12))
                    .frame(width: 48, height: 140)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
                
                // Filled Meter
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        LinearGradient(
                            colors: [barColor.opacity(0.85), glowColor],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: 48, height: max(6, CGFloat(percent / 100.0) * 140))
                    .shadow(color: percent > 5.0 ? barColor.opacity(0.8) : .clear, radius: 8, x: 0, y: 0)
                    .animation(.interactiveSpring(response: 0.08, dampingFraction: 0.8), value: percent)
            }
            
            // Metal Pedal Plate
            RoundedRectangle(cornerRadius: 4)
                .fill(LinearGradient(
                    colors: [Color(white: 0.45), Color(white: 0.28)],
                    startPoint: .top,
                    endPoint: .bottom
                ))
                .frame(width: 54, height: 18)
                .overlay(
                    HStack(spacing: 4) {
                        Circle().fill(Color.black.opacity(0.6)).frame(width: 3.5, height: 3.5)
                        Circle().fill(Color.black.opacity(0.6)).frame(width: 3.5, height: 3.5)
                        Circle().fill(Color.black.opacity(0.6)).frame(width: 3.5, height: 3.5)
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(red: 0.16, green: 0.18, blue: 0.22))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
}
