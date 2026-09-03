# Strings y tests

## Claves que entran

Tres, todas rótulos de ilustración. Van en las dos tablas, `EN` y `ES`.

| Clave | EN | ES | Dónde |
|---|---|---|---|
| `art.untouched` | `Untouched` | `Intactos` | pie de la variante `protect` (cinta del control) y rótulo de la tarjeta del bypass |
| `art.decide` | `You decide` | `Tú decides` | pie de la variante `control` |
| `art.byteForByte` | `Byte for byte, exactly as you copied it.` | `Byte a byte, exactamente como lo copiaste.` | pie derecho de la ilustración del bypass |

`art.byteForByte` es la única de las tres que es una frase y no un rótulo. **Si prefieres no
añadirla, se cae sin más**: la tarjeta y el rótulo `art.untouched` ya dicen lo esencial.
Quítala del diseño, no la dejes sin traducir.

## Claves que salen

| Clave | Por qué |
|---|---|
| `art.copied` | era el rótulo de uno de los dos naipes rotados de `transform`. Los naipes desaparecen. |
| `art.clean` | ídem, el otro naipe. |
| `art.automatic` | la variante `control` pasa a usar los rótulos de los ajustes reales (`settings.automatic`), que ya existen. |
| `art.cleaning` | ídem — la fila «Cleaning rules» pasa a ser `settings.formatting` y `settings.tracking`. |
| `art.exclude` | ídem — «App rules» sale de la ilustración; el quinto interruptor pasa a ser `settings.quotes`, apagado. |
| `demo.try` | el rótulo «Try it with an example» sale del paso 2: prometía una acción, y ahí no hay nada que probar. |
| `demo.original` | el botón «See the original» sale de la demo con la tarjeta que lo envolvía. |

`art.images`, `art.files` y `art.secrets` **se quedan**: son los rótulos de las tres tarjetas
de la cinta.

`demo.replay`, `demo.a11y.before` y `demo.a11y.after` **se quedan**: la accesibilidad de la
demo no cambia.

Balance: entran 3 (o 2 si descartas `art.byteForByte`), salen 7.

## Tests que hay que tocar

| Test | Qué comprueba y qué cambia |
|---|---|
| `tests/unit/test_strings.py` | paridad de claves entre `EN` y `ES`, y que no haya claves huérfanas. **Añadir las nuevas y retirar las siete que salen.** |
| `tests/unit/test_strings_runtime.py` | que cada clave usada en QML exista. Falla si retiras una clave que un `.qml` todavía pide: retira las claves **después** de tocar los QML. |
| `tests/unit/test_ui_contract.py` | compara la tabla `refusals` de `Panel.qml` con los motivos de `classify.py` / `transform.py` / `daemon.py`. **No cambia**: este rediseño no toca ninguna condición. |
| `tests/unit/test_demo_sample.py` | pasa `demo.sample1.*` por el motor real y comprueba la costura `head + spare + tail == original`. **No cambia**: el tramo sigue siendo una sola cadena en `Strings.js`, aunque el QML lo pinte carácter a carácter. |
| `tests/unit/test_empty_samples.py` | pasa los tres ejemplos del carrusel por el motor en los dos idiomas. **No cambia**: los ejemplos son los mismos. |
| `tests/qml.sh` / `tests/qmllint.sh` | ejecutar tras cada componente. La caída introduce un `Repeater` sobre caracteres en `DemoTransformation`: vigila los avisos de `qmllint` sobre propiedades no declaradas en los delegados. |
| `tests/unit/test_properties.py` | si añades propiedades públicas nuevas a los componentes (por ejemplo `revealed` en `ClipboardRow`, si no existe ya), decláralas con su tipo y su valor por defecto. |

## Accesibilidad — lo que no puede cambiar

- **El texto que cicla queda fuera del árbol de accesibilidad.** El carrusel cambia cada
  2 600 ms y no hay manera de pararlo, así que leerlo sería ruido: `Accessible.ignored: true`
  en el contenido, y el `Accessible.name` del `root` anuncia `empty.art.a11y`, que no cambia.
- **Las ilustraciones no anuncian su animación.** `TransformationIllustration` sigue con su
  `Accessible.name` de siempre; el grano, la cinta y los interruptores son decoración para un
  lector de pantalla.
- **F.5 · el mensaje de resultado no se va solo mientras el foco siga en el botón.** El reloj
  de 2 500 ms se rearma en vez de borrarlo. Nada de esto cambia.
- **El foco no para en un párrafo.** Si mueves un bloque de prosa, comprueba que sigue
  entrando en el mismo golpe de vista que el control que sí toma el foco.
- **La caída no roba el foco ni cambia el orden de tabulación**: los añicos viven en una capa
  hermana, sin foco, y desaparecen.

## Contraste — los valores medidos

Sobre `Color.popups.background`:

| Uso | Alfa | Contraste |
|---|---|---|
| prosa que envuelve | `0.72` | 6.20:1 |
| rótulos y `foreground` de control | `0.68` | 5.65:1 |
| pista del campo de clase | `0.68` | 5.55:1 (el `placeholderTextColor` del kit daba 4.19:1, por debajo del 4.5 de la AA) |

El acento sobre el fondo del panel, y la tinta `Color.background` sobre el acento, ya cumplen
en el tema. **El chip que se retira baja a `0.75` de acento y pierde el relleno**: sigue
cumpliendo, y deja de ser lo más brillante de la fila — que es lo que no debe ser algo que se
va.
