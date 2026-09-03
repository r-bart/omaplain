# Estados

Las once pantallas del panel: qué las dispara, qué monta cada una, y qué se anima.

Los disparadores son los de `Panel.qml` tal como está hoy. Nada de este rediseño cambia una
condición.

---

## Acto I · La primera vez (cinco pantallas, una vez en la vida)

### 1 · Bienvenida — `WelcomePage`

**Disparador**: `setting("onboardingVersion", 0) < 2` al abrir el panel. También desde
Ajustes → «Review the welcome».

**Composición**: contenido a `x 28 / y 26`, `spacing 14`, ancho útil 464 px.

1. **Ilustración `transform`**, 464 × 190 — *el activo nuevo*
2. Eyebrow centrado: `welcome.eyebrow.first` («First visit») o `.return` si vuelve de ajustes
3. Titular `welcome.title` a `displayLarge`, dos líneas, centrado
4. Cuerpo `welcome.body`, tope de 420 px, centrado
5. Tres tarjetas `welcome.card1..3`, rejilla de 3 (o 1 si el ancho baja de 420)
6. `welcome.start` (primario) + `welcome.enter` / `.return`
7. Nota `welcome.again`

**La ilustración**: dos tarjetas de cristal **rectas y alineadas** —una barra de dirección de
42 px encima, una página de 104 px debajo, ambas de 304 px de ancho, `gap 9`— centradas en
`x 80, y 14`. Se leen como un objeto, un navegador, y no como dos dibujos cerca.

**Fuera los dos naipes rotados y la flecha central** de la versión de hoy. Eran la manera de
contar «antes → después» en un dibujo quieto; con movimiento sobran, porque la
transformación *ocurre*. Y dos naipes de 116 × 122 en 248 px de ancho no dejaban respirar
nada. Se gana toda la anchura para una hoja legible.

**Fuera también el sello ✓.** La prueba es el hueco cerrado; un ✓ encima repetía en un glifo
lo que la propia línea acaba de demostrar.

**Se anima**: sólo la ilustración, con el **motor de compresión** (`ANIMACIONES.md` §2),
`t₀ = 250 ms`. Tres tramos: cuatro bloques en la barra de dirección, tres en un renglón de la
página, y una caja vacía punteada en otro. Termina antes de que se lea el título — es el
reparto correcto: la ilustración capta, el texto explica.

**Nada más se mueve en esta pantalla.**

---

### 2 · Tour, paso 1 de 3 — `protect`

**Disparador**: `welcome.start`, o Ajustes → «Repeat the mini tour», o el botón
`empty.how` de la pantalla del portapapeles vacío.

**Composición**: `x 30 / y 28`, `spacing 14`, útil 460 px. Eyebrow `tour.eyebrow` (o
`.replay`) + contador `tour.step`; barra de tres segmentos; ilustración 460 × 220; titular
`tour.1.title`; cuerpo `tour.1.body`; nota `tour.1.note` en su superficie; `tour.back` +
`tour.next`; salida `tour.skip` / `tour.leave` sin borde.

**La barra de progreso rellena todos los segmentos hasta el paso actual** (`index <= step`),
no sólo el primero.

**La ilustración**: la **cinta del control de seguridad** (`ANIMACIONES.md` §3). Un arco, una
cinta y cuatro tarjetas de cristal que pasan por delante de los montantes y salen enteras.
Dentro del arco, cada tarjeta se convierte en grano: señal codificada.

**Fuera el rombo de acento** con el ✓ gigante rotado 45° de la versión de hoy: tapaba la
palabra «Secrets», tocaba el borde derecho, y su ✓ era el mismo glifo del sello — dos cosas
distintas con la misma cara.

**Se anima**: la cinta, en bucle de 15 600 ms. **Nada cae ni se comprime**: aquí no se retira
nada.

---

### 3 · Tour, paso 2 de 3 — la demostración

**Disparador**: `tour.next` desde el paso 1.

**Esta pantalla NO monta ilustración.** Preside `DemoTransformation`, y ocupa el sitio que en
los otros pasos ocupa el dibujo.

Es un cambio respecto de hoy: `TourPage.illustrationVariant` monta `transform` en el paso 2 y
`DemoTransformation` es visible en el mismo paso, así que la pantalla tenía dos activos con
caída y repetía la composición de la bienvenida en la pantalla siguiente. **La ilustración
sale de este paso.** Con eso el choque desaparece por sí solo y cada pantalla del recorrido
presenta un activo distinto.

**La demo**:

- Una sola tarjeta de cristal de **88 px** con el texto dentro, anclado arriba, recortado.
- La cadena es `demo.sample1.head` + `spare` + `tail` (con su `ZWSP` dentro del tramo que se
  retira). **Verbatim de `Strings.js`.**
- Debajo, **fuera de la tarjeta**, la frase `demo.outcome1`.
- **Fuera el rótulo `demo.try` («Try it with an example»)**: prometía una acción, y aquí no
  hay nada que probar — está ocurriendo.
- **Fuera el botón `demo.original` («See the original»)** y fuera la tarjeta que envolvía:
  metían tres bordes concéntricos para enseñar una cadena.

**Se anima**: el **motor de caída** (`ANIMACIONES.md` §1), `t₀ = 200 ms`. Los 54 caracteres
del tramo se sueltan de izquierda a derecha, caen por delante y rebotan en el borde inferior
de la tarjeta. La frase entra cuando el suelo está limpio, y **entonces** la tarjeta se recoge
de 88 a 68 px (tres renglones pasan a dos).

Aquí es donde la caída se gana el sitio: la cadena es real, los caracteres que se van son los
que se irían, y el resultado se cuenta cuando ya ha pasado.

---

### 4 · Tour, paso 3 de 3 — `control`

**Disparador**: `tour.next` desde el paso 2. El primario dice `tour.finish` («See the
settings») si el recorrido continúa a los ajustes, o `tour.done` («Finish») si termina aquí.

**La ilustración**: los **interruptores dentro de una tarjeta de cristal, con recorrido
automático** (`ANIMACIONES.md` §4).

Esto invierte una decisión anterior («fuera el recuadro, los interruptores ya son la
ilustración»). Con la familia de cristal puesta es lo correcto: la caja ya no es un recuadro
de más, es **el mismo objeto** que en los dos pasos anteriores. Tres pasos, tres cosas
distintas hechas del mismo material — una cinta de tarjetas que pasan, una tarjeta con tu
texto, una tarjeta de ajustes.

**Fuera el ✓ flotando en la esquina** de la versión de hoy: pisaba el recuadro sin decir a
qué se refería, y era la tercera aparición del mismo glifo en tres variantes.

**Se anima**: los cuatro interruptores encendidos, escalonados, y luego el recorrido de la
lista. El quinto interruptor **no se mueve nunca**.

---

### 5 · Ajustes · último paso del recorrido

**Disparador**: `showOnboardingSettings()` — la primera vez, tras el paso 3.
`onboardingSettings = true`, `panelPage = "settings"`, `viewMode = "main"`.

**Diferencias con la página de ajustes normal**:

- Una banda arriba con `onboarding.last` + `onboarding.last.body`.
- El engranaje de la cabecera pasa a ser `nav.skip` («Skip ›»), y **salta a la pantalla
  frecuente**, no a ajustes.
- Al final, el primario `onboarding.done` («Start using it»).
- **El techo de 720 px no aplica**: se mide contra la pantalla menos 32. Se ve una vez, se
  lee de arriba abajo y su acción primaria vive al final; cortarla por el techo dejaba
  «Siguiente» y la salida por debajo del borde.

**Cero activos animados**, y es correcto: es una lista de ajustes.

---

## Acto II · Cada día (cinco estados de la pantalla frecuente)

Todos comparten la cabecera: «OmaPlain» + el engranaje `nav.options`, un filete, la cabecera
de estado (`StatusHeader`, silenciosa si el servicio va bien y no tiene nada que contar), el
veredicto a `heading` y su explicación a `bodySmall`.

### 6 · Se puede limpiar

**Disparador**: `peek.eligible && peek.changed`.

**Monta**: fila `row.now` + fila `row.would` + el desglose de `peek.applied` + `action.apply`
+ `footnote.safe`.

**Se anima**: **la fila del resultado** (`row.would`), con el motor de caída y `t₀ = 250 ms`
— y sólo si está descubierta (ver el disparador de `ClipboardRow` en `ANIMACIONES.md` §1).

La fila `row.now` **se queda quieta**, con el tramo que se va marcado en acento a `0.85`. Así
la pantalla se lee de arriba abajo como una frase: esto es lo que hay, y esto es lo que
queda.

Ambas filas nacen cubiertas por el vaho. El ojo de cada fila levanta **la suya**, no las
siguientes.

### 7 · Ya está limpio

**Disparador**: `peek.eligible && !peek.changed`.

**Monta**: una sola fila `row.single` + `footnote.safe`. **Sin botón primario** (0015).

**No se anima nada**, y no por ahorro: no hay nada que retirar, así que una animación
mentiría. Es el estado más frecuente con el automático puesto — tres líneas y una fila.

### 8 · Portapapeles vacío

**Disparador**: `peek.eligible !== true && peek.reason === "empty"`.

**Monta**: `verdict.empty` + `detail.empty` + `EmptyCarousel` + el botón `empty.how`.

**Se anima**: el **sónar** de la cabecera de estado (sólo si el servicio está arrancando) y
el **carrusel**. Dos cosas en bucle a la vez: **es el peor caso del panel.** Aguanta porque
van a velocidades muy distintas y ninguna pide atención — y porque aquí no cae nada.

Si al usarlo cansa, lo que sobra es el sónar: el carrusel enseña el producto, el sónar sólo
dice que el servicio arranca, y ese estado dura segundos.

### 9 · Bypass (imagen, archivos, secreto, demasiado grande, app bloqueada…)

**Disparador**: `peek.eligible !== true && peek.reason !== "empty"` (`peekBypass`).

**Monta**: el veredicto y la explicación del motivo (tabla `refusals` de `Panel.qml`), la
**ilustración de una sola tarjeta**, `MimeChips` con los tipos de la oferta, y la nota al pie
que corresponda.

**La ilustración**: **una** tarjeta de cristal de 206 × 146 con el dibujo de lo que hay en el
portapapeles, y el grano quieto encima al **34 %** — el mismo grano de la cinta del tour, sin
movimiento, que es lo único que OmaPlain llega a ver de ella. A su derecha, el anillo +
«Untouched», un filete, y `art.byteForByte`.

**Fuera el inventario de tres filas** (Images / Files / Secrets): es del tour, y aquí sobraba
dos tercios. Esta pantalla habla de **una** cosa concreta — la que tienes en el portapapeles
ahora. Y «Untouched» colgando debajo de la lista se leía como una cuarta fila del inventario;
ahora rotula la tarjeta.

**Quieto siempre**: `motionEnabled: false` desde `Panel.qml`. Un bypass se ve muchas veces al
día —cada captura de pantalla es uno— y una animación de entrada en cada apertura es justo lo
que no se le hace a un gesto frecuente.

### 10 · Sólo se retira el formato

**Disparador**: `peekChanges && peek.original === peek.cleaned` (`peekFormatOnly`).

**Monta**: las dos filas (idénticas), `MimeChips` comparando antes → después, el desglose con
`rule.rich_text`, y el primario.

**Se anima**: el **chip `text/html`**, comprimiéndose (`ANIMACIONES.md` §2). Es el único
estado donde las dos filas salen idénticas —no cambia ni un carácter—, así que el cambio lo
tienen que contar los chips.

---

## Acto III · Los ajustes

### 11 · Página de ajustes

**Disparador**: el engranaje (`togglePage()`), que además captura las ventanas abiertas para
el selector.

**Orden de la página** (sin cambios respecto de hoy): Idioma → Movimiento → Modo (+ la nota
del historial y el desplegable `history.why`) → Limpieza (cuatro visibles + el desplegable
`settings.optional` con cuatro más) → Aplicaciones (párrafo, nota de Wayland, selector de
ventanas abiertas, campo de clase, botón, mensaje, lista de tarjetas `AppRules`) → la promesa
de privacidad → Ayuda y aprendizaje.

**Techo real de 720 px con desplazamiento interno.**

**Cero animación en toda la página**, y es la única pantalla del panel donde eso no hay que
justificarlo. Los interruptores que el usuario pulsa llevan su transición propia
(`ANIMACIONES.md` §4, último apartado).

---

## Resumen

Once pantallas, cinco animaciones, y **seis pantallas que no mueven nada**. Es la proporción
que hay que defender. Las que se mueven lo hacen por un motivo distinto cada una:

| Pantalla | Qué se mueve | Por qué |
|---|---|---|
| Bienvenida | la ilustración se comprime | capta antes de que se lea el título |
| Tour 1 | la cinta pasa | afirma que no se toca nada |
| Tour 2 | la demo cae | demuestra con una cadena real |
| Tour 3 | los interruptores y la lista | «ya viene configurado, y hay más» |
| Se puede limpiar | la fila del resultado cae | prueba lo que promete |
| Sólo formato | el chip se comprime | es el único sitio donde se ve el cambio |
| Vacío | sónar + carrusel | espera; el único bucle del panel |
