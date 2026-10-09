---
name: flutter-feature
description: Implementa o modifica una funcionalidad visual o de interacción de Distance en Flutter/Dart, incluidas pantallas, widgets, estado y consumo HTTP cuando proceda.
argument-hint: "Pantalla, interacción o funcionalidad que quieres implementar"
---

# Implementar una funcionalidad Flutter en Distance

**Solicitud:** $ARGUMENTS

Aplica el `CLAUDE.md` de la raíz. El frontend vive en `frontend/`; el backend Go está disponible en `backend/` dentro del mismo workspace.

## Procedimiento

1. **Inspeccionar antes de editar.** Revisa estructura, widgets, navegación, estado, servicios, dependencias, tests y, si se consume API, el handler y contrato disponibles en Go. No presupongas pantallas, modelos ni endpoints.
2. **Definir la experiencia mínima.** Expresa flujo y criterios de aceptación. Considera carga, error, vacío y éxito donde corresponda. Mantén la experiencia mobile-first y accesible.
3. **Proponer el cambio mínimo.** Reutiliza patrones y paquetes existentes. Separa presentación, estado y datos de forma proporcionada. Para dependencias, decisiones arquitectónicas o refactorizaciones importantes, justifica alternativas y espera aprobación.
4. **Implementar incrementalmente.** Maneja operaciones asíncronas, errores y ciclo de vida cuando apliquen. Evita funciones fuera del MVP.
5. **Integrar con Go con evidencia.** Comprueba el contrato y la implementación real en `backend/`. Si el backend requerido no existe, describe la brecha y el contrato necesario; no simules que ya está disponible ni añadas endpoints sin alcance acordado. Distingue emulador, dispositivo y host de la API al configurar URL.
6. **Verificar.** Añade o ajusta tests de lógica/UI pertinentes. Ejecuta `dart format` en los archivos modificados, `flutter analyze` y `flutter test` desde `frontend/` cuando el entorno lo permita. Indica requisitos de dispositivo/emulador si aplican.
7. **Explicar.** Resume cambios, decisiones, verificaciones y pendientes. Explica brevemente conceptos Dart/Flutter relevantes cuando ayude al aprendizaje.

## Privacidad

Solicita permisos de ubicación solo cuando sean necesarios y evita exponer coordenadas personales precisas sin requisito y autorización explícitos.

## Criterio de finalización

El flujo solicitado es verificable, sigue los patrones reales del proyecto, las pruebas pertinentes se ejecutaron o se justificó por qué no, y las limitaciones quedan explícitas.