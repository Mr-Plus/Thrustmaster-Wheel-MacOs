import SwiftUI

struct ButtonsVisualView: View {
    let pressedButtons: Set<Int>
    let hatDirection: Int
    
    // Mapping common Thrustmaster buttons
    let buttonLabels: [Int: String] = [
        1: "1 (X)",
        2: "2 (A)",
        3: "3 (B)",
        4: "4 (Y)",
        5: "5 (L1)",
        6: "6 (R1)",
        7: "7 (L2)",
        8: "8 (R2)",
        9: "9 (SELECT)",
        10: "10 (START)",
        11: "11 (L3)",
        12: "12 (R3)",
        13: "13 (MODE)"
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "circle.grid.3x3.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.yellow)
                Text("BOUTONS & CROIX DIRECTIONNELLE")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
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
                            .fill(hatDirection >= 0 ? Color.yellow : Color(white: 0.35))
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
                        let isPressed = pressedButtons.contains(btnIndex)
                        
                        HStack(spacing: 6) {
                            Circle()
                                .fill(isPressed ? Color.red : Color(white: 0.45))
                                .frame(width: 8, height: 8)
                                .shadow(color: isPressed ? .red : .clear, radius: 4)
                            
                            Text(buttonLabels[btnIndex] ?? "BTN \(btnIndex)")
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
        return dirs.contains(hatDirection)
    }
}
