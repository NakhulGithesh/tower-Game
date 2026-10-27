import XCTest
@testable import CastleAttack

final class CardTests: XCTestCase {
    
    func testCardTypeCountAndCases() {
        XCTAssertEqual(CardType.allCases.count, 6)
        let expectedCases: [CardType] = [.arrows, .stones, .fireball, .shield, .repair, .counterattack]
        XCTAssertEqual(CardType.allCases, expectedCases)
    }
    
    func testCardCosts() {
        XCTAssertEqual(CardType.arrows.cost, 2)
        XCTAssertEqual(CardType.stones.cost, 4)
        XCTAssertEqual(CardType.fireball.cost, 5)
        XCTAssertEqual(CardType.shield.cost, 3)
        XCTAssertEqual(CardType.repair.cost, 4)
        XCTAssertEqual(CardType.counterattack.cost, 5)
    }
    
    func testCardRoles() {
        XCTAssertEqual(CardType.arrows.role, .attack)
        XCTAssertEqual(CardType.stones.role, .attack)
        XCTAssertEqual(CardType.fireball.role, .attack)
        XCTAssertEqual(CardType.shield.role, .defense)
        XCTAssertEqual(CardType.repair.role, .defense)
        XCTAssertEqual(CardType.counterattack.role, .hybrid)
    }
    
    func testCardAimability() {
        XCTAssertTrue(CardType.arrows.isAimable)
        XCTAssertTrue(CardType.stones.isAimable)
        XCTAssertTrue(CardType.fireball.isAimable)
        XCTAssertTrue(CardType.counterattack.isAimable)
        XCTAssertFalse(CardType.shield.isAimable)
        XCTAssertFalse(CardType.repair.isAimable)
    }
    
    func testCardDamagesAndHeals() {
        // Arrows: 50 DMG total
        XCTAssertEqual(CardType.arrows.impactDamage, 50)
        XCTAssertTrue(CardType.arrows.splitsMidAir)
        XCTAssertEqual(CardType.arrows.splitCount, 3)
        
        // Stones: 180 DMG + screen shake
        XCTAssertEqual(CardType.stones.impactDamage, 180)
        XCTAssertTrue(CardType.stones.causesScreenShake)
        
        // Fireball: 100 Impact + 50 Burn DoT
        XCTAssertEqual(CardType.fireball.impactDamage, 100)
        XCTAssertEqual(CardType.fireball.burnDamage, 50)
        XCTAssertEqual(CardType.fireball.totalDamage, 150)
        XCTAssertEqual(CardType.fireball.effectDuration, 5.0)
        
        // Shield: 5 seconds duration
        XCTAssertEqual(CardType.shield.impactDamage, 0)
        XCTAssertEqual(CardType.shield.effectDuration, 5.0)
        
        // Repair: 150 HP over 5 seconds
        XCTAssertEqual(CardType.repair.healAmount, 150)
        XCTAssertEqual(CardType.repair.effectDuration, 5.0)
        
        // Counterattack: Interceptor bolt
        XCTAssertEqual(CardType.counterattack.impactDamage, 120)
        XCTAssertTrue(CardType.counterattack.canInterceptProjectiles)
    }
    
    func testCardGravityAndSpeed() {
        // Arrows: fast, low-gravity
        XCTAssertLessThan(CardType.arrows.gravityFactor, 1.0)
        XCTAssertGreaterThan(CardType.arrows.speedMultiplier, 1.0)
        
        // Stones: heavy gravity arc
        XCTAssertGreaterThan(CardType.stones.gravityFactor, 1.0)
        
        // Counterattack: high-speed interceptor
        XCTAssertGreaterThan(CardType.counterattack.speedMultiplier, 1.5)
        XCTAssertLessThan(CardType.counterattack.gravityFactor, 0.5)
    }
}
