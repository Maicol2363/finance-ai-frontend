# Validación de arquitectura: rol Responsable de cierre

**Fecha:** 2026-10-17
**Decisión:** no crear ni asignar un cuarto rol para la entrega del 19 de octubre.

## Modelo verificado

- `app_user` tiene un `role_id`; los roles sembrados son `user` y `admin`. El registro asigna `user` por nombre.
- El principal autenticado expone el identificador del usuario. Las rutas privadas validan bearer y pasan `principal.user_id` como propietario.
- `financial_transaction` y `account_movement` guardan `user_id`; las relaciones compuestas impiden asociar una transacción o movimiento a una cuenta de otro usuario.
- No hay membresías, hogares, organizaciones, usuarios colaboradores, invitaciones ni permisos de lectura compartida. Tampoco hay administración o entitlement premium funcional que permita resolverlo desde el cliente.

## Decisión y alternativas

Un Responsable de cierre que no puede registrar movimientos no obtiene registros de otra persona: sus consultas están aisladas al dueño autenticado. Crear el rol sin compartir datos produciría una pantalla vacía o una promesa falsa.

1. **Recomendado para el MVP:** conservar el rol `user` y presentar el cierre como un flujo personal sobre cuentas y movimientos propios ya existentes. Usar cuenta, rango de fechas, movimientos confirmados/anulados y saldo; para la demostración se carga información sintética con los formularios existentes. Esto respeta el uso personal y evita migraciones de autorización.
2. **No recomendado antes del 19 de octubre:** habilitar cuentas compartidas o un espacio de trabajo. Requiere membresía/propiedad compartida, invitaciones, permisos por operación, cambios de consultas en todas las rutas financieras, pruebas de aislamiento y migración. Es un alcance de seguridad, no solo una etiqueta de rol.
3. **Descartado:** ocultar funciones en Flutter o marcar al usuario como `admin`. El cliente no es un límite de autorización; además `admin` no tiene permisos de negocio definidos y ampliaría el acceso de manera insegura.

La diferenciación defendible es el **cierre personal por cuenta y periodo**, no un cuarto rol ni conciliación multiusuario. No se afirma conciliación bancaria automática ni acceso a datos de terceros. La auditoría conserva la UI compacta actual; esta decisión no implementa ni cambia roles.

## MVP implementable

Demostrar con un usuario normal y datos sintéticos: registrar cuenta y movimientos de muestra con las funciones actuales; revisar el historial filtrado por cuenta y periodo; verificar balance sin mezclar monedas y distinguir movimientos confirmados de anulados. Cualquier saldo externo se compara manualmente fuera de la aplicación hasta que exista una historia aprobada para importar extractos o persistir una conciliación.

## Criterios de aceptación

- Un registro nuevo recibe siempre el rol `user`.
- El usuario solo lee o modifica cuentas, transacciones e historial propios; el `user_id` procede de la sesión, nunca de un identificador enviado por el cliente.
- La demostración crea datos ficticios dentro de una cuenta de prueba y verifica cuenta, periodo, moneda y estado del movimiento.
- No se muestra un cuarto rol, plan premium, permisos de administración ni conciliación compartida como capacidad disponible.
- Un futuro MVP multiusuario requiere antes criterios de membresía, permisos mínimos, invitación/revocación y pruebas negativas entre dos usuarios en todas las operaciones financieras.

## Evidencia de código

- Backend: `src/finance_ai/db/models/identity.py`, `src/finance_ai/db/seeds.py`, `src/finance_ai/db/models/transactions.py`, `src/finance_ai/accounts/dependencies.py` y `src/finance_ai/accounts/router.py`.
- Backend: `src/finance_ai/expenses/router.py` y `src/finance_ai/db/repositories/expenses.py` aplican el propietario autenticado en las operaciones.
- Los commits de backend disponibles se mantienen en su worktree separado; no se integran ni se publican desde esta rama frontend.
