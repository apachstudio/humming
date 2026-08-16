const HUM_MIN_HZ = 70
const HUM_MAX_HZ = 900

export function hzToMidi(hz: number): number {
  return 69 + 12 * Math.log2(hz / 440)
}

export function midiToHz(midi: number): number {
  return 440 * 2 ** ((midi - 69) / 12)
}

const NOTE_NAMES = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'] as const

export function midiToNoteName(midi: number): string {
  const rounded = Math.round(midi)
  const name = NOTE_NAMES[((rounded % 12) + 12) % 12]
  const octave = Math.floor(rounded / 12) - 1
  return `${name}${octave}`
}

function parabolicPeak(prev: number, current: number, next: number): number {
  const denom = 2 * (2 * current - prev - next)
  if (denom === 0) return 0
  return (prev - next) / denom
}

/**
 * YIN pitch detection. Returns Hz or null if unvoiced / out of humming range.
 */
export function detectPitch(
  buffer: Float32Array,
  sampleRate: number,
  threshold = 0.15,
): number | null {
  const half = Math.floor(buffer.length / 2)
  if (half < 32) return null

  const yin = new Float32Array(half)
  for (let tau = 1; tau < half; tau++) {
    let sum = 0
    for (let i = 0; i < half; i++) {
      const delta = buffer[i]! - buffer[i + tau]!
      sum += delta * delta
    }
    yin[tau] = sum
  }

  yin[0] = 1
  let running = 0
  for (let tau = 1; tau < half; tau++) {
    running += yin[tau]!
    yin[tau] = running === 0 ? 1 : (yin[tau]! * tau) / running
  }

  const minTau = Math.max(2, Math.floor(sampleRate / HUM_MAX_HZ))
  const maxTau = Math.min(half - 1, Math.floor(sampleRate / HUM_MIN_HZ))

  let tau = minTau
  for (; tau <= maxTau; tau++) {
    if (yin[tau]! < threshold) {
      while (tau + 1 <= maxTau && yin[tau + 1]! < yin[tau]!) tau++
      break
    }
  }

  if (tau > maxTau || yin[tau]! >= threshold) return null

  const shift = parabolicPeak(yin[tau - 1] ?? 1, yin[tau]!, yin[tau + 1] ?? 1)
  const freq = sampleRate / (tau + shift)
  if (!Number.isFinite(freq) || freq < HUM_MIN_HZ || freq > HUM_MAX_HZ) return null
  return freq
}

export function sineWave(
  hz: number,
  sampleRate: number,
  seconds: number,
  amplitude = 0.6,
): Float32Array {
  const n = Math.floor(sampleRate * seconds)
  const out = new Float32Array(n)
  for (let i = 0; i < n; i++) {
    out[i] = Math.sin((2 * Math.PI * hz * i) / sampleRate) * amplitude
  }
  return out
}
