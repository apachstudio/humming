import { formatTimer } from '../audio/titles'
import { TopBar } from '../components/TopBar'
import { Waveform } from '../components/Waveform'

type Props = {
  elapsedMs: number
  levels: number[]
  onStop: () => void
}

export function RecordingScreen({ elapsedMs, levels, onStop }: Props) {
  return (
    <button type="button" className="screen recording" onClick={onStop}>
      <TopBar title="Recording" />
      <p className="recording-hint">
        <span className="rec-dot" />
        Tap and start humming
      </p>
      <p className="timer">{formatTimer(elapsedMs)}</p>
      <Waveform values={levels} live mode="bars" />
      <p className="hint-bottom">Tap to stop</p>
    </button>
  )
}
