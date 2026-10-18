# Auditoría de presentación: validación final

**Fecha:** 2026-10-17
**Base:** `origin/develop` `e5be471`
**Rama aislada:** `codex/presentation-audit-20261017`
**Estado:** validación local completada; sin push ni merge.

## Resultado automatizado

| Verificación | Resultado |
|---|---|
| Flutter | 559 pruebas aprobadas; 0 fallidas |
| Flutter analyze | PASS, sin problemas |
| Formato y `git diff --check` | PASS |
| Backend PostgreSQL aislado | 415 aprobadas, 0 omitidas, 0 fallidas; Ruff PASS |
| APK release ARM64 | PASS, 33.9 MB; paquete `com.nullcorvus.finance_ai.release_audit`, versión 0.8.0, código 2008; base URL aislada `http://127.0.0.1:8016` |
| Instalación en dispositivo | PASS con `adb install -r`; SHA-256 instalado y artefacto: `6ee6692bdb87e0ca68645a9fe945eb8b6895aa1556f2c334d5021ee68ec94f90` |
| Aplicación habitual | Conserva `com.nullcorvus.finance_ai`, versión 0.8.0, código 8; no se limpió ni desinstaló |

## Recorrido Android con datos sintéticos

Se registró e inició sesión con un usuario ficticio contra API local aislada. En el perfil sintético actual se creó `DemoEfectivo`, dos gastos de 9.000 y 7.000 COP y un ingreso Salary de 15.000 COP. Inicio muestra ingresos de +15.000 COP, gastos de -16.000 COP y balance de -1.000 COP. Tras la reinstalación con `adb install -r`, la sesión y los datos siguieron disponibles. Historial muestra los dos gastos y el ingreso con cuenta, categoría y fecha.

También se recorrieron Inicio, cuentas, categorías, fuentes de ingreso, presupuesto mensual de 60.000 COP con 20% usado, ajustes y temas claro/oscuro. Registro, login, permisos de cámara y micrófono fueron visitados. Los permisos de cámara/micrófono se denegaron y los flujos se cerraron sin capturar una foto ni grabar audio. El menú flotante se abrió; Back lo cerró y cambiar de pestaña también lo cerró. La captura rápida abrió; Back ocultó primero el teclado y luego cerró la hoja.

No se ejecutaron captura real de recibo, reconocimiento de voz ni envío de una propuesta a IA. Los tests automatizados de voz y los pasos hasta permisos no demuestran reconocimiento hablado. No se inspeccionó cada combinación de accesibilidad con TalkBack; la revisión de semántica y targets táctiles está cubierta por tests de widgets.

Evidencia local sin credenciales: `artifacts/android/presentation-audit-release-20261017/` (capturas y jerarquías de pantallas recorridas). Se comprobó que las jerarquías guardadas no contienen el correo sintético.

## Segunda pasada física posterior a la instalación final

En el perfil sintético de auditoría se creó una cuenta adicional `CuentaAhorro` para cubrir transferencias. Se registró una transferencia interna de 100 COP desde `CuentaDemo` para el 16 de octubre de 2026; la lista de cuentas reflejó el movimiento en ambos saldos. Historial mostró dos movimientos tras limpiar los filtros: el gasto existente y la transferencia bajo el grupo “Ayer”, correspondiente al 16 de octubre en el dispositivo con fecha 17 de octubre. No se modificó la app de paquete habitual. La pantalla de transferencia y el Historial tienen evidencia en `final-transfer-form.png/xml` y `final-transfer-history.png/xml`.

Se confirmó también el filtro físico combinado de tipo, origen, registro, comercio y cuenta, con resultado limitado a `CafeFinal` y `CuentaDemo`; evidencia en `final-filter-modal.png/xml`, `filter-chips-selected.png/xml` y `filter-result-final.png/xml`. Login en landscape y formulario/registro cuentan con capturas limpias de la pasada final. La instalación conservó el paquete aislado `com.nullcorvus.finance_ai.release_audit`; hash del APK instalado y del artefacto verificado: `6ee6692bdb87e0ca68645a9fe945eb8b6895aa1556f2c334d5021ee68ec94f90`.

No se abrió el detalle de transferencia porque el elemento de resumen de Historial no expuso navegación al tocarlo; sí se verificó la fecha elegida en el formulario y el día mostrado en la lista. No se capturó recibo ni se envió propuesta a IA. Una captura temporal que mostró sugerencias personales del sistema durante la prueba de teclado fue eliminada; no se conserva ni se documenta su contenido.

## Cierre tras regresión de carga incremental

`HistoryController.loadMore()` ahora consume una solicitud de recarga en su bloque `finally`, igual que `load()`, por lo que un refresh solicitado durante la carga de una página termina recargando desde la primera página. La regresión usa un `Completer` controlado para no depender de timing. La suite final ejecutó 559 pruebas visibles y aprobó todas; analyzer y `git diff --check` también pasan.

Para el APK release se excluyó temporalmente `integration_test` del `GeneratedPluginRegistrant.java` generado y no rastreado, porque Flutter lo registraba como dependencia dev-only en el classpath release y Gradle fallaba al compilar. Se reconstruyó con `--no-pub`; se restauró el archivo generado original después, no se modificó ni versionó como fuente. APK ARM64 instalada con `adb install -r`; hash instalado/artefacto: `6ee6692bdb87e0ca68645a9fe945eb8b6895aa1556f2c334d5021ee68ec94f90`. Tras instalar, la sesión y los movimientos sintéticos permanecieron visibles en Historial.

La API aislada está activa en `127.0.0.1:8016`; PostgreSQL corre en el contenedor de auditoría y usa solo `tmpfs`, publicado en loopback. La API se reinició desde la configuración privada local existente y quedó `ready`. No se limpió ni desinstaló la app; `com.nullcorvus.finance_ai` conserva versión 0.8.0, código 8. No se modificó el backend remoto ni datos reales. La prueba de backend corrió en su worktree aparte.

## Regresión de recarga del historial

Se corrigió una carrera al registrar un movimiento desde el estado vacío: el CTA conserva la ruta de Historial, y el controlador repite una recarga solicitada mientras una carga anterior sigue en curso. Las dos regresiones de gasto e ingreso pasan; el recorrido físico posterior a reinstalar muestra los tres movimientos en Historial.

## Cambios principales

- Espaciado y mensajes en español en autenticación; formulario manual continúa si catálogos opcionales fallan, pero sesión y cuentas siguen siendo obligatorias.
- Menú de captura responde primero a Atrás; se cierra al cambiar de pestaña y captura rápida usa el navegador raíz.
- Historial calcula balance desde todos los movimientos confirmados de los registros cargados, respeta cuenta y moneda, y conserva la fecha API para ingresos y transferencias.
- Totales recorren páginas completas hasta un límite explícito y fallan en vez de devolver un parcial; periodos anteriores se ocultan mientras cargan métricas de otra ventana; los anulados quedan fuera de las sumas.
- Diagnósticos aceptan solo códigos técnicos estructurados permitidos y ocultan contenido crudo/sensible. Release bloquea HTTP remoto y permite loopback de auditoría.
- Se preservó el diseño compacto y la paleta actuales; acciones y objetivos táctiles accesibles se validaron en widget tests.

## Decisión de arquitectura y extensión

El informe [`role-architecture-decision.md`](role-architecture-decision.md) recomienda no crear un cuarto rol: el backend no tiene membresías ni acceso compartido, y cada recurso financiero se filtra por el `user_id` del principal autenticado. El MVP demostrable antes del 19 de octubre es un cierre personal sobre movimientos propios y datos sintéticos; no se implementó rol, sharing, permiso premium ni conciliación bancaria automática.

Security Baseline está habilitada: privacidad de diagnósticos, propiedad por usuario y restricción de HTTP remoto se verificaron en código/tests. Resiliency Baseline está deshabilitada y no se añadió alcance de resiliencia. Property-Based Testing está parcial; esta entrega añade regresiones deterministas, no fuzzing nuevo. Esto no es certificación de producción.

## Auditoría ampliada de UI por pantalla

| Pantalla/flujo | Estado | Observación y alcance |
|---|---|---|
| Login y registro | PASS físico; landscape PASS | Marca compacta y CTA visible en horizontal; confirmaciones y errores conocidos en español, sin pasar texto crudo del backend. |
| Inicio y Análisis | PASS físico | Se recorrieron ventanas y selector de periodo; resumen se adapta con `Wrap` a ancho corto. |
| Movimientos, filtros y detalle | PASS físico para filtros, detalle de gasto e historial | Se aplicaron cinco filtros simultáneos y el modal no cubre navegación/FAB; transfer detail no se abrió desde el resumen. |
| Cuentas | PASS físico | Lista, creación, detalle y edición con cuenta sintética. |
| Gastos | PASS físico | Formulario, validación, creación y detalle; Historial se actualiza después de crear. |
| Ingresos y fuentes | PASS físico | Formulario, lista y detalle; las etiquetas visibles se localizan sin cambiar `incomeSourceId`. |
| Transferencias | PASS físico de formulario y fecha en Historial | Fecha elegida conserva el día y se muestra localmente; detalle no expuso navegación en el recorrido. |
| Categorías | PASS físico | Lista y alta de categoría sintética. |
| Presupuestos | PASS físico | Lista, alta y edición; ayudas permiten hasta dos líneas. |
| Ajustes y temas | PASS físico | Ajustes y modos claro/oscuro. |
| Captura rápida y chat | PASS de apertura/cierre | No se envió contenido real ni solicitud de IA. |
| Recibo, cámara y voz | PARCIAL / NOT RUN | Se abrió la entrada a cámara, pero se denegó permiso y no se tomó foto. No se ejecutó revisión de imagen, propuesta IA ni dictado real. |
| Accesibilidad | PARCIAL | Etiquetas/targets revisados con pruebas de widgets; no se ejecutó TalkBack ni todas las escalas de fuente físicamente. |

Correcciones UI de esta pasada: separación segura entre sugerencias de comercio y selector Cuenta; resumen de Historial adaptable; login compacto en landscape; mensajes de registro y fallos de autenticación localizados y sanitizados; etiquetas visuales conocidas (por ejemplo Necesidades, Salario y Peso colombiano) sin alterar IDs/códigos de API; fecha de transferencia presentada en formato local sin convertir la fecha API; textos de ayuda de cuenta/presupuesto con wrap.

La revisión crítica detectó y corrigió una recarga perdida si se solicita mientras `loadMore()` pagina Historial. Ahora se consume la solicitud pendiente al concluir la página; un test con `Completer` controlado cubre la carrera. Tests de formulario comprueban que la etiqueta “Salario” conserva `incomeSourceId: 4` y los tests de cuenta/presupuesto conservan moneda y categoría originales.

La validación final queda en 559 pruebas Flutter PASS, `flutter analyze` PASS, `git diff --check` PASS, APK ARM64 instalada y SHA verificado arriba. Un intento aislado de debug build falló por incompatibilidad de JDK 27 (`jlink` al transformar Android API 36); la variante de presentación release se construyó e instaló correctamente. El registro generado de `integration_test` requirió exclusión temporal local durante el release build; se restauró y quedó fuera de Git. Las capturas de pantalla permanecen en `artifacts/android/presentation-audit-release-20261017/`.

## Corrección de Vosk/JNA en APK release

La build release anterior tenía R8 activo por la configuración Android/Flutter y su mapping renombraba `com.sun.jna.Pointer.peer` a `i`; la excepción observada en `Native.initIDs` coincide con esa pérdida del nombre requerido por JNI. Se conservó minificación y se añadió `-keep class com.sun.jna.** { *; }`, además de `-dontwarn java.awt.**` para los helpers desktop opcionales de JNA que Android no incluye. El mapping nuevo conserva `com.sun.jna.Pointer` y ya no registra el miembro `peer` como renombrado. La build ARM64 release y `adb install -r` al paquete separado `com.nullcorvus.finance_ai.release_audit` pasaron. APK instalada y artefacto SHA-256: `ee8e7a0ca792aff55e018ac8449e0286e010a42dea8582b40a3a912bec51cda5`.

Tras el cambio: `flutter analyze` PASS; `flutter test --no-pub --reporter json` PASS (633 tests, 0 fallos); `git diff --check` PASS. El primer intento Gradle reveló nuevamente el registro generado no rastreado de `integration_test` en release; se excluyó temporalmente, se restauró el archivo y no quedó en Git. R8 también requirió suprimir referencias opcionales `java.awt` de JNA, sin ocultar warnings de otras clases.

La validación física de preparación/dictado queda NOT RUN: el API local `127.0.0.1:8016` no estaba escuchando y el inicio de sesión queda en “Checking your session”. El CTA disponible borraría la sesión local, por lo que no se usó; el worktree backend solo contiene plantillas de configuración, no una configuración privada local recuperable. El contenedor de la base sintética se dejó intacto. No se obtuvo transcripción ni se guardó/envió una operación. La ausencia de `speech_fallback_unavailable` está confirmada en el mapping de la nueva APK, pero requiere revalidación en runtime cuando el API aislado esté disponible.

## Corrección de dictado y errores en español (2026-10-17)

| Verificación | Resultado |
|---|---|
| `flutter analyze` | PASS |
| `flutter test --no-pub --reporter json` | 633 pruebas aprobadas, 0 fallidas |
| Catálogo de errores de dictado | 21 códigos conocidos y códigos nativos desconocidos cubiertos; el usuario recibe mensajes españoles y no se filtran detalles privados |
| Regla R8/JNA | PASS; se conserva `com.sun.jna.**` para JNI/reflexión; se mantiene minificación |
| APK ARM64 de presentación | PASS; `com.nullcorvus.finance_ai.release_audit`, 0.8.0 (2008) |
| Instalación ADB | PASS; paquete de auditoría actualizado; paquete habitual intacto |
| SHA-256 de APK | `ee8e7a0ca792aff55e018ac8449e0286e010a42dea8582b40a3a912bec51cda5` |
| Dictado real con transcripción | NOT RUN: API local `127.0.0.1:8016` no tiene listener y la app permanece en comprobación de sesión. El worktree backend aislado no tiene `.env`; no se reutilizaron credenciales ni se tocaron datos o base de auditoría. |

La causa de `speech_fallback_unavailable` era R8 cambiando el nombre del campo `com.sun.jna.Pointer.peer`, que JNA necesita localizar desde código nativo. La regla ProGuard mantiene intactos JNA y sus miembros. La corrección está instalada, pero no se declara validado el reconocimiento de voz hasta probarlo con sesión disponible y obtener una transcripción sintética visible en el campo de edición.

APK instalada localmente: `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`. Para probar las pantallas que requieren sesión, primero debe iniciarse el backend aislado en el puerto 8016 y conservar el reverse ADB configurado. Después, abrir la aplicación “Finance AI (auditoría)”, iniciar sesión con la cuenta sintética existente, abrir captura por voz, permitir micrófono si se solicita y dictar una frase ficticia. Verificar que el texto aparece para edición; no pulsar enviar ni guardar.

## Validación física final del dictado offline

La API aislada se recuperó sin tocar el paquete habitual ni reiniciar la base. Se verificó el contenedor `finance-ai-audit-postgres-20261016`: PostgreSQL 18.6, mount `tmpfs` en `/var/lib/postgresql`, puerto host `127.0.0.1:32768`, base `finance_ai_audit_test` y rol `finance_audit`. La API local se conectó a esa base, aplicó migraciones/seeds del servicio y quedó healthy en `127.0.0.1:8016`; la APK requiere `--dart-define=FINANCE_AI_API_BASE_URL=http://127.0.0.1:8016` (la propiedad Gradle no establece el valor Dart). Se configuró `adb reverse tcp:8016 tcp:8016`.

La causa restante tras conservar `Pointer.peer` fue otra eliminación de R8: `org.vosk.Model()` público sin argumentos estaba presente en el AAR, pero figuraba como removido en `usage.txt`. JNA lo construye mediante reflexión al registrar métodos nativos. Se agregó `-keep class org.vosk.** { *; }` junto a la regla de JNA; en el mapping final `org.vosk.Model.<init>()` se conserva y el DEX mantiene `Pointer.peer` como campo `long`. Se mantuvo la minificación activa. El log nativo temporal es acotado, sanea caracteres y registra solo la cadena de clases/mensajes de fallo de enlace, nunca audio, texto dictado ni datos del formulario.

Con la APK release instalada en `com.nullcorvus.finance_ai.release_audit`, la preparación en español pasó y la captura mostró “Escuchando…”. Reproduje audio TTS sintético en español, el reconocedor produjo texto temporal y lo descarté desde la UI antes de cualquier envío/guardado. No se conservó ese texto en captura, jerarquía ni documentación. La app quedó en Inicio; sesión y movimientos sintéticos permanecieron visibles. Evidencia sin transcripción: `artifacts/android/presentation-audit-release-20261017/voice-offline-listening.png/xml` y `voice-offline-discarded.png/xml`.

APK final ARM64, construida con keep rules y Dart define local, instalada con `adb install -r`; hash del artefacto e instalado: `516699955a52a969eb426bc8c4dfee54477082ee7ffe2da1c07c28d220e3650e`. `/health/ready` respondió 200. `flutter analyze` y suite Flutter completa (633 tests) pasaron antes de los cambios Kotlin/ProGuard finales; para estos cambios se completaron build release y prueba física en el dispositivo. `git diff --check` pasa.

> **Estado final / sustituye resultados previos de esta página:** los primeros builds tenían `speech_fallback_unavailable` y la API ausente; ya se corrigió ambos. Resultado vigente: API local sana en 8016, APK ARM64 final instalada, preparación es-ES y escucha/reconocimiento sintético PASS; se descartó el texto antes de enviar o guardar. SHA vigente: `516699955a52a969eb426bc8c4dfee54477082ee7ffe2da1c07c28d220e3650e`. Los resultados NOT RUN y el hash `ee8e…` de las secciones anteriores documentan intentos anteriores y quedan sustituidos por la validación física final.

## Regresión de flecha Atrás en Ajustes y formularios

| Verificación | Resultado |
|---|---|
| Flujo Ajustes → Cuentas → Nueva cuenta → Atrás → Cuentas → Atrás → Ajustes | PASS físico en Android; formulario vacío, sin guardar |
| Tests dirigidos de login/router + cuentas, categorías, presupuestos y transferencias | 22 PASS, 0 FAIL |
| `flutter analyze` | PASS |
| Build/install `release_audit` ARM64 | PASS; SHA-256 artefacto e instalado: `8bbf47e7dc78d621a11b91c15b66ed98c4dc9deceb46e8ad73219d4e4d0183b7` |
| `git diff --check` | PASS |

La raíz era que algunos formularios ejecutaban `go()` al volver o terminar una mutación. Eso reemplazaba la pila y hacía que la flecha siguiente perdiera el origen Ajustes. Ahora los formularios usan `pop()` si existe una pantalla anterior; solo usan rutas de respaldo al entrar de forma directa. También se cambió el tooltip de la flecha de Cuentas, y se cubrieron categorías, presupuestos y transferencias, además de la cuenta. El detalle de cuenta preserva el listado al volver de una eliminación. Evidencias: `artifacts/android/presentation-audit-release-20261017/accounts-list-backflow.png/xml` y `new-account-form-backflow.png/xml`.

## Proyección de periodos cerrados y códigos de diagnóstico visibles (2026-10-17)

| Verificación | Resultado |
|---|---|
| Test de mes anterior cerrado | PASS |
| 10 suites afectadas por cambios de diagnóstico | PASS, 137 tests |
| `flutter analyze --no-pub` | PASS |
| Release ARM64, instalación y lanzamiento en `com.nullcorvus.finance_ai.release_audit` | PASS; datos locales conservados |
| Verificación física Análisis → Mes anterior | PASS; muestra “Periodo cerrado al 30 de septiembre: se muestran los gastos reales, sin proyección.” |
| Códigos técnicos en UI | No visibles; se conservan solo en el reporte seguro copiado voluntariamente y con etiquetas en español |
| SHA-256 artefacto e instalación | `1ae333e6ca33f8399d33acf3bedaa3ddce1315b0c0b00e81dcb290c284d48e90` |
| `git diff --check` | PASS |

La ausencia de proyección en un mes totalmente cerrado es intencional: no se estima gasto futuro después del fin del periodo. Los rangos que contienen días transcurridos de un periodo aún abierto pueden mostrar una proyección. El texto superior ahora distingue ambos casos en vez de presentar una fórmula de proyección en todos los periodos. Evidencia física: `artifacts/android/presentation-audit-release-20261017/analysis-last-month-closed-period.png` y `analysis-last-month-closed-period.xml`.

La interfaz deja de mostrar identificadores internos como `speech_fallback_unavailable`; el mensaje legible continúa en español. Al pulsar “Copiar detalles del error”, el reporte voluntario contiene el código técnico, hora, operación y contexto seguro con nombres de campo en español, sin datos del formulario ni secretos.

## Seguimiento de observaciones de revisión en PR (2026-10-18)

| Observación | Corrección y verificación |
|---|---|
| Home perdía totales al volver desde Análisis con otro periodo | Home valida `monthlyTotalsProvider` contra `DashboardPeriod.thisMonth` y `currentMonthWindow(now)`. Regresión cubre selección de “Mes anterior”, vuelta a `/home` y conserva ingresos/gastos actuales. |
| Desarrollo en teléfono físico bloqueado por política de cleartext | Configuración Android específica de `debug` permite HTTP LAN para pruebas. Recursos y manifiestos release mantienen cleartext remoto bloqueado; solo se conservan excepciones localhost/emulador. |
| Guardar una edición duplicaba el detalle de cuenta en la pila | Guardar una edición hace `pop()` al detalle existente, con fallback de ruta si se abre directamente. Prueba cubre guardar y volver al listado sin repetir el detalle. |
| Reintentos backend no distinguían operación recuperada ni intención modificada | Corregido en `db83815`; las tres vías informan `replayed`, y la operación se busca por usuario y proposal ID antes de ramificar por tipo. Backend CI asociado al commit: success. |

| Validación local frontend | Resultado |
|---|---|
| `flutter test --no-pub` | PASS, 565 pruebas |
| `flutter analyze --no-pub` | PASS |
| `dart format --output=none --set-exit-if-changed` | PASS |
| `git diff --check` | PASS |
| Merge de recursos/manifiestos Android debug y release | PASS; LAN cleartext solo en debug |
| Revisión estática final | PASS; sin bloqueos/regresiones detectados |

La regresión de Home restablece el desplazamiento del `ListView` dentro de la prueba porque la ruta conserva su posición inferior al regresar; los valores y el flujo de navegación se verifican después de llevar la lista al inicio. Las tres observaciones frontend y las dos backend están resueltas en GitHub.

## Build de revisión y disponibilidad de Android (2026-10-18)

| Verificación | Resultado |
|---|---|
| API Cloud Run existente `/health/ready` | PASS, HTTP 200; no se desplegó ni modificó infraestructura |
| APK release audit | PASS; versión 0.8.0+2009, solo ABI arm64-v8a, ZIP íntegro |
| SHA-256 | `a8fef331e9d355c3569246a7378b3c2eeebec05d885f93657eb12d3ba92c8dbb` |
| Copia en Descargas | PASS; `/home/d3ad/Downloads/FinanceAI-v0.8.0-arm64-v8a-2026-10-18-reviewfix.apk`, hash coincidente |
| Instalación y revisión visual física de esta nueva build | NOT RUN: `adb devices -l` no detectó teléfono ni emulador en dos comprobaciones; no se limpió ni alteró ningún dato local |
| CI frontend para `394fd25` | En ejecución al cerrar esta verificación; confirmar el resultado en GitHub |

En la primera comprobación el teléfono no apareció en ADB. Se reconectó después y el resultado actualizado está en la sección siguiente. La variante Android release mantiene bloqueado HTTP remoto; la configuración debug permite LAN para pruebas.

### Instalación física tras reconectar el teléfono

El Xiaomi 23021RAAEG (Android 13, serial ADB `6d3dd54`) reapareció. La APK se instaló con `adb install -r` como paquete separado `com.nullcorvus.finance_ai.release_audit`, versión 0.8.0+2009, y se abrió correctamente. La actualización preservó los datos de la variante de auditoría. Capturas y jerarquía: `artifacts/android/review-fix-20261018/initial.png` y `initial.xml`.

La pantalla abierta es el login, sin sesión sintética. No se ingresaron credenciales; por tanto el flujo físico autenticado Análisis → Mes anterior → Volver permanece NOT RUN. No se modificaron movimientos ni otros datos. La prueba de widget automatizada sí cubre el cambio de periodo y los totales de Home al regresar.

## Ventana de información del gráfico de tendencia (2026-10-17)

| Verificación | Resultado |
|---|---|
| `spending_trend_card_test.dart` | PASS, 10/10 |
| `flutter analyze --no-pub` | PASS |
| Objetivo táctil del control | PASS, 48 × 48 dp |
| Verificación física Android | PASS; título, explicación y “Entendido” permanecen tras 10 segundos; el botón cierra el diálogo |
| Release ARM64 instalada en `com.nullcorvus.finance_ai.release_audit` | PASS; datos conservados |
| SHA-256 artefacto e instalación | `6abe403fa87f14f047d448c78e0b726282c30270caeec2f0140815deb71a5576` |
| `git diff --check` | PASS |

Se sustituyó el tooltip temporal por un diálogo de explicación accesible que permanece visible hasta que la persona lo cierra. Evidencia: `artifacts/android/presentation-audit-release-20261017/trend-info-dialog-persistent.png` y `trend-info-dialog-persistent.xml`.

## Espaciado de introducción, panel de error y campos de login (2026-10-17)

| Verificación | Resultado |
|---|---|
| `login_and_router_test.dart` | PASS, 8/8 |
| `flutter analyze --no-pub` | PASS |
| Espacio entre texto introductorio y correo | PASS en test y Android físico |
| Espacio con panel de error visible | PASS; 60 px entre panel y campo en la jerarquía física |
| Mensaje de credenciales inválidas | Visible en español; sin identificador técnico |
| Release ARM64 instalada en `com.nullcorvus.finance_ai.release_audit` | PASS; no se limpiaron datos |
| SHA-256 artefacto e instalación | `815e422c957ffd2155aeab0a55508e1d7c21f744ff2f0a35470642d89069e60d` |
| `git diff --check` | PASS |

Se añadió un margen estándar de 16dp entre la introducción y el campo de correo, y un margen de 24dp cuando se muestra una confirmación o panel de estado/error. Evidencias: `artifacts/android/presentation-audit-release-20261017/login-spacing-final.png`, `login-spacing-final.xml`, `login-error-spacing-final.png` y `login-error-spacing-final.xml`. La jerarquía confirmatoria marca 60 px entre el borde inferior del banner y el comienzo del campo.

## Revisión adicional de espaciado en historial, captura IA y voz (2026-10-17)

| Verificación | Resultado |
|---|---|
| `expenses_screens_test.dart` | PASS, 39/39; separación de sugerencia de comercio a selector de cuenta validada (mínimo 20dp) |
| `text_capture_chat_test.dart` | PASS, 33/33; panel de error y aviso de reintento separados 8dp |
| `voice_chat_test.dart` | PASS, 35/35; acciones del error tienen 8dp entre elementos y filas |
| `flutter analyze --no-pub` | PASS |
| Build/install/launch ARM64 `release_audit` | PASS; datos no borrados |
| Filtro de historial en Android autenticado | NOT RUN; paquete de auditoría quedó en login y no se limpiaron datos ni se registraron movimientos para forzar la ruta |
| SHA-256 artefacto e instalación | `fc29d2899242442e127ae55107a5fea28c7df72822fba48982e35e71f5b17f34` |
| `git diff --check` | PASS |

También se revisaron las capturas disponibles de cuentas, registro, presupuesto, transferencia, gasto manual, análisis, ajustes e historial; no se observaron otros solapamientos relevantes en ese material. La captura `artifacts/android/presentation-audit-release-20261017/expense-validation.png` pertenece a una compilación anterior y muestra un código técnico ya oculto en el código actual; se marca como obsoleta y no se debe incluir en la presentación. No se reemplazó porque el paquete instalado no tenía sesión autenticada durante esta ronda.

Cumplimiento de extensiones para esta ronda: Security Baseline N/A (solo ajustes de espaciado; no cambia manejo de credenciales o permisos), Resiliency Baseline deshabilitada, Property-Based Testing N/A (cambios de layout verificados con pruebas de widgets y análisis estático).

## Entrega Android y PR (2026-10-17)

| Verificación | Resultado |
|---|---|
| APK release ABI arm64-v8a | PASS; versionName 0.8.0, versionCode 2008 |
| Endpoint configurado en APK | API Cloud Run existente: https://finance-api-7caahuohmq-rj.a.run.app; /health/ready devolvió HTTP 200 |
| Tamaño APK | 33,976,441 bytes |
| SHA-256 | 01c064ee636d0e31278ff2e88e0e655a76cb4f05f9618426efc22df6edfa5db4 |
| APK copiada a Descargas | PASS; /home/d3ad/Downloads/FinanceAI-v0.8.0-arm64-v8a-2026-10-17.apk |
| PR frontend | https://github.com/Maicol2363/finance-ai-frontend/pull/35; checks pendientes al abrir |
| PR backend | https://github.com/Maicol2363/finance-ai-backend/pull/24; checks pendientes al abrir |
| Despliegue del nuevo backend | Pendiente de CI y aprobación/merge del PR; el APK usa el servicio Cloud Run actualmente activo |
| Instalación en dispositivo | No ejecutada en esta entrega |

## Actualización inmediata de Movimientos tras guardar (2026-10-18)

| Verificación | Resultado |
|---|---|
| Confirmación de gasto con IA actualiza el historial | PASS; aserción en `text_capture_controller_test.dart` |
| Confirmación de gasto desde recibo actualiza el historial | PASS; aserción en `receipt_capture_notifier_test.dart` |
| Creación manual y navegación Inicio → Movimientos | PASS; regresión en `expenses_screens_test.dart` |
| Tests focalizados de captura IA, recibos y pantallas de gastos | PASS |
| `flutter analyze` focalizado | PASS |

Diagnóstico: las confirmaciones de IA y recibos recargaban los gastos de Inicio, pero no el proveedor de historial usado por Movimientos. Se agregó la recarga del historial en ambos caminos y pruebas de regresión. No se hizo prueba física autenticada de este flujo en esta ronda.
