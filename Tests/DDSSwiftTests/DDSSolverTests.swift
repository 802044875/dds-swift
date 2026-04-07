import XCTest

@testable import DDSSwift

final class DDSSolverTests: XCTestCase {

    /* dealer 0: North 1: East 2: South 3: West */
    private let north: Int32 = .zero
    private let east: Int32 = 1
    private let south: Int32 = 2
    private let west: Int32 = 3

    /* vulnerable 0: None 1: Both 2: NS 3: EW */
    private let none: Int32 = .zero
    private let all: Int32 = 1
    private let ns: Int32 = 2
    private let ew: Int32 = 3

    func testCalcTables() throws {
        let hands: [String] = [
            "N:JT93.T7.32.QT982 65.AJ.AKQJ975.J7 AK842.65.4.K6543 Q7.KQ98432.T86.A",
            "E:7.QT9.A62.KQJ764 642.8632.98.A952 AQJ95.75.J753.T3 KT83.AKJ4.KQT4.8",
            "S:A82.J765.Q73.T93 QJ74.AKT84.K.J54 K95.Q3.AT98.KQ76 T63.92.J6542.A82",
            "W:AK5.T985.AT63.KQ Q972.Q43.4.T9852 JT864.AJ7.QJ972. 3.K62.K85.AJ7643",
            "N:AJ97.KJ9.T.AK763 8.A75432.KQ75.Q8 K65.QT86.A83.JT5 QT432..J9642.942",
            "E:Q9.8.KQ52.AK9842 763.QJ973.843.J7 KT852.A52.97.QT5 AJ4.KT64.AJT6.63",
            "S:AK652.AK74.J.A43 J8.J8.KT982.QT95 Q9.QT2.AQ753.J72 T743.9653.64.K86",
            "W:2.AT62.QT72.AKQ9 T3.KJ75.AK8.7643 AKQJ98.98.J96.T2 7654.Q43.543.J85",
            "N:.AJ65.KT532.AJ62 KJ6.KQ873.J7.K85 AQ9753.9.AQ984.7 T842.T42.6.QT943",
            "E:A92.Q83.AKQJ8.J5 J5.J72.9765.A742 K743.KT964.4.T63 QT86.A5.T32.KQ98",
            "S:87.932.9763.KT62 AQ94.Q7.AQ85.A93 KJT63.J4.JT4.QJ5 52.AKT865.K2.874",
            "W:T6.94.AQJ84.AKJ3 Q9754.K53.K6.Q64 K83.AQT76.95.T97 AJ2.J82.T732.852",
            "N:J983.K54.AQ5.AK5 762.T97.73.Q9863 KQT.63.JT9864.J4 A54.AQJ82.K2.T72",
            "E:QT964.752.AT.T52 AKJ5.T63.QJ2.Q64 832.A4.K6.AKJ987 7.KQJ98.987543.3",
            "S:Q986.A98.Q5.AK32 AJT5.KQ654.K8.T8 42.T73.T972.Q974 K73.J2.AJ643.J65",
            "W:642.A98632.K.Q43 K9..QJ8764.KT975 AQJ8.QJT.T2.AJ82 T753.K754.A953.6",
            "N:J86.QJ752.952.K5 A94.K9864.KJ.QJ8 KQ32.T.AQT74.T63 T75.A3.863.A9742",
            "E:95.Q4.Q4.QJ96543 AJT7.T862.J3.AT8 62.KJ953.AKT952. KQ843.A7.876.K72"
        ]

        let vulns: [Int32] = [none, ns, ew, all, ns, ew, all, none, ew, all, none, ns, all, none, ns, ew, none, ns]
        let dealers: [Int32] = [north, east, south, west, north, east, south, west, north, east, south, west, north, east, south, west, north, east]

        let optimumScores: [String] = [
            "EW 5H; -450",
            "NS 3H; 140",
            "NS 1N+1; 120",
            "EW 4S, EW 4H; -620",
            "S 6C; 1370",
            "EW 4S; -620",
            "NS 6H; 1430",
            "EW 3N+2; -460",
            "NS 7D; 1440",
            "EW 4H; -620",
            "EW 3N+2; -460",
            "E 1N+1; -120",
            "NS 4S+1; 650",
            "NS 4DX-1, S 4HX-1; -100",
            "EW 4H; -420",
            "NS 6DX-2; -300",
            "NS 2S+1; 140",
            "EW 4D; -130"
        ]

        let results = try DDSSolver.calcTables(hands: hands, vulns: vulns, dealers: dealers)

        for (index, result) in results.enumerated() {
            XCTAssertEqual(
                result.optimumScore,
                optimumScores[index],
                "Unexpected optimum score for hand \(index): '\(result.optimumScore)', should be: '\(optimumScores[index])'."
            )
        }
    }

    func testCalcTablesWith51Cards() {
        let hands = ["N:JT93.T7.32.QT982 65.AJ.AKQJ975.J7 AK842.65.4.K6543 Q7.KQ98432.T86."]
        let vulns: [Int32] = [none]
        let dealers: [Int32] = [north]

        do {
            _ = try DDSSolver.calcTables(hands: hands, vulns: vulns, dealers: dealers)
            XCTFail("Error not thrown whilst Double Dummy Solving invalid board.")
        } catch let error as DDSError where error == .cardCount {
            XCTAssertEqual(error.localizedDescription, "Wrong number of remaining cards in a hand")
        } catch {
            XCTFail("Unexpected error thrown: \(error)")
        }
    }

    func testCalcTablesWithDuplicateCards() {
        let hands = ["N:JT93.T7.32.QT982 65.AJ.AKQJ975.J7 AK842.65.4.K6543 Q7.KQ98432.T86.K"]
        let vulns: [Int32] = [none]
        let dealers: [Int32] = [north]

        do {
            _ = try DDSSolver.calcTables(hands: hands, vulns: vulns, dealers: dealers)
            XCTFail("Error not thrown whilst Double Dummy Solving invalid board.")
        } catch let error as DDSError where error == .duplicateCards {
            XCTAssertEqual(error.localizedDescription, "Cards duplicated")
        } catch {
            XCTFail("Unexpected error thrown: \(error)")
        }
    }

    func testGetInfo() {
        let info = DDSSolver.getInfo()
        XCTAssertEqual(info.major, 2)
        XCTAssertEqual(info.minor, 9)
        XCTAssertEqual(info.patch, 0)
        XCTAssertTrue(info.systemString.contains("Apple"))
        XCTAssertTrue(info.systemString.contains("2.9.0"))
    }
}
