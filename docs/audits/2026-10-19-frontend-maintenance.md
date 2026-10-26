# Auditoría de mantenimiento del frontend (Android)

Fecha: 2026-10-19. Repositorio: `finance-ai-frontend`. Rama: `codex/frontend-maintenance-fixes`, creada desde `origin/develop` en `35df926c0097a9d424c94ee2351dae5194e1da3c`. El checkout estaba limpio al iniciar. Alcance revisado: app Flutter y artefacto Android; sin cambios al backend.

## Skills y método

Se instalaron globalmente fuera del repositorio, desde `verygoodopensource/vgv-ai-flutter-plugin` (GitHub, commit `75b25128a57a97ff1705ddaa0d6bb36c864768c5`): `layered-architecture` y `license-compliance`. Se verificaron sus hashes y se leyeron ambos `SKILL.md`; también se leyeron todas las referencias de arquitectura (`data-flow.md`, `pubspec.md`, `model-transformation.md`, `testing.md`, `worked-example.md`). La primera guía se aplicó como evaluación de límites existentes, sin proponer migración general. La segunda se usó para escanear dependencias directas y transitivas y documentar pendientes. Very Good CLI 1.5.0 se instaló globalmente porque no había servidor MCP Very Good configurado.

## Hallazgos confirmados

- El análisis inicial de Dart detectó `unused_element` en `_balanceOf`, helper privado sin llamadas ni referencias en `lib/` o `test/`. Se eliminó. La prueba existente de transferencias confirma que el servidor valida el saldo y permite enviar el importe aunque supere el saldo en caché; no se cambió el comportamiento.
- La app ya agrupa código por feature y separa carpetas `domain`, `data`, `application` y `presentation`; los repositorios HTTP reciben clientes por constructor, hay proveedor configurable de API y se cierran recursos por ciclo de vida Riverpod. El grafo desde `lib/main.dart` incluye 127 de 132 archivos Dart y no mostró ciclos de importación entre archivos. No hay base para una reestructuración general.
- Hay acoplamiento de dirección inversa confirmado: `TransfersRepository` de `data` importa y recibe el `AuthSessionController` de `application`; otros repositorios HTTP repiten el patrón. Las pruebas de `TransfersRepository` montan sesión y almacenamiento seguro para probar llamadas HTTP. Conviene extraer una abstracción pequeña de sesión en una tarea posterior, con pruebas de contrato; no se hizo aquí porque afectaría varios repositorios y excede una corrección pequeña.
- `IncomeListScreen` solicita datos al repositorio y coordina recargas/revisiones desde el widget, aunque existe `incomesListProvider` en la capa de datos y otros consumidores lo usan. Es una oportunidad concreta de mover esa coordinación a un provider de aplicación en cambios incrementales. No se alteró el estado/caché en esta auditoría.
- Cinco archivos no son alcanzables desde el punto de entrada de producción: `budget_dashboard_section.dart`, `daily_allowance_card.dart`, `net_flow_card.dart`, `top_categories_card.dart` y `recent_movements_section.dart`. Tres se usan en pruebas y los otros dos no mostraron consumidores de producción ni referencias externas. No se borraron: la falta de importación no prueba que sean obsoletos.
- Las nueve dependencias externas directas están importadas por `lib/` o código de plataforma; no se confirmó una dependencia completa sin uso. Los recursos de marca que inspeccionamos tienen consumidores Android; no se confirmó otro recurso borrable.
- La licencia upstream de los glifos Lucide faltaba en el bundle: `lucide_icons_flutter` aporta la licencia MIT de su wrapper, pero su README identifica Lucide 1.55.0 y el `NOTICES.Z` generado no contenía el aviso ISC de Lucide ni el aviso MIT de los iconos derivados de Feather. Se añadió el aviso upstream íntegro y se incluyó en los assets Flutter Android.
- Se comprobaron 133 dependencias Pub resueltas: 124 paquetes hosted y 9 entradas root/SDK fuera del escáner de licencias hosted. No se marcaron paquetes hosted como retirados, retractados o afectados por advisories en Pub. OSV devolvió cero advisories para 124 hosted Pub y para 134 módulos Maven del runtime Android debug; no es una garantía frente a vulnerabilidades no registradas ni código nativo empaquetado por terceros.
- En el runtime Android release se resolvieron 123 módulos Maven/Flutter. 118 tenían licencia en el POM cacheado. Faltan declaraciones para cuatro artefactos del engine/embedding de Flutter y para `javax.inject:javax.inject:1`; esos cinco quedan pendientes de corroborar mediante avisos de las fuentes y del APK. JNA 5.18.1 publica `Apache-2.0 OR LGPL-2.1-or-later`; el aviso Android selecciona la opción Apache 2.0 y el texto Apache está incluido. JUnit 4.13.2 (EPL-1.0) aparece solo en el runtime debug, no en release.

## License Compliance Report

### Summary
- Total dependencies scanned: 124 paquetes hosted Pub (licencias de artefactos Maven/Flutter Android revisadas en inventario separado).
- Compliant: 124 según metadatos Pub/Very Good para paquetes hosted.
- Flagged: 0 en ese escaneo Pub. El resultado no cubre licencias del SDK Flutter ni del grafo nativo Android.

### Flagged Dependencies

| Package | License | Risk | Recommendation |
| --- | --- | --- | --- |
| Flutter engine/embedding (4 artefactos release) | Sin licencia en POM cacheado | Aviso de terceros pendiente de verificar en el APK final | Confirmar los avisos del SDK Flutter y conservarlos en la distribución Android. |
| javax.inject:javax.inject:1 | Sin licencia en POM cacheado | Metadato insuficiente para establecer la obligación de distribución | Confirmar licencia desde la fuente primaria y añadir el aviso requerido si aplica. |

### Compliant Dependencies

124 paquetes Pub hosted fueron aceptados por el chequeo de licencias Very Good. El inventario completo de versiones y licencias está en [2026-10-19-pub-dependencies.csv](2026-10-19-pub-dependencies.csv). El grafo de release Android con las licencias declaradas está en [2026-10-19-android-release-dependencies.csv](2026-10-19-android-release-dependencies.csv). JNA utiliza la opción Apache 2.0 de su licencia dual según su `LICENSE` upstream 5.18.1; `android/app/src/main/assets/licenses/NOTICE.txt` atribuye esa elección y el texto Apache está en el repo.

### Recommendations

1. Mantener los avisos Lucide ISC/Feather MIT junto a la app Android; quedan empaquetados en `assets/licenses/lucide-LICENSE.txt`.
2. Verificar en el APK los avisos de Flutter engine/embedding y determinar la licencia de `javax.inject` desde su fuente primaria antes de distribuir.
3. Mantener JNA bajo la opción Apache 2.0 y su texto/atribución al actualizar el componente.
4. Abordar por separado los límites `data` → `application` y la coordinación de carga en widgets, con cambios pequeños respaldados por pruebas.

## Verificaciones

- `flutter pub get --enforce-lockfile`: correcto; lockfile sin cambios.
- `dart format --output=none --set-exit-if-changed lib test integration_test`: 208 archivos, sin cambios necesarios.
- `flutter analyze`: correcto, sin issues después de retirar `_balanceOf`.
- `flutter test --coverage`: 576 pruebas pasaron. Cobertura medida: 11,778 / 13,783 líneas (85.45%; umbral del repo: 80%).
- Very Good CLI 1.5.0 `packages check licenses . --dependency-type direct-main,direct-dev,transitive --reporter csv`: correcto.
- `flutter pub outdated --json --show-all`: sin paquetes discontinued/retracted/advisories; hay cuatro actualizaciones directas disponibles (Riverpod, Secure Storage, Go Router y Lucide). No se cambió ninguna versión.
- Consultas OSV por versión y ecosistema: 0 hallazgos entre los lotes Pub y Maven descritos arriba.
- Grafo Gradle resuelto para `debugRuntimeClasspath` y `releaseRuntimeClasspath`; JUnit solo figura en debug.
- `flutter build apk --debug --android-project-arg=financeAiAudioTest=false --android-project-arg=financeAiVoiceVerification=false`: correcto. Se comprobó que `assets/licenses/lucide-LICENSE.txt` está dentro del APK byte por byte y que Flutter incluye `NOTICES.Z`. Los avisos nativos Android existentes se mantienen en `android/app/src/main/assets/licenses/`; los cinco artefactos sin licencia en POM quedan pendientes de corroboración de fuente primaria.
