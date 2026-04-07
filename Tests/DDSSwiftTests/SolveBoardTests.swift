import XCTest

@testable import DDSSwift

final class SolveBoardTests: XCTestCase {

    // MARK: - Reference Data (from examples/hands.cpp)

    private let pbnHands: [String] = [
        "N:QJ6.K652.J85.T98 873.J97.AT764.Q4 K5.T83.KQ9.A7652 AT942.AQ4.32.KJ3",
        "E:QJT5432.T.6.QJ82 .J97543.K7532.94 87.A62.QJT4.AT75 AK96.KQ8.A98.K63",
        "N:73.QJT.AQ54.T752 QT6.876.KJ9.AQ84 5.A95432.7632.K6 AKJ9842.K.T8.J93"
    ]

    private let trumps: [Int32] = [0, 4, 0]       // Spades, NT, Spades
    private let firsts: [Int32] = [0, 1, 2]        // North, East, South

    // Binary card holdings: holdings[hand][suit][player]
    // From hands.cpp — the array is indexed as holdings[handno][suit][player]
    // Suit order: Spades, Hearts, Diamonds, Clubs
    // Player order: North, East, South, West

    private let R2:  UInt32 = 0x0004
    private let R3:  UInt32 = 0x0008
    private let R4:  UInt32 = 0x0010
    private let R5:  UInt32 = 0x0020
    private let R6:  UInt32 = 0x0040
    private let R7:  UInt32 = 0x0080
    private let R8:  UInt32 = 0x0100
    private let R9:  UInt32 = 0x0200
    private let RT:  UInt32 = 0x0400
    private let RJ:  UInt32 = 0x0800
    private let RQ:  UInt32 = 0x1000
    private let RK:  UInt32 = 0x2000
    private let RA:  UInt32 = 0x4000

    // Expected results for solutions == 3 (all legal cards)
    private let cardsSoln3: [Int32] = [9, 7, 8]

    // Expected card data for solutions == 3
    private let cardsSuits: [[Int32]] = [
        [2, 2, 2, 3, 0, 0, 1, 1, 1,    0, 0, 0, 0],
        [3, 3, 3, 1, 2, 0, 0,    0, 0, 0, 0, 0, 0],
        [1, 2, 2, 0, 1, 1, 3, 3,    0, 0, 0, 0, 0]
    ]

    private let cardsRanks: [[Int32]] = [
        [5, 8, 11, 10, 6, 12, 2, 6, 13,    0, 0, 0, 0],
        [2, 8, 12, 10, 6, 12, 5,    0, 0, 0, 0, 0, 0],
        [14, 3, 7, 5, 5, 9, 6, 13,    0, 0, 0, 0, 0]
    ]

    private let cardsScores: [[Int32]] = [
        [5, 5, 5, 5, 5, 5, 4, 4, 4,    0, 0, 0, 0],
        [4, 4, 4, 3, 3, 3, 2,    0, 0, 0, 0, 0, 0],
        [3, 3, 3, 3, 2, 2, 1, 1,    0, 0, 0, 0, 0]
    ]

    private let cardsEquals: [[Int32]] = [
        [0, 0, 0, 768, 0, 2048, 0, 32, 0,    0, 0, 0, 0],
        [0, 0, 2048, 0, 0, 3072, 28,    0, 0, 0, 0, 0, 0],
        [0, 4, 64, 0, 28, 0, 0, 0,    0, 0, 0, 0, 0]
    ]

    // Expected results for solutions == 2 (all optimal cards)
    private let cardsSoln2: [Int32] = [6, 3, 4]

    // MARK: - PBN Variant Tests

    func testSolveBoardPBN_solutions3() throws {
        for i in 0..<3 {
            let result = try DDSSolver.solveBoard(
                pbn: pbnHands[i],
                target: -1,
                solutions: 3,
                mode: 0,
                trump: trumps[i],
                first: firsts[i]
            )

            XCTAssertEqual(result.cards, cardsSoln3[i],
                           "Hand \(i): expected \(cardsSoln3[i]) cards, got \(result.cards)")

            for j in 0..<Int(result.cards) {
                XCTAssertEqual(result.suit[j], cardsSuits[i][j],
                               "Hand \(i), card \(j): suit mismatch")
                XCTAssertEqual(result.rank[j], cardsRanks[i][j],
                               "Hand \(i), card \(j): rank mismatch")
                XCTAssertEqual(result.score[j], cardsScores[i][j],
                               "Hand \(i), card \(j): score mismatch")
                XCTAssertEqual(result.equals[j], cardsEquals[i][j],
                               "Hand \(i), card \(j): equals mismatch")
            }
        }
    }

    func testSolveBoardPBN_solutions2() throws {
        for i in 0..<3 {
            let result = try DDSSolver.solveBoard(
                pbn: pbnHands[i],
                target: -1,
                solutions: 2,
                mode: 0,
                trump: trumps[i],
                first: firsts[i]
            )

            XCTAssertEqual(result.cards, cardsSoln2[i],
                           "Hand \(i): expected \(cardsSoln2[i]) optimal cards, got \(result.cards)")
        }
    }

    // MARK: - Binary Variant Tests

    func testSolveBoardBinary_solutions3() throws {
        let holdings = makeHoldings()

        for i in 0..<3 {
            let deal = DDSDeal(
                trump: trumps[i],
                first: firsts[i],
                remainCards: holdings[i]
            )

            let result = try DDSSolver.solveBoard(
                deal: deal,
                target: -1,
                solutions: 3,
                mode: 0
            )

            XCTAssertEqual(result.cards, cardsSoln3[i],
                           "Hand \(i): expected \(cardsSoln3[i]) cards, got \(result.cards)")

            for j in 0..<Int(result.cards) {
                XCTAssertEqual(result.suit[j], cardsSuits[i][j],
                               "Hand \(i), card \(j): suit mismatch")
                XCTAssertEqual(result.rank[j], cardsRanks[i][j],
                               "Hand \(i), card \(j): rank mismatch")
                XCTAssertEqual(result.score[j], cardsScores[i][j],
                               "Hand \(i), card \(j): score mismatch")
                XCTAssertEqual(result.equals[j], cardsEquals[i][j],
                               "Hand \(i), card \(j): equals mismatch")
            }
        }
    }

    func testSolveBoardBinary_matchesPBN() throws {
        let holdings = makeHoldings()

        for i in 0..<3 {
            let pbnResult = try DDSSolver.solveBoard(
                pbn: pbnHands[i],
                target: -1,
                solutions: 3,
                mode: 0,
                trump: trumps[i],
                first: firsts[i]
            )

            let deal = DDSDeal(
                trump: trumps[i],
                first: firsts[i],
                remainCards: holdings[i]
            )

            let binResult = try DDSSolver.solveBoard(
                deal: deal,
                target: -1,
                solutions: 3,
                mode: 0
            )

            XCTAssertEqual(pbnResult.cards, binResult.cards,
                           "Hand \(i): card count mismatch between PBN and binary")

            for j in 0..<Int(pbnResult.cards) {
                XCTAssertEqual(pbnResult.suit[j], binResult.suit[j])
                XCTAssertEqual(pbnResult.rank[j], binResult.rank[j])
                XCTAssertEqual(pbnResult.score[j], binResult.score[j])
                XCTAssertEqual(pbnResult.equals[j], binResult.equals[j])
            }
        }
    }

    // MARK: - Helpers

    /// Builds holdings array as [handno][hand][suit] matching the C format.
    /// The C data has holdings[3][4][4] indexed as [handno][suit][hand].
    /// DDSDeal expects remainCards[hand][suit], so we transpose.
    private func makeHoldings() -> [[[UInt32]]] {
        // C layout: holdings[handno][suit][hand]
        let holdingsBySuit: [[[UInt32]]] = [
            [ // Hand 0
                [RQ|RJ|R6, R8|R7|R3, RK|R5, RA|RT|R9|R4|R2],     // spades
                [RK|R6|R5|R2, RJ|R9|R7, RT|R8|R3, RA|RQ|R4],     // hearts
                [RJ|R8|R5, RA|RT|R7|R6|R4, RK|RQ|R9, R3|R2],     // diamonds
                [RT|R9|R8, RQ|R4, RA|R7|R6|R5|R2, RK|RJ|R3]      // clubs
            ],
            [ // Hand 1
                [RA|RK|R9|R6, RQ|RJ|RT|R5|R4|R3|R2, 0, R8|R7],
                [RK|RQ|R8, RT, RJ|R9|R7|R5|R4|R3, RA|R6|R2],
                [RA|R9|R8, R6, RK|R7|R5|R3|R2, RQ|RJ|RT|R4],
                [RK|R6|R3, RQ|RJ|R8|R2, R9|R4, RA|RT|R7|R5]
            ],
            [ // Hand 2
                [R7|R3, RQ|RT|R6, R5, RA|RK|RJ|R9|R8|R4|R2],
                [RQ|RJ|RT, R8|R7|R6, RA|R9|R5|R4|R3|R2, RK],
                [RA|RQ|R5|R4, RK|RJ|R9, R7|R6|R3|R2, RT|R8],
                [RT|R7|R5|R2, RA|RQ|R8|R4, RK|R6, RJ|R9|R3]
            ]
        ]

        // Transpose: holdings[handno][suit][hand] → remainCards[hand][suit]
        return holdingsBySuit.map { handHoldings in
            var result: [[UInt32]] = Array(repeating: Array(repeating: 0, count: 4), count: 4)
            for suit in 0..<4 {
                for hand in 0..<4 {
                    result[hand][suit] = handHoldings[suit][hand]
                }
            }
            return result
        }
    }
}
