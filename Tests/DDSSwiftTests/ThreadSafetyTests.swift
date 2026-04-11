import XCTest

@testable import DDSSwift

/// Tests to investigate the reported thread-safety / Resize crash.
///
/// The bug report claims that rapid sequential calls to DDS public APIs
/// cause EXC_BAD_ACCESS in Memory::Resize because SetMaxThreads(0) tears
/// down and rebuilds thread memory on every call, racing with GCD workers.
///
/// These tests attempt to reproduce that scenario.
final class ThreadSafetyTests: XCTestCase {

    // 10 unique validated PBN deals (52 cards each, no duplicates)
    private let deals = [
        "N:KT5.Q742.K3.KJT8 7.T63.AT542.9643 AQJ983.A85.Q96.5 642.KJ9.J87.AQ72",
        "N:QT95.AJ6.K87.AT9 63.KT875.Q64.J32 A84.42.T932.K875 KJ72.Q93.AJ5.Q64",
        "N:JT94.KT.KQT9.AKJ A63.AQ876.J4.932 85.542.7532.T876 KQ72.J93.A86.Q54",
        "N:QT94.J6.KT9.AKT9 A63.AKT87.Q43.J2 85.542.8762.8753 KJ72.Q93.AJ5.Q64",
        "N:JT93.KJ.KT9.AQT8 AK65.AT874.Q3.92 84.652.7642.7653 Q72.Q93.AJ85.KJ4",
        "N:J62.AT9.KT9.AKJT AKT87.Q63.Q32.52 54.854.8764.9873 Q93.KJ72.AJ5.Q64",
        "N:J87.K953.J985.T2 AT53.A.AQT42.Q64 962.JT84.763.J98 KQ4.Q762.K.AK753",
        "N:JT98.T54.K76.AQ3 A63.AQ876.J3.952 54.K32.QT92.T876 KQ72.J9.A854.KJ4",
        "N:Q95.862.A973.JT2 AK63.K74.T85.A65 J74.AT93.42.Q943 T82.QJ5.KQJ6.K87",
        "N:86.JT2.KQT2.KQ83 Q542.965.A86.J42 T973.AK8.J75.T97 AKJ.Q743.943.A65",
    ]

    /// Rapid sequential calls — each call triggers SetMaxThreads(0) which
    /// tears down and rebuilds all thread memory via Resize(0) then Resize(N).
    /// The bug report claims this races with GCD workers from previous solves.
    func testRapidSequentialCalcTables() throws {
        for (i, deal) in deals.enumerated() {
            let results = try DDSSolver.calcTables(
                hands: [deal],
                vulns: [0],
                dealers: [0]
            )
            XCTAssertFalse(results.isEmpty, "No results for deal \(i)")
        }
    }

    /// Same test but with calcDDTablePBN — a lighter-weight entry point
    /// that still calls SetMaxThreads(0) on each invocation.
    func testRapidSequentialCalcDDTablePBN() throws {
        for (i, deal) in deals.enumerated() {
            let table = try DDSSolver.calcDDTablePBN(pbn: deal)
            // Sanity: at least one cell should be non-zero
            let hasNonZero = table.resTable.flatMap { $0 }.contains { $0 > 0 }
            XCTAssertTrue(hasNonZero, "All-zero table for deal \(i)")
        }
    }

    /// Rapid sequential solveBoard calls with unique deals.
    func testRapidSequentialSolveBoard() throws {
        for (i, deal) in deals.enumerated() {
            let result = try DDSSolver.solveBoard(
                pbn: deal,
                target: -1,
                solutions: 3,
                mode: 1,
                trump: 0,   // Spades
                first: 0    // North on lead
            )
            XCTAssertGreaterThan(result.cards, 0, "No cards returned for deal \(i)")
        }
    }

    /// Concurrent calls from multiple threads.
    /// DDS uses global mutable state and was not designed for concurrent
    /// external calls. This test verifies whether that causes crashes.
    func testConcurrentCalcTables() throws {
        let group = DispatchGroup()
        let lock = NSLock()
        var errors: [Error] = []

        for deal in deals {
            group.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                defer { group.leave() }
                do {
                    let results = try DDSSolver.calcTables(
                        hands: [deal],
                        vulns: [0],
                        dealers: [0]
                    )
                    XCTAssertFalse(results.isEmpty)
                } catch {
                    lock.lock()
                    errors.append(error)
                    lock.unlock()
                }
            }
        }

        let result = group.wait(timeout: .now() + 120)
        XCTAssertEqual(result, .success, "Timed out waiting for concurrent solves")
        XCTAssertTrue(errors.isEmpty, "Errors during concurrent solves: \(errors)")
    }
}
