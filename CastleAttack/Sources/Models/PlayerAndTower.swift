import Foundation
import CoreGraphics

public enum PlayerID: String, Codable, CaseIterable {
    case playerA // Left side, Royal Blue
    case playerB // Right side, Crimson Red
    
    public var opponent: PlayerID {
        switch self {
        case .playerA: return .playerB
        case .playerB: return .playerA
        }
    }
}

public enum TowerID: String, Codable, CaseIterable {
    case tower1
    case tower2
}

public enum TowerState: Equatable {
    case idle
    case aiming(card: CardType)
    case shielded(remainingTime: TimeInterval)
    case repairing(remainingTime: TimeInterval)
    
    public var isBusy: Bool {
        switch self {
        case .idle:
            return false
        case .aiming, .shielded, .repairing:
            return true
        }
    }
}

public enum CardLockError: Error, Equatable {
    case towerBusy(currentCard: CardType)
    case towerInCooldown
}

public struct TowerCardSlot: Equatable {
    public private(set) var activeCard: CardType?
    public private(set) var state: TowerState
    
    public init(activeCard: CardType? = nil, state: TowerState = .idle) {
        self.activeCard = activeCard
        self.state = state
    }
    
    public var canAcceptCard: Bool {
        return activeCard == nil && state == .idle
    }
    
    @discardableResult
    public mutating func applyCard(_ card: CardType) -> Result<TowerState, CardLockError> {
        guard canAcceptCard else {
            return .failure(.towerBusy(currentCard: activeCard ?? card))
        }
        
        activeCard = card
        let newState: TowerState
        switch card {
        case .shield:
            newState = .shielded(remainingTime: card.effectDuration)
        case .repair:
            newState = .repairing(remainingTime: card.effectDuration)
        case .arrows, .stones, .fireball, .counterattack:
            newState = .aiming(card: card)
        }
        state = newState
        return .success(newState)
    }
    
    public mutating func releaseLock() {
        activeCard = nil
        state = .idle
    }
    
    public mutating func updateTimer(deltaTime: TimeInterval) {
        switch state {
        case .shielded(let remaining):
            let updated = remaining - deltaTime
            if updated <= 0 {
                releaseLock()
            } else {
                state = .shielded(remainingTime: updated)
            }
        case .repairing(let remaining):
            let updated = remaining - deltaTime
            if updated <= 0 {
                releaseLock()
            } else {
                state = .repairing(remainingTime: updated)
            }
        case .idle, .aiming:
            break
        }
    }
}
