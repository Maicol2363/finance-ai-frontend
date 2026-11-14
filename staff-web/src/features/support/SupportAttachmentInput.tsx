import { useRef, useState } from 'react'

export function SupportAttachmentInput({ file, busy, onChange, compact = false }: {
  file: File | null
  busy: boolean
  compact?: boolean
  onChange: (file: File | null) => void
}) {
  const input = useRef<HTMLInputElement>(null)
  const [error, setError] = useState('')

  return <div className="support-attachment">
    <input ref={input} type="file" hidden accept=".png,.jpg,.jpeg,.pdf" onChange={(event) => {
      const selected = event.currentTarget.files?.[0]
      event.currentTarget.value = ''
      if (!selected) return
      if (selected.size === 0 || selected.size > 2 * 1024 * 1024 || !/\.(png|jpe?g|pdf)$/i.test(selected.name)) {
        setError('Elige un PNG, JPG o PDF de hasta 2 MB.')
        return
      }
      setError('')
      onChange(selected)
    }} />
    <button className={compact ? 'secondary-button chat-icon' : 'secondary-button'} disabled={busy} type="button" aria-label={file ? 'Cambiar archivo' : 'Adjuntar archivo'} title={file ? 'Cambiar archivo' : 'Adjuntar archivo'} onClick={() => input.current?.click()}>
      {compact ? <svg aria-hidden="true" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round"><path d="M20 11.5l-8.6 8.6a5 5 0 01-7.1-7.1l10-10a3.5 3.5 0 015 5l-10 10a2 2 0 01-2.8-2.8l8.6-8.6"/></svg> : file ? 'Cambiar archivo' : 'Adjuntar archivo'}
    </button>
    {file && <><span>{file.name}</span><button className="secondary-button" disabled={busy} type="button" onClick={() => { setError(''); onChange(null) }}>Quitar</button></>}
    {error && <p role="alert">{error}</p>}
  </div>
}
