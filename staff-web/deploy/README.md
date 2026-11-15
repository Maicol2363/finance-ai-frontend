# Staff Web en Cloud Run

El portal usa React para la interfaz y Nginx para servir la SPA y enviar `/api/` a `finance-api` por HTTPS. Cloud Run proporciona el origen público. Staff Web requiere una versión de FastAPI con las rutas de sesión, soporte y auditoría.

## Primera publicación

1. Confirmar las ramas y fijar el SHA completo del frontend con ambos roles. Ejecutar `npm ci`, `npm run lint`, `npm run typecheck`, `npm test` y `npm run build` desde `staff-web/`. Desde la raíz del frontend, construir con `docker build --platform linux/amd64 --label "org.opencontainers.image.revision=$SHA" -t "$IMAGE" staff-web`. Usar el repositorio regional existente `finance-ai` y el nombre de imagen `staff-web:$SHA`.
2. Confirmar el estado de facturación y probar el prerrequisito de backend con el procedimiento de abajo. Para registrar el origen exacto, se puede crear primero `finance-staff-web` con IAM de invocación privado. Usar el digest publicado en Artifact Registry, `STAFF_API_HOST` con el hostname devuelto por `gcloud run services describe finance-api`, e identidad de ejecución dedicada sin roles adicionales. Usar los límites del workflow y `--invoker-iam-check`. Consultar el `status.url` de Staff Web y usar exactamente ese origen, sin barra final.
3. Tras la actualización autorizada de FastAPI, ejecutar `bash staff-web/deploy/verify-staff-api.sh "$API_URL" "$STAFF_URL"`. Si pasa, habilitar el acceso público de Staff Web mediante la política de invocación del nuevo servicio. FastAPI conserva la autorización de cada operación.
4. Ejecutar `bash staff-web/deploy/verify-staff-api.sh "$STAFF_URL" "$STAFF_URL"` y `node staff-web/deploy/verify-browser.mjs "$STAFF_URL"` desde la raíz del frontend, con Chromium instalado por Playwright. Los checks comprueban el proxy, la denegación de solicitudes anónimas o de otro origen y la carga de rutas/recursos en un navegador. Probar login, MFA, cookies, rol cruzado, sesión, tickets e informes con cuentas y registros de prueba ya autorizados. Usar un entorno aislado para cambios de tickets u otros datos de producción.

## Actualización necesaria de FastAPI

- Confirmar que el PR de release hacia `main` incluye STAFF-01, soporte, Security Auditor y los cambios del workflow de migraciones. La referencia inspeccionada fue el PR #41, con `develop` en `a2a021428d3d80865213027bd0104b9519fa0e8a`. Fusionar ese PR dispara el despliegue al completarse CI. La fusión y las modificaciones a `finance-api` requieren autorización explícita.
- Antes de fusionar, registrar revisión activa y configuración efectiva, validar permisos de migración de la conexión directa de Neon ya configurada en GitHub y ensayar las migraciones y semillas sobre datos aislados. Revisar el plan de recuperación de Neon junto con la revisión de Cloud Run, porque revertir tráfico no revierte el esquema.
- Preparar `FINANCE_AI_CORS_ALLOWED_ORIGINS` con el origen HTTPS exacto, preservando orígenes permitidos previos. Configurar `FINANCE_AI_STAFF_MFA_ENCRYPTION_KEY` mediante Secret Manager con una clave válida de 32 bytes en base64url. Reutilizar la clave existente si ya cifra autenticadores. Otorgar acceso solamente a la identidad de ejecución del backend. Preservar la configuración de producción, la conexión de ejecución, el ingreso y los límites actuales.
- Verificar que el flujo de release conserve los límites efectivos de Cloud Run. La revisión inspeccionada tenía 1 vCPU, 512 MiB, concurrencia 80 y un máximo de 3 por revisión con máximo de servicio 20. Revisar el comando del workflow, que incluye escalado por revisión, para confirmar el efecto antes de aprobar.
- Tras el release comprobar `/health/ready`, el contrato público vía `verify-staff-api.sh` y los controles de origen y cookies. La prueba anónima de refresh exige HTTPS válido según FastAPI y una respuesta 401 tras validar el origen. Mantener la validación de transporte y revisar la confianza en cabeceras del servidor ASGI si falla.

## Actualizaciones del portal

El workflow manual se ejecuta desde `main` sobre el servicio ya creado y habilitado. Configurar el entorno de GitHub `staff-web-production` para permitir despliegues solo desde `main`. Configurar sus variables `STAFF_WIF_PROVIDER`, `STAFF_DEPLOY_SERVICE_ACCOUNT` y `STAFF_RUNTIME_SERVICE_ACCOUNT`.

La condición del proveedor de Workload Identity Federation debe restringir la identidad al repositorio frontend y a `refs/heads/main`. La identidad de despliegue necesita escritura en el repositorio regional `finance-ai`, lectura del servicio `finance-api`, rol Cloud Run Developer sobre `finance-staff-web` y capacidad de actuar como la cuenta de ejecución de Staff Web. Mantener la cuenta de ejecución separada de la identidad de despliegue y del backend.

Después de promover a `main`, ejecutar **Deploy Staff Web to Cloud Run** desde Actions. El workflow publica la imagen etiquetada con el SHA y despliega su digest. Para controlar el almacenamiento, revisar el tamaño y conservar los digests que sirven tráfico o hacen falta para una reversión.
