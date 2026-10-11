import SwiftUI

struct DashboardView: View {
    @ObservedObject var manager: TSPCManager
    
    var body: some View {
        VStack(spacing: 20) {
            HStack(alignment: .top, spacing: 22) {
                // Left Column: Steering Wheel Visualizer
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 8) {
                        Image(systemName: "steeringwheel")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.red)
                        Text("VOLANT EN DIRECT")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    WheelVisualView(
                        angle: manager.wheelAngle,
                        maxRange: manager.currentRange
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color(red: 0.13, green: 0.15, blue: 0.18))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
                }
                .frame(width: 330)
                
                // Right Column: Pedals & Buttons
                VStack(spacing: 18) {
                    // Pedals Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "speedometer")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.cyan)
                            Text("PÉDALIER (3 AXES)")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                        }
                        
                        PedalsVisualView(manager: manager)
                    }
                    .padding(16)
                    .background(Color(red: 0.13, green: 0.15, blue: 0.18))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
                    
                    // Buttons Section
                    ButtonsVisualView(
                        pressedButtons: manager.pressedButtons,
                        hatDirection: manager.hatDirection
                    )
                }
            }
        }
    }
}
