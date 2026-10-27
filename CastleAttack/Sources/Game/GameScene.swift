import SpriteKit
import SwiftUI

public enum GameScenePhase: Equatable {
    case placement
    case countdown(seconds: Int)
    case combat
    case victory(winner: PlayerID)
}

public final class GameScene: SKScene {
    
    // MARK: - Core References
    public weak var network: NetworkManager?
    public var aiController: AIController?
    
    // State Tracking
    public private(set) var currentPhase: GameScenePhase = .placement
    public private(set) var localPlayerID: PlayerID = .playerA
    
    public var isLocalLockedIn = false
    public var isRemoteLockedIn = false
    
    // Energy System (0 to 10)
    public private(set) var currentEnergy: Double = GameConfig.initialEnergy
    
    // Tower Storage
    public private(set) var playerATower1: TowerNode!
    public private(set) var playerATower2: TowerNode!
    public private(set) var playerBTower1: TowerNode!
    public private(set) var playerBTower2: TowerNode!
    
    // Nodes
    private var backgroundNode: ArenaBackgroundNode!
    private var localPlacementZone: PlacementZoneNode?
    private var countdownLabel: SKLabelNode?
    private var activeSlingshot: SlingshotNode?
    private var aimingTower: TowerNode?
    
    // Active Flying Projectiles
    public private(set) var activeProjectiles: [ProjectileNode] = []
    
    // Touch & Drag Handling for Pre-Game Placement
    private var draggedTower: TowerNode?
    private var touchOffset: CGPoint = .zero
    private var lastUpdateTime: TimeInterval = 0
    private var isResolvingMatchOutcome = false
    
    // Callbacks to SwiftUI HUD
    public var onPhaseChange: ((GameScenePhase) -> Void)?
    public var onPlacementValidityChange: ((Bool) -> Void)?
    public var onEnergyUpdate: ((Double) -> Void)?
    public var onTowerCardRejected: ((TowerID) -> Void)?
    
    // MARK: - Initializer & Setup
    public override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.05, green: 0.07, blue: 0.12, alpha: 1.0)
        self.scaleMode = .resizeFill
        
        if let net = network {
            self.localPlayerID = net.localPlayerID
        }
        
        setupArenaBackground()
        setupTowers()
        setupPlacementPhase()
        listenToNetworkPackets()
        
        if network?.role == .localAI {
            self.aiController = AIController(scene: self)
        }
    }
    
    // MARK: - Arena Setup
    private func setupArenaBackground() {
        backgroundNode = ArenaBackgroundNode(size: size)
        addChild(backgroundNode)
    }
    
    private func setupTowers() {
        // Vertical Clash Royale Positions:
        // Local Player A (Bottom): Tower 1 Left (115, 250), Tower 2 Right (315, 250)
        let a1Pos = CGPoint(x: 115, y: 250)
        let a2Pos = CGPoint(x: 315, y: 250)
        playerATower1 = TowerNode(towerID: .tower1, playerID: .playerA, position: a1Pos)
        playerATower2 = TowerNode(towerID: .tower2, playerID: .playerA, position: a2Pos)
        addChild(playerATower1)
        addChild(playerATower2)
        
        // Remote Opponent B (Top): Tower 1 Left (115, 680), Tower 2 Right (315, 680)
        let b1Pos = CGPoint(x: 115, y: 680)
        let b2Pos = CGPoint(x: 315, y: 680)
        playerBTower1 = TowerNode(towerID: .tower1, playerID: .playerB, position: b1Pos)
        playerBTower2 = TowerNode(towerID: .tower2, playerID: .playerB, position: b2Pos)
        addChild(playerBTower1)
        addChild(playerBTower2)
        
        updateDraggability()
    }
    
    private func updateDraggability() {
        let isPlacement = currentPhase == .placement && !isLocalLockedIn
        playerATower1.isDraggable = isPlacement && localPlayerID == .playerA
        playerATower2.isDraggable = isPlacement && localPlayerID == .playerA
        playerBTower1.isDraggable = isPlacement && localPlayerID == .playerB
        playerBTower2.isDraggable = isPlacement && localPlayerID == .playerB
    }
    
    // MARK: - Placement Phase Logic
    private func setupPlacementPhase() {
        let zone = PlacementZoneNode(playerID: localPlayerID, arenaSize: size)
        addChild(zone)
        self.localPlacementZone = zone
        
        if network?.role == .localAI {
            isRemoteLockedIn = true
        }
        
        validateCurrentPlacement()
    }
    
    public var localTowers: (TowerNode, TowerNode) {
        return localPlayerID == .playerA
            ? (playerATower1, playerATower2)
            : (playerBTower1, playerBTower2)
    }
    
    public var remoteTowers: (TowerNode, TowerNode) {
        return localPlayerID == .playerA
            ? (playerBTower1, playerBTower2)
            : (playerATower1, playerATower2)
    }
    
    public var allTowers: [TowerNode] {
        return [playerATower1, playerATower2, playerBTower1, playerBTower2]
    }
    
    @discardableResult
    public func validateCurrentPlacement() -> Bool {
        let (t1, t2) = localTowers
        let distance = hypot(t1.position.x - t2.position.x, t1.position.y - t2.position.y)
        let isSpacingValid = distance >= GameConfig.minTowerSpacing
        
        localPlacementZone?.setSpacingWarning(at: t1.position, isTooClose: !isSpacingValid)
        onPlacementValidityChange?(isSpacingValid)
        return isSpacingValid
    }
    
    public func lockInLocalTowers() {
        guard currentPhase == .placement, !isLocalLockedIn else { return }
        guard validateCurrentPlacement() else { return }
        
        isLocalLockedIn = true
        updateDraggability()
        
        let (t1, t2) = localTowers
        
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        #endif
        
        network?.send(payload: .towerPlacement(
            playerID: localPlayerID,
            tower1Pos: SerializablePoint(t1.position),
            tower2Pos: SerializablePoint(t2.position)
        ))
        
        checkBothPlayersLockedIn()
    }
    
    public func applyRemoteTowerPlacement(playerID: PlayerID, t1Pos: CGPoint, t2Pos: CGPoint) {
        guard playerID != localPlayerID else { return }
        let (t1, t2) = remoteTowers
        t1.run(SKAction.move(to: t1Pos, duration: 0.35).then(SKAction.springPulse()))
        t2.run(SKAction.move(to: t2Pos, duration: 0.35).then(SKAction.springPulse()))
        isRemoteLockedIn = true
        checkBothPlayersLockedIn()
    }
    
    private func checkBothPlayersLockedIn() {
        guard isLocalLockedIn && isRemoteLockedIn else { return }
        startCountdownTransition()
    }
    
    // MARK: - Animated Countdown Transition
    private func startCountdownTransition() {
        localPlacementZone?.dismiss()
        localPlacementZone = nil
        
        let countNode = SKLabelNode(text: "READY!")
        countNode.fontName = "AvenirNext-Heavy"
        countNode.fontSize = 42
        countNode.fontColor = .yellow
        countNode.position = CGPoint(x: size.width / 2, y: size.height * 0.48)
        countNode.zPosition = 100
        addChild(countNode)
        self.countdownLabel = countNode
        
        var count = 3
        currentPhase = .countdown(seconds: count)
        onPhaseChange?(currentPhase)
        
        let countdownAction = SKAction.repeat(SKAction.sequence([
            SKAction.run { [weak self] in
                guard let self = self else { return }
                self.countdownLabel?.text = "\(count)"
                self.countdownLabel?.setScale(1.4)
                self.countdownLabel?.run(SKAction.scale(to: 1.0, duration: 0.3))
                self.currentPhase = .countdown(seconds: count)
                self.onPhaseChange?(self.currentPhase)
                count -= 1
            },
            SKAction.wait(forDuration: 1.0)
        ]), count: 3)
        
        let battleAction = SKAction.sequence([
            countdownAction,
            SKAction.run { [weak self] in
                guard let self = self else { return }
                self.countdownLabel?.text = "BATTLE!"
                self.countdownLabel?.fontColor = .red
                self.countdownLabel?.run(SKAction.sequence([
                    SKAction.scale(to: 1.6, duration: 0.25),
                    SKAction.wait(forDuration: 0.6),
                    SKAction.fadeOut(withDuration: 0.4),
                    SKAction.removeFromParent()
                ]))
                self.currentPhase = .combat
                self.onPhaseChange?(.combat)
            }
        ])
        run(battleAction)
    }
    
    // MARK: - Direct Drag-and-Drop Targeting (No Button Bar)
    
    /// Called continuously as player drags a card across the arena.
    public func handleCardDragHover(at scenePoint: CGPoint) {
        guard case .combat = currentPhase else { return }
        let (t1, t2) = localTowers
        
        let d1 = hypot(scenePoint.x - t1.position.x, scenePoint.y - t1.position.y)
        let d2 = hypot(scenePoint.x - t2.position.x, scenePoint.y - t2.position.y)
        
        if d1 <= 75.0 && !t1.isDestroyed {
            t1.isTargetHaloActive = true
            t2.isTargetHaloActive = false
        } else if d2 <= 75.0 && !t2.isDestroyed {
            t2.isTargetHaloActive = true
            t1.isTargetHaloActive = false
        } else {
            t1.isTargetHaloActive = false
            t2.isTargetHaloActive = false
        }
    }
    
    /// Called when player releases the card over the arena.
    public func handleCardDrop(card: CardType, at scenePoint: CGPoint) {
        guard case .combat = currentPhase else { return }
        let (t1, t2) = localTowers
        
        t1.isTargetHaloActive = false
        t2.isTargetHaloActive = false
        
        let d1 = hypot(scenePoint.x - t1.position.x, scenePoint.y - t1.position.y)
        let d2 = hypot(scenePoint.x - t2.position.x, scenePoint.y - t2.position.y)
        
        if d1 <= 75.0 && !t1.isDestroyed {
            applyCardToTower(card: card, towerID: .tower1)
        } else if d2 <= 75.0 && !t2.isDestroyed {
            applyCardToTower(card: card, towerID: .tower2)
        }
    }
    
    /// Core application of card with Single-Card-Per-Tower rule.
    @discardableResult
    public func applyCardToTower(card: CardType, towerID: TowerID) -> Bool {
        guard case .combat = currentPhase else { return false }
        guard currentEnergy >= Double(card.cost) else { return false }
        
        let (t1, t2) = localTowers
        let tower = towerID == .tower1 ? t1 : t2
        
        guard !tower.isDestroyed else { return false }
        
        // Single-Card-Per-Tower rule: reject if busy!
        guard tower.cardSlot.canAcceptCard else {
            triggerRejectionAnimation(on: tower)
            onTowerCardRejected?(towerID)
            return false
        }
        
        currentEnergy -= Double(card.cost)
        onEnergyUpdate?(currentEnergy)
        
        let result = tower.cardSlot.applyCard(card)
        guard case .success = result else { return false }
        
        tower.displayActiveCardBadge(for: card)
        network?.send(payload: .cardApplied(playerID: localPlayerID, towerID: towerID, cardType: card))
        
        if card == .shield {
            #if os(iOS)
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            #endif
        } else if card == .repair {
            let sparkles = ParticleFactory.makeHealingSparkles()
            sparkles.position = CGPoint(x: 0, y: -20)
            tower.addChild(sparkles)
            
            let healPerSec = card.healAmount / 5
            let healAction = SKAction.repeat(SKAction.sequence([
                SKAction.wait(forDuration: 1.0),
                SKAction.run { tower.heal(healPerSec) }
            ]), count: 5)
            tower.run(healAction)
        } else if card.isAimable {
            spawnSlingshot(on: tower, card: card)
        }
        
        return true
    }
    
    private func triggerRejectionAnimation(on tower: TowerNode) {
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
        #endif
        
        let shake = SKAction.sequence([
            SKAction.moveBy(x: -8, y: 0, duration: 0.05),
            SKAction.moveBy(x: 16, y: 0, duration: 0.05),
            SKAction.moveBy(x: -12, y: 0, duration: 0.05),
            SKAction.moveBy(x: 4, y: 0, duration: 0.05)
        ])
        tower.run(shake)
    }
    
    // MARK: - Slingshot Aiming Controller
    private func spawnSlingshot(on tower: TowerNode, card: CardType) {
        guard !tower.isDestroyed else { return }
        activeSlingshot?.removeFromParent()
        
        let slingshot = SlingshotNode(card: card, origin: tower.launchOrigin, playerID: localPlayerID)
        addChild(slingshot)
        self.activeSlingshot = slingshot
        self.aimingTower = tower
        
        slingshot.onLaunch = { [weak self, weak tower] vector in
            guard let self = self, let tower = tower else { return }
            self.launchProjectile(card: card, from: tower, velocity: vector)
        }
        
        slingshot.onCancel = { [weak self, weak tower] in
            guard let self = self, let tower = tower else { return }
            tower.cardSlot.releaseLock()
            tower.clearActiveCardBadge()
            self.activeSlingshot = nil
            self.aimingTower = nil
        }
    }
    
    private func launchProjectile(card: CardType, from tower: TowerNode, velocity: CGVector) {
        tower.cardSlot.releaseLock()
        tower.clearActiveCardBadge()
        
        spawnProjectile(card: card, owner: localPlayerID, origin: tower.launchOrigin, velocity: velocity)
        
        network?.send(payload: .projectileLaunched(
            playerID: localPlayerID,
            towerID: tower.towerID,
            cardType: card,
            launchVector: SerializableVector(velocity)
        ))
        
        self.activeSlingshot = nil
        self.aimingTower = nil
    }
    
    @discardableResult
    public func spawnProjectile(card: CardType, owner: PlayerID, origin: CGPoint, velocity: CGVector, hasSplit: Bool = false) -> ProjectileNode {
        let projectile = ProjectileNode(card: card, owner: owner, origin: origin, velocity: velocity)
        projectile.hasSplit = hasSplit
        addChild(projectile)
        activeProjectiles.append(projectile)
        return projectile
    }
    
    // MARK: - Touch Handling
    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        
        if currentPhase == .placement && !isLocalLockedIn {
            let (t1, t2) = localTowers
            for tower in [t1, t2] where tower.isDraggable && tower.contains(location) {
                draggedTower = tower
                tower.isSelected = true
                touchOffset = CGPoint(
                    x: tower.position.x - location.x,
                    y: tower.position.y - location.y
                )
                break
            }
            return
        }
        
        if let slingshot = activeSlingshot {
            slingshot.handleTouchBegan(at: location)
        }
    }
    
    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        
        if let tower = draggedTower, let zone = localPlacementZone {
            let candidatePos = CGPoint(x: location.x + touchOffset.x, y: location.y + touchOffset.y)
            tower.position = zone.clampPosition(candidatePos)
            validateCurrentPlacement()
            return
        }
        
        if let slingshot = activeSlingshot {
            slingshot.updateAim(at: location)
        }
    }
    
    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        
        if draggedTower != nil {
            draggedTower?.isSelected = false
            draggedTower = nil
            validateCurrentPlacement()
            return
        }
        
        if let slingshot = activeSlingshot {
            slingshot.handleTouchEnded(at: location)
        }
    }
    
    public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesEnded(touches, with: event)
    }
    
    // MARK: - Frame Update Loop
    public override func update(_ currentTime: TimeInterval) {
        if lastUpdateTime == 0 { lastUpdateTime = currentTime }
        let dt = currentTime - lastUpdateTime
        lastUpdateTime = currentTime
        
        // Recharge Elixir (+1 every 2.5s)
        if case .combat = currentPhase {
            currentEnergy = min(GameConfig.maxEnergy, currentEnergy + dt * GameConfig.energyRechargeRate)
            onEnergyUpdate?(currentEnergy)
            aiController?.update(deltaTime: dt, currentTime: currentTime)
        }
        
        for tower in allTowers {
            tower.updateTimers(deltaTime: dt)
        }
        
        // Cancel active slingshot if the aiming tower was destroyed
        if let aiming = aimingTower, aiming.isDestroyed {
            activeSlingshot?.removeFromParent()
            activeSlingshot = nil
            aimingTower = nil
        }
        
        var deadProjectiles: [ProjectileNode] = []
        for projectile in Array(activeProjectiles) {
            projectile.updatePhysics(
                deltaTime: dt,
                arenaBounds: CGRect(origin: .zero, size: size),
                towers: allTowers,
                scene: self
            )
            if projectile.parent == nil {
                deadProjectiles.append(projectile)
            }
        }
        activeProjectiles.removeAll(where: { deadProjectiles.contains($0) })
        
        checkMatchOutcome()
    }
    
    private func checkMatchOutcome() {
        guard case .combat = currentPhase, !isResolvingMatchOutcome else { return }
        
        let playerADefeated = playerATower1.currentHP <= 0 && playerATower2.currentHP <= 0
        let playerBDefeated = playerBTower1.currentHP <= 0 && playerBTower2.currentHP <= 0
        
        if playerADefeated || playerBDefeated {
            isResolvingMatchOutcome = true
            let winner: PlayerID = playerADefeated ? .playerB : .playerA
            
            run(SKAction.sequence([
                SKAction.wait(forDuration: 1.5),
                SKAction.run { [weak self] in
                    guard let self = self else { return }
                    self.currentPhase = .victory(winner: winner)
                    self.onPhaseChange?(self.currentPhase)
                }
            ]))
        }
    }
    
    // MARK: - Network Packet Receiver
    private func listenToNetworkPackets() {
        network?.onPacketReceived = { [weak self] packet in
            guard let self = self else { return }
            switch packet.payload {
            case .towerPlacement(let senderID, let t1, let t2):
                self.applyRemoteTowerPlacement(playerID: senderID, t1Pos: t1.cgPoint, t2Pos: t2.cgPoint)
            case .cardApplied(let player, let towerID, let card):
                self.handleRemoteCardApplied(player: player, towerID: towerID, card: card)
            case .projectileLaunched(let player, let towerID, let card, let vector):
                self.handleRemoteProjectileLaunched(player: player, towerID: towerID, card: card, vector: vector.cgVector)
            case .towerHealthSync(let towerID, let hp):
                self.handleRemoteHealthSync(towerID: towerID, currentHP: hp)
            case .gameRestart:
                self.resetScene()
            default:
                break
            }
        }
    }
    
    private func handleRemoteCardApplied(player: PlayerID, towerID: TowerID, card: CardType) {
        guard player != localPlayerID else { return }
        let (t1, t2) = remoteTowers
        let tower = towerID == .tower1 ? t1 : t2
        _ = tower.cardSlot.applyCard(card)
        tower.displayActiveCardBadge(for: card)
        
        if card == .repair {
            let sparkles = ParticleFactory.makeHealingSparkles()
            sparkles.position = CGPoint(x: 0, y: -20)
            tower.addChild(sparkles)
        }
    }
    
    private func handleRemoteProjectileLaunched(player: PlayerID, towerID: TowerID, card: CardType, vector: CGVector) {
        guard player != localPlayerID else { return }
        let (t1, t2) = remoteTowers
        let tower = towerID == .tower1 ? t1 : t2
        tower.cardSlot.releaseLock()
        tower.clearActiveCardBadge()
        spawnProjectile(card: card, owner: player, origin: tower.launchOrigin, velocity: vector)
    }
    
    private func handleRemoteHealthSync(towerID: TowerID, currentHP: Int) {
        let (t1, t2) = remoteTowers
        let tower = towerID == .tower1 ? t1 : t2
        tower.setHealth(currentHP)
    }
    
    public func resetScene() {
        removeAllActions()
        removeAllChildren()
        activeProjectiles.removeAll()
        activeSlingshot = nil
        aimingTower = nil
        isLocalLockedIn = false
        isRemoteLockedIn = false
        isResolvingMatchOutcome = false
        currentEnergy = GameConfig.initialEnergy
        currentPhase = .placement
        didMove(to: view ?? SKView())
    }
}
