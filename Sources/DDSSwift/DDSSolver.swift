import Foundation
internal import DDS

/// Pure Swift interface to the DDS (Double Dummy Solver) C library.
///
/// Replaces the ObjC++ `DoubleDummyWrapper` / `DoubleDummy` bridge layer.
/// All methods call DDS C functions directly via the `DDS` SPM module.
public enum DDSSolver {

    // MARK: - System Info

    /// Returns DDS system information (version, threading, memory, cores).
    public static func getInfo() -> DDSInfoResult {
        SetMaxThreads(0)
        var info = DDSInfo()
        GetDDSInfo(&info)
        return DDSInfoResult(info)
    }

    // MARK: - Batch Table Calculation

    /// Result for a single board from a batch table calculation.
    public struct BoardResult: Sendable {
        /// Par score string, e.g. "NS 4S; 420"
        public let optimumScore: String
        /// Trick table string, e.g. "N  S 10\nN  H  8\n..."
        public let optimumResultTable: String
    }

    /// Calculates DD tables and par results for a batch of boards.
    ///
    /// This is the primary batch operation — replaces `DoubleDummyWrapper.ddsBoards(_:)`.
    ///
    /// - Parameters:
    ///   - hands: PBN deal strings (e.g. "N:QJ6.K652.J85.T98 ...").
    ///   - vulns: Vulnerability per board (0=None, 1=Both, 2=NS, 3=EW).
    ///   - dealers: Dealer per board (0=North, 1=East, 2=South, 3=West).
    /// - Returns: Array of `BoardResult` with par score and trick table for each board.
    /// - Throws: `DDSError` if DDS returns an error code.
    public static func calcTables(
        hands: [String],
        vulns: [Int32],
        dealers: [Int32]
    ) throws -> [BoardResult] {
        SetMaxThreads(0)

        var dealsPBN = ddTableDealsPBN()
        var tableRes = ddTablesRes()
        var pres = allParResults()

        let mode: Int32 = -1  // no par calculation via CalcAllTablesPBN
        var trumpFilter: (Int32, Int32, Int32, Int32, Int32) = (0, 0, 0, 0, 0)  // all strains

        dealsPBN.noOfTables = Int32(hands.count)

        for (i, hand) in hands.enumerated() {
            hand.withCString { cstr in
                withUnsafeMutablePointer(to: &dealsPBN.deals) { ptr in
                    let base = UnsafeMutableRawPointer(ptr)
                        .assumingMemoryBound(to: ddTableDealPBN.self)
                    let deal = base.advanced(by: i)
                    withUnsafeMutablePointer(to: &deal.pointee.cards) { cardsPtr in
                        let dest = UnsafeMutableRawPointer(cardsPtr).assumingMemoryBound(to: CChar.self)
                        strcpy(dest, cstr)
                    }
                }
            }
        }

        let res = withUnsafeMutablePointer(to: &trumpFilter) { filterPtr in
            filterPtr.withMemoryRebound(to: Int32.self, capacity: 5) { filter in
                CalcAllTablesPBN(&dealsPBN, mode, filter, &tableRes, &pres)
            }
        }

        try checkDDS(res)

        var results: [BoardResult] = []

        for i in 0..<hands.count {
            // Get the table result for this hand
            let tableResult: ddTableResults = withUnsafePointer(to: tableRes.results) { ptr in
                let base = UnsafeRawPointer(ptr).assumingMemoryBound(to: ddTableResults.self)
                return base[i]
            }

            // Calculate dealer par
            var parResDealer = parResultsDealer()
            var mutableTable = tableResult
            let parRes = DealerPar(&mutableTable, &parResDealer, dealers[i], vulns[i])
            try checkDDS(parRes)

            let par = DDSFormatting.formatDealerPar(DDSParResultsDealer(parResDealer))
            let table = DDSFormatting.formatTable(DDSTableResults(tableResult))

            results.append(BoardResult(optimumScore: par, optimumResultTable: table))
        }

        FreeMemory()

        return results
    }

    // MARK: - Single Board Solve (PBN)

    /// Solves a single board position using `SolveBoardPBN`.
    ///
    /// Replaces `DoubleDummyWrapper.solveBoardPBNWithHand(...)`.
    ///
    /// - Parameters:
    ///   - pbn: Remaining cards in PBN format.
    ///   - target: Target number of tricks (-1 for all solutions).
    ///   - solutions: 1 = one optimal, 2 = all optimal, 3 = all legal.
    ///   - mode: 0 = automatic, 1 = always search, 2 = always search + reuse TT.
    ///   - trump: Trump strain (0=Spades, 1=Hearts, 2=Diamonds, 3=Clubs, 4=NT).
    ///   - first: Player on lead (0=North, 1=East, 2=South, 3=West).
    ///   - currentTrickSuit: Suits of cards already played in current trick (up to 3).
    ///   - currentTrickRank: Ranks of cards already played in current trick (up to 3).
    ///   - threadIndex: Thread index for concurrent calls (0 for single-threaded).
    /// - Returns: `DDSFutureTricks` with all playable cards and their trick counts.
    /// - Throws: `DDSError` if DDS returns an error code.
    public static func solveBoard(
        pbn: String,
        target: Int32,
        solutions: Int32,
        mode: Int32,
        trump: Int32,
        first: Int32,
        currentTrickSuit: [Int32] = [0, 0, 0],
        currentTrickRank: [Int32] = [0, 0, 0],
        threadIndex: Int32 = 0
    ) throws -> DDSFutureTricks {
        SetMaxThreads(0)

        var dlPBN = dealPBN()
        dlPBN.trump = trump
        dlPBN.first = first
        dlPBN.currentTrickSuit.0 = currentTrickSuit[0]
        dlPBN.currentTrickSuit.1 = currentTrickSuit[1]
        dlPBN.currentTrickSuit.2 = currentTrickSuit[2]
        dlPBN.currentTrickRank.0 = currentTrickRank[0]
        dlPBN.currentTrickRank.1 = currentTrickRank[1]
        dlPBN.currentTrickRank.2 = currentTrickRank[2]

        pbn.withCString { cstr in
            withUnsafeMutablePointer(to: &dlPBN.remainCards) { ptr in
                let dest = UnsafeMutableRawPointer(ptr).assumingMemoryBound(to: CChar.self)
                strcpy(dest, cstr)
            }
        }

        var futp = futureTricks()
        let res = SolveBoardPBN(dlPBN, target, solutions, mode, &futp, threadIndex)
        try checkDDS(res)

        return DDSFutureTricks(futp)
    }

    // MARK: - Single Board Solve (Binary)

    /// Solves a single board position using `SolveBoard` with binary card representation.
    ///
    /// - Parameters:
    ///   - deal: Binary deal with bitmask card holdings.
    ///   - target: Target number of tricks (-1 for all solutions).
    ///   - solutions: 1 = one optimal, 2 = all optimal, 3 = all legal.
    ///   - mode: 0 = automatic, 1 = always search, 2 = always search + reuse TT.
    ///   - threadIndex: Thread index for concurrent calls (0 for single-threaded).
    /// - Returns: `DDSFutureTricks` with all playable cards and their trick counts.
    /// - Throws: `DDSError` if DDS returns an error code.
    public static func solveBoard(
        deal: DDSDeal,
        target: Int32,
        solutions: Int32,
        mode: Int32,
        threadIndex: Int32 = 0
    ) throws -> DDSFutureTricks {
        SetMaxThreads(0)

        let dl = deal.toCDeal()
        var futp = futureTricks()
        let res = SolveBoard(dl, target, solutions, mode, &futp, threadIndex)
        try checkDDS(res)

        return DDSFutureTricks(futp)
    }

    // MARK: - Batch Solve

    /// Solves multiple board positions in parallel using `SolveAllBoards` (PBN).
    ///
    /// - Parameter boards: Array of tuples containing (pbn, trump, first, target, solutions, mode).
    /// - Returns: Array of `DDSFutureTricks` results, one per board.
    /// - Throws: `DDSError` if DDS returns an error code.
    public static func solveAllBoards(
        boards: [(pbn: String, trump: Int32, first: Int32, target: Int32, solutions: Int32, mode: Int32)]
    ) throws -> [DDSFutureTricks] {
        SetMaxThreads(0)

        var bop = boardsPBN()
        bop.noOfBoards = Int32(boards.count)

        withUnsafeMutablePointer(to: &bop.deals) { dealsPtr in
            let base = UnsafeMutableRawPointer(dealsPtr).assumingMemoryBound(to: dealPBN.self)
            for (i, board) in boards.enumerated() {
                base[i].trump = board.trump
                base[i].first = board.first
                base[i].currentTrickSuit = (0, 0, 0)
                base[i].currentTrickRank = (0, 0, 0)
                board.pbn.withCString { cstr in
                    withUnsafeMutablePointer(to: &base[i].remainCards) { ptr in
                        let dest = UnsafeMutableRawPointer(ptr).assumingMemoryBound(to: CChar.self)
                        strcpy(dest, cstr)
                    }
                }
            }
        }

        withUnsafeMutablePointer(to: &bop.target) { ptr in
            ptr.withMemoryRebound(to: Int32.self, capacity: 200) { base in
                for (i, board) in boards.enumerated() { base[i] = board.target }
            }
        }
        withUnsafeMutablePointer(to: &bop.solutions) { ptr in
            ptr.withMemoryRebound(to: Int32.self, capacity: 200) { base in
                for (i, board) in boards.enumerated() { base[i] = board.solutions }
            }
        }
        withUnsafeMutablePointer(to: &bop.mode) { ptr in
            ptr.withMemoryRebound(to: Int32.self, capacity: 200) { base in
                for (i, board) in boards.enumerated() { base[i] = board.mode }
            }
        }

        var solved = solvedBoards()
        let res = SolveAllBoards(&bop, &solved)
        try checkDDS(res)

        var results: [DDSFutureTricks] = []
        withUnsafePointer(to: solved.solvedBoard) { ptr in
            let base = UnsafeRawPointer(ptr).assumingMemoryBound(to: futureTricks.self)
            for i in 0..<boards.count {
                results.append(DDSFutureTricks(base[i]))
            }
        }

        FreeMemory()
        return results
    }

    // MARK: - DD Table Calculation

    /// Calculates the DD table for a single deal using binary card representation.
    ///
    /// - Parameter deal: Binary deal with bitmask card holdings (4 hands x 4 suits).
    /// - Returns: `DDSTableResults` with the 5x4 trick matrix.
    /// - Throws: `DDSError` if DDS returns an error code.
    public static func calcDDTable(deal: [[UInt32]]) throws -> DDSTableResults {
        SetMaxThreads(0)

        var tableDeal = ddTableDeal()
        withUnsafeMutablePointer(to: &tableDeal.cards) { ptr in
            ptr.withMemoryRebound(to: UInt32.self, capacity: 16) { base in
                for hand in 0..<4 {
                    for suit in 0..<4 {
                        base[hand * 4 + suit] = deal[hand][suit]
                    }
                }
            }
        }

        var tableResult = ddTableResults()
        let res = CalcDDtable(tableDeal, &tableResult)
        try checkDDS(res)

        return DDSTableResults(tableResult)
    }

    /// Calculates the DD table for a single deal using PBN format.
    ///
    /// - Parameter pbn: Deal string in PBN format (e.g. "N:QJ6.K652.J85.T98 ...").
    /// - Returns: `DDSTableResults` with the 5x4 trick matrix.
    /// - Throws: `DDSError` if DDS returns an error code.
    public static func calcDDTablePBN(pbn: String) throws -> DDSTableResults {
        SetMaxThreads(0)

        var tableDealPBN = ddTableDealPBN()
        pbn.withCString { cstr in
            withUnsafeMutablePointer(to: &tableDealPBN.cards) { ptr in
                let dest = UnsafeMutableRawPointer(ptr).assumingMemoryBound(to: CChar.self)
                strcpy(dest, cstr)
            }
        }

        var tableResult = ddTableResults()
        let res = CalcDDtablePBN(tableDealPBN, &tableResult)
        try checkDDS(res)

        return DDSTableResults(tableResult)
    }

    // MARK: - Par Calculation

    /// Calculates par score and contracts from a DD table.
    ///
    /// - Parameters:
    ///   - table: DD table result from `calcDDTable` or `calcDDTablePBN`.
    ///   - vulnerable: Vulnerability (0=None, 1=Both, 2=NS, 3=EW).
    /// - Returns: `DDSParResults` with NS/EW par scores and contract strings.
    /// - Throws: `DDSError` if DDS returns an error code.
    public static func par(table: DDSTableResults, vulnerable: Int32) throws -> DDSParResults {
        var cTable = Self.toCTableResults(table)
        var parRes = parResults()
        let res = Par(&cTable, &parRes, vulnerable)
        try checkDDS(res)
        return DDSParResults(parRes)
    }

    /// Calculates par from a specific dealer's perspective.
    ///
    /// - Parameters:
    ///   - table: DD table result.
    ///   - dealer: Dealer (0=North, 1=East, 2=South, 3=West).
    ///   - vulnerable: Vulnerability (0=None, 1=Both, 2=NS, 3=EW).
    /// - Returns: `DDSParResultsDealer` with par score and contracts.
    /// - Throws: `DDSError` if DDS returns an error code.
    public static func dealerPar(
        table: DDSTableResults,
        dealer: Int32,
        vulnerable: Int32
    ) throws -> DDSParResultsDealer {
        var cTable = Self.toCTableResults(table)
        var parRes = parResultsDealer()
        let res = DealerPar(&cTable, &parRes, dealer, vulnerable)
        try checkDDS(res)
        return DDSParResultsDealer(parRes)
    }

    /// Calculates par for both sides.
    ///
    /// - Parameters:
    ///   - table: DD table result.
    ///   - vulnerable: Vulnerability (0=None, 1=Both, 2=NS, 3=EW).
    /// - Returns: Tuple of `DDSParResultsDealer` for (NS, EW).
    /// - Throws: `DDSError` if DDS returns an error code.
    public static func sidesPar(
        table: DDSTableResults,
        vulnerable: Int32
    ) throws -> (DDSParResultsDealer, DDSParResultsDealer) {
        var cTable = Self.toCTableResults(table)
        var sidesRes: (parResultsDealer, parResultsDealer) = (parResultsDealer(), parResultsDealer())
        let res = withUnsafeMutablePointer(to: &sidesRes) { ptr in
            ptr.withMemoryRebound(to: parResultsDealer.self, capacity: 2) { base in
                SidesPar(&cTable, base, vulnerable)
            }
        }
        try checkDDS(res)
        return (DDSParResultsDealer(sidesRes.0), DDSParResultsDealer(sidesRes.1))
    }

    /// Calculates structured par from a specific dealer's perspective.
    ///
    /// - Parameters:
    ///   - table: DD table result.
    ///   - dealer: Dealer (0=North, 1=East, 2=South, 3=West).
    ///   - vulnerable: Vulnerability (0=None, 1=Both, 2=NS, 3=EW).
    /// - Returns: `DDSParResultsMaster` with structured contract entries.
    /// - Throws: `DDSError` if DDS returns an error code.
    public static func dealerParBin(
        table: DDSTableResults,
        dealer: Int32,
        vulnerable: Int32
    ) throws -> DDSParResultsMaster {
        var cTable = Self.toCTableResults(table)
        var parRes = parResultsMaster()
        let res = DealerParBin(&cTable, &parRes, dealer, vulnerable)
        try checkDDS(res)
        return DDSParResultsMaster(parRes)
    }

    /// Calculates structured par for both sides.
    ///
    /// - Parameters:
    ///   - table: DD table result.
    ///   - vulnerable: Vulnerability (0=None, 1=Both, 2=NS, 3=EW).
    /// - Returns: Tuple of `DDSParResultsMaster` for (NS, EW).
    /// - Throws: `DDSError` if DDS returns an error code.
    public static func sidesParBin(
        table: DDSTableResults,
        vulnerable: Int32
    ) throws -> (DDSParResultsMaster, DDSParResultsMaster) {
        var cTable = Self.toCTableResults(table)
        var sidesRes: (parResultsMaster, parResultsMaster) = (parResultsMaster(), parResultsMaster())
        let res = withUnsafeMutablePointer(to: &sidesRes) { ptr in
            ptr.withMemoryRebound(to: parResultsMaster.self, capacity: 2) { base in
                SidesParBin(&cTable, base, vulnerable)
            }
        }
        try checkDDS(res)
        return (DDSParResultsMaster(sidesRes.0), DDSParResultsMaster(sidesRes.1))
    }

    /// Converts a structured par result to dealer text format.
    ///
    /// - Parameter par: Structured par result from `dealerParBin`.
    /// - Returns: Formatted dealer text string.
    /// - Throws: `DDSError` if DDS returns an error code.
    public static func convertToDealerTextFormat(par: DDSParResultsMaster) throws -> String {
        var cPar = Self.toCParResultsMaster(par)
        var buffer = [CChar](repeating: 0, count: 768)
        let res = ConvertToDealerTextFormat(&cPar, &buffer)
        try checkDDS(res)
        return String(cString: buffer)
    }

    /// Converts structured par results for both sides to text format.
    ///
    /// - Parameter sides: Tuple of `DDSParResultsMaster` for (NS, EW) from `sidesParBin`.
    /// - Returns: `DDSParTextResults` with short par text and equality flag.
    /// - Throws: `DDSError` if DDS returns an error code.
    public static func convertToSidesTextFormat(
        sides: (DDSParResultsMaster, DDSParResultsMaster)
    ) throws -> DDSParTextResults {
        var cSides: (parResultsMaster, parResultsMaster) = (
            Self.toCParResultsMaster(sides.0),
            Self.toCParResultsMaster(sides.1)
        )
        var textRes = parTextResults()
        let res = withUnsafeMutablePointer(to: &cSides) { ptr in
            ptr.withMemoryRebound(to: parResultsMaster.self, capacity: 2) { base in
                ConvertToSidesTextFormat(base, &textRes)
            }
        }
        try checkDDS(res)
        return DDSParTextResults(textRes)
    }

    // MARK: - Play Analysis

    /// Analyses a play sequence for a single deal using binary format.
    ///
    /// - Parameters:
    ///   - deal: Binary deal (trump, first, cards).
    ///   - play: Binary play trace (suits and ranks of played cards).
    ///   - threadIndex: Thread index (0 for single-threaded).
    /// - Returns: `DDSSolvedPlay` with DD trick count after each card.
    /// - Throws: `DDSError` if DDS returns an error code.
    public static func analysePlay(
        deal: DDSDeal,
        play: DDSPlayTrace,
        threadIndex: Int32 = 0
    ) throws -> DDSSolvedPlay {
        SetMaxThreads(0)

        let dl = deal.toCDeal()
        let pt = play.toCPlayTrace()
        var solved = solvedPlay()
        let res = AnalysePlayBin(dl, pt, &solved, threadIndex)
        try checkDDS(res)
        return DDSSolvedPlay(solved)
    }

    /// Analyses a play sequence for a single deal using PBN format.
    ///
    /// - Parameters:
    ///   - deal: PBN deal (trump, first, cards as PBN string).
    ///   - play: PBN play trace (cards as string like "CTC4CACJ...").
    ///   - threadIndex: Thread index (0 for single-threaded).
    /// - Returns: `DDSSolvedPlay` with DD trick count after each card.
    /// - Throws: `DDSError` if DDS returns an error code.
    public static func analysePlayPBN(
        deal: (pbn: String, trump: Int32, first: Int32),
        play: DDSPlayTracePBN,
        threadIndex: Int32 = 0
    ) throws -> DDSSolvedPlay {
        SetMaxThreads(0)

        var dlPBN = dealPBN()
        dlPBN.trump = deal.trump
        dlPBN.first = deal.first
        dlPBN.currentTrickSuit = (0, 0, 0)
        dlPBN.currentTrickRank = (0, 0, 0)
        deal.pbn.withCString { cstr in
            withUnsafeMutablePointer(to: &dlPBN.remainCards) { ptr in
                let dest = UnsafeMutableRawPointer(ptr).assumingMemoryBound(to: CChar.self)
                strcpy(dest, cstr)
            }
        }

        let pt = play.toCPlayTracePBN()
        var solved = solvedPlay()
        let res = AnalysePlayPBN(dlPBN, pt, &solved, threadIndex)
        try checkDDS(res)
        return DDSSolvedPlay(solved)
    }

    /// Analyses play sequences for multiple deals in parallel using binary format.
    ///
    /// - Parameters:
    ///   - boards: Array of binary deals (trump, first, target, solutions, mode, cards).
    ///   - plays: Array of binary play traces.
    ///   - chunkSize: Chunk size for parallel processing (use 1 for maximum parallelism).
    /// - Returns: Array of `DDSSolvedPlay` results.
    /// - Throws: `DDSError` if DDS returns an error code.
    public static func analyseAllPlays(
        boards: [DDSDeal],
        plays: [DDSPlayTrace],
        chunkSize: Int32 = 1
    ) throws -> [DDSSolvedPlay] {
        SetMaxThreads(0)

        var bop = DDS.boards()
        bop.noOfBoards = Int32(boards.count)

        withUnsafeMutablePointer(to: &bop.deals) { ptr in
            let base = UnsafeMutableRawPointer(ptr).assumingMemoryBound(to: deal.self)
            for (i, board) in boards.enumerated() {
                base[i] = board.toCDeal()
            }
        }
        // target, solutions, mode default to -1, 3, 0 for play analysis
        withUnsafeMutablePointer(to: &bop.target) { ptr in
            ptr.withMemoryRebound(to: Int32.self, capacity: 200) { base in
                for i in 0..<boards.count { base[i] = -1 }
            }
        }
        withUnsafeMutablePointer(to: &bop.solutions) { ptr in
            ptr.withMemoryRebound(to: Int32.self, capacity: 200) { base in
                for i in 0..<boards.count { base[i] = 3 }
            }
        }
        withUnsafeMutablePointer(to: &bop.mode) { ptr in
            ptr.withMemoryRebound(to: Int32.self, capacity: 200) { base in
                for i in 0..<boards.count { base[i] = 0 }
            }
        }

        var plp = playTracesBin()
        plp.noOfBoards = Int32(plays.count)
        withUnsafeMutablePointer(to: &plp.plays) { ptr in
            let base = UnsafeMutableRawPointer(ptr).assumingMemoryBound(to: playTraceBin.self)
            for (i, play) in plays.enumerated() {
                base[i] = play.toCPlayTrace()
            }
        }

        var solvedp = solvedPlays()
        let res = AnalyseAllPlaysBin(&bop, &plp, &solvedp, chunkSize)
        try checkDDS(res)

        var results: [DDSSolvedPlay] = []
        withUnsafePointer(to: solvedp.solved) { ptr in
            let base = UnsafeRawPointer(ptr).assumingMemoryBound(to: solvedPlay.self)
            for i in 0..<boards.count {
                results.append(DDSSolvedPlay(base[i]))
            }
        }

        FreeMemory()
        return results
    }

    /// Analyses play sequences for multiple deals in parallel using PBN format.
    ///
    /// - Parameters:
    ///   - boards: Array of PBN deals (pbn, trump, first).
    ///   - plays: Array of PBN play traces.
    ///   - chunkSize: Chunk size for parallel processing (use 1 for maximum parallelism).
    /// - Returns: Array of `DDSSolvedPlay` results.
    /// - Throws: `DDSError` if DDS returns an error code.
    public static func analyseAllPlaysPBN(
        boards: [(pbn: String, trump: Int32, first: Int32)],
        plays: [DDSPlayTracePBN],
        chunkSize: Int32 = 1
    ) throws -> [DDSSolvedPlay] {
        SetMaxThreads(0)

        var bop = boardsPBN()
        bop.noOfBoards = Int32(boards.count)

        withUnsafeMutablePointer(to: &bop.deals) { dealsPtr in
            let base = UnsafeMutableRawPointer(dealsPtr).assumingMemoryBound(to: dealPBN.self)
            for (i, board) in boards.enumerated() {
                base[i].trump = board.trump
                base[i].first = board.first
                base[i].currentTrickSuit = (0, 0, 0)
                base[i].currentTrickRank = (0, 0, 0)
                board.pbn.withCString { cstr in
                    withUnsafeMutablePointer(to: &base[i].remainCards) { ptr in
                        let dest = UnsafeMutableRawPointer(ptr).assumingMemoryBound(to: CChar.self)
                        strcpy(dest, cstr)
                    }
                }
            }
        }
        withUnsafeMutablePointer(to: &bop.target) { ptr in
            ptr.withMemoryRebound(to: Int32.self, capacity: 200) { base in
                for i in 0..<boards.count { base[i] = -1 }
            }
        }
        withUnsafeMutablePointer(to: &bop.solutions) { ptr in
            ptr.withMemoryRebound(to: Int32.self, capacity: 200) { base in
                for i in 0..<boards.count { base[i] = 3 }
            }
        }
        withUnsafeMutablePointer(to: &bop.mode) { ptr in
            ptr.withMemoryRebound(to: Int32.self, capacity: 200) { base in
                for i in 0..<boards.count { base[i] = 0 }
            }
        }

        var plp = playTracesPBN()
        plp.noOfBoards = Int32(plays.count)
        withUnsafeMutablePointer(to: &plp.plays) { ptr in
            let base = UnsafeMutableRawPointer(ptr).assumingMemoryBound(to: playTracePBN.self)
            for (i, play) in plays.enumerated() {
                base[i] = play.toCPlayTracePBN()
            }
        }

        var solvedp = solvedPlays()
        let res = AnalyseAllPlaysPBN(&bop, &plp, &solvedp, chunkSize)
        try checkDDS(res)

        var results: [DDSSolvedPlay] = []
        withUnsafePointer(to: solvedp.solved) { ptr in
            let base = UnsafeRawPointer(ptr).assumingMemoryBound(to: solvedPlay.self)
            for i in 0..<boards.count {
                results.append(DDSSolvedPlay(base[i]))
            }
        }

        FreeMemory()
        return results
    }

    // MARK: - Internal Helpers

    /// Converts a Swift `DDSTableResults` back to the C `ddTableResults` struct.
    private static func toCTableResults(_ table: DDSTableResults) -> ddTableResults {
        var cTable = ddTableResults()
        withUnsafeMutablePointer(to: &cTable.resTable) { ptr in
            ptr.withMemoryRebound(to: Int32.self, capacity: 20) { base in
                for strain in 0..<5 {
                    for hand in 0..<4 {
                        base[strain * 4 + hand] = table.resTable[strain][hand]
                    }
                }
            }
        }
        return cTable
    }

    /// Converts a Swift `DDSParResultsMaster` back to the C `parResultsMaster` struct.
    private static func toCParResultsMaster(_ par: DDSParResultsMaster) -> parResultsMaster {
        var cPar = parResultsMaster()
        cPar.score = par.score
        cPar.number = par.number
        withUnsafeMutablePointer(to: &cPar.contracts) { ptr in
            let base = UnsafeMutableRawPointer(ptr).assumingMemoryBound(to: contractType.self)
            for (i, contract) in par.contracts.enumerated() {
                base[i].underTricks = contract.underTricks
                base[i].overTricks = contract.overTricks
                base[i].level = contract.level
                base[i].denom = contract.denom
                base[i].seats = contract.seats
            }
        }
        return cPar
    }
}
