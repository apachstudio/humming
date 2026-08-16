type Props = {
  title?: string
  onBack?: () => void
}

export function TopBar({ title, onBack }: Props) {
  return (
    <header className="topbar">
      {onBack ? (
        <button type="button" className="icon-btn" onClick={onBack} aria-label="Back">
          <svg viewBox="0 0 24 24" width="22" height="22" aria-hidden="true">
            <path
              d="M15 5 L8 12 L15 19"
              fill="none"
              stroke="currentColor"
              strokeWidth="1.8"
              strokeLinecap="round"
              strokeLinejoin="round"
            />
          </svg>
        </button>
      ) : (
        <span className="icon-btn-spacer" />
      )}
      <h1 className="topbar-title">{title}</h1>
      <span className="icon-btn-spacer" />
    </header>
  )
}
