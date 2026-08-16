import { qualityLabel } from '../audio/chords'
import type { ChordEvent } from '../types'

export function ChordRow({ chords }: { chords: ChordEvent[] }) {
  return (
    <div className="chord-row">
      {chords.map((chord, i) => (
        <div key={`${chord.symbol}-${i}`} className="chord-chip">
          <span className="chord-symbol">{chord.symbol}</span>
          <span className="chord-quality">{qualityLabel(chord.quality)}</span>
        </div>
      ))}
    </div>
  )
}
