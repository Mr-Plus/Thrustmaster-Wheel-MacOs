import SwiftUI
import AppKit

struct GFNForzaView: View {
    @ObservedObject var manager: TSPCManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Image(systemName: "app.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.green)
                    Text("APPLICATION GEFORCE NOW & FORZA HORIZON")
                        .font(.system(size: 15, weight: .black))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    // Status Badge
                    HStack(spacing: 6) {
                        Circle()
                            .fill(manager.isConnected ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                        Text(manager.virtualXboxControllerActive ? "Manette Xbox (macOS) : ACTIVE" : "Manette Xbox : EN ATTENTE")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Color(red: 0.10, green: 0.11, blue: 0.14))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke((manager.virtualXboxControllerActive ? Color.green : Color.orange).opacity(0.5), lineWidth: 1)
                    )
                }
                
                Text("Pilote natif pour l'application macOS GeForceNOW.app. Émulation Xbox sans fil via GameController.framework pour transmission directe à Forza Horizon.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(white: 0.85))
            }
            .padding(.bottom, 2)
            
            // Section 1 : Lancement 1-Clic de GeForce NOW
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: "bolt.circle.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.yellow)
                    Text("LANCEMENT DE L'APPLICATION NATIVE GEFORCE NOW")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                }
                
                Text("L'application GeForce NOW sous macOS utilise le sous-système SDL2 pour ses manettes. En un clic, ce bouton configure les variables d'environnement système et lance GeForceNOW.app avec le support complet de votre TS-PC Racer.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(white: 0.90))
                    .lineSpacing(3)
                
                HStack(spacing: 14) {
                    Button(action: {
                        manager.launchGeForceNowApp()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 13, weight: .bold))
                            Text("LANCER GEFORCE NOW (MODE VOLANT ACTIF)")
                                .font(.system(size: 12, weight: .black))
                        }
                        .foregroundColor(.black)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(Color.green)
                        .cornerRadius(8)
                        .shadow(color: Color.green.opacity(0.3), radius: 6)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.cyan)
                                .font(.system(size: 11))
                            Text("Démarrage automatique configuré")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                        }
                        Text("Variables SDL persistantes installées dans ~/Library/LaunchAgents")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Color(white: 0.75))
                    }
                }
            }
            .padding(18)
            .background(Color(red: 0.13, green: 0.15, blue: 0.18))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.green.opacity(0.3), lineWidth: 1)
            )
            
            // Section 2 : Visualiseur Manette Xbox Émulée en Direct
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: "gamecontroller.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.cyan)
                    Text("CONTRÔLES XBOX REÇUS PAR GEFORCE NOW & FORZA")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                }
                
                HStack(spacing: 16) {
                    // Stick Analogique Gauche (Direction du volant)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Direction (Stick Gauche)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                            Spacer()
                            Text(String(format: "%+.2f", manager.xboxStickX))
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(.cyan)
                        }
                        
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(Color(red: 0.10, green: 0.11, blue: 0.14))
                                
                                // Ligne centrale
                                Rectangle()
                                    .fill(Color.white.opacity(0.4))
                                    .frame(width: 2, height: geo.size.height)
                                    .offset(x: geo.size.width / 2 - 1)
                                
                                // Curseur mobile
                                let center = geo.size.width / 2
                                let width = (geo.size.width / 2) * CGFloat(abs(manager.xboxStickX))
                                let xOffset = manager.xboxStickX >= 0 ? center : center - width
                                
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.cyan)
                                    .frame(width: max(5, width), height: geo.size.height)
                                    .offset(x: xOffset)
                            }
                        }
                        .frame(height: 22)
                        
                        HStack {
                            Text("← Gauche toute")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(Color(white: 0.70))
                            Spacer()
                            Text("Centre")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(Color(white: 0.70))
                            Spacer()
                            Text("Droite toute →")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(Color(white: 0.70))
                        }
                    }
                    .padding(14)
                    .background(Color(red: 0.10, green: 0.11, blue: 0.14))
                    .cornerRadius(10)
                    
                    // Gâchettes LT & RT (Frein & Accélérateur)
                    HStack(spacing: 14) {
                        // Frein LT
                        VStack(spacing: 5) {
                            Text("LT (Frein)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.red)
                            
                            GeometryReader { geo in
                                ZStack(alignment: .bottom) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color(white: 0.12))
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.red)
                                        .frame(height: geo.size.height * CGFloat(manager.xboxLT))
                                }
                            }
                            .frame(width: 30, height: 50)
                            
                            Text(String(format: "%.0f%%", manager.xboxLT * 100))
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                        }
                        
                        // Accélérateur RT
                        VStack(spacing: 5) {
                            Text("RT (Gaz)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.green)
                            
                            GeometryReader { geo in
                                ZStack(alignment: .bottom) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color(white: 0.12))
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.green)
                                        .frame(height: geo.size.height * CGFloat(manager.xboxRT))
                                }
                            }
                            .frame(width: 30, height: 50)
                            
                            Text(String(format: "%.0f%%", manager.xboxRT * 100))
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(14)
                    .background(Color(red: 0.10, green: 0.11, blue: 0.14))
                    .cornerRadius(10)
                    
                    // Boutons Mappés & Palettes
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Boutons & Palettes")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                        
                        HStack(spacing: 6) {
                            XboxBadge(label: "LB (Pal. G)", active: manager.xboxLB, color: .purple)
                            XboxBadge(label: "RB (Pal. D)", active: manager.xboxRB, color: .purple)
                        }
                        
                        HStack(spacing: 6) {
                            XboxBadge(label: "A", active: manager.xboxA, color: .green)
                            XboxBadge(label: "B", active: manager.xboxB, color: .red)
                            XboxBadge(label: "X", active: manager.xboxX, color: .blue)
                            XboxBadge(label: "Y", active: manager.xboxY, color: .yellow)
                        }
                    }
                    .padding(14)
                    .background(Color(red: 0.10, green: 0.11, blue: 0.14))
                    .cornerRadius(10)
                }
            }
            .padding(18)
            .background(Color(red: 0.13, green: 0.15, blue: 0.18))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            
            // Section 3 : Calibrage Forza Horizon & Ressort de Rappel
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.yellow)
                    Text("CALIBRAGE DE DIRECTION & RESSORT DE RAPPEL FFB")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                }
                
                // Presets rapides Forza
                HStack(spacing: 12) {
                    Button(action: { manager.applyGfnPreset("arcade") }) {
                        PresetCard(title: "Forza Vif (360°)", desc: "Drift / Arcade, braquage rapide", isSelected: manager.currentRange == 360)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: { manager.applyGfnPreset("balanced") }) {
                        PresetCard(title: "Forza Équilibré (540°)", desc: "Recommandé pour Forza Horizon", isSelected: manager.currentRange == 540)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: { manager.applyGfnPreset("sim") }) {
                        PresetCard(title: "Forza Simu (900°)", desc: "Grand Tourisme progressif", isSelected: manager.currentRange == 900)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                // Curseurs de réglage
                VStack(spacing: 14) {
                    // Force du rappel physique (Autocentrage)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Force du ressort de rappel physique (Autocentrage TS-PC)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                            Spacer()
                            Text(String(format: "%.0f%%", manager.autocenterForce))
                                .font(.system(size: 13, weight: .black, design: .monospaced))
                                .foregroundColor(.yellow)
                        }
                        Text("Crucial : compense l'absence de FFB du cloud en donnant de la résistance mécanique et du retour au centre réaliste.")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color(white: 0.85))
                        Slider(value: $manager.autocenterForce, in: 0...100, step: 5)
                            .accentColor(.yellow)
                    }
                    
                    // Linéarité
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Linéarité de la direction (Courbe S-Curve)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                            Spacer()
                            Text(String(format: "%.2f", manager.gfnSteeringLinearity))
                                .font(.system(size: 13, weight: .black, design: .monospaced))
                                .foregroundColor(.cyan)
                        }
                        Text("1.0 = direct | 1.2 à 1.4 = précision et stabilité en ligne droite sans coup de volant brusque.")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color(white: 0.85))
                        Slider(value: $manager.gfnSteeringLinearity, in: 1.0...2.0, step: 0.05)
                            .accentColor(.cyan)
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
            
            // Section 4 : Instructions Pas-à-Pas
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.green)
                    Text("GUIDE D'UTILISATION AVEC L'APPLICATION GEFORCE NOW")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    StepItem(step: "1", text: "Gardez votre volant TS-PC Racer branché et l'application TS-PC Control ouverte.")
                    StepItem(step: "2", text: "Cliquez sur le bouton vert 'LANCER GEFORCE NOW' ci-dessus (ou lancez GeForce NOW depuis votre Dock).")
                    StepItem(step: "3", text: "Dans GeForce NOW, lancez Forza Horizon : votre volant est directement reconnu en tant que manette avec retour au centre actif !")
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
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct StepItem: View {
    let step: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(step)
                .font(.system(size: 11, weight: .black))
                .foregroundColor(.black)
                .frame(width: 20, height: 20)
                .background(Color.green)
                .clipShape(Circle())
            Text(text)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color(white: 0.90))
                .lineSpacing(3)
        }
    }
}

struct XboxBadge: View {
    let label: String
    let active: Bool
    let color: Color
    
    var body: some View {
        Text(label)
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(active ? .black : Color(white: 0.95))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(active ? color : Color(white: 0.18))
            .cornerRadius(5)
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(color.opacity(active ? 1.0 : 0.4), lineWidth: 1)
            )
    }
}

struct PresetCard: View {
    let title: String
    let desc: String
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(isSelected ? .white : Color(white: 0.90))
            Text(desc)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(isSelected ? .yellow : Color(white: 0.70))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .background(isSelected ? Color.blue.opacity(0.35) : Color(red: 0.10, green: 0.11, blue: 0.14))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.cyan : Color.white.opacity(0.10), lineWidth: 1.5)
        )
    }
}
