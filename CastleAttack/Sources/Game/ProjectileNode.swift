import SpriteKit

public final class ProjectileNode: SKNode {
    
    public let card: CardType
    public let owner: PlayerID
    public var velocity: CGVector
    public let damage: Int
    
    public var hasSplit = false
    private var isDestroyed = false
    private var timeInFlight: TimeInterval = 0
    
    private var coreShape: SKShapeNode!
    private var emitter: SKEmitterNode?
    
    public var onHitTower: ((TowerNode, ProjectileNode) -> Void)?
    
    public init(card: CardType, owner: PlayerID, origin: CGPoint, velocity: CGVector) {
        self.card = card
        self.owner = owner
        self.velocity = velocity
        self.damage = card.impactDamage
        super.init()
        self.position = origin
        self.zPosition = 35
        
        setupProjectileVisuals()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupProjectileVisuals() {
        switch card {
        case .arrows:
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0, y: 16))
            path.addLine(to: CGPoint(x: 0, y: -16))
            path.move(to: CGPoint(x: 0, y: 16))
            path.addLine(to: CGPoint(x: -5, y: 8))
            path.move(to: CGPoint(x: 0, y: 16))
            path.addLine(to: CGPoint(x: 5, y: 8))
            path.move(to: CGPoint(x: 0, y: -16))
            path.addLine(to: CGPoint(x: -4, y: -22))
            path.move(to: CGPoint(x: 0, y: -16))
            path.addLine(to: CGPoint(x: 4, y: -22))
            
            coreShape = SKShapeNode(path: path)
            coreShape.strokeColor = .white
            coreShape.lineWidth = 2.0
            addChild(coreShape)
            
            let trail = ParticleFactory.makeWindTrail()
            trail.targetNode = self.parent
            addChild(trail)
            self.emitter = trail
            
        case .stones:
            let path = CGMutablePath()
            let pts: [(CGFloat, CGFloat)] = [
                (14, 4), (10, 14), (-4, 16), (-15, 8),
                (-16, -6), (-6, -15), (8, -14), (15, -4)
            ]
            path.move(to: CGPoint(x: pts[0].0, y: pts[0].1))
            for pt in pts.dropFirst() {
                path.addLine(to: CGPoint(x: pt.0, y: pt.1))
            }
            path.closeSubpath()
            
            coreShape = SKShapeNode(path: path)
            coreShape.fillColor = SKColor(red: 0.40, green: 0.38, blue: 0.35, alpha: 1.0)
            coreShape.strokeColor = SKColor(red: 0.25, green: 0.22, blue: 0.20, alpha: 1.0)
            coreShape.lineWidth = 2.0
            addChild(coreShape)
            
            let trail = ParticleFactory.makeDustTrail()
            trail.targetNode = self.parent
            addChild(trail)
            self.emitter = trail
            
        case .fireball:
            coreShape = SKShapeNode(circleOfRadius: 13)
            coreShape.fillColor = SKColor(red: 1.0, green: 0.8, blue: 0.2, alpha: 1.0)
            coreShape.strokeColor = SKColor(red: 1.0, green: 0.3, blue: 0.0, alpha: 1.0)
            coreShape.lineWidth = 3.0
            addChild(coreShape)
            
            let trail = ParticleFactory.makeFireballTrail()
            trail.targetNode = self.parent
            addChild(trail)
            self.emitter = trail
            
        case .counterattack:
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0, y: 18))
            path.addLine(to: CGPoint(x: -4, y: -16))
            path.addLine(to: CGPoint(x: 0, y: -10))
            path.addLine(to: CGPoint(x: 4, y: -16))
            path.closeSubpath()
            
            coreShape = SKShapeNode(path: path)
            coreShape.fillColor = SKColor(red: 0.2, green: 0.9, blue: 1.0, alpha: 1.0)
            coreShape.strokeColor = .yellow
            coreShape.lineWidth = 2.0
            addChild(coreShape)
            
            let trail = ParticleFactory.makeLightningTrail()
            trail.targetNode = self.parent
            addChild(trail)
            self.emitter = trail
            
        default:
            coreShape = SKShapeNode(circleOfRadius: 8)
            coreShape.fillColor = .white
            addChild(coreShape)
        }
    }
    
    // MARK: - Simulation Step
    public func updatePhysics(deltaTime: TimeInterval, arenaBounds: CGRect, towers: [TowerNode], scene: SKScene) {
        guard !isDestroyed else { return }
        timeInFlight += deltaTime
        
        // Vertical arc integration: base gravity applies in Y axis
        // For Player A (firing UP +Y), gravity pulls downward
        // For Player B (firing DOWN -Y), gravity accelerates downward
        let gravityDir: CGFloat = (owner == .playerA) ? 1.0 : -1.0
        let effectiveGravity = GameConfig.baseGravity * CGFloat(card.gravityFactor) * gravityDir
        velocity.dy += effectiveGravity * CGFloat(deltaTime)
        
        position.x += velocity.dx * CGFloat(deltaTime)
        position.y += velocity.dy * CGFloat(deltaTime)
        
        // Orientation
        if card == .stones {
            zRotation += 0.15
        } else {
            // Align with velocity direction
            zRotation = atan2(velocity.dy, velocity.dx) - .pi / 2
        }
        
        // Arrow mid-air split
        if card == .arrows && !hasSplit && timeInFlight >= 0.40 {
            triggerArrowSplit(scene: scene)
        }
        
        // Bulletproof Radial Distance Collision
        for tower in towers where tower.playerID != owner {
            let targetCenter = CGPoint(x: tower.position.x, y: tower.position.y + 15)
            let dist = hypot(position.x - targetCenter.x, position.y - targetCenter.y)
            
            // Check Shield Dome collision first
            if let dome = tower.shieldDomeNode {
                let domeDist = hypot(position.x - tower.position.x, position.y - (tower.position.y + 10))
                if domeDist <= 62.0 {
                    destroyOnShield(dome: dome, tower: tower, scene: scene)
                    return
                }
            }
            
            // Radial hit confirmed (r <= 55 pt)
            if dist <= GameConfig.towerCollisionRadius {
                hitTower(tower, scene: scene)
                return
            }
        }
        
        // Arena Boundary Check (Y: 130 to 860, X: -40 to 470)
        if position.y < 130 || position.y > 860 || position.x < -40 || position.x > 470 {
            destroyGroundImpact(scene: scene)
        }
    }
    
    private func triggerArrowSplit(scene: SKScene) {
        guard let gameScene = scene as? GameScene else { return }
        hasSplit = true
        
        let burst = ParticleFactory.makeArrowSplitBurst()
        burst.position = position
        scene.addChild(burst)
        
        // Split into left and right sub-arrows
        let spreads: [CGFloat] = [-80.0, 80.0]
        for dx in spreads {
            gameScene.spawnProjectile(
                card: .arrows,
                owner: owner,
                origin: position,
                velocity: CGVector(dx: velocity.dx + dx, dy: velocity.dy),
                hasSplit: true
            )
        }
    }
    
    private func hitTower(_ tower: TowerNode, scene: SKScene) {
        isDestroyed = true
        tower.takeDamage(damage)
        
        switch card {
        case .stones:
            let debris = ParticleFactory.makeRockImpactDebris()
            debris.position = position
            scene.addChild(debris)
            triggerScreenShake(scene: scene)
            
        case .fireball:
            let fire = ParticleFactory.makeFireExplosion()
            fire.position = position
            scene.addChild(fire)
            applyBurnDoT(to: tower)
            
        case .arrows:
            let burst = ParticleFactory.makeArrowSplitBurst()
            burst.position = position
            scene.addChild(burst)
            
        case .counterattack:
            let sparks = ParticleFactory.makeLightningTrail()
            sparks.position = position
            sparks.numParticlesToEmit = 30
            scene.addChild(sparks)
            
        default:
            break
        }
        
        onHitTower?(tower, self)
        cleanup()
    }
    
    private func destroyOnShield(dome: SKShapeNode, tower: TowerNode, scene: SKScene) {
        isDestroyed = true
        let shatter = ParticleFactory.makeShieldShatter()
        shatter.position = position
        scene.addChild(shatter)
        
        tower.removeShieldDome()
        tower.cardSlot.releaseLock()
        tower.clearActiveCardBadge()
        cleanup()
    }
    
    private func destroyGroundImpact(scene: SKScene) {
        isDestroyed = true
        if card == .stones {
            let debris = ParticleFactory.makeRockImpactDebris()
            debris.position = position
            scene.addChild(debris)
            triggerScreenShake(scene: scene)
        } else if card == .fireball {
            let fire = ParticleFactory.makeFireExplosion()
            fire.position = position
            scene.addChild(fire)
        }
        cleanup()
    }
    
    private func triggerScreenShake(scene: SKScene) {
        let shake = SKAction.sequence([
            SKAction.moveBy(x: 0, y: 6, duration: 0.04),
            SKAction.moveBy(x: 0, y: -12, duration: 0.04),
            SKAction.moveBy(x: 0, y: 8, duration: 0.04),
            SKAction.moveBy(x: 0, y: -2, duration: 0.04)
        ])
        scene.run(shake)
    }
    
    private func applyBurnDoT(to tower: TowerNode) {
        let ticks = 5
        let burnPerTick = card.burnDamage / ticks // 10 HP per sec
        
        let burnAction = SKAction.repeat(SKAction.sequence([
            SKAction.wait(forDuration: 1.0),
            SKAction.run { tower.takeDamage(burnPerTick) }
        ]), count: ticks)
        tower.run(burnAction, withKey: "burnDoT")
    }
    
    public func cleanup() {
        emitter?.particleBirthRate = 0
        run(SKAction.sequence([
            SKAction.fadeOut(withDuration: 0.1),
            SKAction.removeFromParent()
        ]))
    }
}
