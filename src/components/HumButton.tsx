import { WaveBars } from './Waveform'

type Props = {
  onClick: () => void
  glow?: 'white' | 'cyan'
  label?: string
}

export function HumButton({ onClick, glow = 'white', label = 'TAP TO HUM' }: Props) {
  return (
    <div className="hum-button-wrap">
      <button
        type="button"
        className={`hum-button glow-${glow}`}
        onClick={onClick}
        aria-label={label}
      >
        <WaveBars />
      </button>
      <span className="hum-button-label">{label}</span>
    </div>
  )
}
