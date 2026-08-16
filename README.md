# Humming

**Think it. Hum it. Play it.**

Humming turns your voice into music: hum a melody and the app transcribes
it into chords and a MIDI file you can open in GarageBand, Logic, or any
DAW. Your hums are stored in a lean library where you can replay, export,
and delete them.

## Screens

| Screen | Description |
| --- | --- |
| Onboarding | Brand intro with the liquid-glass button and "Think it / Hum it / Play it" tagline |
| Record | Dark home screen — tap anywhere and start humming |
| Listening | Glowing coral orb, live waveform, elapsed timer, stop control |
| Processing | "Capturing melody..." → "Transcribing melody..." |
| Chords Ready | Detected key, ~BPM, 4/4, chord grid, playback, Record Again / Export MIDI / Save |
| Library | Saved hums with swipe-to-delete; open any hum to view chords and export |

Designs live in the [Humming Figma file](https://www.figma.com/design/0zMHViR6SQ6zjm1Msimfrw/Humming-app)
(core screens node `77-5`, brand guidelines node `18-669`).

## How it works

1. **Record** — `AVAudioRecorder` captures a mono AAC file while metering
   levels for the live waveform (`AudioRecorder`).
2. **Transcribe** — an offline YIN pitch tracker converts the recording
   into note events (`PitchTracker`).
3. **Harmonize** — `ChordEngine` estimates the key (Krumhansl–Schmuckler
   profiles), the tempo (median inter-onset interval), and picks one
   diatonic triad per bar that best matches the melody.
4. **Export** — `MIDIExporter` writes a Standard MIDI File (format 1) with
   a chord track and the melody track, shared via the system share sheet —
   open it straight in GarageBand.
5. **Store** — `HumStore` persists hums as JSON in Documents plus the
   audio recordings; delete removes both.

## Tech

- SwiftUI, iOS 17+, no third-party dependencies
- Xcode 16 project (file-system-synchronized groups)
- All audio analysis runs on-device

## Running

Open `Humming.xcodeproj` in Xcode 16+, select an iOS 17+ device or
simulator, and run. The microphone permission prompt appears on the first
recording (a real device is best — simulators use the Mac microphone).
