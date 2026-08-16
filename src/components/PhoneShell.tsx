import type { ReactNode } from 'react'

export function PhoneShell({ children }: { children: ReactNode }) {
  const now = new Date()
  const time = now.toLocaleTimeString(undefined, { hour: 'numeric', minute: '2-digit' })

  return (
    <div className="stage">
      <div className="phone">
        <div className="status-bar">
          <span>{time.replace(' ', '')}</span>
          <span className="status-icons">●●●</span>
        </div>
        <div className="phone-body">{children}</div>
        <div className="home-indicator" />
      </div>
    </div>
  )
}
