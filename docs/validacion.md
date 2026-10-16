# Validación local

Fecha: 15 de octubre de 2026. macOS 15.7.4, Apple Silicon, Swift 6.2.1.

## Completado

- `bash scripts/test.sh`: ocho pruebas Swift Testing correctas.
- `bash scripts/build-app.sh`: build release y empaquetado de `build/Trazo.app`.
- Las ocho pruebas y el build release también pasaron en una copia temporal que contenía únicamente los archivos versionados del proyecto.
- `codesign --verify --deep --strict`: firma ad hoc válida en disco.
- `plutil -lint Resources/Info.plist`: metadatos válidos.
- Apertura de la aplicación y prueba con imagen sintética, sin permiso de captura.
- Selección por arrastre de un área de 1020 × 470 píxeles.
- Barra de herramientas visible y controles accesibles con sus nombres y atajos.
- Anotaciones visibles de resaltador amarillo, flecha roja, rectángulo rojo y texto.
- Deshacer y rehacer mediante los botones de la barra.
- Panel nativo de guardado; se observó confirmación de guardado y se inspeccionó el PNG resultante de 1020 × 470. El archivo conserva el contenido seleccionado y las anotaciones y excluye la interfaz del editor.

La copia al portapapeles está implementada en PNG y TIFF. Se observó una confirmación de copia durante la prueba local, pero no se validó el pegado en aplicaciones externas.

## Cobertura de pruebas automatizadas

1. Selección arrastrada en sentido inverso y limitada a la pantalla.
2. Movimiento contra los bordes sin alterar el tamaño.
3. Conversión de coordenadas con escalas independientes y origen vertical invertido.
4. Historial de deshacer/rehacer y descarte de rehacer después de un cambio nuevo.
5. Marcas vacías excluidas del historial.
6. Recorte de la mitad inferior, resolución Retina y roundtrip PNG.
7. Anotaciones alineadas con el mismo sistema de coordenadas del recorte.
8. Selecciones fraccionarias y conservación de los píxeles del límite.

## Pendiente de validación

- Permiso de grabación de pantalla y captura real con ScreenCaptureKit.
- Pegado en aplicaciones externas y comportamiento de los tipos de imagen de portapapeles.
- Todas las combinaciones de pantallas físicas, posiciones, escalas, Spaces y apps a pantalla completa.
- Arrastre y redimensionado del recorte en sesiones reales extensas.
- Flujo de permisos revocados, pantalla desconectada, suspensión y errores de escritura reales.
- Binario Intel/universal, Developer ID y notarización.

## Límites actuales

- Una captura abarca una región dentro de una sola pantalla; no cruza monitores.
- Las anotaciones se pueden deshacer/rehacer, pero todavía no seleccionar individualmente para editarlas o moverlas.
- Texto de una línea; Enter lo incorpora a la captura.
- Salida a disco en PNG y atajo global fijo ⌘⇧2.
- Sin búsqueda, impresión, cuenta, subidas ni servicios remotos.
- Nombre y firma actuales son para el desarrollo local.
