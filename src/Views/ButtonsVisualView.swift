import SwiftUI

struct ButtonsVisualView: View {
    @ObservedObject var manager: TSPCManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "circle.grid.3x3.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.yellow)
                Text("BOUTONS & CROIX DIRECTIONNELLE")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: {
                    manager.launchCalibrationAssistant()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "slider.horizontal.below.rectangle")
                            .font(.system(size: 10, weight: .bold))
                        Text("Calibrer")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue)
                    .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: {
                    manager.launchFfbDebugger()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                            .font(.system(size: 10, weight: .bold))
                        Text("Moniteur FFB")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(red: 0.12, green: 0.55, blue: 0.35))
                    .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Ouvrir l'inspecteur télémétrique FFB en direct (GeForce NOW -> TS-PC)")

                Button(action: {
                    manager.loadButtonMapping()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(5)
                        .background(Color(white: 0.25))
                        .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Recharger buttons_mapping.conf")
            }
            
            HStack(alignment: .top, spacing: 18) {
                // D-Pad Widget
                VStack(spacing: 6) {
                    Text("D-PAD")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                    
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(white: 0.16))
                            .frame(width: 84, height: 84)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            )
                        
                        // Up
                        Image(systemName: "arrowtriangle.up.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(isDirActive([0, 1, 7]) ? .yellow : Color(white: 0.45))
                            .offset(y: -26)
                        
                        // Down
                        Image(systemName: "arrowtriangle.down.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(isDirActive([3, 4, 5]) ? .yellow : Color(white: 0.45))
                            .offset(y: 26)
                        
                        // Left
                        Image(systemName: "arrowtriangle.left.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(isDirActive([5, 6, 7]) ? .yellow : Color(white: 0.45))
                            .offset(x: -26)
                        
                        // Right
                        Image(systemName: "arrowtriangle.right.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(isDirActive([1, 2, 3]) ? .yellow : Color(white: 0.45))
                            .offset(x: 26)
                        
                        // Center dot
                        Circle()
                            .fill(manager.hatDirection >= 0 ? Color.yellow : Color(white: 0.35))
                            .frame(width: 9, height: 9)
                    }
                }
                .padding(10)
                .background(Color(white: 0.12))
                .cornerRadius(10)
                
                // Button Grid (1 to 13)
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 8),
                    GridItem(.flexible(), spacing: 8),
                    GridItem(.flexible(), spacing: 8),
                    GridItem(.flexible(), spacing: 8)
                ], spacing: 8) {
                    ForEach(1...13, id: \.self) { btnIndex in
                        let isPressed = manager.pressedButtons.contains(btnIndex)
                        
                        HStack(spacing: 6) {
                            Circle()
                                .fill(isPressed ? Color.red : Color(white: 0.45))
                                .frame(width: 8, height: 8)
                                .shadow(color: isPressed ? .red : .clear, radius: 4)
                            
                            Text(manager.buttonLabel(for: btnIndex))
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .padding(.horizontal, 6)
                        .background(isPressed ? Color.red.opacity(0.4) : Color(white: 0.20))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(isPressed ? Color.red : Color.white.opacity(0.18), lineWidth: 1)
                        )
                        .scaleEffect(isPressed ? 1.04 : 1.0)
                        .animation(.easeInOut(duration: 0.08), value: isPressed)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(red: 0.13, green: 0.15, blue: 0.18))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
    
    private func isDirActive(_ dirs: [Int]) -> Bool {
        return dirs.contains(manager.hatDirection)
    }
}
