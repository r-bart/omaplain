# Informe de validación de OmaPlain 0.2.0

Fecha: 31 de agosto de 2026. Entorno: el baseline de [BASELINE.md](BASELINE.md).

## Resultado

La `0.2.0` pasa la puerta técnica del plan de cierre. Queda **una prueba final
en manos del usuario** antes de fusionar y etiquetar; su guion está en
[`PLAN-CIERRE-0.2.0.md`](../PLAN-CIERRE-0.2.0.md).

No se ha publicado nada ni se ha modificado `/usr/share/omarchy/`.

## Suite reproducible

```sh
tests/run.sh
```

| Prueba | Resultado |
|---|---|
| Unitarias y propiedades | 146 tests, 0 fallos |
| Transformación 10 KiB | p50 0,015 ms; p95 0,016 ms |
| Transformación 100 KiB | p50 0,123 ms; p95 0,129 ms |
| Transformación 1 MiB | p50 1,880 ms; p95 3,101 ms |
| Memoria máxima del benchmark | 22.416 KiB |
| Soak acelerado | 28.800 eventos; 1 escritura; 0 errores |
| Pico de asignaciones en soak | 466.616 bytes |
| Validador oficial | correcto |

## Auditoría de privacidad

Criterio de la `B.3`: una muestra marcada atraviesa `peek` y se persigue por
todas las salidas.

| Superficie | Resultado |
|---|---|
| Respuesta de `peek` por el socket | **aparece**, que es lo que tiene que pasar |
| Ficheros de `$XDG_RUNTIME_DIR/omaplain/` | limpio |
| `status.json` | limpio |
| Journal del shell | limpio |
| `~/.config/omarchy/shell.json` | limpio |

Y las dos rutas que añade la `0009`, comprobadas sobre el socket real con una
copia hecha desde una aplicación bloqueada:

- La respuesta es `source_blocked`, sin contenido y **sin lista de tipos**.
- El portapapeles queda intacto: no se reescribe.
- `status.json` registra `lastReason: source_blocked` y `lastBytes: 0`, ni
  siquiera el tamaño.

## Comprobado en el panel real

- Los diez estados de la pantalla principal, incluido el vacío con su carrusel.
- La página de ajustes entera, con la sección de privacidad y su detección de
  la aplicación en curso.
- El estado «omitir la próxima copia» en la cabecera.
- Movimiento reducido: el carrusel se queda en el primer ejemplo ya peinado y
  sin marcas de posición.
- Los dos idiomas.

## Texto con formato, visto por fin

Era el único estado que nunca se había pintado con contenido real. `wl-copy`
acepta un solo `--type`, así que la oferta doble `text/html` + `text/plain`
que produce cualquier navegador o editor no se puede montar con él, y los
tres caminos que se intentaron antes —`wl-copy --type`, teclas sintéticas
sobre Chromium y una sesión de chromedriver— no la produjeron.

**Sí se puede montar con GTK4**, que es lo que faltaba encontrar. Un
`Gdk.ContentProvider.new_union` sobre `new_for_bytes("text/html", …)` y
`new_for_value(str)` deja la ventana dueña de la selección sirviendo los dos
tipos. El guion está en el scratchpad de la sesión y cabe en 30 líneas.

Con eso, el estado se comprobó de las dos formas:

| Con | Resultado |
|---|---|
| Limpieza automática puesta | El demonio registra `cleaned / rich_text`, y el portapapeles queda ofreciendo sólo los tipos planos |
| `skipNext` armado | La copia llega intacta y **el panel la pinta**: «This can be cleaned», dos filas, y los chips con `text/html` y `text/plain` tachados apuntando al `text/plain;charset=utf-8` que queda |

El desglose lo rotula «Rich formatting». Es el único caso en que el texto no
cambia y aun así se reescribe, y la pantalla lo cuenta con los tipos en vez
de con el texto, que es justo lo que la `0005` decidió.
