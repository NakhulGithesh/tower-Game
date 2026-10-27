import Foundation
import CoreGraphics

public enum GameConfig {
    public static let maxEnergy: Double = 10.0
    public static let energyRechargeRate: Double = 1.0 / 2.5 // +1 Elixir every 2.5s (Clash Royale pace)
    public static let initialEnergy: Double = 4.0
    
    public static let maxTowerHP: Int = 1000
    public static let shieldDuration: TimeInterval = 5.0
    public static let repairDuration: TimeInterval = 5.0
    public static let repairTotalHP: Int = 150
    public static let burnDuration: TimeInterval = 5.0
    public static let burnTotalHP: Int = 50
    
    public static let serviceType = "castleattack"
    
    // Vertical Arena Geometry (Portrait: 430 x 932)
    public static let arenaWidth: CGFloat = 430.0
    public static let arenaHeight: CGFloat = 932.0
    public static let bottomDockHeight: CGFloat = 140.0
    
    // Territory Zones
    public static let playerTerritoryMinY: CGFloat = 185.0
    public static let playerTerritoryMaxY: CGFloat = 410.0
    public static let riverCenterY: CGFloat = 465.0
    public static let riverHeight: CGFloat = 50.0
    public static let opponentTerritoryMinY: CGFloat = 510.0
    public static let opponentTerritoryMaxY: CGFloat = 710.0
    
    public static let minTowerSpacing: CGFloat = 120.0
    public static let towerCollisionRadius: CGFloat = 55.0
    
    // Slingshot Aiming & Trajectory
    public static let maxSlingshotDragRadius: CGFloat = 80.0
    public static let trajectoryPreviewPercent: Double = 0.40 // Exactly first 40% of trajectory
    public static let trajectoryPreviewPointCount: Int = 16
    public static let baseGravity: CGFloat = -450.0 // Gravitational drag in vertical space
    public static let launchSpeedFactor: CGFloat = 9.2
}
