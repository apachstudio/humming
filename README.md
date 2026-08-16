# humming

iOS app (SwiftUI, iOS 17+) that turns a hum into chords and a MIDI file you can open in GarageBand.

Hum a melody. The app listens, estimates key and tempo, maps the phrase to a chord progression, and lets you save it in a local library — or share a `.mid` into GarageBand.

## Screens

Matches the Figma core flow:

1. **Splash** — Think it / Hum it / Play it
2. **Home** — TAP TO HUM
3. **Recording** — timer + live waveform
4. **Processing** — translating the hum
5. **Detection Complete** — chords, key, tempo, play, export MIDI, save
6. **Your Hums / Melody Details** — library with swipe-to-delete

## Run

Open `Humming.xcodeproj` in Xcode 15 or later.

1. Select the **Humming** scheme and an iPhone simulator or device
2. Set your **Team** under Signing & Capabilities
3. Run (`⌘R`)

Allow the microphone when iOS asks. In the simulator, use **or try a sample melody** if the mic is unavailable.

Unit tests: Product → Test (`⌘U`). They cover pitch detection, key/chord mapping, MIDI output, and titles.

## MIDI

**Export MIDI** writes a Standard MIDI File (melody + block chords) and opens the iOS share sheet. Choose GarageBand, Files, or AirDrop.

Hums are stored on-device (Application Support). Deleting a row removes it from the library.

## How analysis works

1. YIN pitch detection on the humming range (~70–900 Hz)
2. Notes from stable pitch frames
3. Key via Krumhansl–Schmuckler profiles
4. Diatonic chords scored per two-beat window
5. MIDI file built from those notes and chords
