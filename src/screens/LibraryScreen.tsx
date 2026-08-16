import { formatDuration, formatRecordedAt } from '../audio/titles'
import { TopBar } from '../components/TopBar'
import type { Hum } from '../types'

type Props = {
  hums: Hum[]
  onBack: () => void
  onOpen: (id: string) => void
  onDelete: (id: string) => void
}

export function LibraryScreen({ hums, onBack, onOpen, onDelete }: Props) {
  return (
    <div className="screen library">
      <TopBar title="Your Hums" onBack={onBack} />
      {hums.length === 0 ? (
        <div className="empty">
          <p>Nothing here yet.</p>
          <p className="lede">Hum a melody and save it — it will live in this library.</p>
        </div>
      ) : (
        <ul className="hum-list">
          {hums.map((hum) => (
            <li key={hum.id} className="hum-row">
              <button type="button" className="hum-row-main" onClick={() => onOpen(hum.id)}>
                <span className="hum-row-title">{hum.title}</span>
                <span className="hum-row-meta">
                  {formatRecordedAt(hum.createdAt)} · {formatDuration(hum.durationMs)}
                  {hum.chords.length ? ` · ${hum.chords.map((c) => c.symbol).join(' ')}` : ''}
                </span>
              </button>
              <button
                type="button"
                className="icon-btn danger"
                aria-label={`Delete ${hum.title}`}
                onClick={() => onDelete(hum.id)}
              >
                <TrashIcon />
              </button>
            </li>
          ))}
        </ul>
      )}
    </div>
  )
}

export function TrashIcon() {
  return (
    <svg viewBox="0 0 24 24" width="20" height="20" aria-hidden="true">
      <path
        d="M5 7h14M10 7V5h4v2M8 7l.8 12h6.4L16 7"
        fill="none"
        stroke="currentColor"
        strokeWidth="1.6"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  )
}
