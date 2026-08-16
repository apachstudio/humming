import { WaveBars } from '../components/Waveform'

export function ProcessingScreen() {
  return (
    <div className="screen processing">
      <div className="processing-mark">
        <WaveBars className="pulse-bars" />
      </div>
      <h2>Translating your hum...</h2>
      <p className="lede">Analyzing pitch, frequency &amp; chords</p>
    </div>
  )
}
