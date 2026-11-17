# Corrección de vista previa de adjuntos (2026-11-17)

## Causa y reproducción

`SupportCasePanel.filesFor` ya pasa el adjunto inicial (`message_id: null`) y los
adjuntos de mensajes al mismo `SupportChatFile`. El contrato devuelve metadatos
sin MIME; PNG/JPEG se reconocen por extensión, incluidos `tmp_*.png`. Los bytes
se reciben como JSON con contenido base64 por la API autenticada de soporte:
`credentials: include`, `X-Staff-Request: 1`, `cache: no-store`.

Nginx enviaba `img-src 'self' data:`. El componente crea URLs `blob:` y el navegador
las bloquea. `onError` eliminaba la imagen; el catch de la consulta también
ocultaba el error. Por eso quedaba únicamente «Descargar …». No se trata de un
`Content-Disposition: attachment`: la respuesta es JSON y el servidor configura
`Cache-Control: no-store`. El nombre temporal conserva una extensión válida.

La regresión Playwright carga el bundle de producción y la CSP tomada de la
plantilla Nginx, con el ticket sintético #2 «No me sirve la AI», un PNG inicial
`tmp_123.png` y una imagen de mensaje. Con la CSP original falla esperando la
imagen; con `blob:` permitido pasa en escritorio y toque. No se accedió a datos
privados del ticket real de producción.

## Comportamiento

Se conserva el componente común y la descarga separada. La miniatura abre un
diálogo nativo, con Escape, botón de cierre y restauración de foco. Los eventos
del visor no llegan al diálogo padre (React propaga cancel/close de diálogos
anidados). El fallo de consulta o decodificación muestra un mensaje y el informe
seguro copiable existente. PNG/JPEG se previsualizan; otros formatos se descargan.
Las URLs temporales se revocan al desmontar y las consultas se cancelan.

Flutter reutiliza `_ChatAttachment` para solicitud y mensajes, con visor
`InteractiveViewer`, cierre y diagnóstico seguro. El mismo código sirve para
Android y Windows. Se prueba con widgets Flutter; no se afirma una prueba manual
en dispositivo Android ni ejecución nativa de Windows en este entorno Linux.

## Autorización

No se añaden URLs públicas ni se modifica la API. `TicketWorkflow.download`
verifica rol, acceso al ticket y pertenencia del adjunto antes de devolver bytes.
La prueba existente `test_attachment_access_and_write_atomicity` se ejecutó en
PostgreSQL desechable: otros clientes, agentes sin asignación y otros agentes
asignados a otros tickets reciben denegación. El dueño y el agente asignado
pueden consultar el archivo. La regresión del navegador verifica que una
respuesta 404 no ofrece miniatura/visor y conserva la descarga con sus permisos.
