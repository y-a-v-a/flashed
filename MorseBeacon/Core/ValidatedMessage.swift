/// A message that has been checked against `MorseTable` and FR-3's length cap.
///
/// Per PRD §7a R2, this is the domain-boundary type that keeps the encoder
/// total. The only way to construct one is through `init(_:)`, which throws
/// on any disallowed character or over-length input. Downstream code (the
/// encoder, the schedule builder) receives a value whose validity is already
/// guaranteed by the type system.
public struct ValidatedMessage: Equatable, Hashable, Sendable {

    /// Maximum accepted message length (PRD FR-3).
    public static let maxLength = 160

    /// Reasons a raw string fails validation.
    public enum ValidationError: Error, Equatable, Sendable {
        /// A character outside the FR-1 accepted set was found at `index`.
        case unsupportedCharacter(Character, at: Int)
        /// The input exceeded `ValidatedMessage.maxLength` characters.
        case tooLong(count: Int, max: Int)
    }

    /// Normalized characters (ASCII letters upper-cased; everything else preserved).
    public let characters: [Character]

    public init(_ raw: String) throws {
        let count = raw.count
        if count > Self.maxLength {
            throw ValidationError.tooLong(count: count, max: Self.maxLength)
        }

        var normalized: [Character] = []
        normalized.reserveCapacity(count)

        for (index, character) in raw.enumerated() {
            guard MorseTable.supports(character) else {
                throw ValidationError.unsupportedCharacter(character, at: index)
            }
            normalized.append(Self.normalize(character))
        }

        self.characters = normalized
    }

    public var isEmpty: Bool { characters.isEmpty }
    public var asString: String { String(characters) }

    // MARK: - Internal

    private static func normalize(_ character: Character) -> Character {
        // Upper-case ASCII letters only. Non-ASCII characters never reach here
        // (supports() rejects them), but guard anyway for defensive clarity.
        let s = String(character)
        if let scalar = s.unicodeScalars.first,
           scalar.isASCII,
           let upper = s.uppercased().first {
            return upper
        }
        return character
    }
}
