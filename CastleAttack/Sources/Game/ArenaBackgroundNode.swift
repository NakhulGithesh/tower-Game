import SpriteKit

/// Vertical 2.5D Clash Royale Arena Background:
/// - Top-down battlefield perspective
/// - Bottom Dock boundary (Y: 140 pt)
/// - Player Green Grasslands (Y: 150 - 420 pt) with cobblestone lanes
/// - Horizontal Central River with dynamic water ripples (Y: 440 - 490 pt)
/// - Twin stone-and-timber bridges (Left X: 115, Right X: 315)
/// - Opponent Territory (Y: 510 - 780 pt) with scorched grass and stone lanes
/// - Distant castle ramparts and twilight horizon at the top
public final class ArenaBackgroundNode: SKNode {
    
    private let arenaSize: CGSize
    
    public init(size: CGSize) {
        self.arenaSize = size
        super.init()
        self.zPosition = -100
        
        setupTerrain()
        setupRiverAndBridges()
        setupCobblestonePaths()
        setupBoundaryTrim()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupTerrain() {
        let width = arenaSize.width
        let height = arenaSize.height
        
        // 1. Overall Backdrop / Sky at Top
        let backdrop = SKSpriteNode(
            color: SKColor(red: 0.08, green: 0.09, blue: 0.16, alpha: 1.0),
            size: arenaSize
        )
        backdrop.position = CGPoint(x: width / 2, y: height / 2)
        addChild(backdrop)
        
        // 2. Local Player Grassland (Bottom Half: Y 140 to 440)
        let playerGrassRect = CGRect(x: 10, y: 140, width: width - 20, height: 300)
        let playerGrass = SKShapeNode(rect: playerGrassRect, cornerRadius: 16)
        playerGrass.fillColor = SKColor(red: 0.18, green: 0.44, blue: 0.22, alpha: 1.0) // Vibrant royal green
        playerGrass.strokeColor = SKColor(red: 0.25, green: 0.55, blue: 0.28, alpha: 1.0)
        playerGrass.lineWidth = 3.0
        addChild(playerGrass)
        
        // Checkered grass tile details (Clash Royale grass pattern)
        for row in 0..<4 {
            for col in 0..<5 {
                if (row + col) % 2 == 0 {
                    let tileW = (width - 40) / 5
                    let tileH: CGFloat = 60
                    let tileRect = CGRect(
                        x: 20 + CGFloat(col) * tileW,
                        y: 155 + CGFloat(row) * tileH,
                        width: tileW,
                        height: tileH
                    )
                    let tile = SKShapeNode(rect: tileRect, cornerRadius: 4)
                    tile.fillColor = SKColor(red: 0.21, green: 0.48, blue: 0.25, alpha: 0.5)
                    tile.strokeColor = .clear
                    addChild(tile)
                }
            }
        }
        
        // 3. Opponent Territory (Top Half: Y 490 to 780)
        let oppGrassRect = CGRect(x: 10, y: 490, width: width - 20, height: 290)
        let oppGrass = SKShapeNode(rect: oppGrassRect, cornerRadius: 16)
        oppGrass.fillColor = SKColor(red: 0.28, green: 0.32, blue: 0.25, alpha: 1.0) // Darker, scorched tone
        oppGrass.strokeColor = SKColor(red: 0.38, green: 0.28, blue: 0.22, alpha: 1.0)
        oppGrass.lineWidth = 3.0
        addChild(oppGrass)
        
        for row in 0..<4 {
            for col in 0..<5 {
                if (row + col) % 2 == 0 {
                    let tileW = (width - 40) / 5
                    let tileH: CGFloat = 60
                    let tileRect = CGRect(
                        x: 20 + CGFloat(col) * tileW,
                        y: 505 + CGFloat(row) * tileH,
                        width: tileW,
                        height: tileH
                    )
                    let tile = SKShapeNode(rect: tileRect, cornerRadius: 4)
                    tile.fillColor = SKColor(red: 0.32, green: 0.26, blue: 0.22, alpha: 0.45)
                    tile.strokeColor = .clear
                    addChild(tile)
                }
            }
        }
        
        // 4. Distant Castle Wall / Horizon at Top (Y: 780 to 920)
        let wallPath = CGMutablePath()
        wallPath.move(to: CGPoint(x: 0, y: 780))
        wallPath.addLine(to: CGPoint(x: 0, y: 840))
        for i in 0..<8 {
            let segX = CGFloat(i) * (width / 8)
            let segW = width / 8
            wallPath.addLine(to: CGPoint(x: segX, y: 860))
            wallPath.addLine(to: CGPoint(x: segX + segW * 0.6, y: 860))
            wallPath.addLine(to: CGPoint(x: segX + segW * 0.6, y: 840))
            wallPath.addLine(to: CGPoint(x: segX + segW, y: 840))
        }
        wallPath.addLine(to: CGPoint(x: width, y: 780))
        wallPath.closeSubpath()
        
        let castleWall = SKShapeNode(path: wallPath)
        castleWall.fillColor = SKColor(red: 0.16, green: 0.18, blue: 0.24, alpha: 1.0)
        castleWall.strokeColor = SKColor(red: 0.28, green: 0.30, blue: 0.38, alpha: 1.0)
        castleWall.lineWidth = 2.0
        addChild(castleWall)
    }
    
    private func setupRiverAndBridges() {
        let width = arenaSize.width
        let riverY = GameConfig.riverCenterY
        let riverH: CGFloat = 52
        
        // Riverbed Chasm (Dark edge)
        let chasmPath = CGMutablePath()
        chasmPath.addRect(CGRect(x: 0, y: riverY - riverH / 2 - 4, width: width, height: riverH + 8))
        let chasm = SKShapeNode(path: chasmPath)
        chasm.fillColor = SKColor(red: 0.10, green: 0.14, blue: 0.18, alpha: 1.0)
        chasm.strokeColor = SKColor(red: 0.25, green: 0.30, blue: 0.35, alpha: 1.0)
        chasm.lineWidth = 2.0
        addChild(chasm)
        
        // Flowing Water
        let waterPath = CGMutablePath()
        waterPath.addRect(CGRect(x: 0, y: riverY - riverH / 2, width: width, height: riverH))
        let water = SKShapeNode(path: waterPath)
        water.fillColor = SKColor(red: 0.12, green: 0.45, blue: 0.82, alpha: 0.95)
        water.strokeColor = SKColor(red: 0.35, green: 0.70, blue: 0.98, alpha: 0.85)
        water.lineWidth = 2.0
        
        // Gentle horizontal water ripple
        let shimmer = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.75, duration: 1.2),
            SKAction.fadeAlpha(to: 0.98, duration: 1.2)
        ])
        water.run(SKAction.repeatForever(shimmer))
        addChild(water)
        
        // Water Currents / Wavelets
        for yOffset in [-12.0, 0.0, 12.0] {
            let wavePath = CGMutablePath()
            wavePath.move(to: CGPoint(x: 20, y: riverY + CGFloat(yOffset)))
            wavePath.addLine(to: CGPoint(x: width - 20, y: riverY + CGFloat(yOffset)))
            let wave = SKShapeNode(path: wavePath)
            wave.strokeColor = SKColor(white: 1.0, alpha: 0.25)
            wave.lineWidth = 1.5
            addChild(wave)
        }
        
        // Twin Bridges (Left Bridge X: 115, Right Bridge X: 315)
        let bridgePositions: [CGFloat] = [115.0, 315.0]
        let bridgeW: CGFloat = 58.0
        let bridgeH: CGFloat = riverH + 18.0
        
        for bX in bridgePositions {
            // Stone Pillar Support
            let pillar = SKShapeNode(
                rectOf: CGSize(width: bridgeW + 6, height: bridgeH),
                cornerRadius: 6
            )
            pillar.position = CGPoint(x: bX, y: riverY)
            pillar.fillColor = SKColor(red: 0.32, green: 0.34, blue: 0.38, alpha: 1.0)
            pillar.strokeColor = SKColor(red: 0.20, green: 0.22, blue: 0.25, alpha: 1.0)
            pillar.lineWidth = 2.0
            addChild(pillar)
            
            // Wooden Timber Planks
            let plankCount = 6
            let plankH = bridgeH / CGFloat(plankCount)
            for p in 0..<plankCount {
                let py = (riverY - bridgeH / 2) + CGFloat(p) * plankH + plankH / 2
                let plank = SKShapeNode(
                    rectOf: CGSize(width: bridgeW - 4, height: plankH - 2),
                    cornerRadius: 2
                )
                plank.position = CGPoint(x: bX, y: py)
                plank.fillColor = (p % 2 == 0)
                    ? SKColor(red: 0.52, green: 0.35, blue: 0.22, alpha: 1.0)
                    : SKColor(red: 0.46, green: 0.30, blue: 0.18, alpha: 1.0)
                plank.strokeColor = SKColor(red: 0.28, green: 0.18, blue: 0.10, alpha: 1.0)
                plank.lineWidth = 1.0
                addChild(plank)
            }
            
            // Side Handrails
            for side in [-1.0, 1.0] {
                let rail = SKShapeNode(rectOf: CGSize(width: 4, height: bridgeH), cornerRadius: 1)
                rail.position = CGPoint(x: bX + CGFloat(side) * (bridgeW / 2 - 2), y: riverY)
                rail.fillColor = SKColor(red: 0.65, green: 0.45, blue: 0.25, alpha: 1.0)
                rail.strokeColor = .clear
                addChild(rail)
            }
        }
    }
    
    private func setupCobblestonePaths() {
        let bridgePositions: [CGFloat] = [115.0, 315.0]
        
        // Cobblestone lane running from local towers to bridges, and from bridges to opponent towers
        for bX in bridgePositions {
            // Player side lane
            let pLane = SKShapeNode(rectOf: CGSize(width: 44, height: 160), cornerRadius: 8)
            pLane.position = CGPoint(x: bX, y: 340)
            pLane.fillColor = SKColor(red: 0.45, green: 0.42, blue: 0.36, alpha: 0.45)
            pLane.strokeColor = SKColor(red: 0.35, green: 0.32, blue: 0.28, alpha: 0.3)
            pLane.lineWidth = 1.5
            addChild(pLane)
            
            // Opponent side lane
            let oppLane = SKShapeNode(rectOf: CGSize(width: 44, height: 160), cornerRadius: 8)
            oppLane.position = CGPoint(x: bX, y: 590)
            oppLane.fillColor = SKColor(red: 0.42, green: 0.38, blue: 0.34, alpha: 0.45)
            oppLane.strokeColor = SKColor(red: 0.32, green: 0.28, blue: 0.25, alpha: 0.3)
            oppLane.lineWidth = 1.5
            addChild(oppLane)
        }
    }
    
    private func setupBoundaryTrim() {
        let width = arenaSize.width
        
        // Dark divider trim at Y: 140 separating arena from Card Tray
        let dockTrim = SKShapeNode(rectOf: CGSize(width: width, height: 6))
        dockTrim.position = CGPoint(x: width / 2, y: 140)
        dockTrim.fillColor = SKColor(red: 0.12, green: 0.14, blue: 0.18, alpha: 1.0)
        dockTrim.strokeColor = SKColor(red: 0.25, green: 0.28, blue: 0.35, alpha: 1.0)
        dockTrim.lineWidth = 1.0
        dockTrim.zPosition = -10
        addChild(dockTrim)
    }
}
