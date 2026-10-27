import SwiftUI
import SpriteKit

public struct GameView: View {
    @ObservedObject var network: NetworkManager
    var onExit: () -> Void
    
    @State private var scene: GameScene?
    @State private var isPlacementValid: Bool = true
    @State private var isLocalLockedIn: Bool = false
    @State private var isRemoteLockedIn: Bool = false
    @State private var currentPhase: GameScenePhase = .placement
    @State private var currentEnergy: Double = GameConfig.initialEnergy
    
    public init(network: NetworkManager, onExit: @escaping () -> Void) {
        self.network = network
        self.onExit = onExit
    }
    
    public var body: some View {
        GeometryReader { proxy in
            let viewSize = proxy.size
            
            ZStack {
                // SpriteKit Vertical Arena
                if let activeScene = scene {
                    SpriteView(scene: activeScene)
                        .ignoresSafeArea()
                } else {
                    Color.black.ignoresSafeArea()
                }
                
                // HUD Layer depending on game phase
                switch currentPhase {
                case .placement:
                    placementHUDOverlay
                case .countdown(let seconds):
                    countdownHUDOverlay(seconds: seconds)
                case .combat:
                    combatHUDOverlay(viewSize: viewSize)
                case .victory(let winner):
                    GameOverView(
                        winner: winner,
                        localPlayerID: network.localPlayerID,
                        onPlayAgain: {
                            scene?.resetScene()
                            network.send(payload: .gameRestart)
                        },
                        onReturnToLobby: {
                            network.disconnect()
                            onExit()
                        }
                    )
                }
                
                // Top Navigation & Stats Bar
                topStatusBar
            }
            .onAppear {
                setupScene(size: viewSize)
            }
        }
    }
    
    private func setupScene(size: CGSize) {
        // Logical portrait arena dimensions
        let arenaWidth = max(390, size.width)
        let arenaHeight = max(800, size.height)
        let newScene = GameScene(size: CGSize(width: arenaWidth, height: arenaHeight))
        newScene.network = network
        
        newScene.onPlacementValidityChange = { valid in
            self.isPlacementValid = valid
        }
        
        newScene.onPhaseChange = { phase in
            self.currentPhase = phase
            self.isLocalLockedIn = newScene.isLocalLockedIn
            self.isRemoteLockedIn = newScene.isRemoteLockedIn
        }
        
        newScene.onEnergyUpdate = { energy in
            self.currentEnergy = energy
        }
        
        self.scene = newScene
    }
    
    // MARK: - Combat HUD Overlay (Card Tray with Direct Drag)
    private func combatHUDOverlay(viewSize: CGSize) -> some View {
        VStack {
            Spacer()
            
            CardTrayView(
                currentEnergy: currentEnergy,
                onDragHover: { card, globalPoint in
                    guard let activeScene = scene else { return }
                    let scenePoint = convertToSceneCoordinates(globalPoint: globalPoint, viewSize: viewSize, sceneSize: activeScene.size)
                    activeScene.handleCardDragHover(at: scenePoint)
                },
                onDragDrop: { card, globalPoint in
                    guard let activeScene = scene else { return }
                    let scenePoint = convertToSceneCoordinates(globalPoint: globalPoint, viewSize: viewSize, sceneSize: activeScene.size)
                    activeScene.handleCardDrop(card: card, at: scenePoint)
                }
            )
        }
    }
    
    private func convertToSceneCoordinates(globalPoint: CGPoint, viewSize: CGSize, sceneSize: CGSize) -> CGPoint {
        let xRatio = sceneSize.width / max(1, viewSize.width)
        let yRatio = sceneSize.height / max(1, viewSize.height)
        let sceneX = globalPoint.x * xRatio
        let sceneY = (viewSize.height - globalPoint.y) * yRatio
        return CGPoint(x: sceneX, y: sceneY)
    }
    
    // MARK: - Placement Phase HUD Overlay
    private var placementHUDOverlay: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 12) {
                // Readiness status
                HStack(spacing: 14) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(isLocalLockedIn ? Color.green : Color.yellow)
                            .frame(width: 8, height: 8)
                        Text(isLocalLockedIn ? "YOU: READY" : "DRAG TOWERS")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.65))
                    .cornerRadius(10)
                    
                    HStack(spacing: 6) {
                        Circle()
                            .fill(isRemoteLockedIn ? Color.green : Color.orange)
                            .frame(width: 8, height: 8)
                        Text(isRemoteLockedIn ? "OPPONENT: READY" : "OPPONENT: CHOOSING...")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.65))
                    .cornerRadius(10)
                }
                
                if !isPlacementValid {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text("TOWERS TOO CLOSE (MIN 120 PT)")
                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                            .foregroundColor(.red)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.85))
                    .cornerRadius(8)
                }
                
                // Lock In Towers Button
                Button(action: {
                    scene?.lockInLocalTowers()
                    isLocalLockedIn = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: isLocalLockedIn ? "checkmark.circle.fill" : "lock.fill")
                            .font(.system(size: 15, weight: .bold))
                        Text(isLocalLockedIn ? "DEFENSES LOCKED" : "LOCK IN TOWERS")
                            .font(.system(size: 14, weight: .black, design: .rounded))
                    }
                    .foregroundColor(isLocalLockedIn ? .white : .black)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(
                        isLocalLockedIn
                            ? AnyView(Color.green.opacity(0.85))
                            : (isPlacementValid
                                ? AnyView(LinearGradient(colors: [.yellow, .orange], startPoint: .topLeading, endPoint: .bottomTrailing))
                                : AnyView(Color.gray.opacity(0.5)))
                    )
                    .cornerRadius(12)
                    .shadow(color: isPlacementValid && !isLocalLockedIn ? .yellow.opacity(0.5) : .clear, radius: 8)
                }
                .disabled(!isPlacementValid || isLocalLockedIn)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
    }
    
    // MARK: - Countdown HUD
    private func countdownHUDOverlay(seconds: Int) -> some View {
        VStack {
            Spacer()
            Text("DEFENSES LOCKED • BATTLE COMMENCES IN \(seconds)")
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundColor(.yellow)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.8))
                .cornerRadius(10)
                .padding(.bottom, 30)
        }
    }
    
    // MARK: - Top Status Bar
    private var topStatusBar: some View {
        VStack {
            HStack {
                Button(action: {
                    network.disconnect()
                    onExit()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Lobby")
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.black.opacity(0.65))
                    .cornerRadius(8)
                }
                
                Spacer()
                
                HStack(spacing: 10) {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(network.localPlayerID == .playerA ? Color.blue : Color.red)
                            .frame(width: 8, height: 8)
                        Text(network.localPlayerID == .playerA ? "BLUE (YOU)" : "RED (YOU)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    
                    if network.latencyMs > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "wifi")
                                .font(.system(size: 9))
                                .foregroundColor(.green)
                            Text("\(network.latencyMs)ms")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(.green)
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.black.opacity(0.65))
                .cornerRadius(8)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            
            Spacer()
        }
    }
}
