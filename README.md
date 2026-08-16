# humming

Lean app that turns a hum into chords and a MIDI file you can open in GarageBand.

Hum a melody. The app listens, estimates key and tempo, maps the phrase to a chord progression, and lets you save it in a local library — or export a `.mid` with melody + chords.

## Screens

Matches the Figma core flow:

1. **Splash** — Think it / Hum it / Play it
2. **Home** — one action: tap to hum
3. **Recording** — timer + live waveform
4. **Processing** — translating the hum
5. **Results** — detected chords, key, tempo, play, export MIDI, save
6. **Library / Melody details** — view and delete saved hums

## Run

```bash
npm install
npm run dev
```

Then open the local URL. Allow the microphone when the browser asks.

No mic? Use **or try a sample melody** on the home screen.

```bash
npm test
npm run build
```

## MIDI

Export writes a Standard MIDI File (melody + block chords). AirDrop or download the `.mid` and open it in GarageBand, Logic, or any DAW.

Hums are stored in this browser only (`localStorage`). Deleting a row removes it from the library.

## How analysis works

1. YIN pitch detection on the humming range (~70–900 Hz)
2. Notes from stable pitch frames
3. Key via Krumhansl–Schmuckler profiles
4. Diatonic chords scored per two-beat window
5. MIDI file built from those notes and chords
