import SwiftUI

struct WheelVisualView: View {
    let angle: Double
    let maxRange: Double
    
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                // Background subtle degree scale
                Circle()
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [
                                Color.red.opacity(0.8),
                                Color.cyan.opacity(0.8),
                                Color.blue.opacity(0.8),
                                Color.cyan.opacity(0.8),
                                Color.red.opacity(0.8)
                            ]),
                            center: .center
                        ),
                        lineWidth: 4
                    )
                    .frame(width: 250, height: 250)
                    .opacity(0.35)
                
                // Rotatable Steering Wheel
                ZStack {
                    // Outer Rim
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [Color(white: 0.32), Color(white: 0.18), Color(white: 0.28)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 26
                        )
                        .frame(width: 220, height: 220)
                        .shadow(color: .black.opacity(0.6), radius: 8, x: 0, y: 4)
                    
                    // Alcantara Grips (Left & Right)
                    Capsule()
                        .fill(Color(white: 0.22))
                        .frame(width: 28, height: 95)
                        .offset(x: -110)
                    
                    Capsule()
                        .fill(Color(white: 0.22))
                        .frame(width: 28, height: 95)
                        .offset(x: 110)
                    
                    // Center Top Red Marker (12 o'clock stripe)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.red)
                        .frame(width: 14, height: 24)
                        .offset(y: -110)
                    
                    // Metal Spokes (Horizontal & Bottom)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(LinearGradient(
                            colors: [Color(white: 0.45), Color(white: 0.28)],
                            startPoint: .top,
                            endPoint: .bottom
                        ))
                        .frame(width: 190, height: 32)
                    
                    RoundedRectangle(cornerRadius: 6)
                        .fill(LinearGradient(
                            colors: [Color(white: 0.45), Color(white: 0.28)],
                            startPoint: .top,
                            endPoint: .bottom
                        ))
                        .frame(width: 32, height: 95)
                        .offset(y: 40)
                    
                    // Center Hub (Carbon-style Pod)
                    Circle()
                        .fill(RadialGradient(
                            colors: [Color(white: 0.32), Color(white: 0.15)],
                            center: .center,
                            startRadius: 5,
                            endRadius: 55
                        ))
                        .frame(width: 110, height: 110)
                        .overlay(
                            Circle()
                                .stroke(Color(white: 0.45), lineWidth: 3)
                        )
                        .shadow(color: .black.opacity(0.8), radius: 6)
                    
                    // Thrustmaster Badge / Logo styling
                    VStack(spacing: 3) {
                        Text("TS-PC")
                            .font(.system(size: 15, weight: .black, design: .monospaced))
                            .foregroundColor(.white)
                        
                        Text("RACER")
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .foregroundColor(.red)
                    }
                }
                .rotationEffect(.degrees(angle))
                .animation(.interactiveSpring(response: 0.08, dampingFraction: 0.85), value: angle)
            }
            .frame(width: 260, height: 260)
            
            // Angle Readout Badge
            HStack(spacing: 12) {
                HStack(spacing: 6) {
                    Text("BRAQUAGE :")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(white: 0.85))
                    
                    Text(String(format: "%+.1f°", angle))
                        .font(.system(size: 17, weight: .heavy, design: .monospaced))
                        .foregroundColor(abs(angle) < 1.0 ? Color.green : Color.cyan)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color(red: 0.18, green: 0.20, blue: 0.24))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                )
                
                Text(String(format: "MAX: ±%.0f°", maxRange / 2.0))
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(white: 0.85))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color(red: 0.18, green: 0.20, blue: 0.24))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
            }
        }
    }
}
