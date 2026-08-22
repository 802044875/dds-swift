import Foundation
internal import DDS

// MARK: - FutureTricks

/// Swift representation of DDS `futureTricks` — the result of `SolveBoardPBN`.
///
/// Contains the number of nodes searched, the number of playable cards found,
/// and parallel arrays of suit/rank/equals/score for each card.
public struct DDSFutureTricks: Sendable {
    public let nodes: Int32
    public let cards: Int32
    public let suit: [Int32]
    public let rank: [Int32]
    public let equals: [Int32]
    public let score: [Int32]

    /// Initialises from the C `FutureTricks` struct returned by DDS.
    init(_ ft: FutureTricks) {
        self.nodes = Int32(ft.nodes)
        self.cards = Int32(ft.cards)
        self.suit = Self.tupleToArray13(ft.suit)
        self.rank = Self.tupleToArray13(ft.rank)
        self.equals = Self.tupleToArray13(ft.equals)
        self.score = Self.tupleToArray13(ft.score)
    }

    public init(
        nodes: Int32 = 0,
        cards: Int32 = 0,
        suit: [Int32] = Array(repeating: 0, count: 13),
        rank: [Int32] = Array(repeating: 0, count: 13),
        equals: [Int32] = Array(repeating: 0, count: 13),
        score: [Int32] = Array(repeating: 0, count: 13)
    ) {
        self.nodes = nodes
        self.cards = cards
        self.suit = suit
        self.rank = rank
        self.equals = equals
        self.score = score
    }

    /// Converts a C 13-element tuple of `Int` to a Swift `[Int32]` array.
    private static func tupleToArray13(_ t: (Int32, Int32, Int32, Int32, Int32, Int32, Int32, Int32, Int32, Int32, Int32, Int32, Int32)) -> [Int32] {
        [t.0, t.1, t.2, t.3, t.4, t.5, t.6, t.7, t.8, t.9, t.10, t.11, t.12]
    }
}

// MARK: - DDTableResults

/// Swift representation of DDS `ddTableResults` — a 5x4 trick table
/// (5 strains: S, H, D, C, NT x 4 hands: N, E, S, W).
public struct DDSTableResults: Sendable {
    /// `resTable[strain][hand]` — number of tricks declarer can make.
    /// Strains: 0=Spades, 1=Hearts, 2=Diamonds, 3=Clubs, 4=NT.
    /// Hands: 0=North, 1=East, 2=South, 3=West.
    public let resTable: [[Int32]]

    /// Initialises from the C `DdTableResults` struct.
    init(_ table: DdTableResults) {
        var result: [[Int32]] = []
        let t = table.res_table
        // resTable is (Int32, Int32, Int32, Int32) for each of 5 strains
        let strains = [t.0, t.1, t.2, t.3, t.4]
        for strain in strains {
            result.append([Int32(strain.0), Int32(strain.1), Int32(strain.2), Int32(strain.3)])
        }
        self.resTable = result
    }

    /// Public initialiser from a caller-supplied makeable table — enables computing par
    /// (`DDSSolver.par` / `dealerPar` / `sidesPar`) from an **externally-derived** DD table
    /// (e.g. a persisted `[DoubleDummyTricks]` / `OptimumResultTable` tag) with **no re-solve**.
    /// `resTable[strain][hand]`, strains 0=S,1=H,2=D,3=C,4=NT, hands 0=N,1=E,2=S,3=W — must be 5×4.
    public init(resTable: [[Int32]]) {
        precondition(resTable.count == 5 && resTable.allSatisfy { $0.count == 4 },
                     "DDSTableResults.resTable must be 5 strains × 4 hands")
        self.resTable = resTable
    }
}

// MARK: - ParResultsDealer

/// Swift representation of DDS `parResultsDealer` — the par result from a specific dealer's perspective.
public struct DDSParResultsDealer: Sendable {
    public let number: Int32
    public let score: Int32
    public let contracts: [String]

    /// Initialises from the C `ParResultsDealer` struct.
    init(_ par: ParResultsDealer) {
        self.number = par.number
        self.score = par.score
        var contracts: [String] = []
        let c = par.contracts
        // contracts is a 10-element tuple of (Int8, Int8, ...) tuples (each 10 chars)
        let all = [c.0, c.1, c.2, c.3, c.4, c.5, c.6, c.7, c.8, c.9]
        for i in 0..<Int(par.number) {
            let tuple = all[i]
            let chars: [CChar] = [tuple.0, tuple.1, tuple.2, tuple.3, tuple.4,
                                   tuple.5, tuple.6, tuple.7, tuple.8, tuple.9]
            if let str = chars.withUnsafeBufferPointer({ ptr in
                String(cString: ptr.baseAddress!)
            }) as String? {
                contracts.append(str)
            }
        }
        self.contracts = contracts
    }
}

// MARK: - DDSDeal

/// Swift representation of DDS `deal` — binary card representation for a board position.
///
/// Each element of `remainCards[hand][suit]` is a bitfield where bits 2–14
/// represent the cards held (bit 2 = deuce, bit 14 = ace).
public struct DDSDeal: Sendable {
    public let trump: Int32
    public let first: Int32
    public let currentTrickSuit: [Int32]
    public let currentTrickRank: [Int32]
    /// `remainCards[hand][suit]` — bitmask of cards held.
    /// Hands: 0=North, 1=East, 2=South, 3=West.
    /// Suits: 0=Spades, 1=Hearts, 2=Diamonds, 3=Clubs.
    public let remainCards: [[UInt32]]

    public init(
        trump: Int32,
        first: Int32,
        currentTrickSuit: [Int32] = [0, 0, 0],
        currentTrickRank: [Int32] = [0, 0, 0],
        remainCards: [[UInt32]]
    ) {
        self.trump = trump
        self.first = first
        self.currentTrickSuit = currentTrickSuit
        self.currentTrickRank = currentTrickRank
        self.remainCards = remainCards
    }

    /// Converts to the C `Deal` struct for passing to DDS functions.
    func toCDeal() -> Deal {
        var dl = Deal()
        dl.trump = trump
        dl.first = first
        dl.currentTrickSuit.0 = currentTrickSuit[0]
        dl.currentTrickSuit.1 = currentTrickSuit[1]
        dl.currentTrickSuit.2 = currentTrickSuit[2]
        dl.currentTrickRank.0 = currentTrickRank[0]
        dl.currentTrickRank.1 = currentTrickRank[1]
        dl.currentTrickRank.2 = currentTrickRank[2]

        withUnsafeMutablePointer(to: &dl.remainCards) { ptr in
            ptr.withMemoryRebound(to: UInt32.self, capacity: 16) { base in
                for hand in 0..<4 {
                    for suit in 0..<4 {
                        base[hand * 4 + suit] = remainCards[hand][suit]
                    }
                }
            }
        }
        return dl
    }
}

// MARK: - DDSParResults

/// Swift representation of DDS `parResults` — par scores and contracts from NS/EW perspective.
public struct DDSParResults: Sendable {
    /// Par score strings, index 0 = NS view, index 1 = EW view. E.g. "NS -110".
    public let parScore: [String]
    /// Par contract strings, index 0 = NS view, index 1 = EW view. E.g. "NS:EW 2S".
    public let parContractsString: [String]

    /// Initialises from the C `ParResults` struct.
    init(_ par: ParResults) {
        var scores: [String] = []
        var contracts: [String] = []

        let s = par.par_score
        let c = par.par_contracts_string

        // parScore is (CChar x 16, CChar x 16)
        let scoreTuples = [s.0, s.1]
        for tuple in scoreTuples {
            let chars: [CChar] = [
                tuple.0, tuple.1, tuple.2, tuple.3, tuple.4, tuple.5, tuple.6, tuple.7,
                tuple.8, tuple.9, tuple.10, tuple.11, tuple.12, tuple.13, tuple.14, tuple.15
            ]
            scores.append(chars.withUnsafeBufferPointer { String(cString: $0.baseAddress!) })
        }

        // parContractsString is (CChar x 128, CChar x 128)
        let contractTuples = [c.0, c.1]
        for tuple in contractTuples {
            withUnsafePointer(to: tuple) { ptr in
                ptr.withMemoryRebound(to: CChar.self, capacity: 128) { base in
                    contracts.append(String(cString: base))
                }
            }
        }

        self.parScore = scores
        self.parContractsString = contracts
    }
}

// MARK: - DDSParResultsMaster

/// Swift representation of DDS `contractType` — a single par contract entry.
public struct DDSContractType: Sendable {
    /// 0 = make, 1-13 = sacrifice (under-tricks).
    public let underTricks: Int32
    /// Over-tricks (0-3).
    public let overTricks: Int32
    /// Contract level (1-7).
    public let level: Int32
    /// Denomination: 0=NT, 1=Spades, 2=Hearts, 3=Diamonds, 4=Clubs.
    public let denom: Int32
    /// Seats: 0=N, 1=E, 2=S, 3=W, 4=NS, 5=EW.
    public let seats: Int32

    init(_ ct: ContractType) {
        self.underTricks = ct.under_tricks
        self.overTricks = ct.over_tricks
        self.level = ct.level
        self.denom = ct.denom
        self.seats = ct.seats
    }
}

/// Swift representation of DDS `parResultsMaster` — structured par result with contract entries.
public struct DDSParResultsMaster: Sendable {
    /// Par score (sign according to NS view).
    public let score: Int32
    /// Number of contracts giving the par score.
    public let number: Int32
    /// Par contracts.
    public let contracts: [DDSContractType]

    /// Initialises from the C `ParResultsMaster` struct.
    init(_ prm: ParResultsMaster) {
        self.score = prm.score
        self.number = prm.number
        let c = prm.contracts
        let all = [c.0, c.1, c.2, c.3, c.4, c.5, c.6, c.7, c.8, c.9]
        var result: [DDSContractType] = []
        for i in 0..<Int(prm.number) {
            result.append(DDSContractType(all[i]))
        }
        self.contracts = result
    }
}

// MARK: - DDSParTextResults

/// Swift representation of DDS `parTextResults` — short par text with equality flag.
public struct DDSParTextResults: Sendable {
    /// Short par text, index 0 = NS, index 1 = EW. E.g. "Par -110: EW 2S EW 2D+1".
    public let parText: [String]
    /// True if it does not matter who starts the bidding.
    public let equal: Bool

    /// Initialises from the C `ParTextResults` struct.
    init(_ ptr: ParTextResults) {
        let t = ptr.par_text
        let tuples = [t.0, t.1]
        var texts: [String] = []
        for tuple in tuples {
            withUnsafePointer(to: tuple) { p in
                p.withMemoryRebound(to: CChar.self, capacity: 128) { base in
                    texts.append(String(cString: base))
                }
            }
        }
        self.parText = texts
        self.equal = ptr.equal
    }
}

// MARK: - DDSPlayTrace

/// Swift representation of DDS `playTraceBin` — a sequence of played cards in binary format.
public struct DDSPlayTrace: Sendable {
    /// Number of cards in the play trace.
    public let number: Int32
    /// Suit of each played card (0=Spades, 1=Hearts, 2=Diamonds, 3=Clubs).
    public let suit: [Int32]
    /// Rank of each played card (2-14).
    public let rank: [Int32]

    public init(number: Int32, suit: [Int32], rank: [Int32]) {
        self.number = number
        self.suit = suit
        self.rank = rank
    }

    /// Converts to the C `PlayTraceBin` struct.
    func toCPlayTrace() -> PlayTraceBin {
        var pt = PlayTraceBin()
        pt.number = number
        withUnsafeMutablePointer(to: &pt.suit) { ptr in
            ptr.withMemoryRebound(to: Int32.self, capacity: 52) { base in
                for i in 0..<min(Int(number), 52) {
                    base[i] = suit[i]
                }
            }
        }
        withUnsafeMutablePointer(to: &pt.rank) { ptr in
            ptr.withMemoryRebound(to: Int32.self, capacity: 52) { base in
                for i in 0..<min(Int(number), 52) {
                    base[i] = rank[i]
                }
            }
        }
        return pt
    }
}

// MARK: - DDSPlayTracePBN

/// Swift representation of DDS `playTracePBN` — a play trace in PBN string format.
public struct DDSPlayTracePBN: Sendable {
    /// Number of cards in the play trace.
    public let number: Int32
    /// Cards as a PBN string (e.g. "CTC4CACJ...").
    public let cards: String

    public init(number: Int32, cards: String) {
        self.number = number
        self.cards = cards
    }

    /// Converts to the C `PlayTracePBN` struct.
    func toCPlayTracePBN() -> PlayTracePBN {
        var pt = PlayTracePBN()
        pt.number = number
        cards.withCString { cstr in
            withUnsafeMutablePointer(to: &pt.cards) { ptr in
                let dest = UnsafeMutableRawPointer(ptr).assumingMemoryBound(to: CChar.self)
                strcpy(dest, cstr)
            }
        }
        return pt
    }
}

// MARK: - DDSSolvedPlay

/// Swift representation of DDS `solvedPlay` — DD trick values after each card in a play sequence.
public struct DDSSolvedPlay: Sendable {
    /// Number of results (generally number of cards played + 1).
    public let number: Int32
    /// DD trick count after each card. Index 0 is before the opening lead.
    public let tricks: [Int32]

    /// Initialises from the C `SolvedPlay` struct.
    init(_ sp: SolvedPlay) {
        self.number = sp.number
        self.tricks = Self.tupleToArray53(sp.tricks)
    }

    /// Converts a C 53-element tuple of `Int32` to a Swift `[Int32]` array.
    private static func tupleToArray53(_ t: (Int32, Int32, Int32, Int32, Int32, Int32, Int32, Int32, Int32, Int32, Int32, Int32, Int32, Int32, Int32, Int32, Int32, Int32, Int32, Int32, Int32, Int32, Int32, Int32, Int32, Int32, Int32, Int32, Int32, Int32, Int32, Int32, Int32, Int32, Int32, Int32, Int32, Int32, Int32, Int32, Int32, Int32, Int32, Int32, Int32, Int32, Int32, Int32, Int32, Int32, Int32, Int32, Int32)) -> [Int32] {
        [t.0, t.1, t.2, t.3, t.4, t.5, t.6, t.7, t.8, t.9,
         t.10, t.11, t.12, t.13, t.14, t.15, t.16, t.17, t.18, t.19,
         t.20, t.21, t.22, t.23, t.24, t.25, t.26, t.27, t.28, t.29,
         t.30, t.31, t.32, t.33, t.34, t.35, t.36, t.37, t.38, t.39,
         t.40, t.41, t.42, t.43, t.44, t.45, t.46, t.47, t.48, t.49,
         t.50, t.51, t.52]
    }
}

// MARK: - DDSInfo

/// Swift representation of DDS `DDSInfo` — system and version information.
public struct DDSInfoResult: Sendable {
    public let major: Int32
    public let minor: Int32
    public let patch: Int32
    public let versionString: String
    public let system: Int32
    public let numBits: Int32
    public let compiler: Int32
    public let constructor: Int32
    public let numCores: Int32
    public let threading: Int32
    public let noOfThreads: Int32
    public let threadSizes: String
    public let systemString: String

    /// Initialises from the C `DDSInfo` struct.
    init(_ info: DDSInfo) {
        self.major = info.major
        self.minor = info.minor
        self.patch = info.patch
        self.system = info.system
        self.numBits = info.numBits
        self.compiler = info.compiler
        self.constructor = info.constructor
        self.numCores = info.numCores
        self.threading = info.threading
        self.noOfThreads = info.noOfThreads

        var v = info.version_string
        self.versionString = withUnsafePointer(to: &v) {
            $0.withMemoryRebound(to: CChar.self, capacity: 10) { String(cString: $0) }
        }

        var t = info.threadSizes
        self.threadSizes = withUnsafePointer(to: &t) {
            $0.withMemoryRebound(to: CChar.self, capacity: 128) { String(cString: $0) }
        }

        var s = info.systemString
        self.systemString = withUnsafePointer(to: &s) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1024) { String(cString: $0) }
        }
    }
}
