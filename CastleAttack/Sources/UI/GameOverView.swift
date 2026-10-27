import SwiftUI

public struct GameOverView: View {
    public let winner: PlayerID
    public let localPlayerID: PlayerID
    public let onPlayAgain: () -> Void
    public let onReturnToLobby: () -> Void
    
    private var isVictory: Bool {
        return winner == localPlayerID
    }
    
    public init(
        winner: PlayerID,
        localPlayerID: PlayerID,
        onPlayAgain: @escaping () -> Void,
        onReturnToLobby: @escaping () -> Void
    ) {
        self.winner = winner
        self.localPlayerID = localPlayerID
        self.onPlayAgain = onPlayAgain
        self.onReturnToLobby = onReturnToLobby
    }
    
    public var body: some View {
        ZStack {
            // Darkened backdrop
            Color.black.opacity(0.85).ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Crest / Banner Icon
                ZStack {
                    Circle()
                        .fill(isVictory ? Color.yellow.opacity(0.25) : Color.red.opacity(0.25))
                        .frame(width: 90, height: 90)
                    
                    Image(systemName: isVictory ? "crown.fill" : "skull.fill")
                        .font(.system(size: 46))
                        .foregroundColor(isVictory ? .yellow : .red)
                        .shadow(color: isVictory ? .orange : .red, radius: 14)
                }
                
                // Result Headline
                VStack(spacing: 6) {
                    Text(isVictory ? "VICTORY!" : "DEFEAT!")
                        .font(.system(size: 44, weight: .black, design: .rounded))
                        .foregroundColor(isVictory ? .yellow : .red)
                        .shadow(color: isVictory ? .orange.opacity(0.7) : .red.opacity(0.7), radius: 10)
                    
                    Text(isVictory ? "You demolished both enemy towers!" : "Both of your castle towers were destroyed.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
                
                // Action Buttons
                HStack(spacing: 20) {
                    Button(action: onPlayAgain) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 16, weight: .bold))
                            Text("BATTLE AGAIN")
                                .font(.system(size: 15, weight: .heavy, design: .rounded))
                        }
                        .foregroundColor(.black)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(
                                colors: [Color.yellow, Color.orange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(12)
                    }
                    
                    Button(action: onReturnToLobby) {
                        HStack(spacing: 8) {
                            Image(systemName: "house.fill")
                                .font(.system(size: 16, weight: .bold))
                            Text("LOBBY")
                                .font(.system(size: 15, weight: .heavy, design: .rounded))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.18))
                        .cornerRadius(12)
                    }
                }
                .padding(.top, 10)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(white: 0.1).opacity(0.95))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(
                                isVictory
                                    ? LinearGradient(colors: [.yellow, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
                                    : LinearGradient(colors: [.red, .purple], startPoint: .topLeading, endPoint: .bottomTrailing),
                                lineWidth: 2.5
                            )
                    )
            )
            .frame(maxWidth: 480)
        }
    }
}
