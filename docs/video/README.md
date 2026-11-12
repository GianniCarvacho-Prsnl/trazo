# Video de Trazo

Demo de 14 segundos, sin audio, compuesta con [HyperFrames](https://github.com/heygen-com/hyperframes). Las imágenes se obtuvieron del editor real mediante **Probar editor**; `trazo-result.png` es el PNG exportado desde la aplicación. El montaje muestra estados de la interfaz y no es una grabación continua de pantalla.

## Reproducir el montaje

Requiere Node.js 22+, FFmpeg y un navegador compatible con HyperFrames.

```sh
cd docs/video
npm run preview
npm run check
npm run render
```

El render genera `docs/media/trazo-demo.mp4`. La versión de HyperFrames está fijada en `package.json`. Las capturas y el montaje no contienen imágenes del escritorio ni datos personales.
