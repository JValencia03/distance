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

## Servicios externos

- No uses servicios que requieran token, API key, cuenta o facturación (Mapbox, Google Maps, proveedores de tiles con clave, etc.), aunque tengan capa gratuita.
- Prefiere datos abiertos (por ejemplo, OpenStreetMap) procesados **offline** por una herramienta del repositorio (`frontend/tool/`) y empaquetados como asset. La app no debe depender de esos servicios en tiempo de ejecución.
- Respeta y muestra la atribución que exija la licencia de los datos (OSM: "© OpenStreetMap contributors").

## Rendimiento

- El rendimiento en móvil es prioritario. Si una librería lista para usar exige bastante más hardware (memoria, GPU, tamaño del binario, CPU en tiempo de ejecución) que una implementación propia y acotada, implementa la funcionalidad tú mismo. Justifica la elección.
- Haz el trabajo pesado (descarga, simplificación, triangulación) antes de tiempo, en herramientas de desarrollo. En la app, carga buffers ya preparados.
- En 3D, minimiza draw calls:
  - Fusiona la geometría estática por material y usa colores por vértice en vez de un material por pieza.
  - Usa `InstancedMesh` para objetos repetidos.
  - Limita cuántos elementos dinámicos se dibujan.
- Comprueba en un emulador o dispositivo que la escena se mantiene fluida, y explica qué se midió.

## Estilo visual

Conserva el estilo propio de la app (clay, pastel, formas redondeadas) también cuando muestres datos reales. Por ejemplo, un mapa debe reflejar la forma y ubicación reales de la ciudad, sus zonas y sus lugares, pero dibujados con la estética de Distance, no como un mapa fotográfico o de proveedor.

## 3D con flutter_scene

- Usa `package:vector_math/vector_math.dart`, no `vector_math_64`.
- Importa `flutter_scene` con `hide Material` en archivos que también usen widgets de Material.
- Espera a `Scene3d.ensureReady()` y ofrece una versión 2D cuando no haya 3D. En tests, `Scene3d.enabled` es `false` y se prueba esa versión 2D.
- Verifica visualmente en el emulador (capturas con adb) cualquier cambio de render.

## Privacidad

Solicita permisos de ubicación solo cuando sean necesarios y evita exponer coordenadas personales precisas sin requisito y autorización explícitos.

## Criterio de finalización

El flujo solicitado es verificable, sigue los patrones reales del proyecto, las pruebas pertinentes se ejecutaron o se justificó por qué no, y las limitaciones quedan explícitas.