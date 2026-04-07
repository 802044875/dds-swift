/// Pure Swift replacements for the C++ formatting functions in `DoubleDummyLibrary.cpp`.
///
/// Produces identical output strings to the original C++ `DoTable()` and `DoDealerPar()`.
enum DDSFormatting {

    private static let suitChars: [Character] = ["S", "H", "D", "C", "N"]
    private static let handChars: [Character] = ["N", "E", "S", "W"]

    /// Formats a DD table result as a multi-line string.
    ///
    /// Output format matches the original C++ `DoTable()`:
    /// ```
    /// N  S 10
    /// N  H  8
    /// ...
    /// W NT  7
    /// ```
    static func formatTable(_ table: DDSTableResults) -> String {
        var result = ""
        // resTable[strain][hand] — Strains: 0=S, 1=H, 2=D, 3=C, 4=NT; Hands: 0=N, 1=E, 2=S, 3=W

        for hand in 0..<4 {
            for suit in 0..<4 {
                let tricks = table.resTable[suit][hand]
                let tricksStr = tricks < 10 ? " \(tricks)" : "\(tricks)"
                result += "\(handChars[hand])  \(suitChars[suit]) \(tricksStr)\n"
            }
            // NT (strain index 4)
            let ntTricks = table.resTable[4][hand]
            let ntStr = ntTricks < 10 ? " \(ntTricks)" : "\(ntTricks)"
            result += "\(handChars[hand]) NT \(ntStr)\n"
        }

        return result
    }

    /// Formats a dealer par result as a string.
    ///
    /// Output format matches the original C++ `DoDealerPar()`:
    /// ```
    /// NS 4S; 420
    /// ```
    /// or for multiple contracts:
    /// ```
    /// NS 4S, NS 4H; 420
    /// ```
    static func formatDealerPar(_ par: DDSParResultsDealer) -> String {
        var result = ""

        for i in 0..<Int(par.number) {
            let contract = par.contracts[i]

            // DDS contract format: "seats-level strain[modifier]"
            // e.g. "N-4S" or "NS-3NT*"
            // DoDealerPar regex: ([^+-]+)-([^+-]+)([+-]*)(.*) → "$2 $1$3$4"
            // This swaps the parts around the hyphen
            let formatted = reformatContract(contract)
            result += formatted

            if i < Int(par.number) - 1 {
                result += ", "
            }
        }

        result += "; \(par.score)"

        // Replace all '*' with 'X' (redouble notation)
        result = result.replacingOccurrences(of: "*", with: "X")

        return result
    }

    /// Reformats a DDS contract string from "seats-bid[modifier]" to "bid seats[modifier]".
    ///
    /// Matches the regex replacement in the original C++:
    /// `regex_replace(contract, re("([^+-]+)-([^+-]+)([+-]*)(.*)"), "$2 $1$3$4")`
    private static func reformatContract(_ contract: String) -> String {
        // Find the hyphen that separates seats from bid
        guard let hyphenIndex = contract.firstIndex(of: "-") else {
            return contract
        }

        let seats = String(contract[contract.startIndex..<hyphenIndex])
        let afterHyphen = String(contract[contract.index(after: hyphenIndex)...])

        // Split afterHyphen into bid part and modifier part (+/-)
        var bid = ""
        var modifier = ""
        var foundModifier = false

        for char in afterHyphen {
            if !foundModifier && (char == "+" || char == "-") {
                foundModifier = true
            }
            if foundModifier {
                modifier.append(char)
            } else {
                bid.append(char)
            }
        }

        return "\(bid) \(seats)\(modifier)"
    }

}
