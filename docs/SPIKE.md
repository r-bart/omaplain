# Resultado del spike técnico

Estado: **go para modo automático standalone**, con una limitación documentada en el historial cuando una transformación cambia caracteres.

## Prototipo validado

El spike se convirtió en la base del helper definitivo para evitar desechar trabajo probado. Su arquitectura es:

```text
wl-paste --watch
  → proceso efímero que envía solo CLIPBOARD_STATE
  → socket Unix 0600
  → daemon serializado
  → clasificación MIME
  → lectura limitada de text/plain
  → transformación e invariantes
  → compare-before-write
  → wl-copy text/plain
```

El estado sensible se descarta antes de consultar MIME o leer stdin. Imágenes sin texto ni siquiera activan el watcher textual; archivos y payloads estructurales que también ofrecen texto se rechazan por MIME.

## Resultados

| Prueba | Resultado |
|---|---|
| URL con `utm_source` | Limpia y conserva host, ruta y parámetros funcionales |
| `wl-copy --sensitive` | Bypass; el probe no apareció en el historial de Omarchy |
| Copia de archivos | Conservó `text/uri-list` y MIME de Nautilus |
| Imagen PNG | Conservó MIME y hash; el watcher textual no intervino |
| 21 copias consecutivas | La última ganó y terminó limpia |
| `skipNext` | Conservó exactamente una copia elegible; `cleanNow` pudo limpiarla después |
| Loop guard | 1.000 eventos sintéticos produjeron como máximo una escritura |
| Pegado en Foot | `Shift+Insert` llegó a la ventana capturada y el proceso verificó el texto |
| Dependencias | Todas presentes; cero paquetes adicionales |

La suite inicial cerró con 39 tests unitarios en menos de 0,1 segundos.

## Historial nativo

El probe confirmó el comportamiento previsto:

- Una URL original y su versión limpia aparecen como dos entradas distintas.
- Un secreto marcado no aparece en el historial.
- El plugin nunca lee ni escribe `clipboard-history.json`.

Esto no impide el modo automático, pero obliga a mostrar una advertencia cuando se activan transformaciones que cambian caracteres. Retirar solo formato conserva el mismo texto y el historial nativo puede deduplicarlo.

## Decisión

Se mantiene el modo automático en `0.1.0` porque:

- No se observó pérdida de ownership, MIME o datos en los casos protegidos.
- Compare-before-write resolvió las copias rápidas.
- El loop guard evitó autoreescrituras.
- La duplicación afecta solo a transformaciones semánticas y tiene workaround: desactivar esas reglas o usar `pasteClean`.

El modo automático se presentará como compatible con una limitación conocida, no como integración transaccional con el historial. Una filter API upstream queda como mejora posterior y no como dependencia de la primera release.

## Spike `D.1` — la cubierta en QML

**Fecha:** 31 de agosto de 2026. **Pregunta:** ¿se puede llevar a QML la
cubierta de vaho del prototipo, que se borra arrastrando?

Dos incógnitas, las dos medidas y no supuestas. La consola de `qml6` no llega
en este entorno, así que ambos spikes devuelven su veredicto en el código de
salida y lo comprueban leyendo píxeles con `getImageData`, no a ojo.

| Pregunta | Método | Resultado |
|---|---|---|
| ¿`Canvas` soporta `globalCompositeOperation = "destination-out"`? | Pintar opaco, borrar un disco, leer el alfa dentro y fuera | **Sí.** Centro transparente, esquina opaca |
| ¿Cuánto cuesta repintar la neblina entera? | 60 repintados de 46 degradados radiales sobre 500×104 | **1,5 ms por fotograma** |

A 30 fps el presupuesto es de 33,3 ms, así que la neblina ocupa un 4,5 % de
él. Cabe de sobra incluso dibujando cada degradado uno a uno, que es el peor
caso: en QML no hay un lienzo auxiliar cómodo del que hacer `drawImage`, así
que no se puede pre-renderizar la textura como en el prototipo HTML.

**Decisión:** la cubierta se implementa con `Canvas`, con el barrido en una
máscara aparte igual que en el prototipo. No hacen falta ni `ShaderEffect` ni
la cubierta lisa de reserva.

**Salvedad:** la medida es con `-platform offscreen` en este equipo. Falta
confirmarla en el panel real, cosa que hace `D.8`.

