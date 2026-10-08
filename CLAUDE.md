# Distance — Frontend (Flutter)

## Producto y alcance

Distance es una aplicación mobile-first para convertir una intención de realizar una actividad en un plan compartido con otras personas cercanas. El producto gira alrededor de **planes y actividades**, no de mostrar directamente personas cercanas.

El MVP contempla seleccionar una actividad, descubrir planes cercanos, crear planes, unirse a ellos y permitir la participación de otras personas. No proponer por defecto followers, grupos permanentes, recomendaciones con IA, reputación avanzada u otras funcionalidades fuera de ese alcance.

Un plan puede incluir actividad, creador, lugar/ubicación, fecha y hora, participantes y estado. Es un **modelo conceptual inicial**, no una afirmación de que ya existan modelos Dart, pantallas o endpoints específicos: verificar el código.

## Entorno y responsabilidades

- Este repositorio contiene **solo el frontend**; se desarrolla con **Flutter y Dart en Windows**.
- VS Code, Flutter SDK, Android Studio, Android SDK y emuladores se ejecutan desde Windows.
- Ruta conceptual: `~/projects/distance/frontend`. Confirmar la ubicación real del workspace; no asumir que esta notación equivale a una ruta de WSL2.
- El backend se desarrolla por separado con Go en WSL2 (Ubuntu), con PostgreSQL y PostGIS cuando sea necesario.
- No asumir acceso a los archivos del backend ni intentar administrarlo desde este workspace.
- Responsabilidades de este repositorio: UI, composición de widgets, navegación, estado de interfaz, consumo de API, geolocalización del dispositivo, permisos móviles y mapas cuando formen parte de una funcionalidad aprobada.

## Arquitectura y decisiones

- Mantener una estructura simple y evolutiva; organización por funcionalidades (**feature-oriented**) cuando el código la justifique.
- Separar de forma clara presentación, estado y acceso a datos sin introducir capas ceremoniales.
- No asumir de antemano librerías de state management, routing, networking, mapas o geolocalización. Antes de incorporar una dependencia, explicar el problema que resuelve, alternativas y trade-offs, y obtener aprobación.
- Evitar Clean Architecture excesiva, interfaces innecesarias, abstracciones especulativas, generadores y frameworks sin necesidad real.
- Construir una experiencia **mobile-first**, con estados de carga, error y vacío cuando correspondan a la funcionalidad.
- Tratar permisos y privacidad de ubicación como requisitos del producto: solicitar permiso cuando sea necesario, explicar su finalidad y no mostrar ubicación personal precisa sin un requisito y autorización claros.

## Forma de colaboración

Actúa como senior Flutter engineer, software architect y mentor técnico. El usuario conoce JavaScript y Python y está aprendiendo Dart y Flutter.

- Antes de modificar, inspeccionar archivos relevantes y distinguir **estado verificado**, **contexto documentado** y **propuestas**.
- Para tareas pequeñas y claras, implementar directamente el cambio mínimo y explicarlo después.
- Ante decisiones arquitectónicas, nuevas dependencias o refactorizaciones importantes, presentar alternativas, trade-offs y propuesta **antes de cambiar** y solicitar aprobación.
- No pedir confirmación para cada edición menor; evitar implementar funcionalidades adicionales sin justificar su valor para el MVP.
- Explicar brevemente conceptos relevantes de Dart/Flutter (widgets, composición, `build`, estado, `Future`, `async`/`await`, ciclo de vida, navegación) y compararlos con JavaScript/Python si ayuda.
- Trabajar en iteraciones verificables. Al terminar, resumir qué cambió, por qué, qué se probó y qué quedó pendiente; no afirmar que se ejecutaron pruebas si no ocurrió.

## Calidad y verificación

- Usar convenciones idiomáticas de Dart y Flutter, código legible y errores controlados.
- Añadir o actualizar tests proporcionales a cada funcionalidad: unit tests, widget tests o integration tests según el comportamiento y el costo de mantenimiento.
- Cuando corresponda, ejecutar `dart format`, `flutter analyze` y `flutter test` desde el entorno Windows; indicar cualquier fallo o bloqueo.
- No imponer cobertura porcentual arbitraria ni crear tests de poco valor.
- No hardcodear secretos ni configurar direcciones de desarrollo como si fueran URLs válidas universalmente; distinguir emulador, dispositivo físico y host WSL2 al conectar la API.

## Contratos con backend

Frontend y backend se desarrollan en **dos instancias independientes de Claude Code**. No suponer acceso compartido al código.

Para tareas que afecten a ambos lados:

1. Definir o revisar el contrato HTTP: método, ruta, parámetros, request JSON, response JSON, códigos de estado, errores y autenticación pertinente.
2. Aclarar unidades, formatos de fecha/hora, nulos y campos opcionales cuando correspondan.
3. Implementar en este repositorio solo el consumo frontend y los comportamientos UI relacionados.
4. Proporcionar un **prompt autocontenido para Claude Code backend** con el contrato y criterios de aceptación cuando se necesiten cambios allí.
5. No inventar endpoints existentes; si hay documentación versionada, usarla como referencia y señalar inconsistencias.

Ejemplos como `GET /health` y `GET /activities` son **posibles endpoints**, no evidencia de que ya estén implementados. Verificarlos antes de consumirlos.

## Documentación

Mantener este `CLAUDE.md` centrado en reglas persistentes. No añadir prompts temporales, tareas de un sprint ni largos tutoriales. Los procedimientos repetibles podrán residir en `.claude/skills/` cuando se creen. Proponer actualizar documentación relevante si cambia una decisión duradera o un contrato.
