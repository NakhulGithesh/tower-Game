import XCTest
@testable import CastleAttack

final class TowerSlotTests: XCTestCase {
    
    func testSingleCardPerTowerRule() {
        var slot = TowerCardSlot()
        XCTAssertTrue(slot.canAcceptCard)
        XCTAssertNil(slot.activeCard)
        XCTAssertEqual(slot.state, .idle)
        
        // Apply Attack card -> enters aiming
        let result = slot.applyCard(.fireball)
        XCTAssertEqual(result, .success(.aiming(card: .fireball)))
        XCTAssertFalse(slot.canAcceptCard)
        XCTAssertEqual(slot.activeCard, .fireball)
        
        // Attempting to drop another card must be REJECTED
        let rejectResult = slot.applyCard(.shield)
        XCTAssertEqual(rejectResult, .failure(.towerBusy(currentCard: .fireball)))
        XCTAssertEqual(slot.activeCard, .fireball)
        
        // Releasing lock (e.g. after launch) frees the tower
        slot.releaseLock()
        XCTAssertTrue(slot.canAcceptCard)
        XCTAssertNil(slot.activeCard)
        XCTAssertEqual(slot.state, .idle)
    }
    
    func testShieldDurationAndExpiry() {
        var slot = TowerCardSlot()
        
        let result = slot.applyCard(.shield)
        XCTAssertEqual(result, .success(.shielded(remainingTime: 5.0)))
        XCTAssertFalse(slot.canAcceptCard)
        
        // 2 seconds pass
        slot.updateTimer(deltaTime: 2.0)
        XCTAssertEqual(slot.state, .shielded(remainingTime: 3.0))
        XCTAssertFalse(slot.canAcceptCard)
        
        // 3.1 more seconds pass -> expires and frees slot
        slot.updateTimer(deltaTime: 3.1)
        XCTAssertEqual(slot.state, .idle)
        XCTAssertNil(slot.activeCard)
        XCTAssertTrue(slot.canAcceptCard)
    }
    
    func testRepairDurationAndExpiry() {
        var slot = TowerCardSlot()
        
        let result = slot.applyCard(.repair)
        XCTAssertEqual(result, .success(.repairing(remainingTime: 5.0)))
        XCTAssertFalse(slot.canAcceptCard)
        
        // 5 seconds pass -> expires and frees slot
        slot.updateTimer(deltaTime: 5.0)
        XCTAssertEqual(slot.state, .idle)
        XCTAssertNil(slot.activeCard)
        XCTAssertTrue(slot.canAcceptCard)
    }
}
