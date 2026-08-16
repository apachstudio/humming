import { useCallback, useEffect, useRef, useState } from 'react'
import { analyzeHum, sampleMelodyFrames } from './audio/chords'
import { detectPitch } from './audio/pitch'
import { buildMidiFile, downloadMidi, midiFileName } from './audio/midi'
import { playHum, stopPlayback } from './audio/playback'
import { titleForHum } from './audio/titles'
import { PhoneShell } from './components/PhoneShell'
import { DetailScreen } from './screens/DetailScreen'
import { HomeScreen } from './screens/HomeScreen'
import { LibraryScreen } from './screens/LibraryScreen'
import { ProcessingScreen } from './screens/ProcessingScreen'
import { RecordingScreen } from './screens/RecordingScreen'
import { ResultsScreen } from './screens/ResultsScreen'
import { SplashScreen } from './screens/SplashScreen'
import { deleteHum, getHum, loadLibrary, upsertHum } from './storage/library'
import type { Hum, PitchFrame, Screen } from './types'

function newId(): string {
  return crypto.randomUUID()
}

export default function App() {
  const [screen, setScreen] = useState<Screen>({ name: 'splash' })
  const [library, setLibrary] = useState<Hum[]>(() => loadLibrary())
  const [elapsedMs, setElapsedMs] = useState(0)
  const [levels, setLevels] = useState<number[]>(() => Array.from({ length: 48 }, () => 0.12))
  const [error, setError] = useState<string | null>(null)

  const framesRef = useRef<PitchFrame[]>([])
  const recRef = useRef<{
    context: AudioContext
    stream: MediaStream
    processor: ScriptProcessorNode
    source: MediaStreamAudioSourceNode
    started: number
    timer: number
  } | null>(null)

  useEffect(() => {
    if (screen.name !== 'splash') return
    const id = window.setTimeout(() => setScreen({ name: 'home' }), 2200)
    return () => window.clearTimeout(id)
  }, [screen.name])

  const stopMic = useCallback(() => {
    const rec = recRef.current
    if (!rec) return
    rec.processor.disconnect()
    rec.source.disconnect()
    rec.stream.getTracks().forEach((t) => t.stop())
    void rec.context.close()
    window.clearInterval(rec.timer)
    recRef.current = null
  }, [])

  useEffect(() => () => stopMic(), [stopMic])

  const finishRecording = useCallback(
    (frames: PitchFrame[], durationMs: number) => {
      stopMic()
      setScreen({ name: 'processing', frames, durationMs })
    },
    [stopMic],
  )

  useEffect(() => {
    if (screen.name !== 'processing') return
    const id = window.setTimeout(() => {
      const analysis = analyzeHum(screen.frames, screen.durationMs)
      if (!analysis) {
        setError("Couldn't hear a melody. Try humming a little louder and longer.")
        setScreen({ name: 'home' })
        return
      }
      const hum: Hum = {
        id: newId(),
        title: titleForHum(new Date(), library.map((h) => h.title)),
        createdAt: new Date().toISOString(),
        durationMs: analysis.durationMs,
        key: analysis.key,
        tempo: analysis.tempo,
        notes: analysis.notes,
        chords: analysis.chords,
      }
      setError(null)
      setScreen({ name: 'results', hum, saved: false })
    }, 1400)
    return () => window.clearTimeout(id)
  }, [screen, library])

  const startRecording = useCallback(async () => {
    setError(null)
    framesRef.current = []
    setElapsedMs(0)
    try {
      const stream = await navigator.mediaDevices.getUserMedia({
        audio: { echoCancellation: true, noiseSuppression: true, autoGainControl: true },
      })
      const context = new AudioContext()
      const source = context.createMediaStreamSource(stream)
      const processor = context.createScriptProcessor(2048, 1, 1)
      const silent = context.createGain()
      silent.gain.value = 0
      source.connect(processor)
      processor.connect(silent)
      silent.connect(context.destination)

      processor.onaudioprocess = (event) => {
        const input = event.inputBuffer.getChannelData(0)
        const copy = new Float32Array(input)
        const hz = detectPitch(copy, context.sampleRate)
        const now = performance.now() - (recRef.current?.started ?? performance.now())
        if (hz) framesRef.current.push({ timeMs: now, hz })
        let sum = 0
        for (let i = 0; i < copy.length; i++) sum += copy[i]! * copy[i]!
        const rms = Math.sqrt(sum / copy.length)
        setLevels((prev) => {
          const next = prev.slice(1)
          next.push(Math.min(1, rms * 8 + 0.08))
          return next
        })
      }

      const started = performance.now()
      const timer = window.setInterval(() => {
        setElapsedMs(performance.now() - started)
      }, 80)

      recRef.current = { context, stream, processor, source, started, timer }
      setScreen({ name: 'recording' })
    } catch {
      setError('Microphone access is needed to hum. You can still try a sample melody.')
    }
  }, [])

  const stopRecording = useCallback(() => {
    const rec = recRef.current
    const durationMs = rec ? performance.now() - rec.started : elapsedMs
    finishRecording(framesRef.current, Math.max(durationMs, 400))
  }, [elapsedMs, finishRecording])

  const runSample = useCallback(() => {
    setError(null)
    const sample = sampleMelodyFrames()
    setScreen({ name: 'processing', frames: sample.frames, durationMs: sample.durationMs })
  }, [])

  const exportHum = useCallback((hum: Hum) => {
    const bytes = buildMidiFile(hum.notes, hum.chords, hum.tempo)
    downloadMidi(bytes, midiFileName(hum.title))
  }, [])

  const play = useCallback((hum: Hum) => {
    void playHum(hum.notes, hum.chords)
  }, [])

  useEffect(() => {
    return () => {
      void stopPlayback()
    }
  }, [screen.name])

  const body = (() => {
    switch (screen.name) {
      case 'splash':
        return <SplashScreen onDone={() => setScreen({ name: 'home' })} />
      case 'home':
        return (
          <HomeScreen
            onHum={() => void startRecording()}
            onSample={runSample}
            onLibrary={() => setScreen({ name: 'library' })}
          />
        )
      case 'recording':
        return (
          <RecordingScreen elapsedMs={elapsedMs} levels={levels} onStop={stopRecording} />
        )
      case 'processing':
        return <ProcessingScreen />
      case 'results':
        return (
          <ResultsScreen
            hum={screen.hum}
            saved={screen.saved}
            onBack={() => setScreen({ name: 'home' })}
            onPlay={() => play(screen.hum)}
            onExport={() => exportHum(screen.hum)}
            onSave={() => {
              const next = upsertHum(screen.hum)
              setLibrary(next)
              setScreen({ name: 'results', hum: screen.hum, saved: true })
            }}
          />
        )
      case 'library':
        return (
          <LibraryScreen
            hums={library}
            onBack={() => setScreen({ name: 'home' })}
            onOpen={(id) => setScreen({ name: 'detail', id })}
            onDelete={(id) => setLibrary(deleteHum(id))}
          />
        )
      case 'detail': {
        const hum = getHum(screen.id)
        if (!hum) {
          return (
            <LibraryScreen
              hums={library}
              onBack={() => setScreen({ name: 'home' })}
              onOpen={(id) => setScreen({ name: 'detail', id })}
              onDelete={(id) => setLibrary(deleteHum(id))}
            />
          )
        }
        return (
          <DetailScreen
            hum={hum}
            onBack={() => setScreen({ name: 'library' })}
            onPlay={() => play(hum)}
            onExport={() => exportHum(hum)}
            onDelete={() => {
              setLibrary(deleteHum(hum.id))
              setScreen({ name: 'library' })
            }}
          />
        )
      }
    }
  })()

  return (
    <PhoneShell>
      {error ? <p className="banner">{error}</p> : null}
      {body}
    </PhoneShell>
  )
}
