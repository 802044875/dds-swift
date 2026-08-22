import Testing
import Foundation
import DDS

@testable import DDSSwift

/// Stress and thread-safety tests for the DDS C API and DDSSolver wrapper.
///
/// DDS 3.1.0 is thread-safe by construction (SolverContext-based parallelism).
/// The "Direct C API" suite confirms the legacy C entry points still work correctly
/// under concurrent load now that the external ddsQueue serialisation has been removed.
///
/// The top-level suite is .serialized to avoid state collisions between the direct
/// C API suite and the wrapper suite.

// MARK: - Helper

/// Calls CalcAllTablesPBN directly via the C API for a single deal.
private func callCalcAllTablesPBNDirect(_ pbn: String) -> Int32 {
    var dealsPBN = DdTableDealsPBN()
    var tableRes = DdTablesRes()
    var pres = AllParResults()
    var trumpFilter: (Int32, Int32, Int32, Int32, Int32) = (0, 0, 0, 0, 0)

    dealsPBN.no_of_tables = 1
    pbn.withCString { cstr in
        withUnsafeMutablePointer(to: &dealsPBN.deals) { ptr in
            let base = UnsafeMutableRawPointer(ptr)
                .assumingMemoryBound(to: DdTableDealPBN.self)
            withUnsafeMutablePointer(to: &base.pointee.cards) { cardsPtr in
                let dest = UnsafeMutableRawPointer(cardsPtr)
                    .assumingMemoryBound(to: CChar.self)
                strcpy(dest, cstr)
            }
        }
    }

    return withUnsafeMutablePointer(to: &trumpFilter) { filterPtr in
        filterPtr.withMemoryRebound(to: Int32.self, capacity: 5) { filter in
            CalcAllTablesPBN(&dealsPBN, -1, filter, &tableRes, &pres)
        }
    }
}

private let stressDeals = [
    "N:KT5.Q742.K3.KJT8 7.T63.AT542.9643 AQJ983.A85.Q96.5 642.KJ9.J87.AQ72",
    "N:QT95.AJ6.K87.AT9 63.KT875.Q64.J32 A84.42.T932.K875 KJ72.Q93.AJ5.Q64",
    "N:JT94.KT.KQT9.AKJ A63.AQ876.J4.932 85.542.7532.T876 KQ72.J93.A86.Q54",
    "N:QT94.J6.KT9.AKT9 A63.AKT87.Q43.J2 85.542.8762.8753 KJ72.Q93.AJ5.Q64",
    "N:JT93.KJ.KT9.AQT8 AK65.AT874.Q3.92 84.652.7642.7653 Q72.Q93.AJ85.KJ4",
    "N:QT94.J6.KT98.AKJ A3.AKT87.Q4.T532 865.542.7632.987 KJ72.Q93.AJ5.Q64",
    "N:J62.AT9.KT9.AKJT AKT87.Q63.Q32.52 54.854.8764.9873 Q93.KJ72.AJ5.Q64",
    "N:J87.K953.J985.T2 AT53.A.AQT42.Q64 962.JT84.763.J98 KQ4.Q762.K.AK753",
    "N:JT98.T54.K76.AQ3 A63.AQ876.J3.952 54.K32.QT92.T876 KQ72.J9.A854.KJ4",
    "N:QT94.AJ.KT98.AKT A63.KT875.Q4.J32 85.642.7632.9875 KJ72.Q93.AJ5.Q64",
    "N:AT94.KT.JT97.AQ8 J63.AQ875.KQ.T92 85.642.6432.7653 KQ72.J93.A85.KJ4",
    "N:Q95.862.A973.JT2 AK63.K74.T85.A65 J74.AT93.42.Q943 T82.QJ5.KQJ6.K87",
    "N:86.JT2.KQT2.KQ83 Q542.965.A86.J42 T973.AK8.J75.T97 AKJ.Q743.943.A65",
    "N:QT87.T95.876.T64 J93.J8764.Q43.87 652.A2.T92.AKQ95 AK4.KQ3.AKJ5.J32",
    "N:T87.T95.876.T654 J93.J87632.Q4.87 Q652.A.T952.AKQ3 AK4.KQ4.AKJ3.J92",
    "N:T9.AJT8.T987.AK5 QJ8763.94.Q4.876 52.7652.632.JT94 AK4.KQ3.AKJ5.Q32",
    "N:AK2.J87.A76.T965 Q973.QT962.T2.KQ T64.53.J985.A874 J85.AK4.KQ43.J32",
    "N:Q95.AJ6.K873.AT9 63.KT875.Q64.J32 AKT4.42.T92.K875 J872.Q93.AJ5.Q64",
    "N:KJ6.93.AQ8.86543 853.QJT87.95.T72 AT94.54.KJT32.A9 Q72.AK62.764.KQJ",
    "N:KT53.Q74.K3.KJT8 72.T63.AT542.964 AQJ98.A85.Q96.53 64.KJ92.J87.AQ72",
]

@Suite("DDS Stress Reproduction", .serialized)
struct StressReproductionTests {

    // MARK: - Direct C API tests (3.1.0 — thread-safe by construction)
    // No .serialized here — the two direct C tests run concurrently with each other.

    @Suite("Direct C API")
    struct DirectCAPITests {

        /// Rapid sequential SetMaxThreads(0) + CalcAllTablesPBN.
        /// In 3.1.0, SetMaxThreads is a no-op alias for InitializeStaticMemory().
        @Test("Rapid sequential — SetMaxThreads(0) + CalcAllTablesPBN")
        func rapidSequentialDirectC() {
            for deal in stressDeals.prefix(10) {
                SetMaxThreads(0)
                let res = callCalcAllTablesPBNDirect(deal)
                #expect(res == 1, "CalcAllTablesPBN failed with code \(res)")
            }
        }

        /// FreeMemory() between every call — deprecated in 3.1.0 (RAII via SolverContext),
        /// but still callable; verifies the legacy path doesn't crash.
        @Test("Rapid sequential with FreeMemory between each call")
        func rapidSequentialDirectCWithFree() {
            for deal in stressDeals.prefix(10) {
                SetMaxThreads(0)
                let res = callCalcAllTablesPBNDirect(deal)
                #expect(res == 1, "CalcAllTablesPBN failed with code \(res)")
                FreeMemory()
            }
        }
    }

    // MARK: - DDSSolver wrapper tests

    @Suite("DDSSolver Wrapper")
    struct WrapperTests {

        /// 4 concurrent threads each solving 5 deals through ddsQueue.sync.
        @Test("4 parallel groups of 5 deals")
        func parallelGroupsOf5Deals() throws {
            let group = DispatchGroup()
            let lock = NSLock()
            var errors: [Error] = []

            for _ in 0..<4 {
                group.enter()
                DispatchQueue.global(qos: .userInitiated).async {
                    defer { group.leave() }
                    for deal in stressDeals.prefix(5) {
                        do {
                            let result = try DDSSolver.calcTables(
                                hands: [deal], vulns: [0], dealers: [0]
                            )
                            if result.isEmpty {
                                lock.lock()
                                errors.append(DDSError.unknownFault)
                                lock.unlock()
                            }
                        } catch {
                            lock.lock()
                            errors.append(error)
                            lock.unlock()
                        }
                    }
                }
            }

            let result = group.wait(timeout: .now() + 300)
            #expect(result == .success)
            #expect(errors.isEmpty)
        }

        /// Interleave calcTables and solveBoard from concurrent threads.
        @Test("Mixed API concurrent stress")
        func mixedAPIConcurrentStress() throws {
            let group = DispatchGroup()
            let lock = NSLock()
            var errors: [Error] = []

            for deal in stressDeals.prefix(5) {
                group.enter()
                DispatchQueue.global(qos: .userInitiated).async {
                    defer { group.leave() }
                    do {
                        let result = try DDSSolver.calcTables(
                            hands: [deal], vulns: [0], dealers: [0]
                        )
                        if result.isEmpty {
                            lock.lock()
                            errors.append(DDSError.unknownFault)
                            lock.unlock()
                        }
                    } catch {
                        lock.lock()
                        errors.append(error)
                        lock.unlock()
                    }
                }

                group.enter()
                DispatchQueue.global(qos: .userInitiated).async {
                    defer { group.leave() }
                    do {
                        _ = try DDSSolver.solveBoard(
                            pbn: deal,
                            target: -1, solutions: 3, mode: 1,
                            trump: 0, first: 0
                        )
                    } catch {
                        lock.lock()
                        errors.append(error)
                        lock.unlock()
                    }
                }
            }

            let result = group.wait(timeout: .now() + 300)
            #expect(result == .success)
            #expect(errors.isEmpty)
        }

        /// All 20 deals back-to-back through the wrapper.
        @Test("Rapid-fire sequential 20 deals")
        func rapidFireSequential() throws {
            for deal in stressDeals {
                let result = try DDSSolver.calcTables(
                    hands: [deal], vulns: [0], dealers: [0]
                )
                #expect(!result.isEmpty)
            }
        }
    }
}
