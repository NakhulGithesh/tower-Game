import SpriteKit

/// Highlights the player's valid deployment zone during pre-game placement phase in vertical orientation.
public final class PlacementZoneNode: SKNode {
    
    public let playerID: PlayerID
    public let territoryRect: CGRect
    
    private var zoneOutline: SKShapeNode!
    private var warningRing: SKShapeNode!
    private var bannerLabel: SKLabelNode!
    
    public init(playerID: PlayerID, arenaSize: CGSize) {
        self.playerID = playerID
        
        let marginX: CGFloat = 25.0
        let rectWidth = arenaSize.width - marginX * 2
        
        let rect: CGRect
        if playerID == .playerA {
            // Local Player: Bottom Half (Y: 160 to 410)
            rect = CGRect(
                x: marginX,
                y: GameConfig.playerTerritoryMinY,
                width: rectWidth,
                height: GameConfig.playerTerritoryMaxY - GameConfig.playerTerritoryMinY
            )
        } else {
            // Opponent: Top Half (Y: 520 to 770)
            rect = CGRect(
                x: marginX,
                y: GameConfig.opponentTerritoryMinY,
                width: rectWidth,
                height: GameConfig.opponentTerritoryMaxY - GameConfig.opponentTerritoryMinY
            )
        }
        self.territoryRect = rect
        super.init()
        self.zPosition = -30
        
        setupZoneVisuals()
        setupWarningRing()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupZoneVisuals() {
        let teamColor = playerID == .playerA
            ? SKColor(red: 0.15, green: 0.55, blue: 1.0, alpha: 0.15)
            : SKColor(red: 1.0, green: 0.25, blue: 0.25, alpha: 0.15)
        
        let strokeColor = playerID == .playerA
            ? SKColor(red: 0.3, green: 0.7, blue: 1.0, alpha: 0.85)
            : SKColor(red: 1.0, green: 0.4, blue: 0.4, alpha: 0.85)
        
        zoneOutline = SKShapeNode(rect: territoryRect, cornerRadius: 14)
        zoneOutline.fillColor = teamColor
        zoneOutline.strokeColor = strokeColor
        zoneOutline.lineWidth = 2.5
        addChild(zoneOutline)
        
        let pulse = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.6, duration: 1.0),
            SKAction.fadeAlpha(to: 1.0, duration: 1.0)
        ])
        zoneOutline.run(SKAction.repeatForever(pulse))
        
        let title = playerID == .playerA
            ? "🛡️ ROYAL TERRITORY (DRAG TOWERS TO DEPLOY)"
            : "⚔️ CRIMSON TERRITORY (DEPLOY ZONE)"
        bannerLabel = SKLabelNode(text: title)
        bannerLabel.fontName = "AvenirNext-Bold"
        bannerLabel.fontSize = 10
        bannerLabel.fontColor = strokeColor
        bannerLabel.position = CGPoint(x: territoryRect.midX, y: territoryRect.maxY + 6)
        addChild(bannerLabel)
    }
    
    private func setupWarningRing() {
        warningRing = SKShapeNode(circleOfRadius: GameConfig.minTowerSpacing / 2)
        warningRing.fillColor = SKColor(red: 1.0, green: 0.1, blue: 0.1, alpha: 0.2)
        warningRing.strokeColor = .red
        warningRing.lineWidth = 2.0
        warningRing.isHidden = true
        warningRing.zPosition = 5
        addChild(warningRing)
    }
    
    public func containsPosition(_ point: CGPoint) -> Bool {
        return territoryRect.contains(point)
    }
    
    public func clampPosition(_ point: CGPoint) -> CGPoint {
        let halfW = TowerNode.towerSize.width / 2 + 5
        let halfH = TowerNode.towerSize.height / 2 + 5
        
        let minX = territoryRect.minX + halfW
        let maxX = territoryRect.maxX - halfW
        let minY = territoryRect.minY + halfH
        let maxY = territoryRect.maxY - halfH
        
        let clampedX = max(minX, min(point.x, maxX))
        let clampedY = max(minY, min(point.y, maxY))
        return CGPoint(x: clampedX, y: clampedY)
    }
    
    public func setSpacingWarning(at point: CGPoint, isTooClose: Bool) {
        warningRing.position = point
        warningRing.isHidden = !isTooClose
        if isTooClose {
            zoneOutline.strokeColor = .red
        } else {
            zoneOutline.strokeColor = playerID == .playerA
                ? SKColor(red: 0.3, green: 0.7, blue: 1.0, alpha: 0.85)
                : SKColor(red: 1.0, green: 0.4, blue: 0.4, alpha: 0.85)
        }
    }
    
    public func dismiss() {
        run(SKAction.sequence([
            SKAction.fadeOut(withDuration: 0.4),
            SKAction.removeFromParent()
        ]))
    }
}
