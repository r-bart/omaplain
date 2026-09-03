# Tokens

Todos los valores de los prototipos, y de dónde salen en el tema.

## Colores

| Prototipo | Token del tema | Valor usado | Dónde |
|---|---|---|---|
| `--pbg` | `Color.popups.background` | `#151d2c` | fondo de la tarjeta del panel |
| `--bg` | `Color.background` | `#0c1626` | fondo de la pantalla, y tinta sobre acento |
| `--pt` | `Color.popups.text` | `#d8cbb4` | texto |
| `--accent` | `Color.accent` | `#d9a862` | lo que se va, y las acciones primarias |
| `--muted` | `Color.muted` | `#5d6673` | estado del servicio |
| — | `Color.urgent` | (del tema) | sólo mensajes de error |
| escritorio | — | `#07101d` | fuera del panel; no es del producto |

**Los alfas son un idioma, no decoración.** El panel ya los distingue y hay que respetarlos:

| Alfa sobre `popups.text` | Para qué |
|---|---|
| `1.0` | titulares, veredicto, rótulos de tarjeta |
| `0.72` | **prosa que envuelve** (párrafos de dos o más líneas) |
| `0.68` | **rótulos y `foreground` de controles**, notas al pie |
| `0.55 – 0.60` | texto secundario dentro de una ilustración |
| `0.45` | tinta de reposo de un tramo que va a marcarse (ver `ANIMACIONES.md` §2) |
| `0.30 – 0.34` | renglones de relleno de una ilustración |
| `0.26` | borde del cristal |
| `0.20` | borde de control |
| `0.14` | filetes y reglas separadoras |
| `0.12 – 0.16` | rieles y fondos de superficie |

Nunca uses `0.68` para prosa ni `0.72` para un rótulo: es lo que hacía que la frase de
estado se leyera más apagada que el subtítulo del veredicto tres líneas más abajo.

## Tipografía

`JetBrains Mono` en los prototipos, `Style.font.family` en el producto. **Los tamaños son
estimaciones**: sustitúyelos por los del tema.

| Prototipo | Token | Uso |
|---|---|---|
| 28 px | `Style.font.displayLarge` | titular de la bienvenida (interlínea 1.06, `letterSpacing -0.5`) |
| 23 px | `Style.font.display` | titular de cada paso del tour (1.08, `-0.4`) |
| 18 px | `Style.font.heading` | veredicto (`-0.3`, negrita) |
| 16 px | `Style.font.title` | «OmaPlain» en la cabecera (`-0.2`, negrita) |
| 13.5 px | `Style.font.body` | rótulos de control, cuerpo del tour (1.5) |
| 12.5 px | `Style.font.bodySmall` | prosa del panel (1.45), filas de desglose |
| 11 px | `Style.font.caption` | eyebrows, notas al pie, insignias |
| 10.5 px | — | etiqueta de chip MIME |

Mayúsculas y `letterSpacing` de los eyebrows: `1.9 px` (`Style.spaceReal(0.9)` en el QML de
hoy). Rótulos de fila del portapapeles: `1.7 px`. Insignia de estado: `0.8 px`.

## Espaciado y geometría

| Valor | Qué es |
|---|---|
| `Style.space(520)` | ancho del panel. Todas las medidas de los prototipos están a este ancho. |
| `Style.space(20)` | margen de la pantalla principal; contenido útil 480 px |
| `Style.space(12)` | `spacing` de la columna principal |
| `28 / 26` y `spacing 14` | `x` / `y` / `spacing` del contenido de la bienvenida; contenido útil 464 px |
| `30 / 28` y `spacing 14` | ídem del tour; contenido útil 460 px |
| `Style.space(44)` | alto mínimo de área táctil (engranaje, primarios, campo de texto) |
| `Style.space(40)` | alto de los controles secundarios |
| `Style.space(720)` | **techo de la pantalla principal.** El onboarding no lo usa: su techo es la pantalla menos 32. |
| `Style.cornerRadius` (≈10) | tarjetas y superficies |
| 8 px | controles |
| 11 px | chips MIME (píldora) |
| 21 px | la barra de dirección de las ilustraciones (píldora de 42 px de alto) |

**Cuidado con `flex-shrink` / `Layout.fillHeight`.** En una columna con desplazamiento, todo
lo que lleve altura fija tiene que declararse no-comprimible (en QML: `Layout.preferredHeight`
+ `Layout.minimumHeight` iguales, o alturas explícitas dentro de un `Column`, no de un
`ColumnLayout` que reparta sobrantes). En el prototipo esto aplastó el botón «Start using it»
de 44 a 26 px.

## La receta del cristal

Es el material de todos los activos nuevos. Tres declaraciones y ninguna sombra de verdad:

```
fill:    linear-gradient(150°, rgba(216,203,180,.15) → rgba(216,203,180,.05))
border:  1 px rgba(216,203,180,.26)
sombra:  0 12px 26px rgba(4,10,20,.50)
filo:    inset 0 1px 0 rgba(255,255,255,.08)   ← el highlight interior de arriba
brillo:  hijo a inset 0, alto 46 %, linear-gradient(rgba(255,255,255,.055) → transparente)
radio:   10 px  (píldoras: alto/2)
```

**En QML**: una `BorderSurface` con un `Gradient` de dos paradas para el relleno, un
`Rectangle` de 1 px al `top` con `rgba(255,255,255,.08)` para el filo, y un `Rectangle` hijo
con `Gradient` vertical para el brillo. **No hace falta `ShaderEffect` ni desenfoque de
fondo**: el panel tiene color plano detrás, así que un desenfoque real no se distinguiría de
esto y costaría un repintado por cuadro.

Variantes:

| Variante | Cambios |
|---|---|
| **Atenuada** (la hoja de detrás) | relleno `.07 → .03`, borde `.13`, sombra `0 8px 18px rgba(4,10,20,.40)`, sin filo ni brillo |
| **Pequeña** (piezas de 100 × 96 del carrusel) | radio 8, sombra `0 6px 14px rgba(4,10,20,.45)`, filo `.07`, brillo alto 44 % a `.05` |
| **Hundida** (un campo dentro de una tarjeta) | fondo `rgba(12,22,38,.34)`, borde `rgba(216,203,180,.18)`, `inset 0 1px 3px rgba(4,10,20,.45)`, sin filo ni brillo |

## Halo

Todas las ilustraciones llevan el mismo: un radial de acento que muere antes del borde.

```
background: radial-gradient(circle, rgba(217,168,98,.13-.16), rgba(217,168,98,0) 66-68%)
```

Va centrado **en el dibujo, no en el recuadro**: cada composición ocupa un trozo distinto, y
un halo centrado «bien» asoma por una esquina como una sombra mal puesta. En el carrusel
además da un único empujón de escala cuando pasa el peine (`ANIMACIONES.md` §5).

Nunca un halo plano: al 10-18 % sobre un fondo tan oscuro no llega a brillar y sí llega a
ensuciar — se lee como un disco gris detrás del dibujo. En modo oscuro la profundidad sale
de un escalón claro, no de un velo.
