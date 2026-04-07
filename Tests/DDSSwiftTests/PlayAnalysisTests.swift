import XCTest

@testable import DDSSwift

final class PlayAnalysisTests: XCTestCase {

    // MARK: - Reference Data (from examples/hands.cpp)

    private let pbnHands: [String] = [
        "N:QJ6.K652.J85.T98 873.J97.AT764.Q4 K5.T83.KQ9.A7652 AT942.AQ4.32.KJ3",
        "E:QJT5432.T.6.QJ82 .J97543.K7532.94 87.A62.QJT4.AT75 AK96.KQ8.A98.K63",
        "N:73.QJT.AQ54.T752 QT6.876.KJ9.AQ84 5.A95432.7632.K6 AKJ9842.K.T8.J93"
    ]

    private let trumps: [Int32] = [0, 4, 0]
    private let firsts: [Int32] = [0, 1, 2]

    private let playNo: [Int32] = [45, 52, 12]

    private let playStrings: [String] = [
        "CTC4CACJH8H4HKH9D5DAD9D2S7S5S2SQD8D4DQD3H3HAH6H7C3C8CQC2S3SKSAS6HQH5HJHTCKC9D6C5S4SJS8C6DJ",
        "SQD2S8SAHKHTH3H2HQS2H4H6H8D6HJHAS7SKS4C4D8C2DKD4H9C5S6S3H7C7C3S5H5CTD9STD3DQDAC8S9SJC9DTCQD5CAC6DJCKCJD7",
        "HAHKHQH7D7D8DAD9C5CAC6C3"
    ]

    // Binary play sequences
    private let playSuit: [[Int32]] = [
        [3, 3, 3, 3,  1, 1, 1, 1,  2, 2, 2, 2,
         0, 0, 0, 0,  2, 2, 2, 2,  1, 1, 1, 1,
         3, 3, 3, 3,  0, 0, 0, 0,  1, 1, 1, 1,
         3, 3, 2, 3,  0, 0, 0, 3,  2],
        [0, 2, 0, 0,  1, 1, 1, 1,  1, 0, 1, 1,
         1, 2, 1, 1,  0, 0, 0, 3,  2, 3, 2, 2,
         1, 3, 0, 0,  1, 3, 3, 0,  1, 3, 2, 0,
         2, 2, 2, 3,  0, 0, 3, 2,  3, 2, 3, 3,
         2, 3, 3, 2],
        [1, 1, 1, 1,  2, 2, 2, 2,  3, 3, 3, 3]
    ]

    private let playRank: [[Int32]] = [
        [10, 4, 14, 11,  8, 4, 13, 9,  5, 14, 9, 2,
          7, 5,  2, 12,  8, 4, 12, 3,  3, 14, 6, 7,
          3, 8, 12,  2,  3, 13, 14, 6, 12, 5, 11, 10,
         13, 9,  6,  5,  4, 11, 8, 6,  11],
        [12, 2, 8, 14,  13, 10, 3, 2,  12, 2, 4, 6,
          8, 6, 11, 14,   7, 13, 4, 4,   8, 2, 13, 4,
          9, 5,  6,  3,   7,  7, 3, 5,   5, 10, 9, 10,
          3, 12, 14, 8,   9, 11, 9, 10,  12, 5, 14, 6,
         11, 13, 11, 7],
        [14, 13, 12, 7,  7, 8, 14, 9,  5, 14, 6, 3]
    ]

    // Expected trick counts
    private let traceNo: [Int32] = [46, 49, 13]

    private let expectedTrace: [[Int32]] = [
        [8,  8, 8, 8, 8,  8, 8, 8, 8,  8, 8, 8, 8,  8, 8, 8, 8,
             8, 8, 8, 8,  8, 8, 8, 8,  8, 8, 8, 8,  8, 8, 8, 8,
             8, 8, 8, 8,  8, 8, 8, 8,  8, 8, 8, 8,  8],
        [9, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10,
            10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10,
            10, 10, 10, 10,  9,  9,  9,  9,  9,  9,  9,  9,  9,  9,  9,  9],
        [10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10]
    ]

    // MARK: - Play Analysis (Binary)

    func testAnalysePlayBin() throws {
        let R2:  UInt32 = 0x0004; let R3:  UInt32 = 0x0008; let R4:  UInt32 = 0x0010
        let R5:  UInt32 = 0x0020; let R6:  UInt32 = 0x0040; let R7:  UInt32 = 0x0080
        let R8:  UInt32 = 0x0100; let R9:  UInt32 = 0x0200; let RT:  UInt32 = 0x0400
        let RJ:  UInt32 = 0x0800; let RQ:  UInt32 = 0x1000; let RK:  UInt32 = 0x2000
        let RA:  UInt32 = 0x4000

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

        for i in 0..<3 {
            // Transpose to [hand][suit]
            var remainCards: [[UInt32]] = Array(repeating: Array(repeating: 0, count: 4), count: 4)
            for suit in 0..<4 {
                for hand in 0..<4 {
                    remainCards[hand][suit] = holdingsBySuit[i][suit][hand]
                }
            }

            let deal = DDSDeal(
                trump: trumps[i],
                first: firsts[i],
                remainCards: remainCards
            )

            let play = DDSPlayTrace(
                number: playNo[i],
                suit: Array(playSuit[i][0..<Int(playNo[i])]),
                rank: Array(playRank[i][0..<Int(playNo[i])])
            )

            let solved = try DDSSolver.analysePlay(deal: deal, play: play)

            XCTAssertEqual(solved.number, traceNo[i],
                           "Hand \(i): expected \(traceNo[i]) trace entries, got \(solved.number)")

            for j in 0..<Int(solved.number) {
                XCTAssertEqual(solved.tricks[j], expectedTrace[i][j],
                               "Hand \(i), trace \(j): expected \(expectedTrace[i][j]), got \(solved.tricks[j])")
            }
        }
    }

    // MARK: - Play Analysis (PBN)

    func testAnalysePlayPBN() throws {
        for i in 0..<3 {
            let deal = (pbn: pbnHands[i], trump: trumps[i], first: firsts[i])
            let play = DDSPlayTracePBN(number: playNo[i], cards: playStrings[i])

            let solved = try DDSSolver.analysePlayPBN(deal: deal, play: play)

            XCTAssertEqual(solved.number, traceNo[i],
                           "Hand \(i): expected \(traceNo[i]) trace entries, got \(solved.number)")

            for j in 0..<Int(solved.number) {
                XCTAssertEqual(solved.tricks[j], expectedTrace[i][j],
                               "Hand \(i), trace \(j): expected \(expectedTrace[i][j]), got \(solved.tricks[j])")
            }
        }
    }

    // MARK: - Play Analysis (PBN matches Binary)

    func testAnalysePlay_PBNmatchesBinary() throws {
        let R2:  UInt32 = 0x0004; let R3:  UInt32 = 0x0008; let R4:  UInt32 = 0x0010
        let R5:  UInt32 = 0x0020; let R6:  UInt32 = 0x0040; let R7:  UInt32 = 0x0080
        let R8:  UInt32 = 0x0100; let R9:  UInt32 = 0x0200; let RT:  UInt32 = 0x0400
        let RJ:  UInt32 = 0x0800; let RQ:  UInt32 = 0x1000; let RK:  UInt32 = 0x2000
        let RA:  UInt32 = 0x4000

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

        for i in 0..<3 {
            var remainCards: [[UInt32]] = Array(repeating: Array(repeating: 0, count: 4), count: 4)
            for suit in 0..<4 {
                for hand in 0..<4 {
                    remainCards[hand][suit] = holdingsBySuit[i][suit][hand]
                }
            }

            let binDeal = DDSDeal(trump: trumps[i], first: firsts[i], remainCards: remainCards)
            let binPlay = DDSPlayTrace(
                number: playNo[i],
                suit: Array(playSuit[i][0..<Int(playNo[i])]),
                rank: Array(playRank[i][0..<Int(playNo[i])])
            )
            let binSolved = try DDSSolver.analysePlay(deal: binDeal, play: binPlay)

            let pbnDeal = (pbn: pbnHands[i], trump: trumps[i], first: firsts[i])
            let pbnPlay = DDSPlayTracePBN(number: playNo[i], cards: playStrings[i])
            let pbnSolved = try DDSSolver.analysePlayPBN(deal: pbnDeal, play: pbnPlay)

            XCTAssertEqual(binSolved.number, pbnSolved.number,
                           "Hand \(i): trace count mismatch between binary and PBN")

            for j in 0..<Int(binSolved.number) {
                XCTAssertEqual(binSolved.tricks[j], pbnSolved.tricks[j],
                               "Hand \(i), trace \(j): binary/PBN mismatch")
            }
        }
    }

    // MARK: - Batch Play Analysis (PBN)

    func testAnalyseAllPlaysPBN() throws {
        let boards = (0..<3).map { i in
            (pbn: pbnHands[i], trump: trumps[i], first: firsts[i])
        }
        let plays = (0..<3).map { i in
            DDSPlayTracePBN(number: playNo[i], cards: playStrings[i])
        }

        let results = try DDSSolver.analyseAllPlaysPBN(boards: boards, plays: plays)

        XCTAssertEqual(results.count, 3)

        for i in 0..<3 {
            XCTAssertEqual(results[i].number, traceNo[i],
                           "Hand \(i): expected \(traceNo[i]) trace entries, got \(results[i].number)")

            for j in 0..<Int(results[i].number) {
                XCTAssertEqual(results[i].tricks[j], expectedTrace[i][j],
                               "Hand \(i), trace \(j): expected \(expectedTrace[i][j]), got \(results[i].tricks[j])")
            }
        }
    }

    // MARK: - Batch Play Analysis (Binary)

    func testAnalyseAllPlaysBin() throws {
        let R2:  UInt32 = 0x0004; let R3:  UInt32 = 0x0008; let R4:  UInt32 = 0x0010
        let R5:  UInt32 = 0x0020; let R6:  UInt32 = 0x0040; let R7:  UInt32 = 0x0080
        let R8:  UInt32 = 0x0100; let R9:  UInt32 = 0x0200; let RT:  UInt32 = 0x0400
        let RJ:  UInt32 = 0x0800; let RQ:  UInt32 = 0x1000; let RK:  UInt32 = 0x2000
        let RA:  UInt32 = 0x4000

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

        var boards: [DDSDeal] = []
        var plays: [DDSPlayTrace] = []

        for i in 0..<3 {
            var remainCards: [[UInt32]] = Array(repeating: Array(repeating: 0, count: 4), count: 4)
            for suit in 0..<4 {
                for hand in 0..<4 {
                    remainCards[hand][suit] = holdingsBySuit[i][suit][hand]
                }
            }
            boards.append(DDSDeal(trump: trumps[i], first: firsts[i], remainCards: remainCards))
            plays.append(DDSPlayTrace(
                number: playNo[i],
                suit: Array(playSuit[i][0..<Int(playNo[i])]),
                rank: Array(playRank[i][0..<Int(playNo[i])])
            ))
        }

        let results = try DDSSolver.analyseAllPlays(boards: boards, plays: plays)

        XCTAssertEqual(results.count, 3)

        for i in 0..<3 {
            XCTAssertEqual(results[i].number, traceNo[i],
                           "Hand \(i): expected \(traceNo[i]) trace entries, got \(results[i].number)")

            for j in 0..<Int(results[i].number) {
                XCTAssertEqual(results[i].tricks[j], expectedTrace[i][j],
                               "Hand \(i), trace \(j): expected \(expectedTrace[i][j]), got \(results[i].tricks[j])")
            }
        }
    }
}
