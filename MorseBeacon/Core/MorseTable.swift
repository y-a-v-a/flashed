/// The ITU-R M.1677-1 International Morse Code table.
///
/// This enum namespaces the canonical symbol mapping. It is the single source
/// of truth for "which characters can this app transmit" — `ValidatedMessage`
/// (R2) is built on top of `supports(_:)`, and the encoder reads `symbols(for:)`.
///
/// Lookups are case-insensitive: callers may pass upper- or lower-case ASCII
/// letters; space and punctuation are matched as-is.
public enum MorseTable {

    /// Returns the dit/dah sequence for a character, or `nil` if unsupported.
    ///
    /// Space is *not* encoded as symbols here — it is a word separator handled
    /// by the encoder as a `wordGap` element. `symbols(for: " ")` returns `nil`
    /// by design; callers that want to know "is this a valid input character"
    /// should use `supports(_:)` instead.
    public static func symbols(for character: Character) -> [MorseSymbol]? {
        let key = normalized(character)
        return letters[key]
    }

    /// Whether a character is part of the app's accepted input set (PRD FR-1).
    ///
    /// The accepted set is: A–Z (case-insensitive), 0–9, space, and the
    /// punctuation listed in FR-1. Space is accepted here even though it has
    /// no symbol sequence, because it is a valid *message* character.
    public static func supports(_ character: Character) -> Bool {
        if character == " " { return true }
        return letters[normalized(character)] != nil
    }

    // MARK: - Internal

    private static func normalized(_ character: Character) -> Character {
        // ASCII upper-casing only. Non-ASCII characters are left as-is and
        // will miss the table lookup, which is the correct behavior.
        let s = String(character)
        if let scalar = s.unicodeScalars.first,
           scalar.isASCII,
           let upper = s.uppercased().first {
            return upper
        }
        return character
    }

    /// ITU-R M.1677-1 mapping. Keys are canonical (upper-case for letters).
    private static let letters: [Character: [MorseSymbol]] = [
        // Letters
        "A": [.dit, .dah],
        "B": [.dah, .dit, .dit, .dit],
        "C": [.dah, .dit, .dah, .dit],
        "D": [.dah, .dit, .dit],
        "E": [.dit],
        "F": [.dit, .dit, .dah, .dit],
        "G": [.dah, .dah, .dit],
        "H": [.dit, .dit, .dit, .dit],
        "I": [.dit, .dit],
        "J": [.dit, .dah, .dah, .dah],
        "K": [.dah, .dit, .dah],
        "L": [.dit, .dah, .dit, .dit],
        "M": [.dah, .dah],
        "N": [.dah, .dit],
        "O": [.dah, .dah, .dah],
        "P": [.dit, .dah, .dah, .dit],
        "Q": [.dah, .dah, .dit, .dah],
        "R": [.dit, .dah, .dit],
        "S": [.dit, .dit, .dit],
        "T": [.dah],
        "U": [.dit, .dit, .dah],
        "V": [.dit, .dit, .dit, .dah],
        "W": [.dit, .dah, .dah],
        "X": [.dah, .dit, .dit, .dah],
        "Y": [.dah, .dit, .dah, .dah],
        "Z": [.dah, .dah, .dit, .dit],

        // Digits
        "0": [.dah, .dah, .dah, .dah, .dah],
        "1": [.dit, .dah, .dah, .dah, .dah],
        "2": [.dit, .dit, .dah, .dah, .dah],
        "3": [.dit, .dit, .dit, .dah, .dah],
        "4": [.dit, .dit, .dit, .dit, .dah],
        "5": [.dit, .dit, .dit, .dit, .dit],
        "6": [.dah, .dit, .dit, .dit, .dit],
        "7": [.dah, .dah, .dit, .dit, .dit],
        "8": [.dah, .dah, .dah, .dit, .dit],
        "9": [.dah, .dah, .dah, .dah, .dit],

        // Punctuation (FR-1 set)
        ".": [.dit, .dah, .dit, .dah, .dit, .dah],
        ",": [.dah, .dah, .dit, .dit, .dah, .dah],
        "?": [.dit, .dit, .dah, .dah, .dit, .dit],
        "'": [.dit, .dah, .dah, .dah, .dah, .dit],
        "!": [.dah, .dit, .dah, .dit, .dah, .dah],
        "/": [.dah, .dit, .dit, .dah, .dit],
        "(": [.dah, .dit, .dah, .dah, .dit],
        ")": [.dah, .dit, .dah, .dah, .dit, .dah],
        "&": [.dit, .dah, .dit, .dit, .dit],
        ":": [.dah, .dah, .dah, .dit, .dit, .dit],
        ";": [.dah, .dit, .dah, .dit, .dah, .dit],
        "=": [.dah, .dit, .dit, .dit, .dah],
        "+": [.dit, .dah, .dit, .dah, .dit],
        "-": [.dah, .dit, .dit, .dit, .dit, .dah],
        "_": [.dit, .dit, .dah, .dah, .dit, .dah],
        "\"": [.dit, .dah, .dit, .dit, .dah, .dit],
        "$": [.dit, .dit, .dit, .dah, .dit, .dit, .dah],
        "@": [.dit, .dah, .dah, .dit, .dah, .dit]
    ]
}
