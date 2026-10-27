import XCTest
import CoreGraphics
@testable import CastleAttack

final class NetworkPacketTests: XCTestCase {
    
    func testTowerPlacementPacketEncodingDecoding() throws {
        let p1 = CGPoint(x: 120.5, y: 350.0)
        let p2 = CGPoint(x: 280.0, y: 420.75)
        
        let payload = PacketPayload.towerPlacement(
            playerID: .playerA,
            tower1Pos: SerializablePoint(p1),
            tower2Pos: SerializablePoint(p2)
        )
        let packet = GamePacket(sender: .playerA, payload: payload)
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(packet)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(GamePacket.self, from: data)
        
        XCTAssertEqual(decoded.sender, .playerA)
        if case .towerPlacement(let playerID, let tower1, let tower2) = decoded.payload {
            XCTAssertEqual(playerID, .playerA)
            XCTAssertEqual(tower1.cgPoint.x, p1.x)
            XCTAssertEqual(tower1.cgPoint.y, p1.y)
            XCTAssertEqual(tower2.cgPoint.x, p2.x)
            XCTAssertEqual(tower2.cgPoint.y, p2.y)
        } else {
            XCTFail("Decoded payload did not match towerPlacement")
        }
    }
    
    func testCardAppliedPacketEncodingDecoding() throws {
        let payload = PacketPayload.cardApplied(playerID: .playerB, towerID: .tower2, cardType: .shield)
        let packet = GamePacket(sender: .playerB, payload: payload)
        
        let data = try JSONEncoder().encode(packet)
        let decoded = try JSONDecoder().decode(GamePacket.self, from: data)
        
        XCTAssertEqual(decoded.sender, .playerB)
        if case .cardApplied(let player, let tower, let card) = decoded.payload {
            XCTAssertEqual(player, .playerB)
            XCTAssertEqual(tower, .tower2)
            XCTAssertEqual(card, .shield)
        } else {
            XCTFail("Payload did not match cardApplied")
        }
    }
    
    func testProjectileLaunchPacketEncodingDecoding() throws {
        let launchVec = CGVector(dx: 520.4, dy: -310.2)
        let payload = PacketPayload.projectileLaunched(
            playerID: .playerA,
            towerID: .tower1,
            cardType: .fireball,
            launchVector: SerializableVector(launchVec)
        )
        let packet = GamePacket(sender: .playerA, payload: payload)
        
        let data = try JSONEncoder().encode(packet)
        let decoded = try JSONDecoder().decode(GamePacket.self, from: data)
        
        XCTAssertEqual(decoded.sender, .playerA)
        if case .projectileLaunched(let player, let tower, let card, let vector) = decoded.payload {
            XCTAssertEqual(player, .playerA)
            XCTAssertEqual(tower, .tower1)
            XCTAssertEqual(card, .fireball)
            XCTAssertEqual(vector.cgVector.dx, launchVec.dx)
            XCTAssertEqual(vector.cgVector.dy, launchVec.dy)
        } else {
            XCTFail("Payload did not match projectileLaunched")
        }
    }
    
    func testTowerHealthSyncPacketEncodingDecoding() throws {
        let payload = PacketPayload.towerHealthSync(towerID: .tower1, currentHP: 850)
        let packet = GamePacket(sender: .playerB, payload: payload)
        
        let data = try JSONEncoder().encode(packet)
        let decoded = try JSONDecoder().decode(GamePacket.self, from: data)
        
        if case .towerHealthSync(let tower, let hp) = decoded.payload {
            XCTAssertEqual(tower, .tower1)
            XCTAssertEqual(hp, 850)
        } else {
            XCTFail("Payload did not match towerHealthSync")
        }
    }
}
