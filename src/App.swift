import SwiftUI

struct MainContentView: View {
    @StateObject private var manager = TSPCManager()
    
    var body: some View {
        VStack(spacing: 0) {
            // Top Bar / Status Header
            HStack(spacing: 16) {
                // App Title & Brand
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.red.opacity(0.2))
                            .frame(width: 36, height: 36)
                        Image(systemName: "steeringwheel")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.red)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("THRUSTMASTER TS-PC RACER")
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("PANNEAU DE CONTRÔLE macOS (Apple Silicon)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Color(white: 0.75))
                    }
                }
                
                Spacer()
                
                // Connection Badge
                HStack(spacing: 8) {
                    Circle()
                        .fill(badgeColor)
                        .frame(width: 9, height: 9)
                        .shadow(color: badgeColor.opacity(0.8), radius: 5)
                    
                    Text(manager.statusMessage)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(badgeColor.opacity(0.18))
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(badgeColor.opacity(0.4), lineWidth: 1.5)
                )
                
                // Unlock Button if in boot mode
                if manager.isBootMode {
                    Button(action: { manager.unlock() }) {
                        HStack(spacing: 6) {
                            Image(systemName: "bolt.fill")
                            Text("Activer 1080°")
                        }
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Color.yellow)
                        .cornerRadius(8)
                        .shadow(color: .yellow.opacity(0.4), radius: 4)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                // Refresh Button
                Button(action: { manager.refreshStatus() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color(white: 0.2))
                        .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Rafraîchir la connexion USB")
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
            .background(Color(red: 0.12, green: 0.14, blue: 0.17))
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color.white.opacity(0.12)),
                alignment: .bottom
            )
            
            // Tab Picker Bar
            HStack(spacing: 10) {
                ForEach(TabSelection.allCases) { tab in
                    Button(action: { manager.selectedTab = tab }) {
                        HStack(spacing: 8) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 13, weight: .semibold))
                            Text(tab.rawValue)
                                .font(.system(size: 13, weight: manager.selectedTab == tab ? .bold : .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.vertical, 9)
                        .padding(.horizontal, 18)
                        .background(
                            manager.selectedTab == tab
                            ? LinearGradient(colors: [Color.red.opacity(0.85), Color.red.opacity(0.65)], startPoint: .top, endPoint: .bottom)
                            : LinearGradient(colors: [Color(white: 0.18), Color(white: 0.14)], startPoint: .top, endPoint: .bottom)
                        )
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(manager.selectedTab == tab ? Color.red : Color.white.opacity(0.14), lineWidth: 1)
                        )
                        .shadow(color: manager.selectedTab == tab ? Color.red.opacity(0.3) : .clear, radius: 4)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                Spacer()
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 10)
            .background(Color(red: 0.10, green: 0.11, blue: 0.14))
            
            // Main Tab Content
            ScrollView {
                VStack(spacing: 20) {
                    switch manager.selectedTab {
                    case .dashboard:
                        DashboardView(manager: manager)
                    case .settings:
                        SettingsView(manager: manager)
                    case .geforceNow:
                        GFNForzaView(manager: manager)
                    case .games:
                        GamesHelpView(manager: manager)
                    }
                }
                .padding(22)
            }
            
            // Footer
            HStack {
                Text("Pilote User-Space IOKit (Sans kext / SIP Intact) • VID: 0x044F | PID: 0xB689")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(white: 0.75))
                Spacer()
                Text("TS-PC Racer Control v1.0.0")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color(white: 0.85))
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 10)
            .background(Color(red: 0.10, green: 0.11, blue: 0.13))
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color.white.opacity(0.08)),
                alignment: .top
            )
        }
        .frame(minWidth: 840, minHeight: 660)
        .background(Color(red: 0.08, green: 0.09, blue: 0.11).ignoresSafeArea())
    }
    
    private var badgeColor: Color {
        switch manager.connectionStatus.rawValue {
        case 2: return .green
        case 1: return .yellow
        default: return .red
        }
    }
}

@main
struct TSPCControlApp: App {
    var body: some Scene {
        WindowGroup {
            MainContentView()
        }
        .windowStyle(HiddenTitleBarWindowStyle())
        .commands {
            SidebarCommands()
        }
    }
}
