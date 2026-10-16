# Trazo

Aplicación independiente de captura y anotación para **macOS 14 o posterior**. Primera versión local: selecciona una región, añade marcas y copia o guarda el resultado. Trazo es el nombre de trabajo del proyecto.

## Funciones

- Selección rectangular ajustable, con dimensiones en píxeles.
- Lápiz, resaltador, flechas, líneas, rectángulos, elipses y texto.
- Cinco colores y tres grosores.
- Deshacer y rehacer.
- Copia al portapapeles en PNG/TIFF y guardado local en PNG.
- Activación desde la barra de menús o con **⌘⇧2**.
- Prueba del editor con una imagen sintética, sin capturar la pantalla.

## Descargar

La [primera prerelease v0.1.0](https://github.com/GianniCarvacho-Prsnl/trazo/releases/tag/v0.1.0) incluye un ZIP de la aplicación para **Apple Silicon** con macOS 14+. Es una versión de prueba con firma ad hoc, todavía sin notarización; Gatekeeper puede impedir abrir el archivo descargado. Puedes compilar desde el código siguiendo los pasos de abajo.

## Compilar y abrir

Necesitas macOS 14+ y Xcode con Swift 6 (Xcode 16 o posterior). El proyecto usa Swift Package Manager y los frameworks de macOS, sin dependencias de terceros.

```sh
bash scripts/build-app.sh
open build/Trazo.app
```

El build genera `build/Trazo.app` para la arquitectura de tu Mac y le aplica una firma ad hoc para uso local. No es todavía una distribución con Developer ID y notarización.

Para preparar un ZIP y su checksum SHA-256 después de compilar:

```sh
bash scripts/package-release.sh --skip-build
```

Los archivos se guardan en `build/releases/`. Las [notas de v0.1.0](docs/releases/v0.1.0.md) documentan el alcance probado y las limitaciones.

Para probar:

1. Pulsa **Probar editor** para usar la imagen de ejemplo, o **Nueva captura** para capturar la pantalla.
2. Arrastra para seleccionar un área en una pantalla.
3. Escoge una herramienta y dibuja dentro del recorte. Con Texto, haz clic, escribe y pulsa Enter.
4. Usa **Copiar** o **Guardar**. Escape cierra la captura; dentro de un campo de texto, descarta primero ese texto.

La captura real necesita el permiso de **Grabación de pantalla** de macOS para Trazo. La app explica cómo abrir Ajustes del Sistema si el permiso está denegado. Después de concederlo, macOS puede requerir cerrar y volver a abrir Trazo. Las imágenes se procesan localmente.

Para ajustar el recorte, activa **Selección** y arrastra el interior o una de sus cuatro esquinas. Las anotaciones permanecen sobre la captura congelada mientras cambia el recorte. Si hay varias pantallas, selecciona un área dentro de una; las selecciones que cruzan monitores no están implementadas.

## Atajos del editor

| Acción | Atajo |
| --- | --- |
| Selección / Lápiz / Resaltador | V / P / H |
| Flecha / Línea / Rectángulo / Elipse / Texto | A / L / R / O / T |
| Copiar la selección / Guardar | ⌘C / ⌘S |
| Deshacer / Rehacer | ⌘Z / ⇧⌘Z |
| Cerrar captura | Esc |

Mientras editas texto, los comandos de edición actúan sobre el texto; pulsa Enter para incorporarlo a la imagen. El atajo global ⌘⇧2 depende de que otra aplicación no lo haya registrado. La ventana inicial avisa si está ocupado; siempre puedes usar el menú de Trazo.

## Verificación

```sh
bash scripts/test.sh
```

Ocho pruebas comprueban recortes, inversión del eje vertical, escalas de píxeles, composición de anotaciones, exportación PNG y el historial de deshacer/rehacer. Se compiló y abrió la app en este Mac. Se comprobó visualmente el editor y un PNG de 1020 × 470 píxeles con resaltador, flecha, rectángulo y texto. El permiso y la captura real con ScreenCaptureKit quedan pendientes de prueba por el usuario. Ver [validación y límites](docs/validacion.md).

## Estructura

- `Sources/CaptureCore`: geometría, datos de anotaciones, historial y composición/exportación.
- `Sources/Trazo`: aplicación AppKit, captura con ScreenCaptureKit, editor y barra de menús.
- `Tests/CaptureCoreTests`: pruebas de las conversiones y exportación.
- `Resources/Info.plist`: identidad y requisitos de la app.

El código está bajo [MIT](LICENSE). Los símbolos de interfaz se obtienen de las APIs del sistema.
