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

