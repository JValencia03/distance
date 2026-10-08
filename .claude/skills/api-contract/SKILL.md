---
name: api-contract
description: Diseña, revisa o coordina contratos HTTP/JSON para consumir la API Go de Distance desde Flutter. Úsala al integrar endpoints, resolver discrepancias cliente-servidor o preparar un prompt autocontenido para el backend. No implementa funcionalidades por sí sola.
argument-hint: "Endpoint o funcionalidad a coordinar"
---

# Contratos de API — Distance (frontend)

**Solicitud:** $ARGUMENTS

Sigue `CLAUDE.md` del repositorio abierto. Estás en Flutter/Windows, **sin acceso garantizado al backend Go en WSL2**. Esta Skill define o valida contratos; para implementar después se puede usar `flutter-feature`.

## Procedimiento

1. **Verificar el estado real.** Inspecciona cliente HTTP, modelos Dart, configuración de URL, tests y documentación API disponibles en este workspace. Distingue **confirmado**, **propuesto** y **pendiente**. No supongas que un endpoint existe por aparecer en un ejemplo.
2. **Localizar la fuente de verdad.** Prioriza una especificación versionada o un contrato aprobado aportado por el usuario. Si falta, redacta un contrato en borrador: no lo presentes como comportamiento confirmado del servidor.
3. **Especificar contrato.** Define método, ruta, autorización, parámetros y unidades; request y response JSON con tipos, formatos y nulabilidad; status codes, estructura de errores, ejemplos y condiciones de resultado vacío. Aclara fechas UTC ISO 8601 cuando correspondan; sigue las convenciones realmente acordadas.
4. **Analizar impacto en Flutter.** Explica los campos necesarios para la UI, serialización/deserialización, estados de loading/error/empty, timeouts y tratamiento de fallos de red, sin inventar dependencias ni implementar fuera de alcance. Distingue URL base de desarrollo entre emulador Android, dispositivo físico y host WSL2; no hardcodees una URL universal.
5. **Privacidad y evolución.** Evita enviar ubicación precisa sin necesidad y permisos; no exponer ubicaciones personales en vistas o logs. Si hay incompatibilidad con un contrato vigente, identifícala y pide acuerdo antes de cambiarlo.
6. **Preparar traspaso al backend.** Entrega un prompt autocontenido listo para Claude Code en WSL2, con el contrato, estado (`BORRADOR` o `APROBADO`), comportamiento esperado, validaciones, errores, pruebas y criterios de aceptación. Ordena inspeccionar el Go real antes de implementar, sin asumir acceso al frontend Windows.
7. **Cerrar con verificación.** Expón pruebas de mapeo JSON y de estados de UI que correspondan, y deja explícito qué aspectos no se pudieron verificar sin el backend.

## Plantilla mínima de salida

- **Estado:** CONFIRMADO / BORRADOR / APROBADO, con evidencia o fuente del acuerdo.
- **Evidencia:** archivos revisados y partes no verificadas.
- **Objetivo:** caso de uso del MVP.
- **HTTP:** método, path, autenticación, parámetros.
- **Request y response:** JSON de ejemplo + semántica, tipos, opcionales y formatos.
- **Errores:** status y formato de body, fallo de red y comportamiento UI.
- **Compatibilidad y privacidad:** riesgos reales o `no aplica`.
- **Responsabilidades:** frontend / backend separadas.
- **Pruebas:** parsing, comportamiento observable y errores.
- **Prompt para backend:** autocontenido y listo para copiar.

## Límites

- No editar archivos Go ni ejecutar infraestructura del backend desde Windows.
- No implementar automáticamente la UI ni el cliente API solo por invocar esta Skill; si se solicita implementación, acordar primero el contrato y aplicar `flutter-feature` al cambio funcional.
- No introducir librerías, generación automática de clientes u OpenAPI sin justificar su necesidad y obtener aprobación.
- No afirmar que el backend cumple el contrato sin evidencias verificables.
