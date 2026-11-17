# APK automática en el QR existente

El workflow **Release Android integration** conserva la integración manual con
emulador. Su nuevo job `publish-android` se dispara cuando **Frontend CI** termina
correctamente para un push a `main`, hace checkout del SHA probado y publica
únicamente si ese SHA sigue siendo el HEAD de `main`.

## Configuración necesaria en `android-release`

- Variable `ANDROID_RELEASE_API_BASE_URL`: URL HTTPS de la API pública que ya usa
  la APK distribuida. El valor por defecto del código es solo para el emulador y
  no sirve para una release.
- Secreto `ANDROID_DEBUG_KEYSTORE_BASE64`: base64 del **mismo** `debug.keystore`
  utilizado para firmar la APK actual. Gradle ya firma release con la configuración
  `debug`; se conserva esta configuración (alias/contraseñas Android por defecto).
  No generar ni sustituir esta clave: se compara el certificado de ambas APK antes
  de publicar. Una migración a otra firma requiere un proceso separado.
- Secreto `DRIVE_AUTHORIZED_USER_JSON`: JSON OAuth de usuario autorizado con
  `client_id`, `client_secret` y `refresh_token`, con scope Drive que permita editar
  el archivo existente. La identidad tiene que tener permiso de editor o dueño
  sobre `1z__jJblXcb8MC2PZvE1tJzy3Kkh2GFgs`. No se leen secretos ni se cambian
  permisos desde este script.

La conexión de esta sesión no pudo listar secretos/variables de Actions (403).
Estos nombres son requisitos del nuevo job; su existencia no está confirmada.
Un administrador debe habilitar auto-merge en el repositorio: la configuración
consultada tiene `allow_auto_merge=false` y la conexión tiene push pero no admin.

## Artefacto y publicación

Se usa la versión de `pubspec.yaml` (`0.8.1+10` para esta corrección) y el mismo
formato arm64 por ABI que la APK del QR: nombre de versión `0.8.1`, código `2010`.
Se verifica con `apksigner`, se comprueba la continuidad del certificado frente a
la descarga pública actual y se conserva la APK con su versión y SHA-256 como
artefacto de CI. No se distribuye una APK generada con una clave nueva de runner.

El PATCH de media actualiza el contenido del mismo ID, conserva nombre, carpetas,
permisos y URL, y repetir la ejecución actualiza ese mismo destino. Tras publicar
se comparan el SHA-256 de Drive y el de una descarga anónima con el generado en
CI. Un fallo de descarga, permisos, firma o checksum deja el job fallido y conserva
el artefacto generado. Nunca se registra el token ni la respuesta de OAuth.

URL del QR:
https://drive.google.com/file/d/1z__jJblXcb8MC2PZvE1tJzy3Kkh2GFgs/view?usp=drivesdk

Prueba sin red de la publicación y sus reintentos:
`python .github/scripts/test_publish_android_drive.py`.
