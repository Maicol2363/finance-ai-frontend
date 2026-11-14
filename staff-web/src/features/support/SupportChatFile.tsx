import { useEffect, useState } from 'react'
import { supportTicketsApi, type AttachmentSummary } from './supportTicketsApi'

const imageTypes: Record<string, string> = { png: 'image/png', jpg: 'image/jpeg', jpeg: 'image/jpeg' }

export function SupportChatFile({ ticketId, file, busy, onDownload }: {
  ticketId: number
  file: AttachmentSummary
  busy: boolean
  onDownload: (file: AttachmentSummary) => void
}) {
  const [preview, setPreview] = useState<string>()
  const mediaType = imageTypes[file.name.split('.').pop()?.toLowerCase() ?? '']

  useEffect(() => {
    if (!mediaType) return
    const controller = new AbortController()
    let url: string | undefined
    void supportTicketsApi.download(ticketId, file.id, controller.signal).then(({ content }) => {
      if (controller.signal.aborted) return
      const bytes = Uint8Array.from(atob(content), character => character.charCodeAt(0))
      url = URL.createObjectURL(new Blob([bytes], { type: mediaType }))
      setPreview(url)
    }).catch(() => { /* The download action remains available and reports failures. */ })
    return () => {
      controller.abort()
      if (url) URL.revokeObjectURL(url)
    }
  }, [ticketId, file.id, mediaType])

  return <div className="chat-file">
    {preview && <img src={preview} alt={file.name} onError={() => setPreview(undefined)} />}
    <button className="secondary-button support-file" disabled={busy} type="button" onClick={() => onDownload(file)}>Descargar {file.name}</button>
  </div>
}
