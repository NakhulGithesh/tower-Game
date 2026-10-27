import SpriteKit

/// Procedurally drawn stone castle tower node with battlements, team banners, glowing windows, floating HP bar, card badges, and proximity selection halo.
public final class TowerNode: SKNode {
    
    // MARK: - Properties
    public let towerID: TowerID
    public let playerID: PlayerID
    
    public private(set) var currentHP: Int = GameConfig.maxTowerHP
    public let maxHP: Int = GameConfig.maxTowerHP
    public private(set) var isDestroyed: Bool = false
    
    public var cardSlot = TowerCardSlot()
    public var isDraggable: Bool = false
    public var isSelected: Bool = false {
        didSet { updateSelectionHighlight() }
    }
    
    public var isTargetHaloActive: Bool = false {
        didSet { updateTargetHalo() }
    }
    
    // Geometry & Sizes (Calibrated for Portrait 430 x 932)
    public static let towerSize = CGSize(width: 74, height: 110)
    
    // Child Nodes
    private var baseNode: SKNode!
    private var bodyShape: SKShapeNode!
    private var battlementShape: SKShapeNode!
    private var bannerNode: SKNode!
    private var windowNodes: [SKShapeNode] = []
    
    // HUD Nodes
    private var hpBarBackground: SKShapeNode!
    private var hpBarFill: SKShapeNode!
    private var hpTextLabel: SKLabelNode!
    private var titleLabel: SKLabelNode!
    
    // Card Badge & Status Nodes
    public private(set) var cardBadgeNode: SKNode!
    private var cardBadgeIcon: SKLabelNode!
    private var cardBadgeRing: SKShapeNode!
    private var selectionGlowRing: SKShapeNode!
    private var targetHaloRing: SKShapeNode!
    public private(set) var shieldDomeNode: SKShapeNode?
    
    // Slingshot launch origin (top of battlements)
    public var launchOrigin: CGPoint {
        let launchOffsetY: CGFloat = (playerID == .playerA) ? 45.0 : -45.0
        return CGPoint(x: position.x, y: position.y + launchOffsetY)
    }
    
    // MARK: - Initializer
    public init(towerID: TowerID, playerID: PlayerID, position: CGPoint) {
        self.towerID = towerID
        self.playerID = playerID
        super.init()
        self.position = position
        self.name = "\(playerID.rawValue)_\(towerID.rawValue)"
        self.zPosition = 10
        
        setupTowerArt()
        setupFloatingHUD()
        setupActiveCardBadge()
        setupSelectionRings()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Procedural Vector Graphics
    private func setupTowerArt() {
        baseNode = SKNode()
        addChild(baseNode)
        
        let stoneColor = SKColor(red: 0.28, green: 0.30, blue: 0.35, alpha: 1.0)
        let stoneDark = SKColor(red: 0.18, green: 0.20, blue: 0.24, alpha: 1.0)
        let stoneLight = SKColor(red: 0.38, green: 0.40, blue: 0.46, alpha: 1.0)
        
        // 1. Foundation Base
        let foundationPath = CGMutablePath()
        foundationPath.addRoundedRect(
            in: CGRect(x: -40, y: -55, width: 80, height: 24),
            cornerWidth: 6,
            cornerHeight: 6
        )
        let foundation = SKShapeNode(path: foundationPath)
        foundation.fillColor = stoneDark
        foundation.strokeColor = stoneLight
        foundation.lineWidth = 2.0
        baseNode.addChild(foundation)
        
        // 2. Main Tower Shaft
        let shaftPath = CGMutablePath()
        shaftPath.move(to: CGPoint(x: -35, y: -38))
        shaftPath.addLine(to: CGPoint(x: -31, y: 30))
        shaftPath.addLine(to: CGPoint(x: 31, y: 30))
        shaftPath.addLine(to: CGPoint(x: 35, y: -38))
        shaftPath.closeSubpath()
        
        bodyShape = SKShapeNode(path: shaftPath)
        bodyShape.fillColor = stoneColor
        bodyShape.strokeColor = stoneDark
        bodyShape.lineWidth = 2.5
        baseNode.addChild(bodyShape)
        
        // Horizontal mortar lines
        for yOffset in [-20, 0, 16] {
            let linePath = CGMutablePath()
            linePath.move(to: CGPoint(x: -32, y: CGFloat(yOffset)))
            linePath.addLine(to: CGPoint(x: 32, y: CGFloat(yOffset)))
            let brickLine = SKShapeNode(path: linePath)
            brickLine.strokeColor = stoneDark
            brickLine.lineWidth = 1.5
            baseNode.addChild(brickLine)
        }
        
        // 3. Battlements (Crenellations) on Top
        let battlementPath = CGMutablePath()
        let bY: CGFloat = 30
        let bH: CGFloat = 18
        battlementPath.move(to: CGPoint(x: -38, y: bY))
        battlementPath.addLine(to: CGPoint(x: -38, y: bY + bH))
        battlementPath.addLine(to: CGPoint(x: -24, y: bY + bH))
        battlementPath.addLine(to: CGPoint(x: -24, y: bY + 7))
        battlementPath.addLine(to: CGPoint(x: -9, y: bY + 7))
        battlementPath.addLine(to: CGPoint(x: -9, y: bY + bH))
        battlementPath.addLine(to: CGPoint(x: 9, y: bY + bH))
        battlementPath.addLine(to: CGPoint(x: 9, y: bY + 7))
        battlementPath.addLine(to: CGPoint(x: 24, y: bY + 7))
        battlementPath.addLine(to: CGPoint(x: 24, y: bY + bH))
        battlementPath.addLine(to: CGPoint(x: 38, y: bY + bH))
        battlementPath.addLine(to: CGPoint(x: 38, y: bY))
        battlementPath.closeSubpath()
        
        battlementShape = SKShapeNode(path: battlementPath)
        battlementShape.fillColor = stoneLight
        battlementShape.strokeColor = stoneDark
        battlementShape.lineWidth = 2.0
        baseNode.addChild(battlementShape)
        
        // 4. Arched Glowing Windows
        for (idx, yPos) in [(-10.0), (10.0)].enumerated() {
            let winPath = CGMutablePath()
            let wX: CGFloat = idx == 0 ? -14 : 14
            winPath.addRoundedRect(
                in: CGRect(x: wX - 5, y: CGFloat(yPos) - 8, width: 10, height: 16),
                cornerWidth: 5,
                cornerHeight: 5
            )
            let winNode = SKShapeNode(path: winPath)
            winNode.fillColor = SKColor(red: 1.0, green: 0.85, blue: 0.3, alpha: 0.9)
            winNode.strokeColor = stoneDark
            winNode.lineWidth = 1.5
            
            let pulseAction = SKAction.sequence([
                SKAction.fadeAlpha(to: 0.6, duration: 1.2),
                SKAction.fadeAlpha(to: 1.0, duration: 1.2)
            ])
            winNode.run(SKAction.repeatForever(pulseAction))
            baseNode.addChild(winNode)
            windowNodes.append(winNode)
        }
        
        // 5. Team Banner
        setupTeamBanner()
    }
    
    private func setupTeamBanner() {
        bannerNode = SKNode()
        bannerNode.position = CGPoint(x: 0, y: 5)
        
        let teamColor = playerID == .playerA
            ? SKColor(red: 0.12, green: 0.45, blue: 0.95, alpha: 1.0) // Royal Blue
            : SKColor(red: 0.90, green: 0.20, blue: 0.20, alpha: 1.0) // Crimson Red
        
        let goldBorder = SKColor(red: 0.95, green: 0.80, blue: 0.25, alpha: 1.0)
        
        let bannerPath = CGMutablePath()
        bannerPath.move(to: CGPoint(x: -14, y: 12))
        bannerPath.addLine(to: CGPoint(x: 14, y: 12))
        bannerPath.addLine(to: CGPoint(x: 14, y: -20))
        bannerPath.addLine(to: CGPoint(x: 0, y: -30))
        bannerPath.addLine(to: CGPoint(x: -14, y: -20))
        bannerPath.closeSubpath()
        
        let bannerShape = SKShapeNode(path: bannerPath)
        bannerShape.fillColor = teamColor
        bannerShape.strokeColor = goldBorder
        bannerShape.lineWidth = 2.0
        bannerNode.addChild(bannerShape)
        
        let emblem = SKLabelNode(text: playerID == .playerA ? "⚔️" : "🛡️")
        emblem.fontSize = 12
        emblem.verticalAlignmentMode = .center
        emblem.horizontalAlignmentMode = .center
        emblem.position = CGPoint(x: 0, y: -4)
        bannerNode.addChild(emblem)
        
        baseNode.addChild(bannerNode)
    }
    
    // MARK: - Floating Health Bar & Title
    private func setupFloatingHUD() {
        let hudNode = SKNode()
        hudNode.position = CGPoint(x: 0, y: 65)
        hudNode.zPosition = 5
        
        // Tower Name Label
        let title = towerID == .tower1 ? "TOWER 1" : "TOWER 2"
        titleLabel = SKLabelNode(text: title)
        titleLabel.fontName = "AvenirNext-Bold"
        titleLabel.fontSize = 9
        titleLabel.fontColor = playerID == .playerA ? .cyan : .orange
        titleLabel.position = CGPoint(x: 0, y: 12)
        hudNode.addChild(titleLabel)
        
        // HP Bar Background
        let barWidth: CGFloat = 66
        let barHeight: CGFloat = 7
        hpBarBackground = SKShapeNode(rectOf: CGSize(width: barWidth, height: barHeight), cornerRadius: 3.5)
        hpBarBackground.fillColor = SKColor(white: 0.1, alpha: 0.9)
        hpBarBackground.strokeColor = SKColor(white: 0.3, alpha: 1.0)
        hpBarBackground.lineWidth = 1.0
        hudNode.addChild(hpBarBackground)
        
        // HP Bar Fill
        hpBarFill = SKShapeNode(rectOf: CGSize(width: barWidth - 2, height: barHeight - 2), cornerRadius: 2.5)
        hpBarFill.fillColor = SKColor(red: 0.2, green: 0.85, blue: 0.3, alpha: 1.0)
        hpBarFill.strokeColor = .clear
        hpBarFill.position = CGPoint(x: 0, y: 0)
        hudNode.addChild(hpBarFill)
        
        // HP Text Label
        hpTextLabel = SKLabelNode(text: "\(currentHP)")
        hpTextLabel.fontName = "AvenirNext-Heavy"
        hpTextLabel.fontSize = 8
        hpTextLabel.fontColor = .white
        hpTextLabel.verticalAlignmentMode = .center
        hpTextLabel.position = CGPoint(x: 0, y: 0)
        hudNode.addChild(hpTextLabel)
        
        addChild(hudNode)
    }
    
    // MARK: - Active Card Badge
    private func setupActiveCardBadge() {
        cardBadgeNode = SKNode()
        cardBadgeNode.position = CGPoint(x: 0, y: 100)
        cardBadgeNode.zPosition = 6
        cardBadgeNode.isHidden = true
        
        cardBadgeRing = SKShapeNode(circleOfRadius: 16)
        cardBadgeRing.fillColor = SKColor(white: 0.15, alpha: 0.95)
        cardBadgeRing.strokeColor = .yellow
        cardBadgeRing.lineWidth = 2.0
        cardBadgeNode.addChild(cardBadgeRing)
        
        cardBadgeIcon = SKLabelNode(text: "🛡️")
        cardBadgeIcon.fontSize = 16
        cardBadgeIcon.verticalAlignmentMode = .center
        cardBadgeIcon.horizontalAlignmentMode = .center
        cardBadgeIcon.position = CGPoint(x: 0, y: -1)
        cardBadgeNode.addChild(cardBadgeIcon)
        
        addChild(cardBadgeNode)
    }
    
    private func setupSelectionRings() {
        // Placement Selection Ring
        selectionGlowRing = SKShapeNode(ellipseOf: CGSize(width: 95, height: 45))
        selectionGlowRing.position = CGPoint(x: 0, y: -45)
        selectionGlowRing.fillColor = SKColor(white: 1.0, alpha: 0.08)
        selectionGlowRing.strokeColor = .cyan
        selectionGlowRing.lineWidth = 2.5
        selectionGlowRing.zPosition = -1
        selectionGlowRing.isHidden = true
        addChild(selectionGlowRing)
        
        // Direct Card Drag Proximity Halo (r = 65 pt)
        targetHaloRing = SKShapeNode(circleOfRadius: 65)
        targetHaloRing.position = CGPoint(x: 0, y: 10)
        targetHaloRing.fillColor = SKColor(red: 0.2, green: 0.8, blue: 1.0, alpha: 0.15)
        targetHaloRing.strokeColor = .yellow
        targetHaloRing.lineWidth = 3.0
        targetHaloRing.zPosition = -1
        targetHaloRing.isHidden = true
        addChild(targetHaloRing)
    }
    
    private func updateSelectionHighlight() {
        selectionGlowRing.isHidden = !isSelected
        if isSelected {
            let pulse = SKAction.sequence([
                SKAction.fadeAlpha(to: 0.3, duration: 0.5),
                SKAction.fadeAlpha(to: 0.8, duration: 0.5)
            ])
            selectionGlowRing.run(SKAction.repeatForever(pulse), withKey: "selectionPulse")
        } else {
            selectionGlowRing.removeAction(forKey: "selectionPulse")
        }
    }
    
    private func updateTargetHalo() {
        targetHaloRing.isHidden = !isTargetHaloActive
        if isTargetHaloActive {
            let pulse = SKAction.sequence([
                SKAction.scale(to: 1.15, duration: 0.25),
                SKAction.scale(to: 1.0, duration: 0.25)
            ])
            targetHaloRing.run(SKAction.repeatForever(pulse), withKey: "haloPulse")
        } else {
            targetHaloRing.removeAction(forKey: "haloPulse")
            targetHaloRing.setScale(1.0)
        }
    }
    
    // MARK: - Public Actions & Damage
    
    public func setHealth(_ newHP: Int) {
        currentHP = max(0, min(newHP, maxHP))
        hpTextLabel.text = "\(currentHP)"
        
        let fraction = CGFloat(currentHP) / CGFloat(maxHP)
        let barWidth: CGFloat = max(2, 64 * fraction)
        
        let fillColor: SKColor
        if fraction > 0.5 {
            fillColor = SKColor(red: 0.2, green: 0.85, blue: 0.3, alpha: 1.0)
        } else if fraction > 0.25 {
            fillColor = SKColor(red: 0.95, green: 0.8, blue: 0.1, alpha: 1.0)
        } else {
            fillColor = SKColor(red: 0.95, green: 0.2, blue: 0.2, alpha: 1.0)
        }
        
        let updatedPath = CGPath(
            roundedRect: CGRect(x: -32, y: -2.5, width: barWidth, height: 5),
            cornerWidth: 2,
            cornerHeight: 2,
            transform: nil
        )
        hpBarFill.path = updatedPath
        hpBarFill.fillColor = fillColor
        
        if currentHP <= 0 && !isDestroyed {
            isDestroyed = true
            playDestructionSequence()
        }
    }
    
    public func playDestructionSequence() {
        // 1. Extinguish Windows
        windowNodes.forEach { $0.run(SKAction.fadeOut(withDuration: 0.15)) }
        
        // 2. Fade Floating HUD
        hpBarBackground.parent?.run(SKAction.fadeOut(withDuration: 0.25))
        cardBadgeNode?.run(SKAction.fadeOut(withDuration: 0.2))
        removeShieldDome()
        
        // 3. Explosion & Debris (45 rock & smoke particles)
        let debris = ParticleFactory.makeRockImpactDebris()
        debris.numParticlesToEmit = 45
        debris.position = CGPoint(x: 0, y: 0)
        addChild(debris)
        
        // 4. Structural Collapse
        battlementShape.run(SKAction.rotate(byAngle: 0.2, duration: 0.25))
        baseNode.run(SKAction.moveBy(x: 0, y: -26, duration: 0.5))
        bodyShape.run(SKAction.customAction(withDuration: 0.3) { [weak self] _, _ in
            self?.bodyShape.fillColor = SKColor(white: 0.15, alpha: 1.0)
        })
        
        // 5. Screen Shake & Heavy Haptic Feedback
        if let scene = self.scene {
            let shake = SKAction.sequence([
                SKAction.moveBy(x: -8, y: 0, duration: 0.05),
                SKAction.moveBy(x: 16, y: 0, duration: 0.05),
                SKAction.moveBy(x: -12, y: 0, duration: 0.05),
                SKAction.moveBy(x: 4, y: 0, duration: 0.05)
            ])
            scene.run(shake)
        }
        
        #if os(iOS)
        let haptic = UIImpactFeedbackGenerator(style: .heavy)
        haptic.impactOccurred()
        #endif
    }
    
    public func takeDamage(_ amount: Int) {
        setHealth(currentHP - amount)
        spawnFloatingDamageText(amount: amount)
        
        // Red damage flash
        let flash = SKAction.sequence([
            SKAction.run { [weak self] in self?.bodyShape.fillColor = .red },
            SKAction.wait(forDuration: 0.15),
            SKAction.run { [weak self] in
                self?.bodyShape.fillColor = SKColor(red: 0.28, green: 0.30, blue: 0.35, alpha: 1.0)
            }
        ])
        run(flash)
    }
    
    public func heal(_ amount: Int) {
        setHealth(currentHP + amount)
        spawnFloatingHealText(amount: amount)
    }
    
    // Floating combat text popup
    private func spawnFloatingDamageText(amount: Int) {
        let label = SKLabelNode(text: "-\(amount)")
        label.fontName = "AvenirNext-Heavy"
        label.fontSize = 18
        label.fontColor = .yellow
        label.position = CGPoint(x: 0, y: 40)
        label.zPosition = 50
        addChild(label)
        
        let moveUp = SKAction.moveBy(x: 0, y: 35, duration: 0.6)
        let fadeOut = SKAction.fadeOut(withDuration: 0.6)
        let group = SKAction.group([moveUp, fadeOut])
        label.run(SKAction.sequence([group, SKAction.removeFromParent()]))
    }
    
    private func spawnFloatingHealText(amount: Int) {
        let label = SKLabelNode(text: "+\(amount)")
        label.fontName = "AvenirNext-Heavy"
        label.fontSize = 16
        label.fontColor = .green
        label.position = CGPoint(x: 0, y: 40)
        label.zPosition = 50
        addChild(label)
        
        let moveUp = SKAction.moveBy(x: 0, y: 30, duration: 0.6)
        let fadeOut = SKAction.fadeOut(withDuration: 0.6)
        let group = SKAction.group([moveUp, fadeOut])
        label.run(SKAction.sequence([group, SKAction.removeFromParent()]))
    }
    
    public func displayActiveCardBadge(for card: CardType) {
        cardBadgeNode.isHidden = false
        switch card {
        case .arrows:
            cardBadgeIcon.text = "🏹"
            cardBadgeRing.strokeColor = .cyan
        case .stones:
            cardBadgeIcon.text = "🪨"
            cardBadgeRing.strokeColor = .brown
        case .fireball:
            cardBadgeIcon.text = "🔥"
            cardBadgeRing.strokeColor = .orange
        case .shield:
            cardBadgeIcon.text = "🛡️"
            cardBadgeRing.strokeColor = .cyan
            spawnShieldDome()
        case .repair:
            cardBadgeIcon.text = "🛠️"
            cardBadgeRing.strokeColor = .green
        case .counterattack:
            cardBadgeIcon.text = "⚡️"
            cardBadgeRing.strokeColor = .yellow
        }
        
        cardBadgeNode.setScale(0.2)
        cardBadgeNode.run(SKAction.scale(to: 1.0, duration: 0.25).then(SKAction.springPulse()))
    }
    
    public func clearActiveCardBadge() {
        cardBadgeNode.run(SKAction.scale(to: 0.01, duration: 0.15)) { [weak self] in
            self?.cardBadgeNode.isHidden = true
            self?.cardBadgeNode.setScale(1.0)
        }
        removeShieldDome()
    }
    
    public func spawnShieldDome() {
        removeShieldDome()
        let dome = SKShapeNode(circleOfRadius: 58)
        dome.position = CGPoint(x: 0, y: 10)
        dome.fillColor = SKColor(red: 0.2, green: 0.8, blue: 1.0, alpha: 0.22)
        dome.strokeColor = SKColor(red: 0.4, green: 0.9, blue: 1.0, alpha: 0.9)
        dome.lineWidth = 3.0
        dome.zPosition = 8
        
        let shimmer = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.5, duration: 0.6),
            SKAction.fadeAlpha(to: 0.9, duration: 0.6)
        ])
        dome.run(SKAction.repeatForever(shimmer), withKey: "shimmer")
        addChild(dome)
        self.shieldDomeNode = dome
    }
    
    public func removeShieldDome() {
        guard let dome = shieldDomeNode else { return }
        dome.run(SKAction.sequence([
            SKAction.scale(to: 1.2, duration: 0.15),
            SKAction.fadeOut(withDuration: 0.15),
            SKAction.removeFromParent()
        ]))
        self.shieldDomeNode = nil
    }
    
    public func updateTimers(deltaTime: TimeInterval) {
        cardSlot.updateTimer(deltaTime: deltaTime)
        if cardSlot.activeCard == nil && !cardBadgeNode.isHidden {
            clearActiveCardBadge()
        }
    }
}

// MARK: - SKAction Extensions
extension SKAction {
    public static func springPulse() -> SKAction {
        return SKAction.sequence([
            SKAction.scale(to: 1.15, duration: 0.08),
            SKAction.scale(to: 1.0, duration: 0.08)
        ])
    }
    
    public func then(_ nextAction: SKAction) -> SKAction {
        return SKAction.sequence([self, nextAction])
    }
}
