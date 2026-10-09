---
name: feature-testing
description: Diseña, implementa o depura pruebas para los módulos Flutter/Dart o Go de Distance. Úsala cuando el objetivo principal sea verificar comportamiento o regresiones, no implementar una funcionalidad completa.
argument-hint: "Módulo, componente, comportamiento o fallo que deseas probar"
---

# Pruebas de funcionalidades — Distance

**Solicitud:** $ARGUMENTS

Lee el `CLAUDE.md` de la raíz. Este workspace contiene frontend Flutter/Dart y backend Go. Esta skill se concentra en pruebas; si la solicitud busca una funcionalidad completa, usa `flutter-feature` o `go-feature`.

## Procedimiento

1. **Inspeccionar antes de actuar.** Revisa código de producción, pruebas, helpers, dependencias y comandos del módulo implicado. Para flujos entre módulos, inspecciona ambos y verifica el contrato real.
2. **Definir comportamiento observable.** Selecciona casos valiosos de éxito, error, entradas inválidas, límites e interacción/regresión. Separa comportamiento confirmado de expectativas propuestas; evita acoplar tests a detalles internos sin motivo.
3. **Elegir el nivel apropiado.** Para Go, prioriza `testing`, tests de tabla y `net/http/httptest`; usa integración con PostgreSQL/PostGIS solo si el comportamiento lo requiere. Para Flutter, usa tests unitarios para lógica y `flutter_test` para widgets/interacción; usa integración de plataforma solo cuando sea necesaria.
4. **Aislar recursos.** No llames servicios externos reales en unit/widget tests ni uses datos reales. Antes de usar base de datos, verifica prerrequisitos, aislamiento y limpieza. No introduzcas frameworks, paquetes de mocking o infraestructura solo por conveniencia.
5. **Cambiar lo mínimo.** Añade o corrige pruebas si eso se pidió. En una auditoría, no edites. Si la solución exige alterar contrato, arquitectura o dependencias, plantea opciones y espera aprobación.
6. **Ejecutar y diagnosticar.** Desde `backend/`, usa `go test ./...` y `gofmt` en los Go modificados. Desde `frontend/`, usa `dart format`, tests dirigidos o `flutter test`, y `flutter analyze` cuando sea pertinente. Distingue fallo del código, bloqueo del entorno y test no ejecutado.
7. **Informar.** Resume comportamiento verificado, casos cubiertos y pendientes, archivos cambiados, comandos realmente ejecutados y riesgos. Explica brevemente conceptos de testing de Go o Flutter cuando ayuden.

## Límites

- No exigir porcentajes de cobertura ni crear tests redundantes.
- No inventar contratos HTTP, tablas o funcionalidades que no estén implementadas o acordadas.
- Para casos que crucen frontend y backend, comprobar JSON, estados HTTP y estados de UI pertinentes sin acoplar los tests unitarios a servicios externos.