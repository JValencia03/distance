---
name: go-feature
description: Implementa o modifica una funcionalidad del backend Go de Distance, incluidos handlers HTTP, reglas de negocio y persistencia cuando proceda.
argument-hint: "Funcionalidad o cambio que quieres implementar"
---

# Implementar una funcionalidad Go en Distance

**Solicitud:** $ARGUMENTS

Aplica el `CLAUDE.md` de la raíz. El backend vive en `backend/` y Flutter en `frontend/`; ambos módulos están disponibles en el mismo workspace.

## Procedimiento

1. **Inspeccionar antes de editar.** Identifica paquetes, handlers, rutas, modelos, migraciones, pruebas y convenciones relevantes en Go. Revisa Flutter también si cambia un contrato. No presupongas endpoints, tablas ni modelos por estar documentados.
2. **Acotar el comportamiento.** Define resultados observables, errores y límites. Si afecta HTTP, especifica método, ruta, parámetros, JSON y status codes, respetando contratos vigentes.
3. **Elegir el cambio mínimo.** Prioriza Go idiomático y biblioteca estándar. Evita interfaces, capas y dependencias especulativas. Para una dependencia nueva, decisión arquitectónica o refactorización importante, presenta opciones y espera aprobación.
4. **Implementar incrementalmente.** Valida entradas y maneja errores explícitamente; usa `context.Context` cuando corresponda. Para cambios de esquema, sigue la herramienta de migraciones existente; no introduzcas una nueva sin acuerdo.
5. **Coordinar Flutter cuando aplique.** Inspecciona el consumidor disponible y mantén el contrato coherente. Modifica Flutter solo si la solicitud cubre ambos módulos; no generes un traspaso a otra sesión por defecto.
6. **Probar.** Añade tests útiles de éxito, error y límites cuando corresponda. Ejecuta `gofmt` en los `.go` modificados y `go test ./...` desde `backend/` cuando el entorno lo permita.
7. **Cerrar.** Resume archivos modificados, decisiones, pruebas y resultados, bloqueos y pendientes. Explica brevemente conceptos Go relevantes cuando ayude al aprendizaje.

## Criterio de finalización

El cambio respeta el alcance acordado, el contrato es coherente con Flutter cuando aplique y los resultados de verificación se informan con evidencia. No amplíes el backend más allá de la funcionalidad solicitada.