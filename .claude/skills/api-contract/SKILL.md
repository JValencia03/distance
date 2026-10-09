---
name: api-contract
description: Diseña o revisa contratos HTTP/JSON entre los módulos Go y Flutter de Distance. Úsala para aclarar comportamiento cliente-servidor, compatibilidad, seguridad o criterios de aceptación; no implementa por sí sola una funcionalidad.
argument-hint: "Endpoint o funcionalidad a coordinar"
---

# Contratos de API — Distance

**Solicitud:** $ARGUMENTS

Lee el `CLAUDE.md` de la raíz. Los módulos Go y Flutter están disponibles en el mismo workspace; inspecciona el código de ambos cuando corresponda y no supongas que una especificación equivale a código implementado.

## Procedimiento

1. **Verificar el estado real.** Inspecciona rutas, handlers, clientes HTTP, modelos, tests y documentación API existente. Distingue `CONFIRMADO`, `BORRADOR` y `PENDIENTE`; cita evidencia concreta. No infieras endpoints a partir de ejemplos.
2. **Encontrar la fuente de verdad.** Prioriza contratos versionados o acuerdos explícitos que ya existan. Si no hay, redacta el contrato en la respuesta antes de fijar expectativas. No añadas OpenAPI, generación de clientes ni infraestructura contractual sin necesidad justificada y aprobación.
3. **Especificar el comportamiento.** Incluye método, ruta, objetivo, autenticación/autorización, parámetros y unidades, request/response JSON con tipos y nulabilidad, códigos HTTP, formato de errores y ejemplos. Aclara fechas UTC ISO 8601 cuando aplique, resultados vacíos, límites y paginación según el caso.
4. **Revisar los dos consumidores/productores.** Contrasta el handler Go y el consumo Flutter disponibles. Explica impacto en serialización, estados de carga/error/vacío, compatibilidad y manejo de fallos de red. Señala discrepancias sin asumir que ambos lados ya coinciden.
5. **Revisar seguridad y privacidad.** Minimiza datos personales; separa la ubicación de un plan de la ubicación personal y comprueba autorización, precisión y exposición de coordenadas.
6. **Respetar el alcance de la solicitud.** Esta skill define o revisa contratos, no implementa la funcionalidad. Si se solicita implementación, concreta qué módulos deben cambiar y usa el procedimiento de implementación correspondiente. No generes prompts para otra instancia de Claude por defecto; este workspace es compartido.
7. **Cerrar con verificación.** Indica qué se inspeccionó, cómo probar éxito y errores, qué falta implementar en cada lado y qué decisiones siguen abiertas.

## Formato mínimo

- **Estado:** CONFIRMADO / BORRADOR / APROBADO, con evidencia o acuerdo.
- **Objetivo y evidencia:** caso de uso y archivos/rutas inspeccionados.
- **HTTP:** método, path, autenticación y parámetros.
- **Request/response:** JSON de ejemplo y semántica de campos.
- **Errores:** status, formato y condiciones.
- **Compatibilidad y privacidad:** riesgos concretos o `no aplica`.
- **Responsabilidades y pruebas:** cambios necesarios por módulo y casos de aceptación.
- **Pendientes:** decisiones o implementación aún no verificada.