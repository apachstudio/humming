import { ChordRow } from '../components/ChordRow'
import { TopBar } from '../components/TopBar'
import { TrashIcon } from './LibraryScreen'
import { formatDuration, formatRecordedAt } from '../audio/titles'
import type { Hum } from '../types'

type Props = {
  hum: Hum
  onBack: () => void
  onPlay: () => void
  onExport: () => void
  onDelete: () => void
}

export function DetailScreen({ hum, onBack, onPlay, onExport, onDelete }: Props) {
  return (
    <div className="screen detail">
      <TopBar title="Melody Details" onBack={onBack} />
      <h2 className="hum-title">{hum.title}</h2>
      <p className="meta">
        Recorded {formatRecordedAt(hum.createdAt)} · {formatDuration(hum.durationMs)} sec
      </p>

      <section>
        <p className="kicker">Detected chord progression</p>
        <ChordRow chords={hum.chords} />
      </section>

      <section>
        <p className="kicker">Full chord timeline</p>
        <div className="timeline">
          {hum.chords.map((chord, i) => (
            <div key={`${chord.symbol}-${i}`} className="timeline-item">
              <span>{formatDuration(chord.startMs)}</span>
              <strong>{chord.symbol}</strong>
            </div>
          ))}
        </div>
      </section>

      <div className="action-stack">
        <button type="button" className="btn-primary" onClick={onPlay}>
          Play
        </button>
        <button type="button" className="btn-secondary" onClick={onExport}>
          Export MIDI
        </button>
        <button type="button" className="btn-danger-text" onClick={onDelete}>
          <TrashIcon />
          Delete hum
        </button>
      </div>
    </div>
  )
}
