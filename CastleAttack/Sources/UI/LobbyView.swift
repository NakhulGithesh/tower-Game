import SwiftUI

public struct LobbyView: View {
    @ObservedObject var network: NetworkManager
    var onStartGame: () -> Void
    
    @AppStorage("savedServerURL") private var savedServerURL: String = "ws://localhost:8080"
    @State private var serverURLInput: String = ""
    @State private var radarPulse = false
    @State private var hasAutoLaunched = false
    
    public init(network: NetworkManager, onStartGame: @escaping () -> Void) {
        self.network = network
        self.onStartGame = onStartGame
    }
    
    public var body: some View {
        ZStack {
            // Atmospheric Dark Twilight Gradient
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.09, blue: 0.16),
                    Color(red: 0.04, green: 0.05, blue: 0.08)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            // Atmospheric Golden Star Particles
            GeometryReader { proxy in
                ForEach(0..<20, id: \.self) { i in
                    Circle()
                        .fill(Color.yellow.opacity(0.12))
                        .frame(width: CGFloat((i % 4) * 2 + 3), height: CGFloat((i % 4) * 2 + 3))
                        .position(
                            x: CGFloat((i * 47) % Int(max(proxy.size.width, 100))),
                            y: CGFloat((i * 73) % Int(max(proxy.size.height, 100)))
                        )
                }
            }
            .ignoresSafeArea()
            
            VStack(spacing: 16) {
                // Header Title & Emblems
                headerView
                    .padding(.top, 16)
                
                Spacer()
                
                // Main Content depending on connection status
                switch network.status {
                case .disconnected:
                    connectionSetupView
                    
                case .connecting(let url):
                    connectingRadarView(url: url)
                    
                case .connected(let role, let statusText):
                    connectedLobbyView(role: role, statusText: statusText)
                    
                case .error(let message):
                    errorStateView(message: message)
                }
                
                Spacer()
                
                // Bottom Status Bar
                bottomStatusBar
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .onAppear {
            if serverURLInput.isEmpty {
                serverURLInput = savedServerURL.isEmpty ? "ws://localhost:8080" : savedServerURL
            }
            setupCallbacks()
        }
    }
    
    private func setupCallbacks() {
        network.onMatchReady = {
            guard !hasAutoLaunched else { return }
            hasAutoLaunched = true
            // Smooth delayed transition into arena
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                onStartGame()
            }
        }
    }
    
    // MARK: - Header
    private var headerView: some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: "shield.checkered")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.yellow)
                
                Text("CASTLE ATTACK")
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .orange.opacity(0.6), radius: 8, x: 0, y: 0)
                
                Image(systemName: "flame.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.red)
            }
            
            Text("Real-Time 2D Physics & Strategy • Online WebSocket Relay")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(Color.white.opacity(0.65))
        }
    }
    
    // MARK: - Connection Setup View (URL Input + Buttons)
    private var connectionSetupView: some View {
        VStack(spacing: 16) {
            // URL Input Card
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "network")
                        .foregroundColor(.cyan)
                    Text("ARENA RELAY SERVER")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundColor(.cyan)
                }
                
                HStack {
                    Image(systemName: "globe")
                        .foregroundColor(.gray)
                    
                    TextField("ws://192.168.1.x:8080 or wss://ngrok...", text: $serverURLInput)
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .keyboardType(.URL)
                    
                    if !serverURLInput.isEmpty {
                        Button(action: { serverURLInput = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color(white: 0.08))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
                
                Text("Enter local IP port 8080 or public ngrok URL to challenge another iPhone over the internet.")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(.gray)
                    .padding(.horizontal, 4)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(white: 0.12).opacity(0.9))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(LinearGradient(colors: [.blue.opacity(0.5), .purple.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5)
                    )
            )
            
            // Primary Connect Button
            Button(action: {
                let trimmed = serverURLInput.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                savedServerURL = trimmed
                hasAutoLaunched = false
                network.connect(to: trimmed)
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 18, weight: .black))
                    Text("CONNECT TO ARENA")
                        .font(.system(size: 16, weight: .black, design: .rounded))
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(
                    LinearGradient(
                        colors: [Color.yellow, Color.orange],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(14)
                .shadow(color: .orange.opacity(0.4), radius: 10, y: 4)
            }
            .disabled(serverURLInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(serverURLInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1.0)
            
            // Divider with OR
            HStack {
                Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1)
                Text("OR")
                    .font(.system(size: 11, weight: .black))
                    .foregroundColor(.gray)
                    .padding(.horizontal, 8)
                Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1)
            }
            .padding(.vertical, 4)
            
            // Offline Solo AI Option
            Button(action: {
                hasAutoLaunched = false
                network.startLocalAIMode()
                onStartGame()
            }) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color.green.opacity(0.2))
                            .frame(width: 44, height: 44)
                        Image(systemName: "cpu")
                            .font(.system(size: 20))
                            .foregroundColor(.green)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("PASS & PLAY / SOLO AI")
                            .font(.system(size: 15, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("Instant Practice Battle against AI Bot on Single Phone")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.green.opacity(0.7))
                        .font(.system(size: 14, weight: .bold))
                }
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, minHeight: 68)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(white: 0.10).opacity(0.85))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(LinearGradient(colors: [.green.opacity(0.6), .mint.opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5)
                        )
                )
            }
        }
    }
    
    // MARK: - Connecting Radar View
    private func connectingRadarView(url: String) -> some View {
        VStack(spacing: 20) {
            ZStack {
                ForEach(0..<3) { i in
                    Circle()
                        .stroke(Color.cyan.opacity(0.4), lineWidth: 2)
                        .scaleEffect(radarPulse ? 1.0 + CGFloat(i) * 0.4 : 0.6)
                        .opacity(radarPulse ? 0.0 : 0.8)
                        .animation(
                            Animation.easeOut(duration: 1.6)
                                .repeatForever(autoreverses: false)
                                .delay(Double(i) * 0.4),
                            value: radarPulse
                        )
                        .frame(width: 100, height: 100)
                }
                
                Circle()
                    .fill(Color.cyan)
                    .frame(width: 54, height: 54)
                    .overlay(
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .foregroundColor(.black)
                            .font(.system(size: 24, weight: .bold))
                    )
            }
            .frame(height: 120)
            .onAppear { radarPulse = true }
            
            VStack(spacing: 6) {
                Text("Connecting to relay server...")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text(url)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.cyan)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.horizontal, 24)
            }
            
            Button(action: {
                network.disconnect()
            }) {
                Text("Cancel")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white.opacity(0.85))
                    .padding(.horizontal, 28)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.14))
                    .cornerRadius(10)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
    
    // MARK: - Connected Lobby View
    private func connectedLobbyView(role: PlayerID, statusText: String) -> some View {
        VStack(spacing: 22) {
            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    Circle()
                        .fill(role == .playerA ? Color.blue : Color.red)
                        .frame(width: 16, height: 16)
                    
                    Text(role == .playerA ? "YOU: PLAYER A (ROYAL BLUE)" : "YOU: PLAYER B (CRIMSON RED)")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundColor(role == .playerA ? .cyan : .orange)
                }
                
                Text(statusText)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                
                if role == .playerA && network.connectedPeerName?.contains("Waiting") == true {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .yellow))
                        .scaleEffect(1.2)
                        .padding(.top, 4)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(white: 0.10).opacity(0.92))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(role == .playerA ? Color.blue.opacity(0.6) : Color.red.opacity(0.6), lineWidth: 2)
                    )
            )
            
            // Manual Enter Battle Button (or auto-launches on matchReady)
            Button(action: {
                onStartGame()
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 20, weight: .black))
                    Text("ENTER BATTLE ARENA")
                        .font(.system(size: 17, weight: .black, design: .rounded))
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(
                    LinearGradient(
                        colors: [Color.yellow, Color.orange],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(14)
                .shadow(color: .yellow.opacity(0.4), radius: 12)
            }
            
            HStack(spacing: 24) {
                Button(action: {
                    network.ping()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "bolt")
                        Text("Ping: \(network.latencyMs)ms")
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.cyan)
                }
                
                Button(action: {
                    network.disconnect()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark")
                        Text("Disconnect")
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.red.opacity(0.85))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }
    
    // MARK: - Error State View
    private func errorStateView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 44))
                .foregroundColor(.red)
            
            VStack(spacing: 6) {
                Text("Connection Failed")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text(message)
                    .font(.system(size: 12, weight: .medium))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.gray)
                    .padding(.horizontal, 20)
            }
            
            Button(action: {
                network.disconnect()
            }) {
                Text("Back to Server Setup")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.yellow)
                    .cornerRadius(10)
            }
        }
        .padding(24)
    }
    
    // MARK: - Status Bar
    private var bottomStatusBar: some View {
        HStack {
            HStack(spacing: 6) {
                Circle()
                    .fill(statusIndicatorColor)
                    .frame(width: 8, height: 8)
                Text(statusDescription)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)
            }
            
            Spacer()
            
            if case .connected = network.status {
                HStack(spacing: 4) {
                    Image(systemName: "network")
                        .font(.system(size: 10))
                        .foregroundColor(.green)
                    Text("\(network.latencyMs) ms")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.green)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.45))
        .cornerRadius(10)
    }
    
    private var statusIndicatorColor: Color {
        switch network.status {
        case .disconnected: return .gray
        case .connecting: return .yellow
        case .connected: return .green
        case .error: return .red
        }
    }
    
    private var statusDescription: String {
        switch network.status {
        case .disconnected:
            return "Relay: Offline"
        case .connecting(let url):
            return "Connecting to \(url)"
        case .connected(_, let status):
            return status
        case .error(let msg):
            return "Error: \(msg)"
        }
    }
}
