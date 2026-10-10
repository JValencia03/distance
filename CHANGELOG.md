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
- **MVP Feature 4 (unirse a un plan).**
  - Backend: `POST /plans/{id}/participants`. Reglas, en este orden: el plan existe, no está cancelado, no ha comenzado, el usuario no participa ya y quedan plazas.
  - Los planes tienen estado (`active` o `cancelled`). Todavía no hay forma de cancelar un plan, porque requiere autenticación. Los planes cancelados no aparecen en el descubrimiento.
  - Los `GET` de planes aceptan `X-User-Id` opcional para devolver `isParticipant`. Nunca se exponen los ids de otros participantes.
  - Frontend:
    - El detalle muestra "Unirme" con estado de carga y bloqueo de pulsaciones repetidas.
    - Tras unirse, actualiza el contador y muestra una confirmación.
    - Si el usuario no puede unirse, muestra un aviso con el motivo: ya participa, plan completo, cancelado o ya comenzado.
    - Ante un `409`, refresca el plan para mostrar su estado real.
    - La lista se recarga al volver del detalle y muestra la etiqueta "Participas".
- **Persistencia con PostgreSQL** (`DATABASE_URL`).
  - Driver `pgx/v5` (v5.11.0), aprobado.
  - Migraciones SQL versionadas en `backend/internal/database/migrations/`, incrustadas con `embed` y aplicadas al arrancar. Un advisory lock evita que dos procesos migren a la vez, y una tabla `schema_migrations` registra las versiones aplicadas.
  - Tablas `plans` y `plan_participants`. La clave primaria `(plan_id, user_id)` impide inscribir dos veces al mismo usuario.
  - Interfaz `Store` con dos implementaciones:
    - `MemoryStore`: se usa sin `DATABASE_URL` y en los tests de handlers.
    - `PostgresStore`.
  - `compose.yaml` con PostgreSQL 18 para desarrollo local. Sin PostGIS: todavía no hay coordenadas reales.
- **Modo oscuro.** Temas claro y oscuro generados a partir del mismo color semilla. Por defecto sigue al sistema y se puede cambiar en Ajustes.
- **Idiomas español e inglés.**
  - App: `flutter_localizations` + `intl` con `gen-l10n`. Los textos están en `lib/l10n/app_es.arb` (plantilla) y `app_en.arb`.
  - Fechas, horas, números y plurales siguen el idioma: "sáb, 17 oct · 21:30" frente a "Sat, Oct 17 · 9:30 PM", y "A 4,2 km" frente a "4.2 km away".
  - Los selectores de fecha y hora también se traducen.
  - API: `Accept-Language` (`es` o `en`; español por defecto) decide el idioma de los nombres de actividades y de los mensajes de error. Las respuestas incluyen `Vary: Accept-Language`.
  - Los títulos y descripciones de los planes no se traducen.
- **Ajustes** (icono de engranaje en la pantalla de inicio): tema e idioma, guardados en el dispositivo con `shared_preferences`.
- Dependencias aprobadas: `flutter_localizations` (SDK), `intl` y `shared_preferences` (^2.5.6).
- **Identidad visual "Pastel clay"**, sin paquetes nuevos.
  - Tema propio en `lib/shared/theme.dart`:
    - Primario lavanda, secundario durazno y terciario menta, sobre crema (claro) o ciruela (oscuro).
    - Formas redondeadas y títulos en Fraunces (variable, eje `SOFT`) con cuerpo en Nunito.
  - Assets en `frontend/assets/`, con sus licencias en las mismas carpetas:
    - Fuentes bajo licencia SIL OFL.
    - Emoji 3D de Microsoft Fluent Emoji (MIT).
  - Cada actividad tiene emoji y tono pastel propios (`ActivityStyle`). Los ids desconocidos usan un estilo neutro.
  - Superficies "clay": degradado suave, borde claro y sombra teñida.
  - Animaciones:
    - Entrada escalonada.
    - Tarjetas que se inclinan en 3D con `Matrix4` y vuelven con efecto resorte.
    - `Hero` del emoji entre inicio, lista y detalle.
    - Esqueletos con brillo en lugar de spinners.
    - Al unirse: confeti, vibración y asientos que se rellenan.
    - Todas se desactivan si el dispositivo pide reducir el movimiento.
  - El detalle recibe el plan de la lista como vista previa mientras carga la versión actual. Unirse sigue esperando a esa versión.
- **Fondo animado y animaciones Lottie.**
  - Fondo del inicio con un fragment shader (`frontend/shaders/aurora.frag`): resplandores pastel que se desplazan despacio y un grano sutil de papel.
    - Se pausa cuando otra pantalla lo cubre.
    - Mientras el shader carga, o si falla, se muestra el fondo estático.
  - Dependencia aprobada: `lottie` (^3.6.1).
  - Cuatro animaciones generadas por `frontend/tool/generate_lottie.dart`, en `frontend/assets/lottie/`:
    - Carga inicial: bolitas que rebotan.
    - Estado vacío: pin que salta, con destellos.
    - Error de conexión: nube triste con lluvia.
    - Unirse a un plan: insignia con check que se dibuja, junto al confeti.
  - `AmbientMotion.enabled` controla las animaciones en bucle. `test/flutter_test_config.dart` lo desactiva para que `pumpAndSettle` termine.

### Fixed

- Al recargar la lista de planes (al volver del detalle, tirar para refrescar o cambiar de filtro), la lista ya no se reconstruye entera: conserva la posición de scroll y no repite las animaciones de entrada.
- Al reintentar tras un error de catálogo, se muestra la carga en lugar de dejar el error en pantalla hasta que llega la respuesta.

### Changed

- Consolidada la documentación Claude que antes estaba separada entre frontend y backend; retiradas las copias locales de las instrucciones y skills.
- Movido el repositorio Git existente de `frontend/` a la raíz del workspace para incluir ambos módulos en un único repositorio, conservando el historial.
- Trasladadas y ajustadas las reglas de `.gitignore` para cubrir los artefactos Flutter bajo `frontend/`.
- Las instrucciones compartidas dejan de asumir WSL2, repositorios aislados o sesiones Claude separadas. OpenAPI no se establece como requisito.
- La pantalla inicial `HomeScreen` se reemplaza por el catálogo de actividades.
- Las compilaciones debug de Android permiten HTTP sin cifrar para alcanzar la API local.
- El cliente Flutter envía `X-User-Id` en todas las peticiones de planes; los catálogos no lo envían.
- Los errores inesperados del almacenamiento responden `500 internal_error` sin revelar detalles; la causa se registra en el log del servidor.
- Los errores que detecta la app (sin conexión, timeout, respuesta ilegible) llevan un tipo (`ApiErrorKind`) y la interfaz los traduce. Los mensajes del servidor se muestran tal cual, ya traducidos.
- La pantalla de inicio vuelve a cargar el catálogo cuando cambia el idioma.
- **Mapa 3D de participantes, fase 1: duración, planes en curso y zona de cada participante.**
  - Los planes tienen duración: entre 15 minutos y 12 horas, 1 hora por defecto. `endsAt = startsAt + duración`.
  - Es posible unirse a un plan desde que se crea hasta que termina, también mientras está en curso. El error `409 plan_started` se sustituye por `409 plan_ended`. Este cambio rompe el contrato anterior, así que se actualizaron los dos módulos.
  - Descubrir planes devuelve los planes próximos y los que están en curso.
  - Cada participante elige qué zona mostrar a los demás:
    - Al unirse, en una hoja con la zona de búsqueda preseleccionada y un aviso de que será visible.
    - Al crear un plan, en el campo "Tu zona", que por defecto sigue a la zona del plan.
    - Todavía no se muestra en ninguna parte; la usará el mapa (fase 3).
  - Migración `0002`:
    - Añade `plans.duration_minutes`. Los planes existentes quedan con 60.
    - Añade `plan_participants.zone_id`. A los participantes existentes se les asigna la zona del plan.
  - Frontend:
    - Etiqueta "En curso".
    - Horario con hora de fin ("Hoy · 17:00 – 18:00").
    - Fila "Duración" en el detalle.
    - Selector de duración en el formulario de creación.
- **Mapa 3D de participantes, fase 2: personaje personalizable.**
  - Cada usuario tiene un personaje (`Avatar`) compuesto por ids de catálogo:
    - `skin`: modelo; de momento solo `basic`.
    - `bodyColor`: 8 colores.
    - `skinTone`: 6 tonos de piel.
    - `accessory`: ninguno, gorra, gorro, audífonos, flor o gafas.
  - El servidor valida los ids y la app decide cómo se dibuja cada uno, así que los colores se pueden retocar sin migrar datos.
  - Quien no ha guardado un personaje recibe uno por defecto, derivado de su id, para que el mapa muestre variedad desde el principio.
  - Las skins nuevas (por ejemplo, modelos `.glb`) se añadirán como valores de `skin` sin cambiar el resto de campos.
  - Migración `0003`: tabla `user_avatars`.
  - Backend:
    - Endpoints `GET /avatar-options`, `GET /me/avatar` y `PUT /me/avatar`.
    - El código vive en el paquete `plans` para reutilizar sus utilidades HTTP y de idiomas; se separará cuando exista un módulo de usuarios.
  - Frontend:
    - Pantalla "Tu personaje" (Ajustes → Tu personaje, o desde el mapa) con vista previa 3D giratoria, muestras de color y accesorios.
    - El personaje básico se genera por código con primitivas de `flutter_scene`.
    - Si el dispositivo no puede renderizar 3D, se muestra un dibujo plano equivalente (`AvatarBadge`).
- **Mapa 3D de participantes, fase 3: mapa de planes.**
  - Backend: `GET /map[?activity=]`. Devuelve la posición de las zonas (normalizada de 0 a 1, nunca latitud ni longitud) y los planes próximos y en curso (máximo 40) con sus participantes. De cada participante solo expone su personaje, la zona que eligió y si es el usuario de la petición; nunca su id.
  - Frontend:
    - Pantalla "Mapa de planes", desde el icono de mapa en la lista de planes.
    - Cada participante aparece en la zona que eligió, agrupado con las demás personas del mismo plan. (La primera versión dibujaba cada zona como una isla; la sustituyó la ciudad real, descrita más abajo.)
    - Los planes en curso tienen personajes que saltan y saludan y un anillo rojo brillante; los próximos, personajes en reposo y la hora de inicio.
    - El personaje del usuario lleva un marcador y su grupo dice "Tú".
    - Un dedo desplaza el mapa, dos dedos acercan y giran. La cámara empieza sobre la zona del usuario.
    - Las etiquetas de los grupos se colocan proyectando cada grupo a pantalla y se recolocan para no solaparse.
    - Al tocar una etiqueta se abre una hoja con el plan, los personajes de sus participantes y las zonas desde las que se unen, y un botón para ver el plan y unirse. Al volver, el mapa se recarga.
    - Filtro por actividad, estados de carga, error y vacío, y un mapa 2D alternativo cuando no hay 3D.
  - Dependencias aprobadas: `flutter_scene` (^0.24.3, motor 3D sobre Flutter GPU) y `vector_math` (^2.4.3, tipos de vectores que usa `flutter_scene`).
  - Flutter GPU está activado en `AndroidManifest.xml` e `Info.plist`, como pide `flutter_scene`.
  - En `flutter_test` no hay GPU: `Scene3d.enabled = false` en `test/flutter_test_config.dart`, así que las pantallas usan su versión 2D. La escena 3D se verificó en el emulador Android.
- **El mapa de planes muestra Bogotá real con el estilo de la app.**
  - Forma y posición reales de las 19 localidades urbanas, avenidas, ríos, parques, humedales, bosques de los Cerros Orientales y aeropuerto, dibujados como una maqueta pastel.
    - Las 8 zonas del catálogo tienen su propio color; el resto de localidades, un tono neutro.
  - 12 lugares reconocibles en su sitio, con un modelo pequeño y su nombre: Monserrate, Plaza de Bolívar, Torre Colpatria, El Campín, Universidad Nacional, Museo del Oro, Movistar Arena, Maloka, Parque Simón Bolívar, Jardín Botánico, Parque de la 93 y El Dorado.
  - Sin tokens ni servicios de mapas.
    - Datos de OpenStreetMap (ODbL), descargados una sola vez y procesados offline por `frontend/tool/build_city_map.dart`: simplificación, recorte, triangulación propia (adaptación de earcut) y asset binario `assets/map/bogota.bin`, de 1,1 MB.
    - La app no hace peticiones de mapa: solo carga buffers ya preparados.
    - La atribución "© OpenStreetMap contributors" se muestra sobre el mapa.
  - Cada zona se coloca en el centro urbano que usa el servidor para las distancias, leído de `backend/internal/plans/catalog.go` como única fuente de verdad. El centro geométrico de algunas localidades, como Chapinero, cae en los cerros.
  - Rendimiento:
    - Cada capa de la ciudad es una sola malla con colores por vértice.
    - Los árboles (~2.500) son 2 mallas instanciadas.
    - Los personajes se dibujan con una malla instanciada por pieza (`Crowd`), así que el coste en draw calls no crece con el número de personas. Las matrices se reescriben en su sitio cada frame, sin reservar memoria.
    - Solo personajes y lugares emblemáticos proyectan sombra, con 2 cascadas.
    - Medido en el emulador (debug): de 179 a 95 draw calls y de 3,8 M a 1,4 M vértices por frame, a ~60 fps.
  - Niveles de detalle:
    - De cerca, una etiqueta por grupo; si para no tapar a otra tendría que alejarse mucho de sus personajes, se omite.
    - De lejos, una etiqueta por zona con personas, planes y si hay algo en curso; al tocarla, la cámara vuela hacia la zona.
  - La vista 2D alternativa dibuja la misma ciudad con `Canvas.drawVertices`.
  - Skills actualizadas (`flutter-feature`, `go-feature`, `feature-testing`):
    - No usar servicios con token ni de pago.
    - Priorizar el rendimiento e implementar piezas propias cuando las alternativas listas cuesten mucho más hardware.
    - Conservar el estilo de la app con datos reales.
    - Convenciones de 3D y pruebas.
  - Corregido: la pantalla del personaje mostraba un error genérico en vez del mensaje del servidor cuando fallaba la carga (`unwrapWaitError`).

### Contrato HTTP vigente

- Todas las rutas aceptan `Accept-Language`: gana el idioma soportado con mayor `q` y, en caso de empate, el primero. Se ignora la región (`en-US` → `en`).
- Errores: `{"error": {"code": string, "message": string, "fields"?: {campo: mensaje}}}`.
- `GET /activities` → `200 {"activities": [{"id", "name"}]}`.
- `GET /zones` → `200 {"zones": [{"id", "name"}]}`. Las coordenadas de las zonas no salen del servidor.
- `GET /plans?zone=<id>[&activity=<id>]` → `200 {"plans": [Plan + "distanceKm"]}`. Devuelve los planes activos que no han terminado, ya sean próximos o en curso. Responde `400 invalid_query` si la zona falta o es desconocida, o si la actividad es desconocida.
- `GET /plans/{id}` → `200 Plan`; `404 not_found`.
- `POST /plans` con header `X-User-Id` (identidad de desarrollo, **no es autenticación**).
  - Body: `{"activityId", "title", "description"?, "zoneId", "place", "startsAt" (ISO 8601 UTC), "durationMinutes"? (15–720, 60 por defecto), "maxParticipants"?, "creatorZoneId"? (por defecto, `zoneId`)}`.
  - Éxito: `201 Plan` + `Location`.
  - Errores: `401 unauthenticated`, `400 invalid_json`, `413 body_too_large`, `422 validation_failed`.
- `POST /plans/{id}/participants` con header `X-User-Id` y body `{"zoneId"}`: la zona que el participante muestra a los demás.
  - Éxito: `200 Plan` actualizado (con `isParticipant: true`).
  - Errores:
    - `401 unauthenticated`.
    - `400 invalid_json`: body ausente, malformado o con campos desconocidos.
    - `422 validation_failed` con `fields.zoneId`: zona ausente o desconocida. Se valida antes de buscar el plan.
    - `404 not_found`.
    - `409 already_joined`, `409 plan_full`, `409 plan_cancelled` o `409 plan_ended`.
- `Plan`:
  - `id`, `activity {id,name}`, `title`, `description` (nullable), `zone {id,name}`, `place`.
  - `startsAt` (UTC) y `status` (`active` | `cancelled`).
  - `durationMinutes`, `endsAt` (UTC) e `isOngoing` (`startsAt <= ahora < endsAt` según el servidor). La app recalcula `isOngoing` con su reloj para que no quede desactualizado.
- `Avatar`: `{"skin", "bodyColor", "skinTone", "accessory"}`, todos ids de `GET /avatar-options`.
- `GET /avatar-options` → `200 {"skins": [{"id","name"}], "bodyColors": [id], "skinTones": [id], "accessories": [{"id","name"}]}`. Los nombres siguen `Accept-Language`.
- `GET /me/avatar` con `X-User-Id` → `200 {"avatar": Avatar, "isDefault": bool}`. `isDefault` es `true` mientras el usuario no haya guardado uno. Errores: `401 unauthenticated`.
- `PUT /me/avatar` con `X-User-Id` y body `Avatar` (todos los campos obligatorios) → `200 {"avatar": Avatar, "isDefault": false}`. Errores: `401 unauthenticated`, `400 invalid_json`, `413 body_too_large`, `422 validation_failed` con `fields` por campo.
- `GET /map[?activity=<id>]`, con `X-User-Id` opcional → `200 {"zones": [{"id","name","x","y"}], "plans": [Plan + "participants": [{"avatar": Avatar, "zoneId", "isMe"}]]}`.
  - `x` crece hacia el este e `y` hacia el sur, ambos de 0 a 1.
  - Planes activos sin terminar, ordenados del más próximo al más lejano; máximo 40.
  - Errores: `400 invalid_query` si la actividad es desconocida.
  - `participantCount`, `maxParticipants` (nullable = sin límite) e `isFull`.
  - `isParticipant`: `true` si el `X-User-Id` de la petición participa; `false` si no se envió.
  - No expone el creador ni los participantes.

### Concurrencia

- **En memoria:** `MemoryStore.Join` comprueba y añade al participante bajo el mismo cerrojo de escritura.
- **En PostgreSQL**, cada `Join` es una transacción en tres pasos:
  1. Bloquea la fila del plan con `SELECT … FOR UPDATE`.
  2. Lee los participantes en una sentencia **posterior** y aplica las reglas.
  3. Inserta la participación.
- **Por qué importa el paso 2:** si los participantes se leyeran en la misma sentencia que bloquea, PostgreSQL usaría la instantánea anterior a la espera del bloqueo, y el límite podría superarse.
  - Se comprobó con dos sesiones `psql`.
  - Lo cubre un test de integración que falla con esa variante incorrecta: deja entrar a un tercer participante en un plan de 2.

### Verification

- **Go:**
  - `gofmt` y `go vet` limpios.
  - `go test ./...` en `backend/` pasa: handlers, reglas de unirse, 50 uniones simultáneas, el mismo usuario uniéndose a la vez y la batería común de tests de almacenes en memoria.
- **Integración con PostgreSQL 18.1:** portátil y temporal, fuera del repositorio.
  - Los tests de `PostgresStore` pasan en 10 ejecuciones seguidas, incluido el test determinista de bloqueo.
- **Prueba manual con el servidor compilado + PostgreSQL + `curl`:**
  - Crear un plan y unirse responden `201` y `200`.
  - Errores: `already_joined`, `plan_full`, `unauthenticated` y `not_found`.
  - Tras reiniciar el servidor, los datos persisten.
- **Flutter:** `dart format`, `flutter analyze` (sin issues) y `flutter test` pasan: 27 tests, que incluyen unirse, carga, doble pulsación, conflicto `409`, fallo de red y avisos por estado.
- **Windows:** Smart App Control bloquea de forma intermitente los binarios de prueba de Go en `%TEMP%`; usar `GOTMPDIR` apuntando a otro directorio lo evitó.
- **Docker:**
  - `docker compose config` es válido; PostgreSQL 18 arranca y queda `healthy`.
  - Las migraciones se aplican y el servidor funciona contra el contenedor.
  - Los tests de `PostgresStore` pasan contra el contenedor.
  - Los datos persisten tras `docker compose down` + `up`.
- **Idioma y tema:**
  - Go: tests de `requestLang` (prioridades `q`, regiones, idiomas no soportados) y de respuestas en inglés y español.
  - Flutter: 32 tests que cubren formatos en ambos idiomas, persistencia de ajustes, cambio a modo oscuro, y cambio de idioma con recarga del catálogo pidiendo `Accept-Language: en`.
  - `curl` contra el servidor compilado confirma catálogo y errores en ambos idiomas.
- **Emulador Android** (Pixel 7, Android 36, APK debug, backend contra PostgreSQL en Docker):
  - Recorrido completo en español con modo oscuro, y en inglés con modo claro.
  - Catálogo traducido desde la API; elección de zona; lista con orden, etiquetas y distancias.
  - Detalle y unión a un plan (2/5 → 3/5, "Participas"); aviso de plan completo.
  - Creación de un plan con los selectores de fecha y hora traducidos.
  - El tema y el idioma se conservan tras cerrar la app por completo.
- **Corregido tras la prueba en emulador:** la distancia ("A 5,8 km", "5.8 km away") se partía en dos líneas; ahora el número y la unidad van unidos con espacios de no separación.
