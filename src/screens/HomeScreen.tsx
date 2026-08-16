import { HumButton } from '../components/HumButton'
import { WaveBars } from '../components/Waveform'

const GREETINGS = [
  { kicker: 'Yo!', line: "What's in your head?" },
  { kicker: "Haven't seen you in a while", line: 'Feeling creative today?' },
  { kicker: 'Yo.', line: 'Back for another hit?' },
  { kicker: 'Welcome back my friend,', line: 'Today is jamming seshhhh' },
] as const

function greetingForToday(): (typeof GREETINGS)[number] {
  const day = Math.floor(Date.now() / 86_400_000)
  return GREETINGS[day % GREETINGS.length]!
}

type Props = {
  onHum: () => void
  onSample: () => void
  onLibrary: () => void
}

export function HomeScreen({ onHum, onSample, onLibrary }: Props) {
  const copy = greetingForToday()

  return (
    <div className="screen home">
      <div className="home-copy">
        <h2 className="greeting">
          {copy.kicker}
          <br />
          {copy.line}
        </h2>
        <p className="lede">Hum a melody and get the chords instantly</p>
      </div>

      <HumButton onClick={onHum} />

      <button type="button" className="text-link" onClick={onSample}>
        or try a sample melody
      </button>

      <footer className="home-footer">
        <span>Humming Beta v1.0</span>
        <button type="button" className="library-link" onClick={onLibrary}>
          <WaveBars className="tiny-bars" />
          Library
        </button>
      </footer>
    </div>
  )
}
