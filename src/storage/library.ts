import type { Hum } from '../types'

const KEY = 'humming.library.v1'

export function loadLibrary(): Hum[] {
  try {
    const raw = localStorage.getItem(KEY)
    if (!raw) return []
    const parsed = JSON.parse(raw) as Hum[]
    return Array.isArray(parsed) ? parsed : []
  } catch {
    return []
  }
}

export function saveLibrary(hums: Hum[]): void {
  localStorage.setItem(KEY, JSON.stringify(hums))
}

export function upsertHum(hum: Hum): Hum[] {
  const next = [hum, ...loadLibrary().filter((h) => h.id !== hum.id)]
  saveLibrary(next)
  return next
}

export function deleteHum(id: string): Hum[] {
  const next = loadLibrary().filter((h) => h.id !== id)
  saveLibrary(next)
  return next
}

export function getHum(id: string): Hum | undefined {
  return loadLibrary().find((h) => h.id === id)
}
