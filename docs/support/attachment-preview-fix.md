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

## Resultado de validación y alcance de promoción

- Flutter: formato de 227 archivos sin cambios, análisis sin incidencias, 647
  pruebas aprobadas, una omitida existente; cobertura 85,94 % (12479/14520 líneas).
- Staff Web: lint, typecheck y build correctos; 269 pruebas Vitest aprobadas;
  cobertura configurada 95,09 % líneas / 86,48 % ramas; npm audit sin incidencias.
- Playwright general: 14 aprobadas, 11 opt-in omitidas. Además, ejecución opt-in
  real con API y PostgreSQL desechables: conversación, adjunto inicial heredado,
  imagen de mensaje, visor y comparación de bytes descargados aprobados.
- Regresiones CSP escritorio/toque: aprobadas, incluidos error HTTP, imagen
  corrupta, foco tras cierre y descarga. La CSP original hace fallar la regresión.
- Backend de `develop`: 18 pruebas unitarias/API relevantes y una prueba real de
  autorización de adjuntos en PostgreSQL aprobadas. No se modificó el backend.
- Publicación Drive: tres pruebas offline aprobadas; actionlint de los workflows
  correcto. La publicación real depende de los requisitos de android-release.

La base de trabajo es `develop` en `2d21e55e0977dbe0f485e892fafd7ddbd1e4a20a`.
Se integró `main` en `22ebbad` en la rama de corrección para resolver el conflicto
previsto de `release-android-integration.yml` y conservar sus cambios: integración
con emulador manual, CI en push a main y build Android sin dispositivo. A la fecha
de revisión no había commits exclusivos de develop pendientes de promoción.
El alcance previsto hacia main comprende la corrección web/Flutter, sus pruebas,
la versión `0.8.1+10`, el workflow/script de publicación del mismo ID y esta
documentación; no incluye cambios de backend, datos ni permisos de Drive.
