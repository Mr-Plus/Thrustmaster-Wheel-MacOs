import SwiftUI

struct GamesHelpView: View {
    @ObservedObject var manager: TSPCManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            VStack(alignment: .leading, spacing: 5) {
                Text("GUIDE DE COMPATIBILITÉ & JEUX")
                    .font(.system(size: 15, weight: .black))
                    .foregroundColor(.white)
                Text("Utiliser votre Thrustmaster TS-PC Racer sur macOS M1 / M2 / M3 / M4 / M5")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(white: 0.75))
            }
            
            // Section 1: Jeux Natifs
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "applelogo")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                    Text("1. Jeux macOS Natifs (GRID Legends, Dirt Rally, F1 2017...)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                }
                Text("Une fois débloqué par cette application en mode actif (0xb689), le TS-PC Racer expose une interface HID Joystick standard universelle. Tous les jeux Mac reconnaissent immédiatement l'axe de direction 16-bit haute précision (0-65535), les 3 pédales et les 13 boutons dans leurs menus de configuration de commandes.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(white: 0.90))
                    .lineSpacing(4)
            }
            .padding(16)
            .background(Color(red: 0.13, green: 0.15, blue: 0.18))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            
            // Section 2: CrossOver / Whisky / Wine
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "gamecontroller.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.cyan)
                    Text("2. Émulation Windows (Whisky, CrossOver, Wine, GPTK)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                }
                Text("Les simulations Windows (Assetto Corsa, Automobilista 2, BeamNG, iRacing, F1 24) tournant sous Wine reçoivent directement les entrées manette/volant. Pour le Force Feedback en jeu, cette application maintient l'autocentrage matériel et le gain, et s'intègre avec le pont direct crossover-wheel sans nécessiter de pilote noyau ou de modification SIP.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(white: 0.90))
                    .lineSpacing(4)
            }
            .padding(16)
            .background(Color(red: 0.13, green: 0.15, blue: 0.18))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            
            // Section 3: Profils Rapides en 1 Clic
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.yellow)
                    Text("PROFILS DE SIMULATION RECOMMANDÉS (1 CLIC)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                }
                
                HStack(spacing: 12) {
                    ProfileCard(title: "F1 / Monoplace", range: 360, gain: 85, center: 60) {
                        manager.currentRange = 360
                        manager.masterGain = 85
                        manager.autocenterForce = 60
                        manager.autocenterEnabled = true
                    }
                    ProfileCard(title: "Rallye / Dirt", range: 540, gain: 75, center: 35) {
                        manager.currentRange = 540
                        manager.masterGain = 75
                        manager.autocenterForce = 35
                        manager.autocenterEnabled = true
                    }
                    ProfileCard(title: "GT3 / Endurance", range: 900, gain: 80, center: 45) {
                        manager.currentRange = 900
                        manager.masterGain = 80
                        manager.autocenterForce = 45
                        manager.autocenterEnabled = true
                    }
                    ProfileCard(title: "Route / Drift", range: 1080, gain: 65, center: 50) {
                        manager.currentRange = 1080
                        manager.masterGain = 65
                        manager.autocenterForce = 50
                        manager.autocenterEnabled = true
                    }
                }
            }
            .padding(16)
            .background(Color(red: 0.13, green: 0.15, blue: 0.18))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ProfileCard: View {
    let title: String
    let range: Double
    let gain: Double
    let center: Double
    let applyAction: () -> Void
    
    var body: some View {
        Button(action: applyAction) {
            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                
                Text(String(format: "%.0f°", range))
                    .font(.system(size: 16, weight: .black, design: .monospaced))
                    .foregroundColor(.cyan)
                
                Text(String(format: "Gain: %.0f%% | C: %.0f%%", gain, center))
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Color(white: 0.75))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color(white: 0.22))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.16), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
