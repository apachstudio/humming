import { describe, expect, it } from 'vitest'
import { buildMidiFile, isMidiFile, midiFileName } from './midi'
import type { ChordEvent, NoteEvent } from '../types'

describe('midi', () => {
  it('writes a valid Standard MIDI File', () => {
    const notes: NoteEvent[] = [
      { midi: 69, startMs: 0, durationMs: 400, velocity: 90 },
      { midi: 72, startMs: 400, durationMs: 400, velocity: 90 },
    ]
    const chords: ChordEvent[] = [
      { symbol: 'Am', root: 9, quality: 'min', startMs: 0, durationMs: 800 },
    ]
    const bytes = buildMidiFile(notes, chords, 100)
    expect(isMidiFile(bytes)).toBe(true)
    expect(bytes.length).toBeGreaterThan(40)
  })

  it('slugs download names', () => {
    expect(midiFileName('Morning Melody #3')).toBe('morning-melody-3.mid')
    expect(midiFileName('')).toBe('hum.mid')
  })
})
