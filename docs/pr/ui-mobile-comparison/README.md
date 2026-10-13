# Comparación móvil de Inicio

Las dos capturas usan el navegador web con un viewport de 390 × 844 px. La cuenta y los movimientos son datos sintéticos de demostración.

## Antes — `develop`

En `develop`, la ruta `/home` abre el flujo de Gastos con captura por texto.

![Inicio en develop](01-inicio-develop.jpg)

## Después — `codex/ui-consistency-mobile`

En esta rama, `/home` abre Inicio con el saldo, los ingresos y gastos del mes, y el acceso al análisis.

![Inicio actualizado](02-inicio-actual.jpg)

Para renderizar la captura base en web se cambió temporalmente el límite entero de moneda en una copia aislada de `develop`; el cambio no se incluye en este PR.
