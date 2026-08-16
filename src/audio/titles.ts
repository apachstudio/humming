export function titleForHum(when: Date, existingTitles: string[]): string {
  const hour = when.getHours()
  const prefixes =
    hour < 5
      ? ['Late Night Jam', 'Night Hum']
      : hour < 12
        ? ['Morning Melody', 'Sunrise Hum']
        : hour < 17
          ? ['Afternoon Sketch', 'Acoustic Idea']
          : hour < 21
            ? ['Evening Hum', 'Golden Hour']
            : ['Late Night Jam', 'Night Hum']

  const prefix = prefixes[0]!
  const used = new Set(existingTitles)
  for (let n = 1; n < 200; n++) {
    const title = `${prefix} #${n}`
    if (!used.has(title)) return title
  }
  return `${prefix} #${Date.now()}`
}

export function formatDuration(ms: number): string {
  const total = Math.max(0, Math.round(ms / 1000))
  const m = Math.floor(total / 60)
  const s = total % 60
  return m > 0 ? `${m}:${s.toString().padStart(2, '0')}` : `0:${s.toString().padStart(2, '0')}`
}

export function formatRecordedAt(iso: string, now = new Date()): string {
  const date = new Date(iso)
  const sameDay =
    date.getFullYear() === now.getFullYear() &&
    date.getMonth() === now.getMonth() &&
    date.getDate() === now.getDate()
  const yesterday = new Date(now)
  yesterday.setDate(now.getDate() - 1)
  const isYesterday =
    date.getFullYear() === yesterday.getFullYear() &&
    date.getMonth() === yesterday.getMonth() &&
    date.getDate() === yesterday.getDate()

  const time = date.toLocaleTimeString(undefined, { hour: 'numeric', minute: '2-digit' })
  if (sameDay) return `Today, ${time}`
  if (isYesterday) return `Yesterday, ${time}`
  return date.toLocaleDateString(undefined, { weekday: 'long', month: 'short', day: 'numeric' })
}

export function formatTimer(ms: number): string {
  const total = Math.floor(ms / 1000)
  const m = Math.floor(total / 60)
  const s = total % 60
  return `${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}`
}
