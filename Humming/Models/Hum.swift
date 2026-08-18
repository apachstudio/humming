import Foundation

/// A single detected melody note.
struct NoteEvent: Codable, Equatable, Hashable {
    /// MIDI note number (60 = middle C).
    var pitch: Int
    /// Seconds from the start of the recording.
    var start: TimeInterval
    /// Seconds.
    var duration: TimeInterval
}

/// A saved (or freshly analyzed) hum.
struct Hum: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var name: String
    var createdAt: Date
    var duration: TimeInterval
    /// Display key, e.g. "Am" or "C".
    var key: String
    var bpm: Int
    var timeSignature: String
    /// One chord symbol per bar, e.g. ["Am", "F", "C", "G"].
    var chords: [String]
    /// The transcribed melody, kept so MIDI can be exported any time.
    var notes: [NoteEvent]
    /// File name of the recording inside the store's audio directory
    /// (or a temporary file name before the hum is saved).
    var audioFileName: String
    var emojiReaction: String? = nil

    var subtitle: String {
        "\(createdAt.relativeLabel) · \(duration.compactDuration)"
    }
}

extension Hum {
    /// Chords ending in "m" (minor) get the dark emphasis in the grid,
    /// matching the Figma "Chords Ready" screen hierarchy.
    static func isMinorSymbol(_ symbol: String) -> Bool {
        symbol.hasSuffix("m")
    }
}
