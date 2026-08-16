import type { Analysis, ChordEvent, NoteEvent, PitchFrame } from '../types'
import { hzToMidi } from './pitch'

const PC_NAMES = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'] as const

const MAJOR_PROFILE = [6.35, 2.23, 3.48, 2.33, 4.38, 4.09, 2.52, 5.19, 2.39, 3.66, 2.29, 2.88]
const MINOR_PROFILE = [6.33, 2.68, 3.52, 5.38, 2.6, 3.53, 2.54, 4.75, 3.98, 2.69, 3.34, 3.17]

export function pitchClassName(pc: number): string {
  return PC_NAMES[((pc % 12) + 12) % 12]
}

export function chordSymbol(root: number, quality: 'maj' | 'min'): string {
  const name = pitchClassName(root)
  return quality === 'min' ? `${name}m` : name
}

export function qualityLabel(quality: 'maj' | 'min'): string {
  return quality === 'min' ? 'Minor' : 'Major'
}

function pitchClass(midi: number): number {
  return ((Math.round(midi) % 12) + 12) % 12
}

function correlate(histo: number[], profile: number[], tonic: number): number {
  let sum = 0
  for (let i = 0; i < 12; i++) {
    sum += (histo[i] ?? 0) * (profile[(i - tonic + 12) % 12] ?? 0)
  }
  return sum
}

export function estimateKey(notes: NoteEvent[]): { tonic: number; mode: 'major' | 'minor' } {
  const histo = new Array<number>(12).fill(0)
  for (const note of notes) {
    histo[pitchClass(note.midi)] += Math.max(note.durationMs, 1)
  }

  let best: { tonic: number; mode: 'major' | 'minor'; score: number } = {
    tonic: 0,
    mode: 'major',
    score: -Infinity,
  }
  for (let tonic = 0; tonic < 12; tonic++) {
    const major = correlate(histo, MAJOR_PROFILE, tonic)
    const minor = correlate(histo, MINOR_PROFILE, tonic)
    if (major > best.score) best = { tonic, mode: 'major', score: major }
    if (minor > best.score) best = { tonic, mode: 'minor', score: minor }
  }
  return { tonic: best.tonic, mode: best.mode }
}

export function formatKey(tonic: number, mode: 'major' | 'minor'): string {
  const name = pitchClassName(tonic)
  return mode === 'minor' ? `${name} minor` : `${name} major`
}

const MAJOR_DEGREES: Array<{ degree: number; quality: 'maj' | 'min' }> = [
  { degree: 0, quality: 'maj' },
  { degree: 2, quality: 'min' },
  { degree: 4, quality: 'min' },
  { degree: 5, quality: 'maj' },
  { degree: 7, quality: 'maj' },
  { degree: 9, quality: 'min' },
]

const MINOR_DEGREES: Array<{ degree: number; quality: 'maj' | 'min' }> = [
  { degree: 0, quality: 'min' },
  { degree: 3, quality: 'maj' },
  { degree: 5, quality: 'min' },
  { degree: 7, quality: 'min' },
  { degree: 8, quality: 'maj' },
  { degree: 10, quality: 'maj' },
]

function triadPitchClasses(root: number, quality: 'maj' | 'min'): Set<number> {
  const third = quality === 'maj' ? 4 : 3
  return new Set([root, (root + third) % 12, (root + 7) % 12])
}

export function estimateTempo(notes: NoteEvent[]): number {
  if (notes.length < 2) return 96
  const iois: number[] = []
  for (let i = 1; i < notes.length; i++) {
    const gap = notes[i]!.startMs - notes[i - 1]!.startMs
    if (gap > 120 && gap < 1400) iois.push(gap)
  }
  if (iois.length === 0) return 96
  iois.sort((a, b) => a - b)
  const median = iois[Math.floor(iois.length / 2)]!
  let bpm = 60000 / median
  while (bpm < 70) bpm *= 2
  while (bpm > 160) bpm /= 2
  return Math.round(bpm)
}

function scoreChord(
  notes: NoteEvent[],
  startMs: number,
  endMs: number,
  root: number,
  quality: 'maj' | 'min',
): number {
  const tones = triadPitchClasses(root, quality)
  let score = 0
  for (const note of notes) {
    const noteEnd = note.startMs + note.durationMs
    const overlap = Math.min(endMs, noteEnd) - Math.max(startMs, note.startMs)
    if (overlap <= 0) continue
    const pc = pitchClass(note.midi)
    if (pc === root) score += overlap * 3
    else if (tones.has(pc)) score += overlap * 2
    else score -= overlap * 0.35
  }
  return score
}

export function detectChords(
  notes: NoteEvent[],
  key: { tonic: number; mode: 'major' | 'minor' },
  tempo: number,
  durationMs: number,
): ChordEvent[] {
  const degrees = key.mode === 'minor' ? MINOR_DEGREES : MAJOR_DEGREES
  const windowMs = Math.max(750, (60000 / tempo) * 2)
  const chords: ChordEvent[] = []

  for (let start = 0; start < durationMs; start += windowMs) {
    const end = Math.min(durationMs, start + windowMs)
    let best: { root: number; quality: 'maj' | 'min'; score: number } | null = null
    for (const { degree, quality } of degrees) {
      const root = (key.tonic + degree) % 12
      const score = scoreChord(notes, start, end, root, quality)
      if (!best || score > best.score) best = { root, quality, score }
    }
    if (!best || best.score <= 0) {
      best = {
        root: key.tonic,
        quality: key.mode === 'minor' ? 'min' : 'maj',
        score: 0,
      }
    }

    const last = chords[chords.length - 1]
    if (last && last.root === best.root && last.quality === best.quality) {
      last.durationMs = end - last.startMs
    } else {
      chords.push({
        symbol: chordSymbol(best.root, best.quality),
        root: best.root,
        quality: best.quality,
        startMs: start,
        durationMs: end - start,
      })
    }
  }

  return chords.length > 0
    ? chords
    : [
        {
          symbol: chordSymbol(key.tonic, key.mode === 'minor' ? 'min' : 'maj'),
          root: key.tonic,
          quality: key.mode === 'minor' ? 'min' : 'maj',
          startMs: 0,
          durationMs,
        },
      ]
}

export function framesToNotes(frames: PitchFrame[]): NoteEvent[] {
  const voiced = frames.filter((f) => f.hz > 0)
  if (voiced.length === 0) return []

  const notes: NoteEvent[] = []
  let currentMidi = Math.round(hzToMidi(voiced[0]!.hz))
  let startMs = voiced[0]!.timeMs
  let lastMs = startMs

  const flush = (endMs: number) => {
    const durationMs = endMs - startMs
    if (durationMs >= 80) {
      notes.push({
        midi: currentMidi,
        startMs,
        durationMs,
        velocity: 84,
      })
    }
  }

  for (let i = 1; i < voiced.length; i++) {
    const frame = voiced[i]!
    const midi = hzToMidi(frame.hz)
    const rounded = Math.round(midi)
    lastMs = frame.timeMs
    if (Math.abs(midi - currentMidi) >= 0.6 && rounded !== currentMidi) {
      flush(frame.timeMs)
      currentMidi = rounded
      startMs = frame.timeMs
    }
  }
  flush(lastMs + 90)
  return notes
}

export function analyzeHum(frames: PitchFrame[], durationMs: number): Analysis | null {
  const notes = framesToNotes(frames)
  if (notes.length === 0) return null
  const key = estimateKey(notes)
  const tempo = estimateTempo(notes)
  const chords = detectChords(notes, key, tempo, durationMs)
  return {
    notes,
    chords,
    key: formatKey(key.tonic, key.mode),
    tempo,
    durationMs,
  }
}

/** A hummed-style Am–F–C–G phrase used when the mic is unavailable. */
export function sampleMelodyFrames(): { frames: PitchFrame[]; durationMs: number } {
  const phrase: Array<{ midi: number; startMs: number; durationMs: number }> = [
    { midi: 69, startMs: 0, durationMs: 620 },
    { midi: 72, startMs: 620, durationMs: 360 },
    { midi: 76, startMs: 980, durationMs: 420 },
    { midi: 69, startMs: 1400, durationMs: 520 },
    { midi: 65, startMs: 2000, durationMs: 640 },
    { midi: 69, startMs: 2640, durationMs: 360 },
    { midi: 65, startMs: 3000, durationMs: 420 },
    { midi: 60, startMs: 3520, durationMs: 700 },
    { midi: 64, startMs: 4220, durationMs: 380 },
    { midi: 67, startMs: 4600, durationMs: 520 },
    { midi: 67, startMs: 5240, durationMs: 480 },
    { midi: 71, startMs: 5720, durationMs: 360 },
    { midi: 74, startMs: 6080, durationMs: 400 },
    { midi: 69, startMs: 6480, durationMs: 900 },
  ]

  const frames: PitchFrame[] = []
  for (const note of phrase) {
    for (let t = 0; t < note.durationMs; t += 40) {
      const wobble = 1 + 0.008 * Math.sin((t / 70) * Math.PI)
      frames.push({
        timeMs: note.startMs + t,
        hz: midiToHzFromMidi(note.midi) * wobble,
      })
    }
  }
  return { frames, durationMs: 7480 }
}

function midiToHzFromMidi(midi: number): number {
  return 440 * 2 ** ((midi - 69) / 12)
}
