import Foundation
import CoreGraphics

@main
struct TestMain {
    static func assertTest(_ condition: Bool, _ message: String) {
        if condition {
            print("  ✅ PASS: \(message)")
        } else {
            print("  ❌ FAIL: \(message)")
            exit(1)
        }
    }

    static func main() {
        print("\n=======================================================")
        print("  CASTLE ATTACK SYSTEM & MULTIPLAYER VERIFICATION")
        print("=======================================================")

        // 1. Verify Card Definitions
        print("\n[1] Verifying 6 Cards & Attributes...")
        assertTest(CardType.allCases.count == 6, "Total card count is 6")
        assertTest(CardType.arrows.cost == 2 && CardType.arrows.role == .attack, "Arrows cost 2 & Attack")
        assertTest(CardType.stones.cost == 4 && CardType.stones.role == .attack, "Stones cost 4 & Attack")
        assertTest(CardType.fireball.cost == 5 && CardType.fireball.role == .attack, "Fireball cost 5 & Attack")
        assertTest(CardType.shield.cost == 3 && CardType.shield.role == .defense, "Shield cost 3 & Defense")
        assertTest(CardType.repair.cost == 4 && CardType.repair.role == .defense, "Repair cost 4 & Defense")
        assertTest(CardType.counterattack.cost == 5 && CardType.counterattack.role == .hybrid, "Counterattack cost 5 & Hybrid")
        assertTest(CardType.arrows.splitsMidAir && CardType.arrows.splitCount == 3, "Arrows split into 3")
        assertTest(CardType.stones.causesScreenShake && CardType.stones.impactDamage == 180, "Stones 180 DMG + screen shake")
        assertTest(CardType.fireball.impactDamage == 100 && CardType.fireball.burnDamage == 50, "Fireball 100 DMG + 50 Burn")
        assertTest(CardType.shield.effectDuration == 5.0, "Shield duration exactly 5.0 seconds")
        assertTest(CardType.repair.healAmount == 150 && CardType.repair.effectDuration == 5.0, "Repair 150 HP over 5.0 seconds")

        // 2. Verify Single-Card-Per-Tower Lock Rule
        print("\n[2] Verifying Single-Card-Per-Tower Rule...")
        var slot = TowerCardSlot()
        assertTest(slot.canAcceptCard, "Empty slot can accept card")
        _ = slot.applyCard(.shield)
        assertTest(slot.activeCard == .shield, "Shield card applied to slot")
        let res2 = slot.applyCard(.fireball)
        assertTest(res2 == .failure(.towerBusy(currentCard: .shield)), "Cannot apply second card to busy tower")
        slot.updateTimer(deltaTime: 5.1)
        assertTest(slot.canAcceptCard && slot.activeCard == nil, "Tower lock freed after 5.0 seconds")

        // 3. Verify Trajectory Kinematics (40% preview)
        print("\n[3] Verifying Trajectory Math...")
        let origin = CGPoint(x: 100, y: 100)
        let drag = CGPoint(x: 70, y: 60)
        let v = TrajectoryMath.calculateLaunchVelocity(origin: origin, dragPosition: drag)
        assertTest(v.dx > 0 && v.dy > 0, "Opposite launch vector generated correctly")
        let pts = TrajectoryMath.calculateTrajectoryPoints(origin: origin, velocity: v, flightTime: 1.5)
        assertTest(pts.count == GameConfig.trajectoryPreviewPointCount, "Generates 16 trajectory points")
        assertTest(pts.first == origin, "First trajectory point matches origin")

        // 4. Verify Network Packets
        print("\n[4] Verifying Deterministic GamePacket Codable...")
        let p1 = CGPoint(x: 125.0, y: 350.0)
        let p2 = CGPoint(x: 275.0, y: 410.0)
        let placementPayload = PacketPayload.towerPlacement(
            playerID: .playerA,
            tower1Pos: SerializablePoint(p1),
            tower2Pos: SerializablePoint(p2)
        )
        let packet1 = GamePacket(sender: .playerA, payload: placementPayload)
        guard let data1 = try? JSONEncoder().encode(packet1),
              let decoded1 = try? JSONDecoder().decode(GamePacket.self, from: data1) else {
            assertTest(false, "Failed to encode/decode packet1")
            return
        }
        assertTest(decoded1.sender == .playerA, "Packet sender preserved")
        if case .towerPlacement(let pID, let t1, let t2) = decoded1.payload {
            assertTest(pID == .playerA && t1.cgPoint == p1 && t2.cgPoint == p2, "Tower placement coordinates synced with 100% fidelity")
        } else {
            assertTest(false, "Decoded payload is towerPlacement")
        }

        let launchPayload = PacketPayload.projectileLaunched(
            playerID: .playerB,
            towerID: .tower2,
            cardType: .counterattack,
            launchVector: SerializableVector(CGVector(dx: -500, dy: 350))
        )
        let packet2 = GamePacket(sender: .playerB, payload: launchPayload)
        guard let data2 = try? JSONEncoder().encode(packet2),
              let decoded2 = try? JSONDecoder().decode(GamePacket.self, from: data2) else {
            assertTest(false, "Failed to encode/decode packet2")
            return
        }
        if case .projectileLaunched(let pID, let tID, let card, let vec) = decoded2.payload {
            assertTest(pID == .playerB && tID == .tower2 && card == .counterattack && vec.cgVector.dx == -500, "Projectile launch packet synced with exact launch vector")
        } else {
            assertTest(false, "Decoded payload is projectileLaunched")
        }

        let hpPayload = PacketPayload.towerHealthSync(towerID: .tower1, currentHP: 720)
        let packet3 = GamePacket(sender: .playerA, payload: hpPayload)
        guard let data3 = try? JSONEncoder().encode(packet3),
              let decoded3 = try? JSONDecoder().decode(GamePacket.self, from: data3) else {
            assertTest(false, "Failed to encode/decode packet3")
            return
        }
        if case .towerHealthSync(let tID, let hp) = decoded3.payload {
            assertTest(tID == .tower1 && hp == 720, "Authoritative tower HP sync matches")
        } else {
            assertTest(false, "Decoded payload is towerHealthSync")
        }

        print("\n=======================================================")
        print("  ALL MULTIPLAYER & LOGIC TESTS PASSED PERFECTLY!")
        print("=======================================================\n")
    }
}
