import Foundation
import CoreGraphics

/// Serializable representation of CGPoint for network packet transmission.
public struct SerializablePoint: Codable, Equatable {
    public var x: Double
    public var y: Double
    
    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
    
    public init(_ point: CGPoint) {
        self.x = Double(point.x)
        self.y = Double(point.y)
    }
    
    public var cgPoint: CGPoint {
        CGPoint(x: x, y: y)
    }
}

/// Serializable representation of CGVector for projectile launch vectors.
public struct SerializableVector: Codable, Equatable {
    public var dx: Double
    public var dy: Double
    
    public init(dx: Double, dy: Double) {
        self.dx = dx
        self.dy = dy
    }
    
    public init(_ vector: CGVector) {
        self.dx = Double(vector.dx)
        self.dy = Double(vector.dy)
    }
    
    public var cgVector: CGVector {
        CGVector(dx: dx, dy: dy)
    }
}

/// Deterministic game events exchanged between peer iPhones.
public enum PacketPayload: Codable, Equatable {
    /// Syncs confirmed tower positions after pre-game placement phase.
    case towerPlacement(playerID: PlayerID, tower1Pos: SerializablePoint, tower2Pos: SerializablePoint)
    
    /// Syncs card applied to a specific tower (e.g. Shield activation, Repair, or Aiming state).
    case cardApplied(playerID: PlayerID, towerID: TowerID, cardType: CardType)
    
    /// Syncs projectile launch vector and origin tower.
    case projectileLaunched(playerID: PlayerID, towerID: TowerID, cardType: CardType, launchVector: SerializableVector)
    
    /// Syncs authoritative tower HP changes.
    case towerHealthSync(towerID: TowerID, currentHP: Int)
    
    /// Signals match reset or restart.
    case gameRestart
    
    /// Heartbeat / ping packet to measure peer latency.
    case ping(clientTimestamp: TimeInterval)
    case pong(clientTimestamp: TimeInterval)
}

/// Root packet envelope with sender and timestamp.
public struct GamePacket: Codable, Equatable {
    public let timestamp: TimeInterval
    public let sender: PlayerID
    public let payload: PacketPayload
    
    public init(sender: PlayerID, payload: PacketPayload, timestamp: TimeInterval = Date().timeIntervalSince1970) {
        self.sender = sender
        self.payload = payload
        self.timestamp = timestamp
    }
}
