import XCTest
import CoreGraphics
@testable import CastleAttack

final class TrajectoryMathTests: XCTestCase {
    
    func testClampDragWithinRadius() {
        let origin = CGPoint(x: 100, y: 100)
        let touch = CGPoint(x: 120, y: 100) // Distance = 20
        let clamped = TrajectoryMath.clampDrag(origin: origin, touch: touch, maxRadius: 50)
        
        XCTAssertEqual(clamped.x, touch.x, accuracy: 0.001)
        XCTAssertEqual(clamped.y, touch.y, accuracy: 0.001)
    }
    
    func testClampDragExceedingRadius() {
        let origin = CGPoint(x: 100, y: 100)
        let touch = CGPoint(x: 200, y: 100) // Distance = 100
        let maxRadius: CGFloat = 50
        let clamped = TrajectoryMath.clampDrag(origin: origin, touch: touch, maxRadius: maxRadius)
        
        XCTAssertEqual(clamped.x, 150.0, accuracy: 0.001)
        XCTAssertEqual(clamped.y, 100.0, accuracy: 0.001)
        
        let dist = hypot(clamped.x - origin.x, clamped.y - origin.y)
        XCTAssertEqual(dist, maxRadius, accuracy: 0.001)
    }
    
    func testCalculateLaunchVelocityOppositeToDrag() {
        let origin = CGPoint(x: 100, y: 100)
        // Drag down and left (dx = -30, dy = -40)
        let drag = CGPoint(x: 70, y: 60)
        let speedFactor: CGFloat = 10.0
        let velocity = TrajectoryMath.calculateLaunchVelocity(
            origin: origin,
            dragPosition: drag,
            speedFactor: speedFactor,
            cardMultiplier: 1.0
        )
        
        // Launch should be up and right (positive vx and vy)
        XCTAssertEqual(velocity.dx, 300.0, accuracy: 0.001)
        XCTAssertEqual(velocity.dy, 400.0, accuracy: 0.001)
    }
    
    func testTrajectoryPointsCover40PercentFlight() {
        let origin = CGPoint(x: 100, y: 100)
        let velocity = CGVector(dx: 200, dy: 300)
        let gravity: CGFloat = -600
        let flightTime: Double = 1.0
        let pointCount = 10
        let fraction = 0.40
        
        let points = TrajectoryMath.calculateTrajectoryPoints(
            origin: origin,
            velocity: velocity,
            gravity: gravity,
            gravityFactor: 1.0,
            flightTime: flightTime,
            fraction: fraction,
            pointCount: pointCount
        )
        
        XCTAssertEqual(points.count, pointCount)
        // First point should be origin
        XCTAssertEqual(points.first?.x ?? 0, origin.x, accuracy: 0.001)
        XCTAssertEqual(points.first?.y ?? 0, origin.y, accuracy: 0.001)
        
        // Last point corresponds to t = flightTime * 0.40 = 0.40s
        let tEnd = 0.40
        let expectedEndX = Double(origin.x) + Double(velocity.dx) * tEnd
        let expectedEndY = Double(origin.y) + Double(velocity.dy) * tEnd + 0.5 * Double(gravity) * tEnd * tEnd
        
        XCTAssertEqual(Double(points.last?.x ?? 0), expectedEndX, accuracy: 0.01)
        XCTAssertEqual(Double(points.last?.y ?? 0), expectedEndY, accuracy: 0.01)
    }
    
    func testGravityFactorEffectOnTrajectory() {
        let origin = CGPoint(x: 0, y: 100)
        let velocity = CGVector(dx: 100, dy: 100)
        let flightTime: Double = 1.0
        
        // Stones have higher gravity factor (1.5) than Arrows (0.5)
        let stonePoints = TrajectoryMath.calculateTrajectoryPoints(
            origin: origin,
            velocity: velocity,
            gravityFactor: CardType.stones.gravityFactor,
            flightTime: flightTime
        )
        let arrowPoints = TrajectoryMath.calculateTrajectoryPoints(
            origin: origin,
            velocity: velocity,
            gravityFactor: CardType.arrows.gravityFactor,
            flightTime: flightTime
        )
        
        // Stone should have lower Y at the end of the preview than arrow due to heavier gravity
        let stoneLastY = stonePoints.last?.y ?? 0
        let arrowLastY = arrowPoints.last?.y ?? 0
        XCTAssertLessThan(stoneLastY, arrowLastY)
    }
}
