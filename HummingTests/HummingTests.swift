import XCTest
@testable import Humming

final class PitchTests: XCTestCase {
    func testA4MapsToMidi69() {
        XCTAssertEqual(Pitch.hzToMidi(440), 69, accuracy: 0.0001)
        XCTAssertEqual(Pitch.midiToHz(69), 440, accuracy: 0.0001)
        XCTAssertEqual(Pitch.midiToNoteName(69), "A4")
        XCTAssertEqual(Pitch.midiToNoteName(60), "C4")
    }

    func testDetects440HzSine() {
        let samples = Pitch.sineWave(hz: 440, sampleRate: 44_100, seconds: 0.12)
        let hz = Pitch.detect(samples, sampleRate: 44_100)
        XCTAssertNotNil(hz)
        XCTAssertEqual(hz ?? 0, 440, accuracy: 10)
    }

    func testDetects220HzSine() {
        let samples = Pitch.sineWave(hz: 220, sampleRate: 44_100, seconds: 0.12)
        let hz = Pitch.detect(samples, sampleRate: 44_100)
        XCTAssertNotNil(hz)
        XCTAssertEqual(hz ?? 0, 220, accuracy: 6)
    }

    func testSilenceIsNil() {
        XCTAssertNil(Pitch.detect([Float](repeating: 0, count: 2048), sampleRate: 44_100))
    }
}

final class ChordTests: XCTestCase {
    func testChordSymbols() {
        XCTAssertEqual(Chords.chordSymbol(root: 9, quality: .minor), "Am")
        XCTAssertEqual(Chords.chordSymbol(root: 5, quality: .major), "F")
        XCTAssertEqual(Chords.chordSymbol(root: 0, quality: .major), "C")
        XCTAssertEqual(Chords.chordSymbol(root: 7, quality: .major), "G")
    }

    func testEstimatesAMinor() {
        let notes = [
            NoteEvent(midi: 69, startMs: 0, durationMs: 400),
            NoteEvent(midi: 72, startMs: 400, durationMs: 400),
            NoteEvent(midi: 76, startMs: 800, durationMs: 400),
            NoteEvent(midi: 77, startMs: 1200, durationMs: 400),
            NoteEvent(midi: 76, startMs: 1600, durationMs: 400),
        ]
        let key = Chords.estimateKey(notes)
        XCTAssertEqual(key.tonic, 9)
        XCTAssertEqual(key.mode, .minor)
        XCTAssertEqual(Chords.formatKey(tonic: key.tonic, mode: key.mode), "A minor")
    }

    func testCMajorPhraseContainsC() {
        let notes = [
            NoteEvent(midi: 60, startMs: 0, durationMs: 700),
            NoteEvent(midi: 64, startMs: 700, durationMs: 500),
            NoteEvent(midi: 67, startMs: 1200, durationMs: 600),
            NoteEvent(midi: 65, startMs: 2000, durationMs: 800),
            NoteEvent(midi: 69, startMs: 2800, durationMs: 500),
            NoteEvent(midi: 67, startMs: 3600, durationMs: 900),
            NoteEvent(midi: 71, startMs: 4500, durationMs: 400),
            NoteEvent(midi: 72, startMs: 5000, durationMs: 800),
        ]
        let key = Chords.estimateKey(notes)
        XCTAssertEqual(key.tonic, 0)
        XCTAssertEqual(key.mode, .major)
        let chords = Chords.detectChords(notes: notes, key: key, tempo: 96, durationMs: 5800)
        XCTAssertTrue(chords.contains { $0.symbol == "C" })
    }

    func testSampleMelodyAnalyzes() {
        let sample = Chords.sampleMelody()
        let analysis = Chords.analyze(frames: sample.frames, durationMs: sample.durationMs)
        XCTAssertNotNil(analysis)
        XCTAssertTrue(["A minor", "C major"].contains(analysis?.key))
        XCTAssertFalse(analysis?.chords.isEmpty ?? true)
        let symbols = Set(analysis?.chords.map(\.symbol) ?? [])
        XCTAssertTrue(["Am", "F", "C", "G"].contains { symbols.contains($0) })
    }

    func testEmptyFrames() {
        XCTAssertNil(Chords.analyze(frames: [], durationMs: 1000))
    }
}

final class MIDITests: XCTestCase {
    func testWritesStandardMIDIFile() {
        let notes = [
            NoteEvent(midi: 69, startMs: 0, durationMs: 400, velocity: 90),
            NoteEvent(midi: 72, startMs: 400, durationMs: 400, velocity: 90),
        ]
        let chords = [
            ChordEvent(symbol: "Am", root: 9, quality: .minor, startMs: 0, durationMs: 800),
        ]
        let data = MIDIFile.build(notes: notes, chords: chords, tempo: 100)
        XCTAssertTrue(MIDIFile.isMIDI(data))
        XCTAssertGreaterThan(data.count, 40)
    }

    func testFileNameSlug() {
        XCTAssertEqual(MIDIFile.fileName(for: "Morning Melody #3"), "morning-melody-3.mid")
        XCTAssertEqual(MIDIFile.fileName(for: ""), "hum.mid")
    }
}

final class TitleTests: XCTestCase {
    func testIncrementsMorningTitles() {
        let morning = Calendar.current.date(from: DateComponents(year: 2026, month: 8, day: 16, hour: 9))!
        XCTAssertEqual(Titles.title(for: morning, existing: []), "Morning Melody #1")
        XCTAssertEqual(Titles.title(for: morning, existing: ["Morning Melody #1"]), "Morning Melody #2")
    }

    func testFormatsDurationAndTimer() {
        XCTAssertEqual(Titles.timer(14), "00:14")
        XCTAssertEqual(Titles.duration(14_000), "0:14")
    }
}
