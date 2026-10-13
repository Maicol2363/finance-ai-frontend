# Luna Camera checklist

- [x] Revisar la guía, la pantalla de cámara, las pruebas asociadas y el catálogo de iconos existente.
- [x] Añadir una acción accesible para reabrir la guía sin alterar el estado persistido.
- [x] Cubrir reaperturas manuales, controles visibles y preferencia persistida con pruebas de widget.
- [x] Ejecutar formato y pruebas focalizadas; registrar resultados.

Resultados: `dart format` sin cambios pendientes; pasaron `receipt_photo_guide_test.dart` (8 pruebas) y `receipt_capture_screens_test.dart` (15 pruebas). Las pruebas ejercitan la UI Flutter; no requieren ni verifican hardware de cámara.
