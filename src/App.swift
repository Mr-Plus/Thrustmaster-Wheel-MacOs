import SwiftUI
import AppKit

// ==============================================================================
// TS2GFN — Interface Épurée (2 Colonnes conforme à la maquette)
// ==============================================================================

struct MainContentView: View {
    @StateObject private var manager = TSPCManager()
    
    private static let appLogo: NSImage? = {
        if let imgPath = Bundle.main.path(forResource: "logo_transparent", ofType: "png"),
           let img = NSImage(contentsOfFile: imgPath) {
            return img
        }
        return NSImage(contentsOfFile: "/Users/matthieu.verpillier/Documents/Thrustmaster/src/logo_transparent.png")
    }()
    
    var body: some View {
        VStack(spacing: 0) {
            // ------------------------------------------------------------------
            // 1. Barre d'en-tête (Top Bar)
            // ------------------------------------------------------------------
            HStack(spacing: 12) {
                // Logo & Titre
                HStack(spacing: 12) {
                    if let logo = Self.appLogo {
                        Image(nsImage: logo)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 38, height: 38)
                    } else {
                        ZStack {
                            Circle()
                                .fill(Color(red: 0.85, green: 0.25, blue: 0.25).opacity(0.20))
                                .frame(width: 34, height: 34)
                            Image(systemName: "steeringwheel")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(Color(red: 0.95, green: 0.35, blue: 0.35))
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("TS2GFN")
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("THRUSTMASTER ➔ GEFORCE NOW")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(Color(white: 0.55))
                    }
                }
                
                Spacer()
                
                // 3 Boutons carrés d'action en haut à droite
                HStack(spacing: 8) {
                    // 1. Télémétrie
                    Button(action: { manager.showTelemetryModal = true }) {
                        Image(systemName: "clock")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Color(white: 0.80))
                            .frame(width: 32, height: 32)
                            .background(Color(white: 0.17))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Télémétrie en direct & Test du matériel")
                    
                    // 2. Notice / Aide
                    Button(action: { manager.showHelpModal = true }) {
                        Image(systemName: "questionmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Color(white: 0.80))
                            .frame(width: 32, height: 32)
                            .background(Color(white: 0.17))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Guide & Notice d'utilisation")
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 18)
            .padding(.bottom, 14)
            
            // ------------------------------------------------------------------
            // 2. Contenu Principal : Layout 2 Colonnes
            // ------------------------------------------------------------------
            HStack(alignment: .top, spacing: 32) {
                
                // ==============================================================
                // COLONNE GAUCHE : LANCEMENT GEFORCE NOW
                // ==============================================================
                VStack(alignment: .leading, spacing: 14) {
                    // Badge Statut GeForce NOW
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(manager.isGfnRunning ? Color(red: 0.40, green: 0.85, blue: 0.45) : Color(white: 0.50))
                        
                        Text(manager.isGfnRunning ? "GeForce NOW en cours" : "Prêt au lancement")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(manager.isGfnRunning ? Color(red: 0.80, green: 0.95, blue: 0.80) : Color(white: 0.70))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        manager.isGfnRunning
                        ? Color(red: 0.15, green: 0.30, blue: 0.18).opacity(0.85)
                        : Color(white: 0.16)
                    )
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                manager.isGfnRunning ? Color(red: 0.35, green: 0.70, blue: 0.40).opacity(0.4) : Color.white.opacity(0.08),
                                lineWidth: 1
                            )
                    )
                    
                    // Grand bouton vert GeForce NOW
                    Button(action: {
                        manager.launchGeForceNowApp()
                    }) {
                        VStack(spacing: 16) {
                            Spacer()
                            
                            // Icône triangle Play
                            Image(systemName: "play.fill")
                                .font(.system(size: 38, weight: .black))
                                .foregroundColor(.black)
                            
                            // Libellé bouton
                            Text(manager.isGfnRunning ? "RELANCER GEFORCE NOW" : "LANCER GEFORCE NOW")
                                .font(.system(size: 13, weight: .black, design: .rounded))
                                .foregroundColor(.black)
                                .multilineTextAlignment(.center)
                            
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.50, green: 0.78, blue: 0.44),
                                    Color(red: 0.46, green: 0.74, blue: 0.40)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .cornerRadius(18)
                        .shadow(color: Color(red: 0.46, green: 0.74, blue: 0.40).opacity(0.35), radius: 10, y: 4)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .frame(width: 250)
                .frame(maxHeight: .infinity)
                
                // ==============================================================
                // ==============================================================
                // COLONNE DROITE : RÉGLAGES DU VOLANT & RETOUR DE FORCE
                // ==============================================================
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {
                        
                        // En-tête Réglages, Badge Volant & Bouton Défaut
                        HStack(alignment: .center) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("RÉGLAGES DU VOLANT & RETOUR DE FORCE")
                                    .font(.system(size: 13, weight: .black))
                                    .foregroundColor(Color(white: 0.95))
                                
                                // Badge Statut Volant
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(badgeColor)
                                        .frame(width: 7, height: 7)
                                        .shadow(color: badgeColor.opacity(0.8), radius: 3)
                                    
                                    Text(manager.statusMessage)
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(badgeTextColor)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(badgeBackgroundColor)
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(badgeColor.opacity(0.35), lineWidth: 1)
                                )
                            }
                            
                            Spacer()
                            
                            // Bouton "Défaut" (Réinitialisation officielle constructeur)
                            Button(action: {
                                manager.resetToThrustmasterDefaults()
                            }) {
                                HStack(spacing: 5) {
                                    Image(systemName: "arrow.counterclockwise")
                                        .font(.system(size: 10, weight: .bold))
                                    Text("Défaut")
                                        .font(.system(size: 11, weight: .bold))
                                }
                                .foregroundColor(Color(white: 0.85))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color(white: 0.18))
                                .cornerRadius(6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            .help("Rétablir les paramètres par défaut officiels Thrustmaster")
                        }
                        
                        // 1. Paramètres Principaux des Forces (Master Gain constructeur)
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Ajuster l'ensemble des forces")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(Color(white: 0.90))
                                Spacer()
                                Text("\(Int(manager.masterGain))%")
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    .foregroundColor(Color(red: 0.95, green: 0.45, blue: 0.40))
                            }
                            
                            Slider(value: $manager.masterGain, in: 0...100, step: 1)
                                .accentColor(Color(red: 0.95, green: 0.45, blue: 0.40))
                            
                            Text("Gain général moteur (défaut constructeur : 75%).")
                                .font(.system(size: 10, weight: .regular))
                                .foregroundColor(Color(white: 0.50))
                        }
                        .padding(14)
                        .background(Color(white: 0.14))
                        .cornerRadius(10)
                        
                        // 2. Paramètres de Retour au Centre (Game vs Wheel)
                        VStack(alignment: .leading, spacing: 12) {
                            Text("PARAMÈTRES DE RETOUR AU CENTRE")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Color(white: 0.70))
                            
                            HStack(spacing: 24) {
                                // Option 1 : via le jeu (Recommandé)
                                Button(action: {
                                    manager.autocenterMode = .game
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: manager.autocenterMode == .game ? "largecircle.fill.circle" : "circle")
                                            .font(.system(size: 15))
                                            .foregroundColor(manager.autocenterMode == .game ? Color(red: 0.46, green: 0.74, blue: 0.40) : Color(white: 0.45))
                                        
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text("via le jeu (Recommandé)")
                                                .font(.system(size: 12, weight: manager.autocenterMode == .game ? .bold : .medium))
                                                .foregroundColor(manager.autocenterMode == .game ? .white : Color(white: 0.75))
                                        }
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                // Option 2 : via le volant
                                Button(action: {
                                    manager.autocenterMode = .wheel
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: manager.autocenterMode == .wheel ? "largecircle.fill.circle" : "circle")
                                            .font(.system(size: 15))
                                            .foregroundColor(manager.autocenterMode == .wheel ? Color(red: 0.35, green: 0.65, blue: 0.95) : Color(white: 0.45))
                                        
                                        Text("via le volant")
                                            .font(.system(size: 12, weight: manager.autocenterMode == .wheel ? .bold : .medium))
                                            .foregroundColor(manager.autocenterMode == .wheel ? .white : Color(white: 0.75))
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            
                            if manager.autocenterMode == .wheel {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text("Ajuster la force de retour au centre")
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundColor(Color(white: 0.80))
                                        Spacer()
                                        Text("\(Int(manager.autocenterWheelForce))%")
                                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                                            .foregroundColor(Color(red: 0.35, green: 0.65, blue: 0.95))
                                    }
                                    
                                    Slider(value: $manager.autocenterWheelForce, in: 0...100, step: 5)
                                        .accentColor(Color(red: 0.35, green: 0.65, blue: 0.95))
                                }
                                .padding(.top, 4)
                            } else {
                                HStack(spacing: 6) {
                                    Image(systemName: "checkmark.seal.fill")
                                        .font(.system(size: 11))
                                        .foregroundColor(Color(red: 0.46, green: 0.74, blue: 0.40))
                                    Text("Ressort interne désactivé : le retour au centre est calculé par la physique du jeu.")
                                        .font(.system(size: 10, weight: .regular))
                                        .foregroundColor(Color(white: 0.60))
                                }
                                .padding(.top, 2)
                            }
                        }
                        .padding(14)
                        .background(Color(white: 0.14))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(
                                    manager.autocenterMode == .game
                                    ? Color(red: 0.46, green: 0.74, blue: 0.40).opacity(0.35)
                                    : Color.white.opacity(0.08),
                                    lineWidth: 1
                                )
                        )
                        
                        // 3. Angle de rotation matériel
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Angle de rotation matériel")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(Color(white: 0.90))
                                Spacer()
                                Text("\(Int(manager.currentRange))°")
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    .foregroundColor(Color(red: 0.35, green: 0.65, blue: 0.95))
                            }
                            
                            Slider(value: $manager.currentRange, in: 140...1080, step: 10)
                                .accentColor(Color(red: 0.35, green: 0.65, blue: 0.95))
                            
                            // 4 Boutons Presets
                            HStack(spacing: 8) {
                                ForEach([360.0, 540.0, 900.0, 1080.0], id: \.self) { deg in
                                    Button(action: { manager.currentRange = deg }) {
                                        Text("\(Int(deg))°")
                                            .font(.system(size: 11, weight: manager.currentRange == deg ? .bold : .medium))
                                            .foregroundColor(manager.currentRange == deg ? .white : Color(white: 0.65))
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 6)
                                            .background(
                                                manager.currentRange == deg
                                                ? Color(red: 0.18, green: 0.36, blue: 0.52)
                                                : Color(white: 0.16)
                                            )
                                            .cornerRadius(6)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 6)
                                                    .stroke(
                                                        manager.currentRange == deg
                                                        ? Color(red: 0.35, green: 0.65, blue: 0.95)
                                                        : Color.white.opacity(0.08),
                                                        lineWidth: 1
                                                    )
                                            )
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                        
                        // 4. Sensibilité & FFB Cloud
                        HStack(spacing: 20) {
                            // Sensibilité braquage
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("Sensibilité braquage")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(Color(white: 0.85))
                                    Spacer()
                                    Text(String(format: "%.2f %@", manager.steeringRatio, manager.steeringRatio == 0.5 ? "(1:1)" : ""))
                                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                                        .foregroundColor(Color(red: 0.95, green: 0.80, blue: 0.35))
                                }
                                Slider(value: $manager.steeringRatio, in: 0.30...1.20, step: 0.05)
                                    .accentColor(Color(red: 0.95, green: 0.80, blue: 0.35))
                            }
                            .frame(maxWidth: .infinity)
                            
                            // Puissance FFB Cloud
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("Puissance FFB Cloud")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(Color(white: 0.85))
                                    Spacer()
                                    Text(String(format: "%.2fx", manager.ffbGain))
                                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                                        .foregroundColor(Color(red: 0.95, green: 0.45, blue: 0.40))
                                }
                                Slider(value: $manager.ffbGain, in: 0.80...2.20, step: 0.05)
                                    .accentColor(Color(red: 0.95, green: 0.45, blue: 0.40))
                            }
                            .frame(maxWidth: .infinity)
                        }
                        
                        // 5. Section repliable : Forces Détaillées (Constante, Périodique, Ressort, Amortisseur, Boost)
                        DisclosureGroup {
                            VStack(spacing: 12) {
                                HStack(spacing: 20) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Text("Forces Constantes")
                                                .font(.system(size: 11))
                                                .foregroundColor(Color(white: 0.75))
                                            Spacer()
                                            Text("\(Int(manager.gainConstant))%")
                                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                                .foregroundColor(Color(white: 0.85))
                                        }
                                        Slider(value: $manager.gainConstant, in: 0...100, step: 5)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Text("Forces Périodiques")
                                                .font(.system(size: 11))
                                                .foregroundColor(Color(white: 0.75))
                                            Spacer()
                                            Text("\(Int(manager.gainPeriodic))%")
                                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                                .foregroundColor(Color(white: 0.85))
                                        }
                                        Slider(value: $manager.gainPeriodic, in: 0...100, step: 5)
                                    }
                                }
                                
                                HStack(spacing: 20) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Text("Forces de Ressort")
                                                .font(.system(size: 11))
                                                .foregroundColor(Color(white: 0.75))
                                            Spacer()
                                            Text("\(Int(manager.gainSpring))%")
                                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                                .foregroundColor(Color(white: 0.85))
                                        }
                                        Slider(value: $manager.gainSpring, in: 0...100, step: 5)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Text("Forces d'Amortisseur")
                                                .font(.system(size: 11))
                                                .foregroundColor(Color(white: 0.75))
                                            Spacer()
                                            Text("\(Int(manager.gainDamper))%")
                                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                                .foregroundColor(Color(white: 0.85))
                                        }
                                        Slider(value: $manager.gainDamper, in: 0...100, step: 5)
                                    }
                                }
                                
                                HStack {
                                    Toggle("BOOST (Constant + Ressort)", isOn: $manager.boostEnabled)
                                        .font(.system(size: 11, weight: .medium))
                                        .toggleStyle(SwitchToggleStyle(tint: Color(red: 0.95, green: 0.45, blue: 0.40)))
                                    Spacer()
                                }
                                .padding(.top, 4)
                            }
                            .padding(.top, 8)
                        } label: {
                            Text("FORCES DÉTAILLÉES (DÉFAUTS CONSTRUCTEUR)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Color(white: 0.65))
                        }
                        .padding(12)
                        .background(Color(white: 0.13))
                        .cornerRadius(8)
                        
                        // 6. Inverser les pédales
                        HStack(spacing: 12) {
                            Text("Inverser les pédales")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color(white: 0.90))
                            
                            Spacer()
                            
                            Toggle("", isOn: $manager.pedalsInverted)
                                .labelsHidden()
                                .toggleStyle(SwitchToggleStyle(tint: Color(red: 0.50, green: 0.78, blue: 0.44)))
                        }
                        .padding(12)
                        .background(Color(white: 0.13))
                        .cornerRadius(8)
                    }
                    .padding(.trailing, 6)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 24)
            .padding(.top, 10)
            .padding(.bottom, 24)
        }
        .frame(minWidth: 880, minHeight: 610)
        .background(Color(red: 0.11, green: 0.12, blue: 0.15).ignoresSafeArea())
        // Modale Télémétrie
        .sheet(isPresented: $manager.showTelemetryModal) {
            TelemetryModalView(manager: manager)
        }
        // Modale Aide
        .sheet(isPresented: $manager.showHelpModal) {
            HelpModalView(manager: manager)
        }
    }
    
    // Couleurs de badges selon état USB
    private var badgeColor: Color {
        switch manager.connectionStatus.rawValue {
        case 2: return Color.green
        case 1: return Color.yellow
        default: return Color(red: 0.95, green: 0.35, blue: 0.35)
        }
    }
    
    private var badgeBackgroundColor: Color {
        switch manager.connectionStatus.rawValue {
        case 2: return Color.green.opacity(0.15)
        case 1: return Color.yellow.opacity(0.15)
        default: return Color(red: 0.95, green: 0.35, blue: 0.35).opacity(0.15)
        }
    }
    
    private var badgeTextColor: Color {
        switch manager.connectionStatus.rawValue {
        case 2: return Color(white: 0.90)
        case 1: return Color(white: 0.90)
        default: return Color(red: 0.95, green: 0.70, blue: 0.70)
        }
    }
}

// ==============================================================================
// MODALE TÉLÉMÉTRIE & TEST MATÉRIEL (Derrière le bouton Horloge/Speedomètre)
// ==============================================================================
struct TelemetryModalView: View {
    @ObservedObject var manager: TSPCManager
    
    var body: some View {
        VStack(spacing: 0) {
            // Header modal
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "gauge.with.needle")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.cyan)
                    Text("TÉLÉMÉTRIE EN DIRECT & TEST DU MATÉRIEL")
                        .font(.system(size: 13, weight: .black))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                Button(action: { manager.showTelemetryModal = false }) {
                    Text("Fermer")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Color(white: 0.22))
                        .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color(red: 0.12, green: 0.13, blue: 0.16))
            
            ScrollView {
                VStack(spacing: 20) {
                    // Volant & Pédales
                    HStack(alignment: .top, spacing: 20) {
                        VStack(spacing: 10) {
                            Text("VOLANT")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Color(white: 0.70))
                            WheelVisualView(angle: manager.wheelAngle, maxRange: manager.currentRange)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(16)
                        .background(Color(red: 0.13, green: 0.14, blue: 0.17))
                        .cornerRadius(10)
                        
                        VStack(spacing: 10) {
                            Text("PÉDALES")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Color(white: 0.70))
                            PedalsVisualView(manager: manager)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(16)
                        .background(Color(red: 0.13, green: 0.14, blue: 0.17))
                        .cornerRadius(10)
                    }
                    
                    // Boutons du volant GT
                    VStack(alignment: .leading, spacing: 10) {
                        Text("BOUTONS DU VOLANT GT (PRESSER POUR TESTER)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color(white: 0.70))
                        ButtonsVisualView(manager: manager)
                    }
                    .padding(16)
                    .background(Color(red: 0.13, green: 0.14, blue: 0.17))
                    .cornerRadius(10)
                }
                .padding(20)
            }
        }
        .frame(minWidth: 720, minHeight: 600)
        .background(Color(red: 0.08, green: 0.09, blue: 0.11))
    }
}

// ==============================================================================
// MODALE AIDE & NOTICE (?) (Derrière le bouton ?)
// ==============================================================================
struct HelpModalView: View {
    @ObservedObject var manager: TSPCManager
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "questionmark.circle.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color(red: 0.50, green: 0.78, blue: 0.44))
                    Text("GUIDE D'UTILISATION & NOTICE TS2GFN")
                        .font(.system(size: 13, weight: .black))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                Button(action: { manager.showHelpModal = false }) {
                    Text("Fermer")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Color(white: 0.22))
                        .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color(red: 0.12, green: 0.13, blue: 0.16))
            
            VStack(alignment: .leading, spacing: 16) {
                // Section 1
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "steeringwheel")
                            .foregroundColor(Color(red: 0.35, green: 0.65, blue: 0.95))
                        Text("1. Émulation Logitech G29 Native")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                    }
                    Text("TS2GFN convertit dynamiquement le flux USB de votre Thrustmaster TS-PC Racer en un volant Logitech G29 standard pour GeForce NOW. Les jeux cloud reconnaissent nativement les axes, les boutons et le retour de force sans kext ni modification système.")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color(white: 0.80))
                        .lineSpacing(3)
                }
                .padding(14)
                .background(Color(white: 0.12))
                .cornerRadius(8)
                
                // Section 2
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "play.circle.fill")
                            .foregroundColor(Color(red: 0.50, green: 0.78, blue: 0.44))
                        Text("2. Comment jouer")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                    }
                    Text("1. Branchez votre volant TS-PC Racer en USB.\n2. Ajustez l'angle et la force souhaités sur la page principale.\n3. Cliquez sur le grand bouton vert « Lancer GeForce NOW ».\n4. Lancez Forza Horizon 5 ou votre simulation préférée : le volant est directement reconnu !")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color(white: 0.80))
                        .lineSpacing(3)
                }
                .padding(14)
                .background(Color(white: 0.12))
                .cornerRadius(8)
                
                // Section 3
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "tuningfork")
                            .foregroundColor(Color(red: 0.95, green: 0.80, blue: 0.35))
                        Text("3. Réglages recommandés dans Forza Horizon")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                    }
                    Text("Dans le menu Paramètres > Paramètres Volant / Commandes Avancées du jeu :\n• Échelle de la force de centrage : Mettre à 0 (par défaut le jeu applique un ressort dur à l'arrêt qui disparaît en vitesse).\n• Échelle de l'amortisseur : Mettre à 0.1 ou 0.2 (supprime la résistance pâteuse/lourde à basse allure).\n• Sensibilité braquage : 0.50 (synchronisation 1:1 exacte entre votre volant physique et le cockpit).")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color(white: 0.80))
                        .lineSpacing(3)
                }
                .padding(14)
                .background(Color(white: 0.12))
                .cornerRadius(8)
                
                Spacer()
                
                // Footer Informations Système & Version
                VStack(spacing: 6) {
                    Divider().background(Color.white.opacity(0.10))
                    
                    HStack {
                        Text("Passerelle locale IOKit User-Space — Sans kext ni désactivation SIP")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Color(white: 0.55))
                        
                        Spacer()
                        
                        Text("TS2GFN v1.0.0")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(Color(white: 0.75))
                    }
                    .padding(.top, 4)
                }
            }
            .padding(20)
        }
        .frame(minWidth: 560, minHeight: 460)
        .background(Color(red: 0.08, green: 0.09, blue: 0.11))
    }
}

// ==============================================================================
// POINT D'ENTRÉE APPLICATION
// ==============================================================================
@main
struct TS2GFNApp: App {
    var body: some Scene {
        WindowGroup("TS2GFN") {
            MainContentView()
        }
        .windowStyle(HiddenTitleBarWindowStyle())
        .commands {
            SidebarCommands()
        }
    }
}
