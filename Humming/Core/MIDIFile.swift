import Foundation

public enum MIDIFile {
    private static let ppq = 480

    public static func fileName(for title: String) -> String {
        let slug = title
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return "\(slug.isEmpty ? "hum" : slug).mid"
    }

    public static func isMIDI(_ data: Data) -> Bool {
        data.count >= 14 && data.starts(with: [0x4D, 0x54, 0x68, 0x64])
    }

    public static func build(notes: [NoteEvent], chords: [ChordEvent], tempo: Int) -> Data {
        let bpm = max(40, min(200, tempo))
        var bytes: [UInt8] = []
        bytes += chunk("MThd", [0x00, 0x01] + u16(3) + u16(UInt16(ppq)))
        bytes += serializeTrack([
            MIDIEvent(tick: 0, bytes: [0xFF, 0x51, 0x03] + u24(tempoMicros(bpm))),
            MIDIEvent(tick: 0, bytes: [0xFF, 0x03, 0x07] + Array("humming".utf8)),
        ])

        var melody: [MIDIEvent] = [
            MIDIEvent(tick: 0, bytes: [0xC0, 73]),
            MIDIEvent(tick: 0, bytes: [0xFF, 0x03, 0x06] + Array("melody".utf8)),
        ]
        for note in notes {
            let midi = UInt8(max(21, min(108, Int(note.midi.rounded()))))
            let start = msToTicks(note.startMs, bpm: bpm)
            let end = msToTicks(note.startMs + max(note.durationMs, 80), bpm: bpm)
            melody.append(MIDIEvent(tick: start, bytes: [0x90, midi, UInt8(note.velocity)]))
            melody.append(MIDIEvent(tick: max(end, start + 20), bytes: [0x80, midi, 0]))
        }

        var chordEvents: [MIDIEvent] = [
            MIDIEvent(tick: 0, bytes: [0xC1, 0]),
            MIDIEvent(tick: 0, bytes: [0xFF, 0x03, 0x06] + Array("chords".utf8)),
        ]
        for chord in chords {
            let start = msToTicks(chord.startMs, bpm: bpm)
            let end = msToTicks(chord.startMs + max(chord.durationMs, 200), bpm: bpm)
            for midi in triad(root: chord.root, quality: chord.quality, octave: 3) {
                chordEvents.append(MIDIEvent(tick: start, bytes: [0x91, midi, 70]))
                chordEvents.append(MIDIEvent(tick: max(end, start + 40), bytes: [0x81, midi, 0]))
            }
        }

        bytes += serializeTrack(melody)
        bytes += serializeTrack(chordEvents)
        return Data(bytes)
    }

    private struct MIDIEvent {
        var tick: Int
        var bytes: [UInt8]
    }

    private static func vlq(_ value: Int) -> [UInt8] {
        var bytes: [UInt8] = [UInt8(value & 0x7F)]
        var n = value >> 7
        while n > 0 {
            bytes.insert(UInt8((n & 0x7F) | 0x80), at: 0)
            n >>= 7
        }
        return bytes
    }

    private static func u16(_ n: UInt16) -> [UInt8] {
        [UInt8(n >> 8), UInt8(n & 0xFF)]
    }

    private static func u32(_ n: UInt32) -> [UInt8] {
        [UInt8(n >> 24), UInt8((n >> 16) & 0xFF), UInt8((n >> 8) & 0xFF), UInt8(n & 0xFF)]
    }

    private static func u24(_ n: Int) -> [UInt8] {
        [UInt8((n >> 16) & 0xFF), UInt8((n >> 8) & 0xFF), UInt8(n & 0xFF)]
    }

    private static func chunk(_ type: String, _ data: [UInt8]) -> [UInt8] {
        Array(type.utf8) + u32(UInt32(data.count)) + data
    }

    private static func tempoMicros(_ bpm: Int) -> Int {
        Int((60_000_000.0 / Double(bpm)).rounded())
    }

    private static func msToTicks(_ ms: Double, bpm: Int) -> Int {
        max(0, Int(((ms / 1000.0) * (Double(bpm) / 60.0) * Double(ppq)).rounded()))
    }

    private static func serializeTrack(_ events: [MIDIEvent]) -> [UInt8] {
        let sorted = events.sorted { $0.tick < $1.tick }
        var data: [UInt8] = []
        var last = 0
        for event in sorted {
            data += vlq(event.tick - last)
            data += event.bytes
            last = event.tick
        }
        data += vlq(0) + [0xFF, 0x2F, 0x00]
        return chunk("MTrk", data)
    }

    private static func triad(root: Int, quality: ChordQuality, octave: Int) -> [UInt8] {
        let base = octave * 12 + 12 + root
        let third = quality == .major ? 4 : 3
        return [UInt8(base), UInt8(base + third), UInt8(base + 7)]
    }
}
