import { describe, expect, it } from 'vitest'
import {
  analyzeHum,
  chordSymbol,
  detectChords,
  estimateKey,
  formatKey,
  framesToNotes,
  sampleMelodyFrames,
} from './chords'
import type { NoteEvent } from '../types'

function note(midi: number, startMs: number, durationMs = 400): NoteEvent {
  return { midi, startMs, durationMs, velocity: 80 }
}

describe('chords', () => {
  it('names major and minor chords', () => {
    expect(chordSymbol(9, 'min')).toBe('Am')
    expect(chordSymbol(5, 'maj')).toBe('F')
    expect(chordSymbol(0, 'maj')).toBe('C')
    expect(chordSymbol(7, 'maj')).toBe('G')
  })

  it('estimates A minor from an A-minor melody', () => {
    const notes = [note(69, 0), note(72, 400), note(76, 800), note(77, 1200), note(76, 1600)]
    const key = estimateKey(notes)
    expect(key.tonic).toBe(9)
    expect(key.mode).toBe('minor')
    expect(formatKey(key.tonic, key.mode)).toBe('A minor')
  })

  it('turns a C-major hummed phrase into C / F / G chords', () => {
    const notes = [
      note(60, 0, 700),
      note(64, 700, 500),
      note(67, 1200, 600),
      note(65, 2000, 800),
      note(69, 2800, 500),
      note(67, 3600, 900),
      note(71, 4500, 400),
      note(72, 5000, 800),
    ]
    const key = estimateKey(notes)
    expect(key.tonic).toBe(0)
    expect(key.mode).toBe('major')
    const chords = detectChords(notes, key, 96, 5800)
    expect(chords.length).toBeGreaterThan(0)
    expect(chords.some((c) => c.symbol === 'C')).toBe(true)
  })

  it('analyzes the sample Am–F–C–G melody', () => {
    const { frames, durationMs } = sampleMelodyFrames()
    const notes = framesToNotes(frames)
    expect(notes.length).toBeGreaterThan(4)
    const analysis = analyzeHum(frames, durationMs)
    expect(analysis).not.toBeNull()
    expect(['A minor', 'C major']).toContain(analysis!.key)
    expect(analysis!.chords.length).toBeGreaterThan(0)
    const symbols = new Set(analysis!.chords.map((c) => c.symbol))
    expect(['Am', 'F', 'C', 'G'].some((s) => symbols.has(s))).toBe(true)
  })

  it('returns null when there is no voiced audio', () => {
    expect(analyzeHum([], 1000)).toBeNull()
  })
})
