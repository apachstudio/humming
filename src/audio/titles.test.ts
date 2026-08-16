import { describe, expect, it } from 'vitest'
import { formatDuration, formatRecordedAt, formatTimer, titleForHum } from './titles'

describe('titles', () => {
  it('increments unused morning titles', () => {
    const morning = new Date('2026-08-16T09:14:00')
    expect(titleForHum(morning, [])).toBe('Morning Melody #1')
    expect(titleForHum(morning, ['Morning Melody #1'])).toBe('Morning Melody #2')
  })

  it('formats clocks and relative dates', () => {
    expect(formatTimer(14_000)).toBe('00:14')
    expect(formatDuration(14_000)).toBe('0:14')
    const now = new Date('2026-08-16T12:00:00')
    expect(formatRecordedAt('2026-08-16T09:41:00', now)).toMatch(/^Today/)
    expect(formatRecordedAt('2026-08-15T15:22:00', now)).toMatch(/^Yesterday/)
  })
})
