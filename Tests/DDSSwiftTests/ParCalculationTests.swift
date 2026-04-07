import XCTest

@testable import DDSSwift

final class ParCalculationTests: XCTestCase {

    private let pbnHands: [String] = [
        "N:QJ6.K652.J85.T98 873.J97.AT764.Q4 K5.T83.KQ9.A7652 AT942.AQ4.32.KJ3",
        "E:QJT5432.T.6.QJ82 .J97543.K7532.94 87.A62.QJT4.AT75 AK96.KQ8.A98.K63",
        "N:73.QJT.AQ54.T752 QT6.876.KJ9.AQ84 5.A95432.7632.K6 AKJ9842.K.T8.J93"
    ]

    private let dealers: [Int32] = [0, 1, 0]       // North, East, North
    private let vulns: [Int32] = [0, 2, 0]          // None, NS, None

    // Expected Par() results
    private let expectedParScores: [[String]] = [
        ["NS -110", "EW 110"],
        ["NS 100", "EW -100"],
        ["NS -300", "EW 300"]
    ]

    private let expectedParContracts: [[String]] = [
        ["NS:EW 2S", "EW:EW 2S"],
        ["NS:EW 4Sx", "EW:EW 4Sx"],
        ["NS:NS 5Hx", "EW:NS 5Hx"]
    ]

    // Expected DealerPar() results
    private let expectedDealerParNo: [Int32] = [1, 1, 1]
    private let expectedDealerScore: [Int32] = [-110, 100, -300]
    private let expectedDealerContract: [[String]] = [
        ["2S-EW"],
        ["4S*-EW-1"],
        ["5H*-NS-2"]
    ]

    // MARK: - Par

    func testPar() throws {
        for i in 0..<3 {
            let table = try DDSSolver.calcDDTablePBN(pbn: pbnHands[i])
            let par = try DDSSolver.par(table: table, vulnerable: vulns[i])

            XCTAssertEqual(par.parScore[0], expectedParScores[i][0],
                           "Hand \(i) NS score: expected '\(expectedParScores[i][0])', got '\(par.parScore[0])'")
            XCTAssertEqual(par.parScore[1], expectedParScores[i][1],
                           "Hand \(i) EW score: expected '\(expectedParScores[i][1])', got '\(par.parScore[1])'")
            XCTAssertEqual(par.parContractsString[0], expectedParContracts[i][0],
                           "Hand \(i) NS contracts: expected '\(expectedParContracts[i][0])', got '\(par.parContractsString[0])'")
            XCTAssertEqual(par.parContractsString[1], expectedParContracts[i][1],
                           "Hand \(i) EW contracts: expected '\(expectedParContracts[i][1])', got '\(par.parContractsString[1])'")
        }
    }

    // MARK: - DealerPar

    func testDealerPar() throws {
        for i in 0..<3 {
            let table = try DDSSolver.calcDDTablePBN(pbn: pbnHands[i])
            let par = try DDSSolver.dealerPar(table: table, dealer: dealers[i], vulnerable: vulns[i])

            XCTAssertEqual(par.number, expectedDealerParNo[i],
                           "Hand \(i): expected \(expectedDealerParNo[i]) contracts, got \(par.number)")
            XCTAssertEqual(par.score, expectedDealerScore[i],
                           "Hand \(i): expected score \(expectedDealerScore[i]), got \(par.score)")

            for j in 0..<Int(par.number) {
                XCTAssertEqual(par.contracts[j], expectedDealerContract[i][j],
                               "Hand \(i), contract \(j): expected '\(expectedDealerContract[i][j])', got '\(par.contracts[j])'")
            }
        }
    }

    // MARK: - SidesPar

    func testSidesPar() throws {
        for i in 0..<3 {
            let table = try DDSSolver.calcDDTablePBN(pbn: pbnHands[i])
            let (nsPar, ewPar) = try DDSSolver.sidesPar(table: table, vulnerable: vulns[i])

            // SidesPar should give consistent par info for both sides
            XCTAssertGreaterThanOrEqual(nsPar.number, 1, "Hand \(i): NS should have at least 1 contract")
            XCTAssertGreaterThanOrEqual(ewPar.number, 1, "Hand \(i): EW should have at least 1 contract")
            // The scores should be opposites (from each side's perspective)
            XCTAssertEqual(nsPar.score, -ewPar.score,
                           "Hand \(i): NS score (\(nsPar.score)) should be negative of EW score (\(ewPar.score))")
        }
    }

    // MARK: - DealerParBin

    func testDealerParBin() throws {
        for i in 0..<3 {
            let table = try DDSSolver.calcDDTablePBN(pbn: pbnHands[i])
            let par = try DDSSolver.dealerParBin(table: table, dealer: dealers[i], vulnerable: vulns[i])

            XCTAssertEqual(par.score, expectedDealerScore[i],
                           "Hand \(i): expected score \(expectedDealerScore[i]), got \(par.score)")
            XCTAssertGreaterThanOrEqual(par.number, 1,
                                        "Hand \(i): should have at least 1 contract")

            for contract in par.contracts {
                XCTAssertGreaterThanOrEqual(contract.level, 1)
                XCTAssertLessThanOrEqual(contract.level, 7)
                XCTAssertGreaterThanOrEqual(contract.denom, 0)
                XCTAssertLessThanOrEqual(contract.denom, 4)
                XCTAssertGreaterThanOrEqual(contract.seats, 0)
                XCTAssertLessThanOrEqual(contract.seats, 5)
            }
        }
    }

    // MARK: - SidesParBin

    func testSidesParBin() throws {
        for i in 0..<3 {
            let table = try DDSSolver.calcDDTablePBN(pbn: pbnHands[i])
            let (nsPar, ewPar) = try DDSSolver.sidesParBin(table: table, vulnerable: vulns[i])

            XCTAssertEqual(nsPar.score, -ewPar.score,
                           "Hand \(i): NS score (\(nsPar.score)) should be negative of EW score (\(ewPar.score))")
        }
    }

    // MARK: - ConvertToDealerTextFormat

    func testConvertToDealerTextFormat() throws {
        for i in 0..<3 {
            let table = try DDSSolver.calcDDTablePBN(pbn: pbnHands[i])
            let parBin = try DDSSolver.dealerParBin(table: table, dealer: dealers[i], vulnerable: vulns[i])
            let text = try DDSSolver.convertToDealerTextFormat(par: parBin)

            XCTAssertFalse(text.isEmpty, "Hand \(i): dealer text should not be empty")
        }
    }

    // MARK: - ConvertToSidesTextFormat

    func testConvertToSidesTextFormat() throws {
        for i in 0..<3 {
            let table = try DDSSolver.calcDDTablePBN(pbn: pbnHands[i])
            let sides = try DDSSolver.sidesParBin(table: table, vulnerable: vulns[i])
            let textResults = try DDSSolver.convertToSidesTextFormat(sides: sides)

            XCTAssertEqual(textResults.parText.count, 2,
                           "Hand \(i): should have 2 par text entries")
            XCTAssertFalse(textResults.parText[0].isEmpty,
                           "Hand \(i): NS par text should not be empty")
            XCTAssertFalse(textResults.parText[1].isEmpty,
                           "Hand \(i): EW par text should not be empty")
        }
    }

    // MARK: - Cross-validation: DealerPar text matches DealerParBin converted

    func testDealerParBin_consistentWithDealerPar() throws {
        for i in 0..<3 {
            let table = try DDSSolver.calcDDTablePBN(pbn: pbnHands[i])
            let dealerParResult = try DDSSolver.dealerPar(table: table, dealer: dealers[i], vulnerable: vulns[i])
            let dealerParBinResult = try DDSSolver.dealerParBin(table: table, dealer: dealers[i], vulnerable: vulns[i])

            XCTAssertEqual(dealerParResult.score, dealerParBinResult.score,
                           "Hand \(i): DealerPar and DealerParBin should give same score")
            XCTAssertEqual(dealerParResult.number, dealerParBinResult.number,
                           "Hand \(i): DealerPar and DealerParBin should give same number of contracts")
        }
    }
}
