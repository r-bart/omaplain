# 0022 — La tinta atenuada lleva suelo de contraste

- Fecha: 4 de septiembre de 2026
- Estado: aceptada el 4 de septiembre de 2026
- Enmienda los números medidos de la
  [`0012`](./0012-el-anillo-de-foco-y-donde-viven-los-ajustes.md)
- Sale de escribir
  [`UPSTREAM-2026-09-04.md`](../notes/UPSTREAM-2026-09-04.md)

## Contexto

La [`0012`](./0012-el-anillo-de-foco-y-donde-viven-los-ajustes.md) fijó el
atenuado del panel en **0,68** del color del texto, con su medida al lado:

> Va en el color del texto al **0,68** —el alfa de rótulo que el panel ya usa,
> sin inventar un número— y mide **6,17:1** contra el fondo y **5,31:1** contra
> el relleno de foco sobre el que se pinta.

El número era correcto y la conclusión era demasiado ancha. Los dos contrastes
están medidos **sobre un tema**: el que estaba puesto ese día, que es
`terminus`. Un alfa mezcla el texto hacia el fondo sin mirar cuál es el fondo,
así que 6,17:1 no es una propiedad del 0,68 — es lo que ese 0,68 dio contra ese
fondo concreto.

Se destapó al escribir el informe de accesibilidad para Omarchy, cuyo argumento
central es exactamente ése: `Qt.darker(foreground, 1.6)` no puede prometer
ninguna ratio porque no mira al fondo. Al medir los treinta temas instalados
con [`contraste-del-kit.py`](../notes/contraste-del-kit.py) para sostener el
informe, apareció que **nuestros números tenían el mismo defecto**, sólo que
fallan menos veces.

Los dos atenuados del panel, contra el 4,5:1 que la WCAG 2.1 SC 1.4.3 pide para
texto:

| | Temas por debajo de 4,5:1 | Los peores |
|---|---|---|
| **0,68** — rótulos y `foreground`s de control | 4 de 30 | `rose-pine` 3,21:1 · `catppuccin-latte` 3,32:1 · `everforest` 4,31:1 · `tokyo-night` 4,46:1 |
| **0,72** — la prosa que envuelve | 2 de 30 | `rose-pine` 3,49:1 · `catppuccin-latte` 3,62:1 |
| **0,78** — el cuerpo del último paso del tour | 2 de 30 | `rose-pine` 3,98:1 · `catppuccin-latte` 4,15:1 |
| **0,60** — el rótulo de las tarjetas de la ilustración | 14 de 30 | `rose-pine` 2,72:1 · `catppuccin-latte` 2,80:1 |

Los dos peores son siempre temas claros, donde mezclar un texto oscuro hacia un
fondo claro pierde más contraste que al revés. Ninguno de los dos es el tema con
el que se desarrolla, que es justamente por lo que no se había visto.

## Decisión

**El alfa que se pide, con suelo de contraste.** Vive en
[`components/Ink.js`](../../components/Ink.js), y da cuatro entradas:

| | Alfa pedido | Suelo | Para qué |
|---|---|---|---|
| `secondary()` | 0,68 | 4,5:1 | rótulos, `foreground`s de control |
| `prose()` | 0,72 | 4,5:1 | descripciones, notas, prosa que envuelve |
| `dim(a)` | el que se le pase | 4,5:1 | los dos sitios con valor propio |
| `ring()` | 0,68 | **3:1** | el anillo de foco y los contornos propios |

Se atenúa lo que el diseño quiere, y se para antes de cruzar el suelo. Con los
treinta temas medidos, el 0,68 se queda **intacto en veintiséis** y sube en
cuatro; el que sube lo hace hasta lo justo, no hasta un valor redondo.

**El anillo va contra un suelo más bajo porque no es texto**: la SC 1.4.11 pide
3:1 para el contorno de un componente. Hoy ningún tema de los treinta se lo
levanta —el 0,68 da 3,21:1 en el peor—, así que `ring()` devuelve exactamente el
color que devolvía antes. Va igualmente: el número que hacía cierta esa frase
era una medida, y un tema nuevo no tiene por qué respetarla.

**Y los alfas por debajo de 0,5 no entran.** Los veinte que quedan sin suelo son
separadores, rellenos, y las rayas con que las ilustraciones dibujan un texto
que no es texto. Todos son `Rectangle`, comprobado uno por uno. Un suelo de
lectura sobre un separador lo convertiría en una raya negra.

## Lo que se descartó

- **Subir el número.** Un 0,835 valdría para los treinta —lo pide `rose-pine`—
  y dejaría el texto secundario casi tan brillante como el principal en los
  veintiséis a los que no les hacía falta. El atenuado existe para decir «esto
  es secundario»; un atenuado que no atenúa no dice nada.
- **Un alfa por modo, claro y oscuro.** Reparte el error en dos en vez de
  quitarlo: dentro de los oscuros, `everforest` y `tokyo-night` seguirían por
  debajo.
- **Esperar a que lo arregle el kit.** Es lo que se le está pidiendo a upstream
  en el informe 1, y puede que lo acepten. Pero el panel dibuja su propia tinta
  desde la `0012` y no la hereda del kit, así que un arreglo allí no llegaría
  aquí solo; y presentar un informe cuyo argumento es «una constante no puede
  prometer una ratio» mientras el panel envía la suya es la clase de cosa que
  un mantenedor tiene todo el derecho a devolvernos.
- **Calcularlo una vez y guardarlo.** El fondo cambia con el tema, en caliente
  y sin reiniciar. Pasarlo en cada llamada es lo que hace que el binding se
  reevalúe solo — la misma razón por la que `Strings.js` recibe el idioma en
  cada llamada en vez de guardarlo.

## Consecuencias

- **Treinta y nueve sitios de llamada** en trece ficheros pasan de
  `Util.alpha(Color.popups.text, α)` a la entrada de `Ink` que les toca: 19
  `secondary`, 16 `prose`, 2 `dim` y 2 `ring`. La expresión deja de estar
  repetida y cada número vive en un sitio.
- **Sobre el tema con el que se desarrolla, el panel no cambia de aspecto**:
  `terminus` no necesita subir ninguno de los cuatro alfas. El cambio se ve en
  los temas claros y en `everforest` y `tokyo-night`, que es donde había que
  verlo.
- La bisección corre en el hilo de interfaz, dentro de un binding. Son 24
  vueltas de aritmética sobre tres canales, y sólo cuando cambia el tema o se
  crea el componente. No es un bucle: no se reevalúa por cuadro.
- Dos guardas nuevos:
  - `tests/qml/TestRoot.qml` **ejecuta** el módulo con los pares de color de
    cinco temas reales, incluidos los cuatro que fallaban. Es la única forma de
    comprobar un suelo: leyendo el fuente sólo se ve que se llama a una función.
  - `test_no_readable_text_carries_a_bare_alpha` impide que vuelva a colarse un
    alfa pelado por encima de 0,5 sobre el color del texto.
- La `0012` conserva su argumento entero —el anillo lo dibujamos nosotros,
  neutro y por dentro— y pierde la lectura de que 6,17:1 sea una propiedad del
  0,68. Lo es de ese 0,68 sobre `terminus`.
