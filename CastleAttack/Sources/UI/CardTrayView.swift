import SwiftUI

public struct CardTrayView: View {
    public let currentEnergy: Double
    public let maxEnergy: Double = GameConfig.maxEnergy
    public var onDragHover: ((CardType, CGPoint) -> Void)?
    public var onDragDrop: ((CardType, CGPoint) -> Void)?
    
    @State private var activeDraggingCard: CardType? = nil
    @State private var dragCurrentPosition: CGPoint = .zero
    
    private let allCards = CardType.allCases.sorted { lhs, rhs in
        if lhs.cost == rhs.cost {
            return lhs.name < rhs.name
        }
        return lhs.cost < rhs.cost
    }
    
    public init(
        currentEnergy: Double,
        onDragHover: ((CardType, CGPoint) -> Void)? = nil,
        onDragDrop: ((CardType, CGPoint) -> Void)? = nil
    ) {
        self.currentEnergy = currentEnergy
        self.onDragHover = onDragHover
        self.onDragDrop = onDragDrop
    }
    
    public var body: some View {
        ZStack(alignment: .bottom) {
            // Bottom Dock Container (Height: 135 pt)
            VStack(spacing: 6) {
                // Clash Royale Continuous Elixir Bar
                elixirBar
                    .padding(.top, 4)
                
                // 6-Card Hand Grid
                HStack(spacing: 6) {
                    ForEach(allCards) { card in
                        let isAffordable = currentEnergy >= Double(card.cost)
                        cardView(for: card, isAffordable: isAffordable)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 6)
            }
            .frame(height: 135)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(red: 0.08, green: 0.10, blue: 0.14).opacity(0.96))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.yellow.opacity(0.4), Color.purple.opacity(0.4)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
                    .shadow(color: .black.opacity(0.8), radius: 10, y: -4)
            )
            .padding(.horizontal, 8)
            .padding(.bottom, 4)
            
            // Dragged Card Ghost Floating with Finger
            if let card = activeDraggingCard {
                draggedCardGhost(card: card)
                    .position(dragCurrentPosition)
                    .transition(.opacity)
            }
        }
    }
    
    // MARK: - Clash Royale Elixir Bar
    private var elixirBar: some View {
        HStack(spacing: 8) {
            // Purple Elixir Bubble
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(red: 0.95, green: 0.35, blue: 0.95), Color(red: 0.55, green: 0.10, blue: 0.75)],
                            center: .center,
                            startRadius: 2,
                            endRadius: 14
                        )
                    )
                    .frame(width: 26, height: 26)
                    .shadow(color: Color.purple.opacity(0.8), radius: 6)
                
                Image(systemName: "drop.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
            }
            
            // Continuous Fill Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.black.opacity(0.8))
                        .overlay(
                            Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )
                    
                    let fraction = max(0.0, min(currentEnergy / maxEnergy, 1.0))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.70, green: 0.15, blue: 0.90), // Magenta
                                    Color(red: 0.45, green: 0.25, blue: 0.95), // Deep Purple
                                    Color(red: 0.20, green: 0.75, blue: 1.0)   // Cyan Edge
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(8, geo.size.width * CGFloat(fraction)))
                        .shadow(color: Color.purple.opacity(0.7), radius: 5)
                    
                    // 10 Segments Tick Marks
                    HStack(spacing: 0) {
                        ForEach(1..<10) { _ in
                            Spacer()
                            Rectangle()
                                .fill(Color.white.opacity(0.18))
                                .frame(width: 1, height: 8)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 2)
                    
                    // Numeric Elixir Text
                    HStack {
                        Spacer()
                        Text(String(format: "%.1f / 10", currentEnergy))
                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(color: .black, radius: 2)
                        Spacer()
                    }
                }
            }
            .frame(height: 15)
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - Individual Card View
    private func cardView(for card: CardType, isAffordable: Bool) -> some View {
        VStack(spacing: 2) {
            // Elixir Cost Bubble in Top-Left
            HStack {
                ZStack {
                    Circle()
                        .fill(isAffordable ? Color(red: 0.75, green: 0.15, blue: 0.85) : Color.gray)
                        .frame(width: 16, height: 16)
                    Text("\(card.cost)")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                }
                Spacer()
            }
            .padding(.top, 2)
            .padding(.leading, 3)
            
            // Icon
            Image(systemName: card.systemIcon)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(isAffordable ? cardAccentColor(for: card) : .gray)
                .frame(height: 20)
            
            // Name
            Text(card.name)
                .font(.system(size: 9, weight: .heavy, design: .rounded))
                .foregroundColor(isAffordable ? .white : .gray)
                .lineLimit(1)
            
            // Role Tag
            Text(card.role.rawValue.uppercased())
                .font(.system(size: 6, weight: .bold))
                .foregroundColor(isAffordable ? roleColor(for: card.role) : .gray.opacity(0.5))
                .padding(.bottom, 2)
        }
        .frame(maxWidth: .infinity, maxHeight: 68)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(white: 0.14).opacity(isAffordable ? 0.95 : 0.4))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            isAffordable
                                ? LinearGradient(colors: [.yellow.opacity(0.8), .purple.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                : LinearGradient(colors: [Color.white.opacity(0.1), Color.white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: isAffordable ? 1.5 : 1
                        )
                )
        )
        .shadow(color: isAffordable ? Color.purple.opacity(0.4) : .clear, radius: 4)
        // Direct Drag Gesture into Arena
        .gesture(
            DragGesture(coordinateSpace: .global)
                .onChanged { gesture in
                    guard isAffordable else { return }
                    activeDraggingCard = card
                    dragCurrentPosition = gesture.location
                    onDragHover?(card, gesture.location)
                }
                .onEnded { gesture in
                    guard isAffordable else { return }
                    onDragDrop?(card, gesture.location)
                    activeDraggingCard = nil
                }
        )
    }
    
    // Floating ghost card during upward drag
    private func draggedCardGhost(card: CardType) -> some View {
        VStack(spacing: 3) {
            Image(systemName: card.systemIcon)
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(cardAccentColor(for: card))
            
            Text(card.name)
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundColor(.white)
        }
        .frame(width: 72, height: 72)
        .background(
            Circle()
                .fill(Color.black.opacity(0.85))
                .overlay(Circle().stroke(Color.yellow, lineWidth: 2.5))
                .shadow(color: .yellow.opacity(0.6), radius: 10)
        )
    }
    
    private func cardAccentColor(for card: CardType) -> Color {
        switch card {
        case .arrows: return .cyan
        case .stones: return Color(white: 0.8)
        case .fireball: return .orange
        case .shield: return .cyan
        case .repair: return .green
        case .counterattack: return .yellow
        }
    }
    
    private func roleColor(for role: CardRole) -> Color {
        switch role {
        case .attack: return .red
        case .defense: return .cyan
        case .hybrid: return .yellow
        }
    }
}
