---
name: feature-testing
description: Revisa, diseña, implementa o depura tests Flutter/Dart del frontend de Distance. Úsala cuando el objetivo principal sea verificar widgets, estado, modelos, consumo de API o regresiones; no para implementar una feature completa, que corresponde a flutter-feature.
argument-hint: "Widget, flujo, comportamiento o fallo que deseas probar"
---

# Feature Testing — Distance frontend (Flutter / Windows)

**Solicitud:** $ARGUMENTS

Lee y respeta el `CLAUDE.md` del repositorio actual. Este workspace contiene solo Flutter/Dart en Windows; no asumas acceso al backend Go en WSL2. Esta Skill se concentra en **pruebas**, no en añadir funcionalidades nuevas. Si la petición busca una nueva feature, indica que corresponde a `flutter-feature`.

## Procedimiento

1. **Inspeccionar antes de actuar.** Revisa widgets, estado, clientes HTTP, modelos, test helpers, `pubspec.yaml` y tests existentes. Identifica qué comportamiento está confirmado en el frontend y qué depende de contratos externos.
2. **Definir comportamientos observables.** Selecciona los casos valiosos: interacción de usuario, rendering, validación, loading, éxito, vacío, error, navegación y regresiones según la funcionalidad. No inventes estados que todavía no existan ni pruebes detalles privados del árbol de widgets sin motivo.
3. **Elegir el nivel apropiado.** Usa unit tests para transformaciones y reglas Dart; widget tests con `flutter_test` para UI e interacción; integration tests cuando sea necesario comprobar comportamiento real de plataforma/dispositivo. Prefiere dependencias y mecanismos ya presentes. No añadas paquetes de mocking, state management o networking solo para testing sin justificar y obtener aprobación.
4. **Aislar dependencias.** Evita red real en unit/widget tests: utiliza fakes o inyección sencilla adaptados al diseño existente, sin abstraer toda la aplicación. Simula respuestas usando únicamente contratos confirmados o aprobados; marca los ejemplos hipotéticos como borradores. Geolocalización, permisos, mapas y APIs nativas deben probarse con mecanismos que respete el entorno de tests; si precisan emulador, indica el requisito.
5. **Implementar un cambio acotado.** Si el usuario pidió añadir/corregir tests, modifica el mínimo necesario. Si para poder testear hay que cambiar arquitectura, contrato API o dependencias, explica alternativas y solicita aprobación. Si se pidió solo revisión, no modifiques archivos. No cambies una expectativa para ocultar una regresión.
6. **Ejecutar y diagnosticar.** Ejecuta `dart format` en archivos modificados, tests específicos cuando ayuden, `flutter test` y `flutter analyze` si el entorno lo permite. Distingue fallos de código, contratos no confirmados y limitaciones del SDK/emulador. No afirmes que un test de integración se ejecutó si no hubo dispositivo o servicio disponible.
7. **Informar y enseñar.** Resume qué comportamiento verificaste, tests añadidos, comandos y resultados, riesgos y pendientes. Explica uno o dos conceptos útiles de Dart/Flutter (por ejemplo `testWidgets`, `WidgetTester`, `pumpAndSettle` y sus límites) comparándolos con JavaScript/Python si es práctico.

## Criterios específicos de Distance

- Prioriza tests sobre descubrir, crear y unirse a planes cuando esas pantallas realmente existan; no diseñes tests de funcionalidades todavía no implementadas.
- En funciones de ubicación, valida permisos, estados de error y exposición mínima de coordenadas solo según el comportamiento acordado.
- Para JSON y llamadas HTTP, utiliza contratos confirmados. Ante ambigüedad, recurre a `api-contract` y produce un prompt de traspaso al backend cuando haga falta, sin acceder a WSL2.
- Evita snapshots/golden tests frágiles si una prueba de comportamiento responde mejor a la necesidad. No impongas porcentajes de cobertura artificiales.

## Formato de cierre

- **Comportamiento examinado** y archivos inspeccionados.
- **Casos cubiertos** y pendientes justificados.
- **Archivos modificados** (o «sin cambios»).
- **Verificación** con comandos realmente ejecutados y resultados.
- **Concepto aprendido** y decisiones abiertas.
