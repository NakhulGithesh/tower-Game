import SpriteKit

/// Procedural particle emitters for all 6 card abilities, impacts, and weather.
public final class ParticleFactory {
    
    // MARK: - Arrows Wind Streak Trail
    public static func makeWindTrail() -> SKEmitterNode {
        let emitter = SKEmitterNode()
        emitter.particleBirthRate = 45
        emitter.particleLifetime = 0.25
        emitter.particleSpeed = 15
        emitter.particleSpeedRange = 10
        emitter.emissionAngle = .pi
        emitter.emissionAngleRange = 0.2
        emitter.particleAlpha = 0.6
        emitter.particleAlphaSpeed = -2.0
        emitter.particleScale = 0.3
        emitter.particleScaleSpeed = -0.5
        emitter.particleColor = SKColor(white: 1.0, alpha: 0.8)
        emitter.particleColorBlendFactor = 1.0
        return emitter
    }
    
    // MARK: - Arrow Split Burst
    public static func makeArrowSplitBurst() -> SKEmitterNode {
        let emitter = SKEmitterNode()
        emitter.particleBirthRate = 120
        emitter.numParticlesToEmit = 18
        emitter.particleLifetime = 0.35
        emitter.particleSpeed = 90
        emitter.particleSpeedRange = 40
        emitter.emissionAngle = 0
        emitter.emissionAngleRange = 2 * .pi
        emitter.particleAlpha = 0.9
        emitter.particleAlphaSpeed = -2.5
        emitter.particleScale = 0.4
        emitter.particleScaleSpeed = -0.8
        emitter.particleColor = SKColor(red: 0.4, green: 0.85, blue: 1.0, alpha: 1.0)
        emitter.particleColorBlendFactor = 1.0
        return emitter
    }
    
    // MARK: - Boulder / Stone Dust Trail
    public static func makeDustTrail() -> SKEmitterNode {
        let emitter = SKEmitterNode()
        emitter.particleBirthRate = 35
        emitter.particleLifetime = 0.4
        emitter.particleSpeed = 20
        emitter.emissionAngle = .pi
        emitter.emissionAngleRange = 0.5
        emitter.particleAlpha = 0.45
        emitter.particleAlphaSpeed = -1.0
        emitter.particleScale = 0.6
        emitter.particleScaleSpeed = 0.8
        emitter.particleColor = SKColor(red: 0.45, green: 0.40, blue: 0.35, alpha: 1.0)
        emitter.particleColorBlendFactor = 1.0
        return emitter
    }
    
    // MARK: - Heavy Rock Impact Explosion
    public static func makeRockImpactDebris() -> SKEmitterNode {
        let emitter = SKEmitterNode()
        emitter.particleBirthRate = 200
        emitter.numParticlesToEmit = 25
        emitter.particleLifetime = 0.5
        emitter.particleSpeed = 140
        emitter.particleSpeedRange = 60
        emitter.emissionAngle = .pi / 2
        emitter.emissionAngleRange = .pi
        emitter.xAcceleration = 0
        emitter.yAcceleration = -400
        emitter.particleAlpha = 0.9
        emitter.particleAlphaSpeed = -1.5
        emitter.particleScale = 0.5
        emitter.particleScaleRange = 0.3
        emitter.particleColor = SKColor(red: 0.5, green: 0.45, blue: 0.4, alpha: 1.0)
        emitter.particleColorBlendFactor = 1.0
        return emitter
    }
    
    // MARK: - Fireball Blazing Trail
    public static func makeFireballTrail() -> SKEmitterNode {
        let emitter = SKEmitterNode()
        emitter.particleBirthRate = 90
        emitter.particleLifetime = 0.3
        emitter.particleSpeed = 40
        emitter.emissionAngle = .pi
        emitter.emissionAngleRange = 0.4
        emitter.particleAlpha = 0.85
        emitter.particleAlphaSpeed = -2.5
        emitter.particleScale = 0.6
        emitter.particleScaleSpeed = -1.2
        emitter.particleColor = SKColor(red: 1.0, green: 0.4, blue: 0.05, alpha: 1.0)
        emitter.particleColorBlendFactor = 1.0
        return emitter
    }
    
    // MARK: - Fireball Explosion & Lingering Embers
    public static func makeFireExplosion() -> SKEmitterNode {
        let emitter = SKEmitterNode()
        emitter.particleBirthRate = 300
        emitter.numParticlesToEmit = 45
        emitter.particleLifetime = 0.6
        emitter.particleSpeed = 160
        emitter.particleSpeedRange = 80
        emitter.emissionAngle = 0
        emitter.emissionAngleRange = 2 * .pi
        emitter.particleAlpha = 1.0
        emitter.particleAlphaSpeed = -1.6
        emitter.particleScale = 0.8
        emitter.particleScaleSpeed = -1.0
        emitter.particleColor = SKColor(red: 1.0, green: 0.25, blue: 0.0, alpha: 1.0)
        emitter.particleColorBlendFactor = 1.0
        return emitter
    }
    
    // MARK: - Repair Rising Green Healing Sparkles
    public static func makeHealingSparkles() -> SKEmitterNode {
        let emitter = SKEmitterNode()
        emitter.particleBirthRate = 35
        emitter.particleLifetime = 1.2
        emitter.particleSpeed = 50
        emitter.particleSpeedRange = 20
        emitter.emissionAngle = .pi / 2
        emitter.emissionAngleRange = 0.4
        emitter.particleAlpha = 0.8
        emitter.particleAlphaSpeed = -0.6
        emitter.particleScale = 0.35
        emitter.particleScaleRange = 0.2
        emitter.particleScaleSpeed = -0.1
        emitter.particleColor = SKColor(red: 0.3, green: 0.95, blue: 0.4, alpha: 1.0)
        emitter.particleColorBlendFactor = 1.0
        return emitter
    }
    
    // MARK: - Counterattack Lightning Trail
    public static func makeLightningTrail() -> SKEmitterNode {
        let emitter = SKEmitterNode()
        emitter.particleBirthRate = 80
        emitter.particleLifetime = 0.2
        emitter.particleSpeed = 60
        emitter.emissionAngle = 0
        emitter.emissionAngleRange = 2 * .pi
        emitter.particleAlpha = 0.9
        emitter.particleAlphaSpeed = -4.0
        emitter.particleScale = 0.3
        emitter.particleColor = SKColor(red: 0.2, green: 0.9, blue: 1.0, alpha: 1.0)
        emitter.particleColorBlendFactor = 1.0
        return emitter
    }
    
    // MARK: - Shield Shatter Shards
    public static func makeShieldShatter() -> SKEmitterNode {
        let emitter = SKEmitterNode()
        emitter.particleBirthRate = 250
        emitter.numParticlesToEmit = 30
        emitter.particleLifetime = 0.5
        emitter.particleSpeed = 120
        emitter.particleSpeedRange = 60
        emitter.emissionAngle = 0
        emitter.emissionAngleRange = 2 * .pi
        emitter.particleAlpha = 0.9
        emitter.particleAlphaSpeed = -1.8
        emitter.particleScale = 0.4
        emitter.particleScaleSpeed = -0.5
        emitter.particleColor = SKColor(red: 0.3, green: 0.85, blue: 1.0, alpha: 1.0)
        emitter.particleColorBlendFactor = 1.0
        return emitter
    }
}
