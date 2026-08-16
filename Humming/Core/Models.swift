import Foundation

public struct NoteEvent: Codable, Hashable, Sendable {
    public var midi: Double
    public var startMs: Double
    public var durationMs: Double
    public var velocity: Int

    public init(midi: Double, startMs: Double, durationMs: Double, velocity: Int = 84) {
        self.midi = midi
        self.startMs = startMs
        self.durationMs = durationMs
        self.velocity = velocity
    }
}

public enum ChordQuality: String, Codable, Hashable, Sendable {
    case major
    case minor
}

public struct ChordEvent: Codable, Hashable, Sendable {
    public var symbol: String
    public var root: Int
    public var quality: ChordQuality
    public var startMs: Double
    public var durationMs: Double

    public init(symbol: String, root: Int, quality: ChordQuality, startMs: Double, durationMs: Double) {
        self.symbol = symbol
        self.root = root
        self.quality = quality
        self.startMs = startMs
        self.durationMs = durationMs
    }

    public var qualityLabel: String {
        quality == .minor ? "Minor" : "Major"
    }
}

public struct PitchFrame: Codable, Hashable, Sendable {
    public var timeMs: Double
    public var hz: Double

    public init(timeMs: Double, hz: Double) {
        self.timeMs = timeMs
        self.hz = hz
    }
}

public struct Analysis: Hashable, Sendable {
    public var notes: [NoteEvent]
    public var chords: [ChordEvent]
    public var key: String
    public var tempo: Int
    public var durationMs: Double
}

public struct Hum: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var title: String
    public var createdAt: Date
    public var durationMs: Double
    public var key: String
    public var tempo: Int
    public var notes: [NoteEvent]
    public var chords: [ChordEvent]

    public init(
        id: UUID = UUID(),
        title: String,
        createdAt: Date = Date(),
        durationMs: Double,
        key: String,
        tempo: Int,
        notes: [NoteEvent],
        chords: [ChordEvent]
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.durationMs = durationMs
        self.key = key
        self.tempo = tempo
        self.notes = notes
        self.chords = chords
    }
}

public enum MusicalMode: String, Sendable {
    case major
    case minor
}

public struct EstimatedKey: Sendable {
    public var tonic: Int
    public var mode: MusicalMode
}
