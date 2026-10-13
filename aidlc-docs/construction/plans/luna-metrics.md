# Métricas financieras para Inicio

- [x] Confirmar límites de propiedad, modelos de historia y ventanas disponibles.
- [x] Definir interfaz de cálculo semanal y proyección mensual para luna_ui.
- [x] Implementar funciones puras con filtros de moneda, fecha local y datos incompletos.
- [x] Añadir pruebas focalizadas de límites y propiedades deterministas.
- [x] Formatear y ejecutar únicamente la prueba de métricas.
- [x] Informar archivos, interfaz, resultado y límites a Sol.

Validación: `flutter test test/features/dashboard/application/home_financial_metrics_test.dart` (11 pruebas aprobadas) y `dart analyze` de los dos archivos (sin incidencias). Los cálculos requieren cobertura de ventana y `historyIsComplete`; el consumidor debe transmitir el metadato real de paginación.
