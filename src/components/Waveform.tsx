import { useEffect, useRef } from 'react'

type Props = {
  values?: number[]
  live?: boolean
  mode?: 'bars' | 'fluid'
}

export function Waveform({ values, live = false, mode = 'fluid' }: Props) {
  const canvasRef = useRef<HTMLCanvasElement>(null)
  const valuesRef = useRef(values)

  useEffect(() => {
    valuesRef.current = values
  }, [values])

  useEffect(() => {
    const canvas = canvasRef.current
    if (!canvas) return
    const ctx = canvas.getContext('2d')
    if (!ctx) return

    let raf = 0
    const start = performance.now()

    const draw = (now: number) => {
      const { width, height } = canvas
      ctx.clearRect(0, 0, width, height)
      const t = (now - start) / 1000
      const samples = valuesRef.current

      if (mode === 'bars') {
        const n = 48
        const gap = 3
        const w = (width - gap * (n - 1)) / n
        for (let i = 0; i < n; i++) {
          const fromData = samples?.[Math.floor((i / n) * (samples.length || 1))] ?? 0
          const pulse = live ? 0.35 + 0.65 * Math.abs(Math.sin(t * 4 + i * 0.35)) : 0.22
          const amp = samples && samples.length ? fromData : pulse
          const h = Math.max(4, amp * height * 0.9)
          const x = i * (w + gap)
          const y = (height - h) / 2
          ctx.fillStyle = '#fff'
          ctx.beginPath()
          ctx.roundRect(x, y, w, h, 2)
          ctx.fill()
        }
      } else {
        ctx.lineWidth = 2.4
        ctx.strokeStyle = 'rgba(255,255,255,0.95)'
        ctx.beginPath()
        const n = 160
        for (let i = 0; i <= n; i++) {
          const x = (i / n) * width
          const data = samples?.[Math.floor((i / n) * (samples.length || 1))] ?? 0
          const base = live
            ? Math.sin(i * 0.18 + t * 5) * 0.22 + Math.sin(i * 0.07 + t * 2.2) * 0.12
            : Math.sin(i * 0.16) * 0.08
          const amp = samples && samples.length ? (data - 0.5) * 1.6 : base
          const y = height / 2 + amp * (height * 0.42)
          if (i === 0) ctx.moveTo(x, y)
          else ctx.lineTo(x, y)
        }
        ctx.stroke()
      }

      raf = requestAnimationFrame(draw)
    }

    raf = requestAnimationFrame(draw)
    return () => cancelAnimationFrame(raf)
  }, [live, mode])

  return <canvas ref={canvasRef} className="waveform" width={320} height={92} />
}

export function WaveBars({ className = '' }: { className?: string }) {
  return (
    <svg className={`wave-bars ${className}`} viewBox="0 0 28 28" aria-hidden="true">
      <rect x="2" y="11" width="3.4" height="6" rx="1.7" />
      <rect x="8.2" y="6" width="3.4" height="16" rx="1.7" />
      <rect x="14.4" y="3" width="3.4" height="22" rx="1.7" />
      <rect x="20.6" y="8" width="3.4" height="12" rx="1.7" />
    </svg>
  )
}
