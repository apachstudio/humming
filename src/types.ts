export type NoteEvent = {
  midi: number
  startMs: number
  durationMs: number
  velocity: number
}

export type ChordEvent = {
  symbol: string
  root: number
  quality: 'maj' | 'min'
  startMs: number
  durationMs: number
}

export type PitchFrame = {
  timeMs: number
  hz: number
}

export type Analysis = {
  notes: NoteEvent[]
  chords: ChordEvent[]
  key: string
  tempo: number
  durationMs: number
}

export type Hum = {
  id: string
  title: string
  createdAt: string
  durationMs: number
  key: string
  tempo: number
  notes: NoteEvent[]
  chords: ChordEvent[]
}

export type Screen =
  | { name: 'splash' }
  | { name: 'home' }
  | { name: 'recording' }
  | { name: 'processing'; frames: PitchFrame[]; durationMs: number }
  | { name: 'results'; hum: Hum; saved: boolean }
  | { name: 'library' }
  | { name: 'detail'; id: string }
