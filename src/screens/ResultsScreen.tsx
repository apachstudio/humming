import { ChordRow } from '../components/ChordRow'
import { TopBar } from '../components/TopBar'
import { formatDuration } from '../audio/titles'
import type { Hum } from '../types'

type Props = {
  hum: Hum
  saved: boolean
  onBack: () => void
  onPlay: () => void
  onExport: () => void
  onSave: () => void
}

export function ResultsScreen({ hum, saved, onBack, onPlay, onExport, onSave }: Props) {
  return (
    <div className="screen results">
      <TopBar title="Detection Complete" onBack={onBack} />
      <p className="kicker">New hum detected</p>
      <h2 className="hum-title">{hum.title}</h2>
      <p className="meta">
        {formatDuration(hum.durationMs)} · {hum.key}
      </p>

      <section>
        <p className="kicker">Detected chord progression</p>
        <ChordRow chords={hum.chords} />
      </section>

      <div className="meta-grid">
        <div>
          <p className="kicker">Estimated key</p>
          <p className="meta-value">{hum.key}</p>
        </div>
        <div>
          <p className="kicker">Tempo</p>
          <p className="meta-value">{hum.tempo} BPM</p>
        </div>
      </div>

      <div className="action-stack">
        <button type="button" className="btn-primary" onClick={onPlay}>
          Play
        </button>
        <button type="button" className="btn-secondary" onClick={onExport}>
          Export MIDI
        </button>
        <button type="button" className="btn-ghost" onClick={onSave} disabled={saved}>
          {saved ? 'Saved to library' : 'Save to library'}
        </button>
      </div>
    </div>
  )
}
