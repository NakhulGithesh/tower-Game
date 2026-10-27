import Foundation
import XCTest
import CastleAttack

class ConsoleTestObserver: NSObject, XCTestObservation {
    var passCount = 0
    var failCount = 0
    
    func testCaseDidFinish(_ testCase: XCTestCase) {
        if let run = testCase.testRun, run.hasSucceeded {
            passCount += 1
            print("  ✅ \(testCase.name) passed")
        } else {
            failCount += 1
            print("  ❌ \(testCase.name) FAILED")
        }
    }
}

@main
struct TestRunner {
    static func main() {
        let observer = ConsoleTestObserver()
        XCTestObservationCenter.shared.addTestObserver(observer)

        let suites: [XCTestCase.Type] = [
            CardTests.self,
            GameConfigTests.self,
            TrajectoryMathTests.self,
            TowerSlotTests.self
        ]

        print("\n=======================================================")
        print("  CASTLE ATTACK REAL TEST SUITE (XCTest)")
        print("=======================================================")

        for suiteType in suites {
            let suite = suiteType.defaultTestSuite
            print("\n▶️ Running Suite: \(suite.name)")
            suite.run()
        }

        print("\n=======================================================")
        print("RESULTS: \(observer.passCount) passed, \(observer.failCount) failed")
        print("=======================================================\n")

        if observer.failCount > 0 {
            exit(1)
        } else {
            exit(0)
        }
    }
}
