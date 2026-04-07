import Foundation

/// Swift error type mapping DDS C error codes to typed cases.
///
/// Each case corresponds to a `RETURN_*` constant from `dll.h`.
/// The raw values match the DDS error codes exactly, so DDS return
/// values can be converted directly: `DDSError(rawValue: result)`.
public enum DDSError: Int32, Error, Sendable {
    case unknownFault    = -1
    case zeroCards       = -2
    case targetTooHigh   = -3
    case duplicateCards  = -4
    case targetWrongLo   = -5
    case targetWrongHi   = -7
    case solnsWrongLo    = -8
    case solnsWrongHi    = -9
    case tooManyCards    = -10
    case suitOrRank      = -12
    case playedCard      = -13
    case cardCount       = -14
    case threadIndex     = -15
    case modeWrongLo     = -16
    case modeWrongHi     = -17
    case trumpWrong      = -18
    case firstWrong      = -19
    case playFault       = -98
    case pbnFault        = -99
    case tooManyBoards   = -101
    case threadCreate    = -102
    case threadWait      = -103
    case threadMissing   = -104
    case noSuit          = -201
    case tooManyTables   = -202
    case chunkSize       = -301
}

extension DDSError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .unknownFault:    return "General error"
        case .zeroCards:       return "Zero cards"
        case .targetTooHigh:   return "Target exceeds number of tricks"
        case .duplicateCards:  return "Cards duplicated"
        case .targetWrongLo:   return "Target is less than -1"
        case .targetWrongHi:   return "Target is higher than 13"
        case .solnsWrongLo:    return "Solutions parameter is less than 1"
        case .solnsWrongHi:    return "Solutions parameter is higher than 3"
        case .tooManyCards:    return "Too many cards"
        case .suitOrRank:      return "currentTrickSuit or currentTrickRank has wrong data"
        case .playedCard:      return "Played card also remains in a hand"
        case .cardCount:       return "Wrong number of remaining cards in a hand"
        case .threadIndex:     return "Thread index is not 0 .. maximum"
        case .modeWrongLo:     return "Mode parameter is less than 0"
        case .modeWrongHi:     return "Mode parameter is higher than 2"
        case .trumpWrong:      return "Trump is not in 0 .. 4"
        case .firstWrong:      return "First is not in 0 .. 2"
        case .playFault:       return "AnalysePlay input error"
        case .pbnFault:        return "PBN string error"
        case .tooManyBoards:   return "Too many boards requested"
        case .threadCreate:    return "Could not create threads"
        case .threadWait:      return "Something failed waiting for thread to end"
        case .threadMissing:   return "Multi-threading system not present"
        case .noSuit:          return "Denomination filter vector has no entries"
        case .tooManyTables:   return "Too many DD tables requested"
        case .chunkSize:       return "Chunk size is less than 1"
        }
    }
}

/// Checks a DDS return code and throws `DDSError` if it indicates failure.
///
/// DDS uses `RETURN_NO_FAULT` (1) for success; all other values are errors.
func checkDDS(_ result: Int32) throws {
    guard result == 1 /* RETURN_NO_FAULT */ else {
        if let error = DDSError(rawValue: result) {
            throw error
        }
        throw DDSError.unknownFault
    }
}
