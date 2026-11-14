# PB-012 — Cliente Flutter y portal de soporte

Guía reproducible, contratos, decisiones y checklist manual:
[SUPPORT-MVP.md en el backend](https://github.com/Maicol2363/finance-ai-backend/blob/codex/sup-01-backend/docs/SUPPORT-MVP.md).

Flutter comparte la sesión opaca existente y llega por Ajustes → Ayuda y soporte.
React utiliza la sesión por cookies existente. Ningún cliente decide permisos.
Actualizar refresca mensajes y estado; no hay WebSockets, push ni adjuntos.
Las categorías y límites reflejan OpenAPI, cuya autoridad conserva el backend.

Prueba real opcional del portal: `staff-web/e2e/supportReal.spec.ts`, contra la demo
exclusiva. Su contraseña se suministra por `SUPPORT_DEMO_PASSWORD`, sin trazas.
Nunca utilizar usuarios reales ni servicios de producción para esa prueba.
