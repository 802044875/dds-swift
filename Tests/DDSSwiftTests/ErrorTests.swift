import XCTest

@testable import DDSSwift

final class ErrorTests: XCTestCase {

    // MARK: - Invalid Trump

    func testSolveBoard_invalidTrump() {
        do {
            _ = try DDSSolver.solveBoard(
                pbn: "N:QJ6.K652.J85.T98 873.J97.AT764.Q4 K5.T83.KQ9.A7652 AT942.AQ4.32.KJ3",
                target: -1,
                solutions: 3,
                mode: 0,
                trump: 5,
                first: 0
            )
            XCTFail("Should throw for invalid trump value 5")
        } catch let error as DDSError {
            XCTAssertEqual(error, .trumpWrong,
                           "Expected .trumpWrong, got \(error)")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Invalid PBN

    func testSolveBoard_invalidPBN() {
        do {
            _ = try DDSSolver.solveBoard(
                pbn: "INVALID_PBN_STRING",
                target: -1,
                solutions: 3,
                mode: 0,
                trump: 0,
                first: 0
            )
            XCTFail("Should throw for invalid PBN")
        } catch let error as DDSError {
            // DDS may return cardCount or pbnFault depending on how the string is parsed
            XCTAssertTrue(error == .pbnFault || error == .cardCount,
                          "Expected .pbnFault or .cardCount, got \(error)")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Duplicate Cards

    func testCalcDDTablePBN_duplicateCards() {
        // North and West both have the Ace of Spades (duplicate)
        do {
            _ = try DDSSolver.calcDDTablePBN(
                pbn: "N:AJ6.K652.J85.T98 873.J97.AT764.Q4 K5.T83.KQ9.A7652 AT942.AQ4.32.KJ3"
            )
            XCTFail("Should throw for duplicate cards")
        } catch let error as DDSError {
            XCTAssertEqual(error, .duplicateCards,
                           "Expected .duplicateCards, got \(error)")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - 51 Cards (Missing One)

    func testCalcDDTablePBN_51Cards() {
        // Remove the last card (Ace from West's clubs)
        do {
            _ = try DDSSolver.calcDDTablePBN(
                pbn: "N:QJ6.K652.J85.T98 873.J97.AT764.Q4 K5.T83.KQ9.A7652 AT942.AQ4.32.KJ"
            )
            XCTFail("Should throw for 51 cards")
        } catch let error as DDSError {
            XCTAssertEqual(error, .cardCount,
                           "Expected .cardCount, got \(error)")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Invalid Solutions Parameter

    func testSolveBoard_solutionsTooLow() {
        do {
            _ = try DDSSolver.solveBoard(
                pbn: "N:QJ6.K652.J85.T98 873.J97.AT764.Q4 K5.T83.KQ9.A7652 AT942.AQ4.32.KJ3",
                target: -1,
                solutions: 0,
                mode: 0,
                trump: 0,
                first: 0
            )
            XCTFail("Should throw for solutions = 0")
        } catch let error as DDSError {
            XCTAssertEqual(error, .solnsWrongLo,
                           "Expected .solnsWrongLo, got \(error)")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testSolveBoard_solutionsTooHigh() {
        do {
            _ = try DDSSolver.solveBoard(
                pbn: "N:QJ6.K652.J85.T98 873.J97.AT764.Q4 K5.T83.KQ9.A7652 AT942.AQ4.32.KJ3",
                target: -1,
                solutions: 4,
                mode: 0,
                trump: 0,
                first: 0
            )
            XCTFail("Should throw for solutions = 4")
        } catch let error as DDSError {
            XCTAssertEqual(error, .solnsWrongHi,
                           "Expected .solnsWrongHi, got \(error)")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Invalid Mode

    func testSolveBoard_modeWrongLo() {
        do {
            _ = try DDSSolver.solveBoard(
                pbn: "N:QJ6.K652.J85.T98 873.J97.AT764.Q4 K5.T83.KQ9.A7652 AT942.AQ4.32.KJ3",
                target: -1,
                solutions: 3,
                mode: -1,
                trump: 0,
                first: 0
            )
            XCTFail("Should throw for mode = -1")
        } catch let error as DDSError {
            XCTAssertEqual(error, .modeWrongLo,
                           "Expected .modeWrongLo, got \(error)")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Error Description

    func testErrorDescriptions() {
        XCTAssertEqual(DDSError.unknownFault.localizedDescription, "General error")
        XCTAssertEqual(DDSError.zeroCards.localizedDescription, "Zero cards")
        XCTAssertEqual(DDSError.duplicateCards.localizedDescription, "Cards duplicated")
        XCTAssertEqual(DDSError.pbnFault.localizedDescription, "PBN string error")
        XCTAssertEqual(DDSError.trumpWrong.localizedDescription, "Trump is not in 0 .. 4")
        XCTAssertEqual(DDSError.playFault.localizedDescription, "AnalysePlay input error")
        XCTAssertEqual(DDSError.tooManyBoards.localizedDescription, "Too many boards requested")
        XCTAssertEqual(DDSError.tooManyTables.localizedDescription, "Too many DD tables requested")
    }

    // MARK: - checkDDS Success

    func testCheckDDS_successDoesNotThrow() {
        XCTAssertNoThrow(try checkDDS(1), "checkDDS(1) should not throw for RETURN_NO_FAULT")
    }

    func testCheckDDS_unknownCodeThrowsUnknownFault() {
        do {
            try checkDDS(-999)
            XCTFail("Should throw for unknown error code")
        } catch let error as DDSError {
            XCTAssertEqual(error, .unknownFault)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
