import XCTest

@testable import DDSSwift

final class SolveAllBoardsTests: XCTestCase {

    private let pbnHands: [String] = [
        "N:QJ6.K652.J85.T98 873.J97.AT764.Q4 K5.T83.KQ9.A7652 AT942.AQ4.32.KJ3",
        "E:QJT5432.T.6.QJ82 .J97543.K7532.94 87.A62.QJT4.AT75 AK96.KQ8.A98.K63",
        "N:73.QJT.AQ54.T752 QT6.876.KJ9.AQ84 5.A95432.7632.K6 AKJ9842.K.T8.J93"
    ]

    private let trumps: [Int32] = [0, 4, 0]
    private let firsts: [Int32] = [0, 1, 2]

    func testSolveAllBoards_matchesIndividual() throws {
        // Solve individually first
        var individualResults: [DDSFutureTricks] = []
        for i in 0..<3 {
            let result = try DDSSolver.solveBoard(
                pbn: pbnHands[i],
                target: -1,
                solutions: 3,
                mode: 0,
                trump: trumps[i],
                first: firsts[i]
            )
            individualResults.append(result)
        }

        // Solve as batch
        let boards = (0..<3).map { i in
            (pbn: pbnHands[i], trump: trumps[i], first: firsts[i],
             target: Int32(-1), solutions: Int32(3), mode: Int32(0))
        }

        let batchResults = try DDSSolver.solveAllBoards(boards: boards)

        XCTAssertEqual(batchResults.count, 3)

        for i in 0..<3 {
            XCTAssertEqual(batchResults[i].cards, individualResults[i].cards,
                           "Hand \(i): card count mismatch")

            for j in 0..<Int(batchResults[i].cards) {
                XCTAssertEqual(batchResults[i].suit[j], individualResults[i].suit[j],
                               "Hand \(i), card \(j): suit mismatch")
                XCTAssertEqual(batchResults[i].rank[j], individualResults[i].rank[j],
                               "Hand \(i), card \(j): rank mismatch")
                XCTAssertEqual(batchResults[i].score[j], individualResults[i].score[j],
                               "Hand \(i), card \(j): score mismatch")
                XCTAssertEqual(batchResults[i].equals[j], individualResults[i].equals[j],
                               "Hand \(i), card \(j): equals mismatch")
            }
        }
    }

    func testSolveAllBoards_solutions2() throws {
        let expectedCards: [Int32] = [6, 3, 4]

        let boards = (0..<3).map { i in
            (pbn: pbnHands[i], trump: trumps[i], first: firsts[i],
             target: Int32(-1), solutions: Int32(2), mode: Int32(0))
        }

        let results = try DDSSolver.solveAllBoards(boards: boards)

        XCTAssertEqual(results.count, 3)
        for i in 0..<3 {
            XCTAssertEqual(results[i].cards, expectedCards[i],
                           "Hand \(i): expected \(expectedCards[i]) optimal cards, got \(results[i].cards)")
        }
    }
}
