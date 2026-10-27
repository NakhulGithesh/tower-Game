import SwiftUI

public enum AppPhase {
    case lobby
    case placement
    case battle
    case gameOver
}

public struct ContentView: View {
    @StateObject private var network = NetworkManager.shared
    @State private var currentPhase: AppPhase = .lobby
    
    public init() {}
    
    public var body: some View {
        ZStack {
            switch currentPhase {
            case .lobby:
                LobbyView(network: network) {
                    currentPhase = .battle
                }
                
            case .placement, .battle, .gameOver:
                GameView(network: network) {
                    currentPhase = .lobby
                }
            }
        }
        .statusBar(hidden: true)
        .persistentSystemOverlays(.hidden)
    }
}

#Preview {
    ContentView()
}
