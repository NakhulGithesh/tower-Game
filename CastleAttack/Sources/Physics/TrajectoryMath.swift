import Foundation
import CoreGraphics

public struct TrajectoryMath {
    
    /// Clamps drag offset from origin to a maximum radius.
    public static func clampDrag(origin: CGPoint, touch: CGPoint, maxRadius: CGFloat) -> CGPoint {
        let dx = touch.x - origin.x
        let dy = touch.y - origin.y
        let distance = hypot(dx, dy)
        
        if distance <= maxRadius || distance == 0 {
            return touch
        }
        
        let ratio = maxRadius / distance
        return CGPoint(x: origin.x + dx * ratio, y: origin.y + dy * ratio)
    }
    
    /// Computes the launch velocity vector based on drag vector, launch speed factor, and card multiplier.
    /// Pulling backward from origin imparts a forward launch impulse in opposite direction.
    public static func calculateLaunchVelocity(
        origin: CGPoint,
        dragPosition: CGPoint,
        speedFactor: CGFloat = GameConfig.launchSpeedFactor,
        cardMultiplier: Double = 1.0
    ) -> CGVector {
        let dragVector = CGVector(dx: dragPosition.x - origin.x, dy: dragPosition.y - origin.y)
        // Opposite of drag vector: pulling down-left fires up-right
        let vx = -dragVector.dx * speedFactor * CGFloat(cardMultiplier)
        let vy = -dragVector.dy * speedFactor * CGFloat(cardMultiplier)
        return CGVector(dx: vx, dy: vy)
    }
    
    /// Computes estimated total flight time until projectile returns to the launch altitude or ground plane.
    /// Uses quadratic equation: p(t) = y0 + vy * t + 0.5 * g * t^2 = groundY
    public static func estimateFlightTime(
        originY: CGFloat,
        groundY: CGFloat,
        initialVelocityY: CGFloat,
        gravityY: CGFloat
    ) -> Double {
        // 0.5 * gravityY * t^2 + initialVelocityY * t + (originY - groundY) = 0
        let a = 0.5 * Double(gravityY)
        let b = Double(initialVelocityY)
        let c = Double(originY - groundY)
        
        if abs(a) < 1e-6 {
            // Linear equation if no gravity
            return b > 0 ? -c / b : 1.5
        }
        
        let discriminant = b * b - 4 * a * c
        if discriminant < 0 {
            // Returns nominal arc duration
            return 1.5
        }
        
        let sqrtD = sqrt(discriminant)
        let t1 = (-b - sqrtD) / (2 * a)
        let t2 = (-b + sqrtD) / (2 * a)
        
        let positiveTimes = [t1, t2].filter { $0 > 0.05 }
        return positiveTimes.min() ?? 1.5
    }
    
    /// Computes discrete trajectory preview points.
    /// By specification: "Render a curved dotted trajectory preview line showing the first 40% of the flight path."
    public static func calculateTrajectoryPoints(
        origin: CGPoint,
        velocity: CGVector,
        gravity: CGFloat = GameConfig.baseGravity,
        gravityFactor: Double = 1.0,
        flightTime: Double,
        fraction: Double = GameConfig.trajectoryPreviewPercent,
        pointCount: Int = GameConfig.trajectoryPreviewPointCount
    ) -> [CGPoint] {
        guard pointCount > 1, flightTime > 0 else {
            return [origin]
        }
        
        let previewDuration = flightTime * fraction
        let effectiveGravity = Double(gravity) * gravityFactor
        var points: [CGPoint] = []
        points.reserveCapacity(pointCount)
        
        for i in 0..<pointCount {
            let t = previewDuration * (Double(i) / Double(pointCount - 1))
            let x = Double(origin.x) + Double(velocity.dx) * t
            let y = Double(origin.y) + Double(velocity.dy) * t + 0.5 * effectiveGravity * t * t
            points.append(CGPoint(x: x, y: y))
        }
        
        return points
    }
}
