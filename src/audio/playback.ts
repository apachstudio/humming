import type { ChordEvent, NoteEvent } from '../types'
import { midiToHz } from './pitch'

let ctx: AudioContext | null = null

function audio(): AudioContext {
  if (!ctx || ctx.state === 'closed') {
    ctx = new AudioContext()
  }
  return ctx
}

function playTone(
  context: AudioContext,
  dest: GainNode,
  hz: number,
  start: number,
  duration: number,
  gain: number,
  type: OscillatorType,
) {
  const osc = context.createOscillator()
  const env = context.createGain()
  osc.type = type
  osc.frequency.value = hz
  env.gain.setValueAtTime(0.0001, start)
  env.gain.exponentialRampToValueAtTime(gain, start + 0.02)
  env.gain.exponentialRampToValueAtTime(0.0001, start + duration)
  osc.connect(env)
  env.connect(dest)
  osc.start(start)
  osc.stop(start + duration + 0.02)
}

export async function playHum(
  notes: NoteEvent[],
  chords: ChordEvent[],
): Promise<AudioContext> {
  const context = audio()
  if (context.state === 'suspended') await context.resume()
  const now = context.currentTime + 0.05
  const master = context.createGain()
  master.gain.value = 0.7
  master.connect(context.destination)

  for (const chord of chords) {
    const start = now + chord.startMs / 1000
    const dur = Math.max(0.2, chord.durationMs / 1000)
    const third = chord.quality === 'maj' ? 4 : 3
    const roots = [48 + chord.root, 48 + chord.root + third, 48 + chord.root + 7]
    for (const midi of roots) {
      playTone(context, master, midiToHz(midi), start, dur, 0.12, 'triangle')
    }
  }

  for (const note of notes) {
    const start = now + note.startMs / 1000
    const dur = Math.max(0.08, note.durationMs / 1000)
    playTone(context, master, midiToHz(note.midi), start, dur, 0.22, 'sine')
  }

  return context
}

export async function stopPlayback(): Promise<void> {
  if (!ctx) return
  await ctx.close()
  ctx = null
}
