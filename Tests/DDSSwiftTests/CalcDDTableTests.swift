import XCTest

@testable import DDSSwift

final class CalcDDTableTests: XCTestCase {

    private let pbnHands: [String] = [
        "N:QJ6.K652.J85.T98 873.J97.AT764.Q4 K5.T83.KQ9.A7652 AT942.AQ4.32.KJ3",
        "E:QJT5432.T.6.QJ82 .J97543.K7532.94 87.A62.QJT4.AT75 AK96.KQ8.A98.K63",
        "N:73.QJT.AQ54.T752 QT6.876.KJ9.AQ84 5.A95432.7632.K6 AKJ9842.K.T8.J93"
    ]

    // From hands.cpp: DDtable[handno][strain*4 + hand]
    // Order: Spades N,E,S,W; Hearts N,E,S,W; Diamonds N,E,S,W; Clubs N,E,S,W; NT N,E,S,W
    private let expectedDDTable: [[Int32]] = [
        [5, 8, 5, 8,  6, 6, 6, 6,  5, 7, 5, 7,  7, 5, 7, 5,  6, 6, 6, 6],
        [4, 9, 4, 9, 10, 2, 10, 2,  8, 3, 8, 3,  6, 7, 6, 7,  9, 3, 9, 3],
        [3, 10, 3, 10,  9, 4, 9, 4,  8, 4, 8, 4,  3, 9, 3, 9,  4, 8, 4, 8]
    ]

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

    func testCalcDDTablePBN() throws {
        for i in 0..<3 {
            let table = try DDSSolver.calcDDTablePBN(pbn: pbnHands[i])

            for strain in 0..<5 {
                for hand in 0..<4 {
                    let expected = expectedDDTable[i][strain * 4 + hand]
                    XCTAssertEqual(table.resTable[strain][hand], expected,
                                   "Hand \(i), strain \(strain), hand \(hand): expected \(expected), got \(table.resTable[strain][hand])")
                }
            }
        }
    }

    func testCalcDDTableBinary() throws {
        let holdings = makeHoldings()

        for i in 0..<3 {
            let table = try DDSSolver.calcDDTable(deal: holdings[i])

            for strain in 0..<5 {
                for hand in 0..<4 {
                    let expected = expectedDDTable[i][strain * 4 + hand]
                    XCTAssertEqual(table.resTable[strain][hand], expected,
                                   "Hand \(i), strain \(strain), hand \(hand): expected \(expected), got \(table.resTable[strain][hand])")
                }
            }
        }
    }

    func testCalcDDTable_PBNmatchesBinary() throws {
        let holdings = makeHoldings()

        for i in 0..<3 {
            let pbnTable = try DDSSolver.calcDDTablePBN(pbn: pbnHands[i])
            let binTable = try DDSSolver.calcDDTable(deal: holdings[i])

            for strain in 0..<5 {
                for hand in 0..<4 {
                    XCTAssertEqual(pbnTable.resTable[strain][hand],
                                   binTable.resTable[strain][hand],
                                   "Hand \(i), strain \(strain), hand \(hand): PBN/binary mismatch")
                }
            }
        }
    }

    // MARK: - Helpers

    private func makeHoldings() -> [[[UInt32]]] {
        // C layout: holdings[handno][suit][hand]
        let holdingsBySuit: [[[UInt32]]] = [
            [
                [RQ|RJ|R6, R8|R7|R3, RK|R5, RA|RT|R9|R4|R2],
                [RK|R6|R5|R2, RJ|R9|R7, RT|R8|R3, RA|RQ|R4],
                [RJ|R8|R5, RA|RT|R7|R6|R4, RK|RQ|R9, R3|R2],
                [RT|R9|R8, RQ|R4, RA|R7|R6|R5|R2, RK|RJ|R3]
            ],
            [
                [RA|RK|R9|R6, RQ|RJ|RT|R5|R4|R3|R2, 0, R8|R7],
                [RK|RQ|R8, RT, RJ|R9|R7|R5|R4|R3, RA|R6|R2],
                [RA|R9|R8, R6, RK|R7|R5|R3|R2, RQ|RJ|RT|R4],
                [RK|R6|R3, RQ|RJ|R8|R2, R9|R4, RA|RT|R7|R5]
            ],
            [
                [R7|R3, RQ|RT|R6, R5, RA|RK|RJ|R9|R8|R4|R2],
                [RQ|RJ|RT, R8|R7|R6, RA|R9|R5|R4|R3|R2, RK],
                [RA|RQ|R5|R4, RK|RJ|R9, R7|R6|R3|R2, RT|R8],
                [RT|R7|R5|R2, RA|RQ|R8|R4, RK|R6, RJ|R9|R3]
            ]
        ]

        // Transpose: [handno][suit][player] → [hand][suit] for ddTableDeal.cards
        // ddTableDeal.cards[hand][suit]
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
