import { useRef, useState } from 'react'

export function SupportAttachmentInput({ file, busy, onChange }: {
  file: File | null
  busy: boolean
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
    <button className="secondary-button" disabled={busy} type="button" onClick={() => input.current?.click()}>
      {file ? 'Cambiar archivo' : 'Adjuntar archivo'}
    </button>
    {file && <><span>{file.name}</span><button className="secondary-button" disabled={busy} type="button" onClick={() => { setError(''); onChange(null) }}>Quitar</button></>}
    {error && <p role="alert">{error}</p>}
  </div>
}
