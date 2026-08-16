import { WaveBars } from '../components/Waveform'

type Props = {
  onDone: () => void
}

export function SplashScreen({ onDone }: Props) {
  return (
    <button type="button" className="screen splash" onClick={onDone}>
      <div className="splash-mark">
        <WaveBars className="splash-bars" />
      </div>
      <p className="wordmark">humming</p>
      <div className="tagline">
        <span>Think it</span>
        <span>Hum it</span>
        <span>Play it</span>
      </div>
      <p className="lede">Hum a melody and get the chords and MIDI instantly</p>
    </button>
  )
}
