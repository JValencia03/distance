# Changelog

## [Unreleased] - 2026-10-09

### Added

- Instrucciones compartidas del workspace en `CLAUDE.md` raíz y skills centralizadas en `.claude/skills/` para Flutter, Go, pruebas y contratos HTTP.
- Servidor Go mínimo en `backend/server.go`, con `GET /health` respondiendo `200` y `{"status":"ok"}` en el puerto `8080`.
- **MVP Features 1–3 (actividades, descubrir planes, crear plan).**
  - Backend (`backend/internal/plans/`): catálogo predefinido de 10 actividades y 8 zonas (Bogotá, provisional); almacén en memoria; endpoints `GET /activities`, `GET /zones`, `GET /plans?zone=&activity=`, `GET /plans/{id}` y `POST /plans`.
  - Reglas: solo se descubren planes futuros, ordenados por disponibilidad, distancia entre zonas y fecha; validación de campos obligatorios, longitudes, límite de participantes (2–50) y fechas futuras; el creador queda registrado como participante inicial.
  - Frontend: catálogo de actividades con selector de zona, lista de planes con filtro por actividad, detalle de plan y formulario de creación, con estados de carga, error y vacío. Cliente HTTP en `lib/data/distance_api.dart`.
  - Dependencia `http` (^1.6.0) aprobada para el consumo HTTP en Flutter.

### Changed

- Consolidada la documentación Claude que antes estaba separada entre frontend y backend; retiradas las copias locales de las instrucciones y skills.
- Movido el repositorio Git existente de `frontend/` a la raíz del workspace para incluir ambos módulos en un único repositorio, conservando el historial.
- Trasladadas y ajustadas las reglas de `.gitignore` para cubrir los artefactos Flutter bajo `frontend/`.
- Las instrucciones compartidas dejan de asumir WSL2, repositorios aislados o sesiones Claude separadas. OpenAPI no se establece como requisito.
- La pantalla inicial `HomeScreen` se reemplaza por el catálogo de actividades.
- Las compilaciones debug de Android permiten HTTP sin cifrar para alcanzar la API local.

### Contrato HTTP vigente

- Errores: `{"error": {"code": string, "message": string, "fields"?: {campo: mensaje}}}`.
- `GET /activities` → `200 {"activities": [{"id", "name"}]}`.
- `GET /zones` → `200 {"zones": [{"id", "name"}]}`. Las coordenadas de las zonas no salen del servidor.
- `GET /plans?zone=<id>[&activity=<id>]` → `200 {"plans": [Plan + "distanceKm"]}`; `400 invalid_query` si la zona falta o es desconocida, o la actividad es desconocida.
- `GET /plans/{id}` → `200 Plan`; `404 not_found`.
- `POST /plans` con header `X-User-Id` (identidad de desarrollo, **no es autenticación**) y body `{"activityId", "title", "description"?, "zoneId", "place", "startsAt" (ISO 8601 UTC), "maxParticipants"?}` → `201 Plan` + `Location`; `401 unauthenticated`, `400 invalid_json`, `413 body_too_large`, `422 validation_failed`.
- `Plan`: `id`, `activity {id,name}`, `title`, `description` (nullable), `zone {id,name}`, `place`, `startsAt` (UTC), `participantCount`, `maxParticipants` (nullable = sin límite), `isFull`. No expone el creador ni los participantes.

### Verification

- `gofmt` y `go vet` limpios; `go test ./...` en `backend/` pasa (`/health`, catálogos, creación, validación, detalle, descubrimiento y orden).
- Prueba manual con `go run .` + `curl`: `/health`, `POST /plans` (201), `GET /plans` con `distanceKm` y errores de validación (422).
- `dart format`, `flutter analyze` (sin issues) y `flutter test` (18 tests: cliente HTTP, formatos, validadores y flujos de UI) pasan en `frontend/`.
- Windows Smart App Control bloquea de forma intermitente los binarios de prueba de Go en `%TEMP%`; usar `GOTMPDIR` apuntando a otro directorio lo evitó en esta sesión.
- No verificado: ejecución de la app en emulador o dispositivo.
