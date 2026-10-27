import XCTest
@testable import CastleAttack

final class GameConfigTests: XCTestCase {
    
    func testEnergySettings() {
        XCTAssertEqual(GameConfig.maxEnergy, 10.0)
        XCTAssertEqual(GameConfig.initialEnergy, 4.0)
        // +1 energy every 2.5s (Clash Royale pace)
        XCTAssertEqual(GameConfig.energyRechargeRate, 1.0 / 2.5, accuracy: 0.0001)
    }
    
    func testTowerHPAndDurations() {
        XCTAssertEqual(GameConfig.maxTowerHP, 1000)
        XCTAssertEqual(GameConfig.shieldDuration, 5.0)
        XCTAssertEqual(GameConfig.repairDuration, 5.0)
        XCTAssertEqual(GameConfig.repairTotalHP, 150)
        XCTAssertEqual(GameConfig.burnDuration, 5.0)
        XCTAssertEqual(GameConfig.burnTotalHP, 50)
    }
    
    func testBonjourServiceTypeConstraints() {
        // Bonjour service type must be 1-15 chars, lowercase ASCII and numbers only
        let service = GameConfig.serviceType
        XCTAssertFalse(service.isEmpty)
        XCTAssertLessThanOrEqual(service.count, 15)
        XCTAssertEqual(service, service.lowercased())
        XCTAssertTrue(service.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" })
        XCTAssertFalse(service.hasPrefix("-"))
        XCTAssertFalse(service.hasSuffix("-"))
    }
    
    func testAimingAndTrajectoryConstraints() {
        XCTAssertEqual(GameConfig.trajectoryPreviewPercent, 0.40, accuracy: 0.001)
        XCTAssertGreaterThan(GameConfig.maxSlingshotDragRadius, 50.0)
        XCTAssertGreaterThan(GameConfig.trajectoryPreviewPointCount, 5)
        XCTAssertLessThan(GameConfig.baseGravity, 0.0) // Gravity pulls downward
    }
}
