import type { ChordEvent, NoteEvent } from '../types'

const PPQ = 480

function vlq(value: number): number[] {
  const bytes = [value & 0x7f]
  let n = value >>> 7
  while (n > 0) {
    bytes.unshift((n & 0x7f) | 0x80)
    n >>>= 7
  }
  return bytes
}

function u16(n: number): number[] {
  return [(n >> 8) & 0xff, n & 0xff]
}

function u32(n: number): number[] {
  return [(n >> 24) & 0xff, (n >> 16) & 0xff, (n >> 8) & 0xff, n & 0xff]
}

function chunk(type: string, data: number[]): number[] {
  const bytes = [...type.split('').map((c) => c.charCodeAt(0)), ...u32(data.length), ...data]
  return bytes
}

function tempoMicros(bpm: number): number {
  return Math.round(60_000_000 / bpm)
}

function msToTicks(ms: number, bpm: number): number {
  return Math.max(0, Math.round((ms / 1000) * (bpm / 60) * PPQ))
}

type MidiEvent = { tick: number; bytes: number[] }

function serializeTrack(events: MidiEvent[]): number[] {
  const sorted = [...events].sort((a, b) => a.tick - b.tick)
  const data: number[] = []
  let last = 0
  for (const event of sorted) {
    data.push(...vlq(event.tick - last), ...event.bytes)
    last = event.tick
  }
  data.push(...vlq(0), 0xff, 0x2f, 0x00)
  return chunk('MTrk', data)
}

function triadMidi(root: number, quality: 'maj' | 'min', octave = 4): number[] {
  const base = octave * 12 + 12 + root
  const third = quality === 'maj' ? 4 : 3
  return [base, base + third, base + 7]
}

export function buildMidiFile(
  notes: NoteEvent[],
  chords: ChordEvent[],
  tempo: number,
): Uint8Array {
  const bpm = Math.max(40, Math.min(200, tempo))
  const header = chunk('MThd', [...u16(1), ...u16(3), ...u16(PPQ)])

  const tempoTrack = serializeTrack([
    { tick: 0, bytes: [0xff, 0x51, 0x03, ...u32(tempoMicros(bpm)).slice(1)] },
    { tick: 0, bytes: [0xff, 0x03, 0x07, ...[...'humming'].map((c) => c.charCodeAt(0))] },
  ])

  const melodyEvents: MidiEvent[] = [
    { tick: 0, bytes: [0xc0, 73] },
    { tick: 0, bytes: [0xff, 0x03, 0x06, ...[...'melody'].map((c) => c.charCodeAt(0))] },
  ]
  for (const note of notes) {
    const midi = Math.max(21, Math.min(108, Math.round(note.midi)))
    const start = msToTicks(note.startMs, bpm)
    const end = msToTicks(note.startMs + Math.max(note.durationMs, 80), bpm)
    melodyEvents.push({ tick: start, bytes: [0x90, midi, note.velocity] })
    melodyEvents.push({ tick: Math.max(end, start + 20), bytes: [0x80, midi, 0] })
  }

  const chordEvents: MidiEvent[] = [
    { tick: 0, bytes: [0xc1, 0] },
    { tick: 0, bytes: [0xff, 0x03, 0x06, ...[...'chords'].map((c) => c.charCodeAt(0))] },
  ]
  for (const chord of chords) {
    const start = msToTicks(chord.startMs, bpm)
    const end = msToTicks(chord.startMs + Math.max(chord.durationMs, 200), bpm)
    for (const midi of triadMidi(chord.root, chord.quality, 3)) {
      chordEvents.push({ tick: start, bytes: [0x91, midi, 70] })
      chordEvents.push({ tick: Math.max(end, start + 40), bytes: [0x81, midi, 0] })
    }
  }

  const bytes = [
    ...header,
    ...tempoTrack,
    ...serializeTrack(melodyEvents),
    ...serializeTrack(chordEvents),
  ]
  return Uint8Array.from(bytes)
}

export function midiFileName(title: string): string {
  const slug = title
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '')
  return `${slug || 'hum'}.mid`
}

export function downloadMidi(bytes: Uint8Array, filename: string): void {
  const copy = new Uint8Array(bytes)
  const blob = new Blob([copy.buffer], { type: 'audio/midi' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = filename
  a.click()
  URL.revokeObjectURL(url)
}

export function isMidiFile(bytes: Uint8Array): boolean {
  return (
    bytes.length >= 14 &&
    bytes[0] === 0x4d &&
    bytes[1] === 0x54 &&
    bytes[2] === 0x68 &&
    bytes[3] === 0x64
  )
}
