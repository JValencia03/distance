# Distance

## Producto y alcance

Distance es una aplicación mobile-first para convertir la intención de realizar una actividad en un plan compartido con personas cercanas. El producto gira alrededor de **planes y actividades**, no de mostrar directamente personas cercanas.

El MVP contempla seleccionar una actividad, descubrir planes cercanos, crear planes, unirse a ellos y permitir la participación de otras personas. No proponer por defecto followers, grupos permanentes, recomendaciones con IA, reputación avanzada u otras funcionalidades fuera de ese alcance.

Un plan puede incluir actividad, creador, lugar/ubicación, fecha y hora, participantes y estado. Es un modelo conceptual inicial, no evidencia de que ya existan entidades, pantallas o endpoints: inspeccionar el código antes de afirmarlo.

## Workspace y responsabilidades

- El workspace compartido contiene `frontend/` (Flutter/Dart) y `backend/` (Go). Inspeccionar ambos módulos cuando la tarea cruce sus límites; no asumir repositorios, sesiones de Claude Code ni entornos aislados.
- No asumir WSL2 ni una plataforma concreta para Go. Detectar el sistema y las herramientas disponibles en la sesión actual. Ejecutar Flutter desde el entorno que tenga Flutter y los SDK móviles configurados.
- El código Flutter vive en `frontend/`; el módulo Go vive en `backend/`. Ejecutar comandos desde el directorio del módulo correspondiente.
- Antes de operaciones Git, comprobar la raíz real. No mover, reinicializar ni alterar metadatos Git sin autorización explícita.
- Responsabilidades Flutter: UI, composición de widgets, navegación, estado de interfaz, consumo HTTP, geolocalización del dispositivo, permisos móviles y mapas cuando formen parte de una funcionalidad aprobada.
- Responsabilidades Go: servidor HTTP, reglas de negocio y persistencia cuando estén justificadas. El backend actual tiene alcance deliberadamente mínimo: `GET /health`; no inventar endpoints ni infraestructura ya implementados.

## Arquitectura y decisiones

### Flutter

- Mantener una estructura simple y evolutiva; organizar por funcionalidades cuando el código lo justifique.
- Separar presentación, estado y acceso a datos sin introducir capas ceremoniales.
- No asumir librerías de state management, routing, networking, mapas o geolocalización. Antes de añadir dependencias, explicar necesidad, alternativas y trade-offs, y obtener aprobación.
- Construir una experiencia mobile-first con estados de carga, error y vacío cuando correspondan.

### Go

- Favorecer un monolito modular pequeño, legible y evolutivo; preferir Go idiomático y `net/http` cuando sea suficiente.
- No añadir frameworks HTTP, ORM, generadores o patrones especulativos. Evitar microservicios, Kubernetes, Clean Architecture ceremonial, DDD complejo, CQRS, event sourcing, interfaces especulativas y capas sin beneficio concreto.
- PostgreSQL/PostGIS y Docker Compose se incorporarán cuando una funcionalidad los necesite; Redis no es obligatorio y requiere una necesidad concreta.
- Usar migraciones versionadas si se modifica un esquema. Validar entradas, tratar errores y mantener secretos fuera del código.

### Integración y privacidad

- Coordinar cambios HTTP entre ambos módulos revisando directamente el código disponible. Definir método, ruta, parámetros, JSON, estados HTTP, errores, autenticación, formatos, unidades y nulabilidad cuando aplique.
- No introducir OpenAPI, generación de clientes ni herramientas de contrato automáticamente. La idea inicial de conectarlos mediante OpenAPI no es un requisito vigente por sí sola; proponerlo únicamente si resuelve una necesidad concreta y obtener aprobación.
- No inventar endpoints existentes. Ejemplos en documentación no prueban que estén implementados.
- Solicitar permiso de ubicación solo cuando sea necesario. Minimizar precisión y exposición; no mostrar ni registrar coordenadas personales precisas sin requisito y autorización claros.
- Distinguir la URL base según emulador, dispositivo físico y host donde corra la API; no hardcodear una URL de desarrollo como universal.

## Colaboración y calidad

- Antes de modificar, inspeccionar el código relevante y distinguir estado verificado, contexto documentado y propuestas.
- Para tareas pequeñas y claras, implementar el cambio mínimo. Ante nuevas dependencias, decisiones arquitectónicas o refactorizaciones importantes, presentar opciones y trade-offs y esperar aprobación.
- No pedir confirmación para cada edición menor ni ampliar el MVP sin justificación.
- Añadir pruebas proporcionales al riesgo: `flutter_test` para lógica/UI y `testing`/`httptest` para Go; reservar pruebas de integración para comportamientos que realmente dependan de servicios externos.
- Ejecutar `dart format`, `flutter analyze` y `flutter test` para cambios Flutter cuando el entorno lo permita. Para Go, ejecutar `gofmt` en los archivos modificados y `go test ./...` desde `backend/` cuando sea posible. Informar bloqueos reales y no afirmar verificaciones que no se ejecutaron.
- Explicar brevemente conceptos relevantes de Dart/Flutter o Go cuando ayude al aprendizaje del usuario.
- Al terminar, resumir qué cambió, por qué, qué se verificó y qué quedó pendiente.

## Documentación y skills

Este archivo contiene reglas persistentes compartidas. Las skills reutilizables viven en `.claude/skills/` en la raíz del workspace; no duplicarlas dentro de `frontend/` o `backend/`. Mantenerlas alineadas con estas reglas.