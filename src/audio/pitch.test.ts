import { describe, expect, it } from 'vitest'
import { detectPitch, hzToMidi, midiToHz, midiToNoteName, sineWave } from './pitch'

describe('pitch', () => {
  it('maps A4 to MIDI 69', () => {
    expect(hzToMidi(440)).toBeCloseTo(69, 8)
    expect(midiToHz(69)).toBeCloseTo(440, 8)
    expect(midiToNoteName(69)).toBe('A4')
    expect(midiToNoteName(60)).toBe('C4')
  })

  it('detects a 440Hz sine as A4', () => {
    const samples = sineWave(440, 44100, 0.12)
    const hz = detectPitch(samples, 44100)
    expect(hz).not.toBeNull()
    expect(hz!).toBeGreaterThan(430)
    expect(hz!).toBeLessThan(450)
  })

  it('detects a hummed-range 220Hz tone', () => {
    const samples = sineWave(220, 44100, 0.12)
    const hz = detectPitch(samples, 44100)
    expect(hz).not.toBeNull()
    expect(hz!).toBeGreaterThan(214)
    expect(hz!).toBeLessThan(226)
  })

  it('returns null for silence', () => {
    expect(detectPitch(new Float32Array(2048), 44100)).toBeNull()
  })
})
