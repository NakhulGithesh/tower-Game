import SpriteKit

/// Autonomous bot controlling Player B during solo practice / pass & play test mode.
public final class AIController {
    
    private weak var scene: GameScene?
    public private(set) var energy: Double = GameConfig.initialEnergy
    private var lastActionTime: TimeInterval = 0
    private var actionCooldown: TimeInterval = 3.5
    
    public init(scene: GameScene) {
        self.scene = scene
    }
    
    public func update(deltaTime: TimeInterval, currentTime: TimeInterval) {
        guard let scene = scene, case .combat = scene.currentPhase else { return }
        
        // Recharge energy (+1 every 2.5s)
        energy = min(GameConfig.maxEnergy, energy + deltaTime * GameConfig.energyRechargeRate)
        
        if currentTime - lastActionTime >= actionCooldown {
            makeDecision(currentTime: currentTime)
        }
    }
    
    private func makeDecision(currentTime: TimeInterval) {
        guard let scene = scene else { return }
        let (t1, t2) = scene.remoteTowers
        let aiTowers = [t1, t2].filter { !$0.isDestroyed && $0.currentHP > 0 }
        
        // 1. Repair if damaged (< 850 HP)
        for tower in aiTowers where tower.currentHP < 850 && tower.cardSlot.canAcceptCard && energy >= Double(CardType.repair.cost) {
            castDefenseCard(.repair, on: tower)
            lastActionTime = currentTime
            actionCooldown = Double.random(in: 3.5...5.5)
            return
        }
        
        // 2. Shield if low HP (< 600 HP)
        for tower in aiTowers where tower.currentHP < 600 && tower.cardSlot.canAcceptCard && energy >= Double(CardType.shield.cost) {
            castDefenseCard(.shield, on: tower)
            lastActionTime = currentTime
            actionCooldown = Double.random(in: 4.0...6.0)
            return
        }
        
        // 3. Offensive Attacks
        let attackOptions: [CardType] = [.fireball, .stones, .arrows]
        for card in attackOptions where energy >= Double(card.cost) {
            if let readyTower = aiTowers.first(where: { $0.cardSlot.canAcceptCard }) {
                launchAttack(card: card, from: readyTower)
                lastActionTime = currentTime
                actionCooldown = Double.random(in: 3.0...5.0)
                return
            }
        }
    }
    
    private func castDefenseCard(_ card: CardType, on tower: TowerNode) {
        guard !tower.isDestroyed else { return }
        energy -= Double(card.cost)
        _ = tower.cardSlot.applyCard(card)
        tower.displayActiveCardBadge(for: card)
        
        if card == .repair {
            let sparkles = ParticleFactory.makeHealingSparkles()
            sparkles.position = CGPoint(x: 0, y: -20)
            tower.addChild(sparkles)
            
            let healPerSec = card.healAmount / 5
            let healAction = SKAction.repeat(SKAction.sequence([
                SKAction.wait(forDuration: 1.0),
                SKAction.run { tower.heal(healPerSec) }
            ]), count: 5)
            tower.run(healAction)
        }
    }
    
    private func launchAttack(card: CardType, from tower: TowerNode) {
        guard let scene = scene, !tower.isDestroyed else { return }
        
        let (target1, target2) = scene.localTowers
        let liveTargets = [target1, target2].filter { !$0.isDestroyed && $0.currentHP > 0 }
        guard let target = liveTargets.min(by: { $0.currentHP < $1.currentHP }) else { return }
        
        energy -= Double(card.cost)
        
        // In vertical arena, AI fires DOWNWARD (-Y) towards Player A
        let dx = (target.position.x - tower.position.x) * 0.7
        let dy: CGFloat = -CGFloat.random(in: 380...520)
        let vector = CGVector(dx: dx, dy: dy)
        
        scene.spawnProjectile(
            card: card,
            owner: .playerB,
            origin: tower.launchOrigin,
            velocity: vector
        )
    }
}
