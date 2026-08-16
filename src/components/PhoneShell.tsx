import type { ReactNode } from 'react'

export function PhoneShell({ children }: { children: ReactNode }) {
  const now = new Date()
  const time = now.toLocaleTimeString(undefined, { hour: 'numeric', minute: '2-digit' })

  return (
    <div className="stage">
      <div className="phone">
        <div className="status-bar">
          <span>{time.replace(' ', '')}</span>
          <span className="status-icons" aria-hidden="true">
            <svg viewBox="0 0 18 12" width="18" height="12">
              <rect x="0" y="8" width="3" height="4" rx="0.6" fill="currentColor" />
              <rect x="5" y="5" width="3" height="7" rx="0.6" fill="currentColor" />
              <rect x="10" y="2" width="3" height="10" rx="0.6" fill="currentColor" />
              <rect x="15" y="0" width="3" height="12" rx="0.6" fill="currentColor" opacity="0.35" />
            </svg>
            <svg viewBox="0 0 16 12" width="16" height="12">
              <path
                d="M1 8.5a7 7 0 0 1 14 0"
                fill="none"
                stroke="currentColor"
                strokeWidth="1.6"
                strokeLinecap="round"
              />
              <path
                d="M4 10a4 4 0 0 1 8 0"
                fill="none"
                stroke="currentColor"
                strokeWidth="1.6"
                strokeLinecap="round"
              />
              <circle cx="8" cy="11" r="1.1" fill="currentColor" />
            </svg>
            <svg viewBox="0 0 25 12" width="25" height="12">
              <rect x="0.5" y="1" width="21" height="10" rx="2.2" fill="none" stroke="currentColor" strokeWidth="1.2" />
              <rect x="2.2" y="2.7" width="16" height="6.6" rx="1" fill="currentColor" />
              <rect x="22.2" y="4" width="1.8" height="4" rx="0.6" fill="currentColor" />
            </svg>
          </span>
        </div>
        <div className="phone-body">{children}</div>
        <div className="home-indicator" />
      </div>
    </div>
  )
}
