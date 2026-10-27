import Foundation

public enum CardRole: String, Codable {
    case attack
    case defense
    case hybrid
}

public enum CardType: String, CaseIterable, Codable, Identifiable {
    case arrows
    case stones
    case fireball
    case shield
    case repair
    case counterattack
    
    public var id: String { rawValue }
    
    public var name: String {
        switch self {
        case .arrows: return "Arrows"
        case .stones: return "Stones"
        case .fireball: return "Fireball"
        case .shield: return "Shield"
        case .repair: return "Repair"
        case .counterattack: return "Counterattack"
        }
    }
    
    public var cost: Int {
        switch self {
        case .arrows: return 2
        case .stones: return 4
        case .fireball: return 5
        case .shield: return 3
        case .repair: return 4
        case .counterattack: return 5
        }
    }
    
    public var role: CardRole {
        switch self {
        case .arrows, .stones, .fireball:
            return .attack
        case .shield, .repair:
            return .defense
        case .counterattack:
            return .hybrid
        }
    }
    
    public var isAimable: Bool {
        switch self {
        case .arrows, .stones, .fireball, .counterattack:
            return true
        case .shield, .repair:
            return false
        }
    }
    
    public var description: String {
        switch self {
        case .arrows:
            return "Fast, low-gravity 3-arrow volley (50 DMG total)"
        case .stones:
            return "Heavy boulder, high gravity arc & screen shake (180 DMG)"
        case .fireball:
            return "Medium arc explosive splash (100 Impact + 50 Burn DMG over 5s)"
        case .shield:
            return "Glowing energy dome blocks projectiles for 5 seconds"
        case .repair:
            return "Rising healing sparkles restore 150 HP over 5 seconds"
        case .counterattack:
            return "High-speed interceptor bolt to snipe enemy missiles or hit towers"
        }
    }
    
    public var impactDamage: Int {
        switch self {
        case .arrows: return 50
        case .stones: return 180
        case .fireball: return 100
        case .counterattack: return 120
        case .shield, .repair: return 0
        }
    }
    
    public var burnDamage: Int {
        switch self {
        case .fireball: return 50
        default: return 0
        }
    }
    
    public var totalDamage: Int {
        return impactDamage + burnDamage
    }
    
    public var healAmount: Int {
        switch self {
        case .repair: return 150
        default: return 0
        }
    }
    
    public var effectDuration: TimeInterval {
        switch self {
        case .shield, .repair, .fireball: return 5.0
        default: return 0.0
        }
    }
    
    public var gravityFactor: Double {
        switch self {
        case .arrows: return 0.5
        case .stones: return 1.05
        case .fireball: return 1.0
        case .counterattack: return 0.2
        case .shield, .repair: return 0.0
        }
    }
    
    public var speedMultiplier: Double {
        switch self {
        case .arrows: return 1.4
        case .stones: return 1.25
        case .fireball: return 1.1
        case .counterattack: return 2.0
        case .shield, .repair: return 1.0
        }
    }
    
    public var splitsMidAir: Bool {
        return self == .arrows
    }
    
    public var splitCount: Int {
        return self == .arrows ? 3 : 1
    }
    
    public var causesScreenShake: Bool {
        return self == .stones
    }
    
    public var canInterceptProjectiles: Bool {
        return self == .counterattack
    }
    
    public var systemIcon: String {
        switch self {
        case .arrows: return "arrow.up.right"
        case .stones: return "circle.fill"
        case .fireball: return "flame.fill"
        case .shield: return "shield.fill"
        case .repair: return "wrench.and.screwdriver.fill"
        case .counterattack: return "bolt.shield.fill"
        }
    }
}

