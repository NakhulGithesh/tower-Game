import SpriteKit

/// Vertical Slingshot Aiming Controller:
/// Pulling downward toward bottom screen imparts an upward (+Y) launch vector towards the opponent.
/// Renders an exact 40% parabolic arc with glowing dots.
public final class SlingshotNode: SKNode {
    
    public let card: CardType
    public let originPoint: CGPoint
    public let playerID: PlayerID
    
    public var onLaunch: ((CGVector) -> Void)?
    public var onCancel: (() -> Void)?
    
    // Visuals
    private var leftBand: SKShapeNode!
    private var rightBand: SKShapeNode!
    private var pouchNode: SKShapeNode!
    private var projectileIcon: SKLabelNode!
    private var trajectoryDots: [SKShapeNode] = []
    
    private let leftAnchor: CGPoint
    private let rightAnchor: CGPoint
    private var isDragging = false
    private var currentPouchPos: CGPoint
    
    public init(card: CardType, origin: CGPoint, playerID: PlayerID) {
        self.card = card
        self.originPoint = origin
        self.playerID = playerID
        self.leftAnchor = CGPoint(x: -14, y: 0)
        self.rightAnchor = CGPoint(x: 14, y: 0)
        self.currentPouchPos = CGPoint(x: 0, y: -5)
        super.init()
        self.position = origin
        self.zPosition = 25
        
        setupVisuals()
        setupTrajectoryDots()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupVisuals() {
        // Fork / Prongs
        let forkPath = CGMutablePath()
        forkPath.move(to: CGPoint(x: -15, y: -15))
        forkPath.addLine(to: CGPoint(x: -14, y: 8))
        forkPath.move(to: CGPoint(x: 15, y: -15))
        forkPath.addLine(to: CGPoint(x: 14, y: 8))
        
        let fork = SKShapeNode(path: forkPath)
        fork.strokeColor = SKColor(red: 0.55, green: 0.35, blue: 0.18, alpha: 1.0)
        fork.lineWidth = 3.5
        fork.lineCap = .round
        addChild(fork)
        
        // Elastic Rubber Bands
        leftBand = SKShapeNode()
        leftBand.strokeColor = SKColor(red: 0.85, green: 0.25, blue: 0.20, alpha: 1.0)
        leftBand.lineWidth = 3.0
        leftBand.lineCap = .round
        addChild(leftBand)
        
        rightBand = SKShapeNode()
        rightBand.strokeColor = SKColor(red: 0.70, green: 0.20, blue: 0.15, alpha: 1.0)
        rightBand.lineWidth = 3.0
        rightBand.lineCap = .round
        addChild(rightBand)
        
        // Leather Pouch
        pouchNode = SKShapeNode(circleOfRadius: 13)
        pouchNode.fillColor = SKColor(red: 0.20, green: 0.15, blue: 0.12, alpha: 1.0)
        pouchNode.strokeColor = .yellow
        pouchNode.lineWidth = 1.5
        pouchNode.position = currentPouchPos
        pouchNode.zPosition = 5
        addChild(pouchNode)
        
        projectileIcon = SKLabelNode(text: ammoIconString)
        projectileIcon.fontSize = 13
        projectileIcon.verticalAlignmentMode = .center
        projectileIcon.horizontalAlignmentMode = .center
        pouchNode.addChild(projectileIcon)
        
        updateBands(pouchLocation: currentPouchPos)
    }
    
    private var ammoIconString: String {
        switch card {
        case .arrows: return "🏹"
        case .stones: return "🪨"
        case .fireball: return "🔥"
        case .counterattack: return "⚡️"
        default: return "🎯"
        }
    }
    
    private func setupTrajectoryDots() {
        let count = GameConfig.trajectoryPreviewPointCount
        for i in 0..<count {
            let radius = max(2.0, 4.5 - CGFloat(i) * 0.12)
            let dot = SKShapeNode(circleOfRadius: radius)
            dot.fillColor = SKColor.yellow.withAlphaComponent(0.9 - CGFloat(i) * 0.03)
            dot.strokeColor = .orange
            dot.lineWidth = 1.0
            dot.zPosition = 20
            dot.isHidden = true
            addChild(dot)
            trajectoryDots.append(dot)
        }
    }
    
    public func handleTouchBegan(at point: CGPoint) {
        isDragging = true
        updateAim(at: point)
    }
    
    public func updateAim(at worldPoint: CGPoint) {
        let localTouch = CGPoint(x: worldPoint.x - position.x, y: worldPoint.y - position.y)
        let clamped = TrajectoryMath.clampDrag(
            origin: .zero,
            touch: localTouch,
            maxRadius: GameConfig.maxSlingshotDragRadius
        )
        currentPouchPos = clamped
        pouchNode.position = clamped
        updateBands(pouchLocation: clamped)
        
        // Invert vector: pulling DOWN (-dy) gives UPWARD launch (+vy)
        let velocity = TrajectoryMath.calculateLaunchVelocity(
            origin: .zero,
            dragPosition: clamped,
            speedFactor: GameConfig.launchSpeedFactor,
            cardMultiplier: card.speedMultiplier
        )
        
        // Vertical arc simulation
        let effectiveGravity = GameConfig.baseGravity * CGFloat(card.gravityFactor)
        let previewDuration = 1.2 * GameConfig.trajectoryPreviewPercent
        let pointCount = GameConfig.trajectoryPreviewPointCount
        
        var points: [CGPoint] = []
        points.reserveCapacity(pointCount)
        
        for i in 0..<pointCount {
            let t = previewDuration * (Double(i) / Double(pointCount - 1))
            let x = Double(velocity.dx) * t
            let y = Double(velocity.dy) * t + 0.5 * Double(effectiveGravity) * t * t
            points.append(CGPoint(x: x, y: y))
        }
        
        let dragDistance = hypot(clamped.x, clamped.y)
        for (i, dot) in trajectoryDots.enumerated() {
            if i < points.count && dragDistance > 12 {
                dot.position = points[i]
                dot.isHidden = false
            } else {
                dot.isHidden = true
            }
        }
    }
    
    public func handleTouchEnded(at worldPoint: CGPoint) {
        let localTouch = CGPoint(x: worldPoint.x - position.x, y: worldPoint.y - position.y)
        let clamped = TrajectoryMath.clampDrag(
            origin: .zero,
            touch: localTouch,
            maxRadius: GameConfig.maxSlingshotDragRadius
        )
        let dragDistance = hypot(clamped.x, clamped.y)
        
        if dragDistance >= 15 {
            let velocity = TrajectoryMath.calculateLaunchVelocity(
                origin: .zero,
                dragPosition: clamped,
                speedFactor: GameConfig.launchSpeedFactor,
                cardMultiplier: card.speedMultiplier
            )
            
            pouchNode.run(SKAction.move(to: .zero, duration: 0.08))
            hideTrajectory()
            onLaunch?(velocity)
            
            run(SKAction.sequence([
                SKAction.wait(forDuration: 0.1),
                SKAction.fadeOut(withDuration: 0.12),
                SKAction.removeFromParent()
            ]))
        } else {
            pouchNode.run(SKAction.move(to: CGPoint(x: 0, y: -5), duration: 0.15))
            updateBands(pouchLocation: CGPoint(x: 0, y: -5))
            hideTrajectory()
            onCancel?()
        }
        isDragging = false
    }
    
    private func updateBands(pouchLocation: CGPoint) {
        let leftPath = CGMutablePath()
        leftPath.move(to: leftAnchor)
        leftPath.addLine(to: pouchLocation)
        leftBand.path = leftPath
        
        let rightPath = CGMutablePath()
        rightPath.move(to: rightAnchor)
        rightPath.addLine(to: pouchLocation)
        rightBand.path = rightPath
    }
    
    private func hideTrajectory() {
        for dot in trajectoryDots {
            dot.isHidden = true
        }
    }
}
