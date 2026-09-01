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
| Unitarias y propiedades | 189 tests, 0 fallos |
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

## Segunda pasada, 1 de septiembre

La cabecera y el tour cambiaron **después** de la pasada de abajo, así que lo
que aquella sección afirma se comprobó sobre un panel que ya no es exactamente
éste. Lo tocado se volvió a ver, midiendo el render en vez de mirarlo:

| Qué | Resultado |
|---|---|
| Cabecera: aire entre el botón y la regla | 16 px por arriba y por abajo (antes el botón cruzaba la regla 4 px) |
| Cabecera: frase de estado | 6,19:1, la misma que el subtítulo del veredicto |
| Cabecera: la insignia de estado | ausente con el servicio corriendo; presente con `skipNext` |
| Tour: aviso, demo y acciones | los tres en `x 39..651`, un solo borde izquierdo y uno derecho |
| Estados vistos de nuevo | vacío con carrusel, imagen, bienvenida, tour 1 y tour 2 |
| Omisión que caduca sola | test nuevo; antes se quedaba puesta indefinidamente |

Los estados que **no** se han vuelto a ver desde el cambio son los que la
cabecera comparte sin modificar: sensible, archivo, demasiado grande, ya
limpio, con formato y aplicación bloqueada. Entran en la prueba final.

## Contraste del borde de los controles — limitación conocida

El contorno de un botón `bordered` mide **2,79:1** contra el fondo del panel,
por debajo del **3:1** que la WCAG 2.1 SC 1.4.11 pide para el límite visual de
un control cuando es lo que lo identifica.

No es de OmaPlain. El color sale de `normal-border-alpha = 0.4`, el valor por
defecto de Omarchy en `default/themed/shell.toml.tpl`, aplicado al color de
texto del panel: `0,4` predice `rgb(94, 94, 95)` y lo medido fue
`rgb(93, 94, 95)`. Lo comparten todos los controles del escritorio.

Se deja como está a propósito. Pisarlo desde aquí haría que los botones de
OmaPlain se dibujaran distintos del resto de Omarchy para tapar un valor del
tema, que es peor para quien eligió ese tema. Quien quiera cruzar el umbral lo
sube en su `shell.toml`: **`0.44` da 3,15:1** y lo arregla en todo el escritorio.

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
