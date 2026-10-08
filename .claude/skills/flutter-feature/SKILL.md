---
name: flutter-feature
description: Implementa o modifica una funcionalidad visual o de interacción de Distance en Flutter/Dart, incluidas pantallas, widgets, estado y consumo de API cuando proceda. Úsala para cambios funcionales acotados; no para dudas teóricas o revisiones sin implementación.
argument-hint: "Pantalla, interacción o funcionalidad que quieres implementar"
---

# Implementar una funcionalidad Flutter en Distance

**Solicitud:** $ARGUMENTS

Aplica las instrucciones del `CLAUDE.md` de este repositorio. Trabaja únicamente en el frontend abierto en Windows; no asumas acceso al backend en WSL2.

## Procedimiento

1. **Inspeccionar antes de editar.** Revisa la estructura real, widgets, navegación, estado, servicios, dependencias y tests relacionados. Distingue lo confirmado de las propuestas; no presupongas pantallas, modelos Dart o endpoints no verificados.
2. **Definir la experiencia mínima.** Expresa el flujo del usuario y los criterios de aceptación. Considera estados de loading, error, vacío y éxito únicamente cuando tengan sentido. Mantén la experiencia mobile-first y accesible.
3. **Proponer el cambio mínimo.** Reutiliza los patrones y paquetes instalados. Separa presentación, estado y acceso a datos de forma proporcionada, sin imponer una arquitectura nueva. Para dependencias, decisiones arquitectónicas o refactorizaciones importantes, justifica alternativas y espera aprobación.
4. **Implementar incrementalmente.** Crea widgets legibles y responsabilidades claras; maneja correctamente operaciones asíncronas, errores y ciclo de vida cuando sean relevantes. Evita introducir pantallas o funcionalidades fuera del MVP.
5. **Verificar el comportamiento.** Añade o ajusta unit/widget tests pertinentes, incluidos casos de interacción y error cuando aporten valor. Ejecuta `dart format` en los archivos modificados, `flutter analyze` y `flutter test` desde Windows cuando el entorno lo permita. Si una prueba requiere dispositivo o emulador, indícalo explícitamente.
6. **Explicar el resultado.** Resume archivos cambiados, decisiones, verificaciones realizadas y pendientes. Explica uno o dos conceptos de Dart/Flutter relevantes (por ejemplo `StatefulWidget`, composición o `Future`) con analogías de JavaScript/Python cuando sirvan.

## Integración con Go

Antes de consumir una API, revisa su contrato disponible y no inventes la existencia de endpoints ni sus respuestas. Distingue emulador Android, dispositivo físico y host WSL2; no hardcodees una URL que solo funcione en tu equipo. Si falta implementación backend, **no edites el otro repositorio**: proporciona un contrato preciso y un prompt autocontenido para el Claude Code de Go con criterios de aceptación.

## Privacidad

Si la funcionalidad usa ubicación, pide permisos solo cuando sean necesarios y evita exponer coordenadas personales precisas sin un requisito explícito y autorización correspondiente.

## Criterio de finalización

El flujo solicitado es verificable, sigue los patrones reales del proyecto, se cubrieron las pruebas que aportan valor y se reportaron claramente los resultados y limitaciones.
