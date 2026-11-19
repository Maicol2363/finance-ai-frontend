import { useEffect, useId, useRef, useState } from 'react'
import { SupportDiagnosticPanel } from './SupportDiagnosticPanel'
import { safeSupportDiagnostic, SupportTicketsApiError, supportTicketsApi, type AttachmentSummary, type SupportDiagnostic } from './supportTicketsApi'

const imageTypes: Record<string, string> = { png: 'image/png', jpg: 'image/jpeg', jpeg: 'image/jpeg' }

export function SupportChatFile({ ticketId, file, busy, onDownload }: {
  ticketId: number
  file: AttachmentSummary
  busy: boolean
  onDownload: (file: AttachmentSummary) => void
}) {
  const [preview, setPreview] = useState<string>()
  const [failure, setFailure] = useState<SupportDiagnostic>()
  const dialog = useRef<HTMLDialogElement>(null)
  const trigger = useRef<HTMLButtonElement>(null)
  const diagnosticId = useId()
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
    }).catch((error: unknown) => {
      if (!controller.signal.aborted) setFailure(safeSupportDiagnostic(error, 'attachment'))
    })
    return () => {
      controller.abort()
      if (url) URL.revokeObjectURL(url)
    }
  }, [ticketId, file.id, mediaType])

  function invalidImage() {
    dialog.current?.close()
    setFailure(safeSupportDiagnostic(new SupportTicketsApiError(0, 'invalid_response', null, 'attachment'), 'attachment'))
  }

  return <div className="chat-file">
    {mediaType && !preview && !failure && <p role="status">Cargando vista previa…</p>}
    {preview && !failure && <>
      <button className="chat-preview" ref={trigger} type="button" aria-label={`Abrir imagen ${file.name}`} onClick={() => dialog.current?.showModal()}>
        <img src={preview} alt={file.name} onError={invalidImage} />
      </button>
      <dialog ref={dialog} className="support-image-viewer" aria-label={`Imagen ${file.name}`} onCancel={event => event.stopPropagation()} onClose={event => { event.stopPropagation(); trigger.current?.focus() }}>
        <button className="secondary-button" type="button" autoFocus onClick={() => dialog.current?.close()}>Cerrar imagen</button>
        <img src={preview} alt={file.name} onError={invalidImage} />
      </dialog>
    </>}
    {failure && <>
      <p role="alert">No se pudo mostrar la vista previa. Puedes intentar descargar el archivo.</p>
      <SupportDiagnosticPanel diagnostic={failure} id={diagnosticId} />
    </>}
    <button className="secondary-button support-file" disabled={busy} type="button" onClick={() => onDownload(file)}>Descargar {file.name}</button>
  </div>
}
