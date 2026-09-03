# Animaciones

Seis motores. Cada uno con sus números exactos, su disparador y su traducción a QML.

Todos respetan `motionEnabled` (que en `Panel.qml` es `!setting("reduceMotion", false)`):
con el movimiento reducido, **el binding se evalúa en su estado final** y la pantalla se
pinta ya terminada. Ver la última sección.

---

## 1 · El motor de caída

**Para qué**: los caracteres que se van de una cadena **real**. Sólo dos sitios lo usan:
`DemoTransformation` (paso 2 del tour) y `ClipboardRow` (la fila del resultado).

**Nunca** para tramos abstractos de una ilustración, ni para lo que sobra en el carrusel, ni
para un chip. Eso se comprime (§2).

### Balística

Forma cerrada, sin integración por cuadro. Para un añico que cae una altura `h`:

```
g  = 1400 px/s²                    (gravedad)
e  = 0.10 + hash₂(i) · 0.20        (restitución propia de cada añico)
t₁ = sqrt(2h / g)                  (llegada al suelo)

t < t₁            →  y = h · (t/t₁)²
rebote k (1 y 2)  →  hₖ = h · eᵏ ;  dₖ = 2 · sqrt(2hₖ / g)
                     u = (t − tc) / dₖ
                     y = h − 4 · hₖ · u · (1 − u)
después           →  y = h  (en reposo)

asiento total = t₁ · (1 + 2√e + 2e)
```

Dos rebotes y para. Un tercero no se ve y cuesta lo mismo.

**Restitución por añico**: es lo que hace que el conjunto no se lea como una cortina bajando.
`e` base es `0.18`; cada añico usa `(0.10 + hash₂·0.20) · (0.18/0.18)`.

**Aplastado en el primer impacto**: `scaleY = 1 − 0.16` durante 70 ms, con
`scaleX = 2 − scaleY` para conservar el área. Sólo en el primer rebote.

**Deriva y giro**, ambos con signo de un hash y aplicados sólo durante la caída libre
(`min(t, t₁)`), no durante los rebotes:

```
deriva = ±(1 + hash₃ · 6) px/s
giro   = ±(8 + hash₃ · 26) °/s
```

**Los hashes son deterministas**, no `Math.random()`: `hash(i) = (i · 2654435761) % 1000`,
`hash₂(i) = (i · 40503 + 17) % 997`, `hash₃(i) = (i · 69069 + 5) % 991`. Se ve irregular y
es reproducible, que es lo que necesita una captura de test.

### Coreografía

| Fase | Tiempo | Curva |
|---|---|---|
| Suelta | `t₀` → `t₀ + 420 ms` | lineal, escalonada por añico |
| Cierre del tramo | tras pasar el frente, 160 ms | `OutCubic` |
| Último suelo | ≈ 1 450 ms | — |
| Desvanecido del añico | 200 ms tras su asiento | lineal |
| Sello ✓ | `suelo + 200 − 20`, 180 ms, escala 0.74 → 1 | `OutCubic` |
| Frase de resultado | `sello + 40`, 180 ms | `OutCubic` |
| Recogida de la tarjeta | `sello − 40`, 380 ms, 88 → 68 px | `InOutCubic` |

**`t₀` por sitio**: 200 ms en la demo del tour, 250 ms en la fila del portapapeles.

**El frente de suelta va por posición pintada, no por orden en el árbol**: se ordenan los
añicos por su `x` real y se reparte `420 ms / N`. Con varios renglones eso dibuja una
diagonal, que es lo que hace un barrido.

**El cierre llega detrás del frente, no a la vez**: cada tramo empieza a cerrarse cuando su
último añico ya se ha soltado (`(rank_max + 1) · step`).

**La frase de resultado no cuelga del progreso de la limpieza**, cuelga del asiento. Hoy en
`DemoTransformation` entra entre `combed` 0.55 y 0.90, que con la caída caería en mitad del
vuelo y contaría el desenlace mientras todavía está ocurriendo.

**La recogida de la tarjeta empieza *después* del último carácter.** Primero se ve que está
limpio, luego la caja se ajusta a ese hecho. Al revés se leería como que la tarjeta empuja al
texto.

### Reglas de implementación

- **El suelo se mide una vez**, al preparar la caída: `alto de la pieza − 4 px`. Si la pieza
  envuelve más que la tarjeta (por ejemplo tarjeta + frase de resultado), hay que fijar el
  suelo a mano al borde inferior de la tarjeta, o los caracteres acaban cayendo al hueco de
  debajo, sueltos sobre el panel.
- **Los añicos viven en una capa hermana**, no dentro del `Flickable` de la fila: si el texto
  es largo hay desplazamiento y un añico podría acabar fuera de la vista. Coordenadas
  congeladas en el momento de la suelta.
- **Cada añico hereda el color de donde salió.** La capa vive fuera del tramo de acento, así
  que sin esto los caracteres que se van caen del color del texto que se queda, y eso rompe
  el idioma entero (acento = lo que se va).
- **El carácter invisible (`ZWSP`) no tiene glifo**: cae una caja vacía punteada de
  9 × 11 px, `border 1.5 dashed currentColor`, radio 2. Es lo que ya hace `CopySpecimen` con
  el mismo carácter, y es la única forma de que se vea irse algo que por definición no se ve.

### En QML

Hoy `DemoTransformation.shownText` reconstruye la cadena en cada cuadro con un `substring` y
el `Text` reenvuelve solo. Con la caída eso ya no sirve: cada carácter necesita su propia
posición.

El tramo que sobra pasa a ser un `Repeater` sobre `spare.split("")` con un `Text` por
carácter. **El fuente sigue teniendo una sola cadena en `Strings.js`** —no hay 54 trozos que
traducir— y `tests/unit/test_demo_sample.py` sigue comprobando la misma costura
(`head + spare + tail == original`).

La altura de la caja de la demo la sigue fijando `measure`. **No se toca**: los botones no se
pueden mover.

### Disparador de `ClipboardRow`

`onBodyChanged` **y** `revealed && motionEnabled`.

- Si al llegar el texto la fila está **descubierta**, cae.
- Si está **cubierta** por el vaho, no pasa nada y el sello hace su trabajo de siempre. Una
  caída debajo del vaho no la ve nadie y gasta la única vez que iba a ocurrir.
- **No se reproduce al destapar tres minutos más tarde.** Quien levanta el vaho quiere leer
  lo que hay, no ver una animación de algo que ya pasó.
- `locked` (app en la lista de «no destapar nunca») corta esto igual que corta el ojo.

Una limpieza, una caída, y sólo si había alguien mirando.

---

## 2 · El motor de compresión — nombrar y comprimir

**Para qué**: los tramos abstractos de una ilustración, lo que sobra en el carrusel, y un
chip MIME entero. Todo lo que **no** es un carácter real.

Tres tiempos, y ninguna letra por el suelo:

| Fase | Tiempo | Qué hace |
|---|---|---|
| **Nombrar** | `t₀` → `t₀ + 340 ms`, `OutCubic` | el tramo pasa de la tinta normal al acento **sin moverse** |
| **Comprimir** | `t₀ + 420` → `t₀ + 940 ms`, `InOutCubic` | se aplasta contra su borde izquierdo mientras el resto cierra el hueco |
| — | — | **sin sello** |

`t₀` = 250 ms en la bienvenida, 300 ms en los chips MIME.

### El color

Interpolación lineal sobre el progreso de la fase 1:

```
de  rgba(216, 203, 180, 0.45)     ← tinta de reposo
a   rgba(217, 168, 98,  1.00)     ← Color.accent
```

Si el tramo es una caja vacía punteada, la interpolación va en `border.color`, no en el
relleno.

### La compresión

Son **dos cosas a la vez**, y hacen falta las dos:

1. El **contenido** se aplasta: `scaleX 1 → 0` con `transformOrigin: Item.Left`, y la
   opacidad baja a `0.65`. Esto es lo que se lee como «comprimirse hacia la izquierda».
2. La **caja** se estrecha: `width → 0` (o `height → 0` si el tramo es vertical) con `clip`.
   Esto es lo que hace que el resto del renglón cierre el hueco.

Con sólo la caja, el tramo se lee recortado por la derecha. Con sólo el contenido, el resto
no se mueve y queda un agujero.

### Por qué este orden

Nombrar antes de retirar es lo que convierte el gesto en una explicación: se ve **qué** se
va, y luego se va. Y por eso **los tramos que sobran van más gruesos que el texto que se
queda** — 12 px contra 5 en la barra de dirección, 11 contra 5 en los renglones — para que
se sepa qué mirar antes de que empiecen a irse.

### El chip MIME

`MimeChips` en el estado «sólo se retira el formato» es el único caso donde las dos filas del
portapapeles salen idénticas: no cambia ni un carácter. Así que el cambio lo cuentan los
chips.

El `text/html` tachado se comprime hacia su izquierda (300 ms de retardo, 520 de recorrido) y
los dos siguientes cierran el hueco. **No cae**: un chip no es un carácter, es una pieza
entera, y las piezas se cierran.

Estilo del chip que se va: `color rgba(217,168,98,.75)`, `border 1px rgba(217,168,98,.32)`,
tachado de 1 px, **sin relleno**. Una sola señal para lo que se va. Los que se quedan van en
la tinta normal del panel (`popups.text`, borde `.30`), no en `Color.muted`: son justamente
lo que sobrevive.

---

## 3 · La cinta del control de seguridad — `TransformationIllustration` variante `protect`

**Para qué**: afirmar que las imágenes, los archivos y los secretos **no se tocan**.

Tres tarjetas quietas y sin acento no decían eso: decían «aquí hay tres cosas». Lo que lo
afirma es verlas pasar por el control y salir enteras.

### Geometría (en un marco de 460 × 220)

```
arco:      hueco de 156 px · montantes de 3 px en x=149 y x=308 · dintel de 3 px
           altura 184 px desde y=6
tarjetas:  130 × 152 px, y=22, sin rotación
cinta:     riel de 2 px a y=183, y un tramo de acento de 4 px entre los montantes
rótulo:    el anillo + «Untouched» centrado abajo, colgando del arco
```

**El hueco de 156 para tarjetas de 130 deja 13 px de aire a cada lado: nada llega a tocar
nunca a nada.**

**El arco va DETRÁS de las tarjetas** (montantes al fondo, tarjetas delante). En una cinta
continua hay siempre dos tarjetas encima de los montantes, así que lo tiene que resolver la
oclusión: la tarjeta tapa el montante, nunca al revés. Un filo de acento cruzando una
tarjeta se lee como un corte, que es exactamente lo contrario de lo que dice la pantalla.

### Movimiento

```
recorrido:  15 600 ms de extremo a extremo, lineal
tarjetas:   4, desfasadas 0 / 0.25 / 0.50 / 0.75 del ciclo
paso:       152.5 px entre una y la siguiente (22 px de hueco)
x(u) = −142 + u · (ancho + 152)
opacidad = fracción de la tarjeta que está dentro del marco
```

Cuatro tarjetas con tres tipos: imagen, archivos, secreto, imagen. Es una cola de copias, y
`4 × 0.25 = 1.0` es lo que hace que la cinta sea continua sin huecos muertos.

La opacidad **por fracción dentro del marco**, no por una banda fija de píxeles: con una
banda, una tarjeta a medio entrar sigue a plena luz y el borde la corta en seco.

Lento a propósito. Esto no compite con el texto del paso.

### El grano — «no la lee»

Dentro del arco, el dibujo de la tarjeta se apaga casi del todo y queda ruido. **La tarjeta
no cambia** —sale por el otro lado exactamente como entró—, es que el control **no la lee**.
Que es literalmente lo que hace el helper con una imagen: mira el tipo de la oferta y se
planta.

```
proximidad = max(0, 1 − |centro − x_arco| / 108)
intensidad = min(1, proximidad · 1.35)

grano:      opacidad = intensidad
dibujo:     opacidad = 1 − 0.9 · intensidad
temblor:    translateX = sin(t / 38) · 1.5 · intensidad   px
arco:       opacidad = 0.5 + 0.5 · proximidad
luz:        opacidad = 0.06 + 0.34 · proximidad
```

El temblor es de un píxel y medio y sale de un seno del reloj: **señal inestable, no tarjeta
rota**.

Lo único que reacciona es la luz del arco, y reacciona **a la presencia, no al contenido**.

### Las tres capas del grano

En el prototipo son tres fondos apilados en modo `screen`:

1. **Ruido**: turbulencia fractal de 120 × 120 en repetición, `baseFrequency 0.55`,
   3 octavas, **saturación 0** (gris; la turbulencia sale en color y en color parece
   confeti). Desplazamiento vertical `t / 9`.
2. **Barrido fino**: líneas de acento de 1 px cada 3 px, `rgba(217,168,98,.42)`.
   Desplazamiento `t / 5`.
3. **Trama ancha**: líneas de 2 px cada 9 px, `rgba(216,203,180,.16)`. Desplazamiento
   `−t / 24`.

**Las tres velocidades distintas son el truco**: con una sola se lee como una textura puesta
encima, no como una señal.

**En QML**: una textura PNG de ruido gris de 120 × 120 en `fillMode: Image.Tile` y dos
`Rectangle` con `Gradient` en repetición (o dos texturas de 1 × 3 y 1 × 9 en `Tile`),
animando sólo `sourceOffset`/`y` y `opacity`. **No hace falta `ShaderEffect`.** Se pinta una
vez y sólo se le anima el desplazamiento.

---

## 4 · Los interruptores y el recorrido — variante `control`

**Para qué**: el paso 3 del tour. «Ya viene configurado, y tú decides.»

Los interruptores **son** la ilustración: van dentro de una tarjeta de cristal, y la tarjeta
recorre la lista sola para enseñar que hay más debajo.

### Geometría (marco 460 × 220)

```
tarjeta:   320 × 148 px en x=70, y=20 · padding 18 / 20
columna:   5 filas de 24 px con 22 de hueco → 208 px de alto
velo:      22 px al pie de la tarjeta, hasta rgba(21,29,44,.78) — dice que hay más
```

Las cinco filas son los **ajustes reales**, con sus valores de fábrica:

| Fila | Estado |
|---|---|
| Clean automatically | encendido |
| Remove rich formatting | encendido |
| Remove link tracking | encendido |
| Remove invisible characters | encendido |
| Normalise quotes | **apagado** |

Salen de `settings.*`, que ya existen en `Strings.js` — así que esta ilustración **no
necesita ninguna clave nueva**, y deja sin usar `art.automatic`, `art.cleaning` y
`art.exclude` (ver `STRINGS.md`).

### Los interruptores

```
encendido:  a 420 / 600 / 780 / 960 ms, 300 ms OutCubic cada uno
pulgar:     left 2 → 18 px
pista:      rgba(216,203,180,.16) → #d9a862
pulgar:     rgba(216,203,180,.55) → #0c1626
```

Escalonados 180 ms. **Es la frase «ya viene configurado» dicha con el pulgar**, no un
interruptor por decisión del usuario.

**El que se queda apagado nunca se mueve.** Es el argumento de la pantalla —no viene nada
impuesto— y animarlo diría lo contrario.

### El recorrido automático

```
arranca:   1 400 ms (cuando los interruptores ya se han asentado)
paradas:   0 → −52 → −104 → −52 px  (va y vuelve)
descanso:  2 000 ms en cada parada
recorrido: 620 ms InOutCubic entre paradas
```

**Va y vuelve, no se reinicia de un salto.** La lista sube a enseñar lo que hay debajo y baja
a donde estaba.

En la parada más profunda, el fondo de la última fila queda a 122 px y el techo del velo a
125: la fila que el recorrido existe para enseñar **queda por encima del velo**, legible. Si
cambias alturas de fila o de tarjeta, recalcula esto o la última fila se queda debajo del
velo para siempre.

### Los interruptores de la página de ajustes (no la ilustración)

Los que el usuario pulsa de verdad llevan transición propia, no coreografía:

```
pulgar:  left 240 ms cubic-bezier(.3, .7, 0, 1) + color 240 ms ease
pista:   background 220 ms ease
```

---

## 5 · El carrusel del portapapeles vacío

**La coreografía no se toca ni un milisegundo.** Es la decisión 0008 y está bien resuelta.
Lo único que cambia es qué dibuja `CopySpecimen` dentro.

Se reproduce aquí para que quede en un solo documento:

```
turno (dwell):    2 600 ms
entrada:            300 ms  Bezier [.32, .72, 0, 1, 1, 1]   ← arranca fuerte y frena largo
retardo del texto:   70 ms  (entra un pelo detrás del dibujo)
asiento:             80 ms
peinado (combed):   620 ms  InOutCubic
descanso:         1 340 ms  ( = 2600 − 300 − 70 − 80 − 620 − 190 )
salida:             190 ms  InCubic
```

- La entrada es un empujón corto desde abajo: `translateY = offset · 14 px`, y
  `opacidad = max(0, 1 − |offset| · 1.3)`. El factor 1.3 es lo justo para que la tarjeta esté
  invisible al llegar al relevo; con 1.7 se quedaba vacía unos 75 ms entre ejemplo y ejemplo.
- **El relevo ocurre con el contenido ya invisible**: no se ve el cambio, sólo se ve llegar
  al siguiente.
- **La tarjeta no se mueve**: es el escenario. Lo que entra y sale es su contenido, así que el
  borde no parpadea tres veces cada ocho segundos.
- **Sólo la llegada asienta** (`landed = 1 − slide` mientras `slide > 0`, y 1 el resto): atado
  a `slide` a secas, la salida deshacía el gesto de entrada, que es una entrada al revés.
- **Las marcas de posición son además el reloj del turno**: la del ejemplo en curso mide
  20 × 5 px y se llena con el progreso; las otras 5 × 5. La transición de ancho es de 240 ms
  `OutCubic`. **Es la pieza más lista de esta pantalla** —convierte un cambio automático en
  algo que se ve venir— y no hay que tocarla.

### Lo que sí cambia: `CopySpecimen` baja a cristal

Los tres ejemplares pasan a ser tarjetas de cristal pequeñas (§`TOKENS.md`), a 100 × 96 px:

| Ejemplo | Composición | Lo que se comprime |
|---|---|---|
| **Enlace** | una hoja atenuada detrás (80 × 48) y una **barra de dirección** de 98 × 30 (radio 15) delante — la misma pieza de la bienvenida a un tercio de tamaño | la cola de seguimiento: cuatro tramos de acento de 6 px |
| **Párrafo** | una hoja de 82 × 88 con cinco renglones | la caja vacía punteada de 13 × 13, que al cerrarse (eje vertical) sube los renglones de abajo |
| **Con formato** | dos hojas apiladas: la atenuada detrás, la de cristal delante | la barra de titular de 42 × 9 (eje vertical) y el filete de cita de 4 × 17 |

Lo que sobra sigue cerrándose con el mismo `combed` de siempre, y el halo sigue dando su
único empujón de escala: `1 + 0.11 · sin(π · sweep)`, con `sweep = min(1, combed / 0.86)` —
el peine termina antes que el encogido, para que se lea como causa y no como acompañamiento.

**Fuera las motas y el barrido** que tenía la versión anterior. Ataban dibujo y frase cuando
el dibujo no se explicaba solo; ahora sí. Y cada uno costaba un `Repeater` y un gradiente
animado repintándose 23 veces por minuto, para siempre, en un panel que también corre en
portátiles.

---

## 6 · El sónar — `StatusHeader`, sólo en «arrancando»

**Para qué**: distinguir «espera un momento» de «pausado», que hoy se ven idénticos.

Es un **sónar y no un latido** a propósito: el servicio no está haciendo esfuerzo, está *a la
escucha* del portapapeles. Un anillo que sale y se pierde dice eso; uno que crece y se
encoge dice que algo se cansa.

```
barrido:   2 600 ms
anillos:   3, desfasados 0 / 0.34 / 0.68
escala:    1 → 3.2  OutCubic
opacidad:  0.85 · (1 − k) · min(1, u · 9)     ← el último factor evita el destello de entrada
trazo:     1 px, SIN escalar
caja:      Style.space(24), con el núcleo de 4 px centrado
```

**Tres anillos a la vez** porque uno solo, con 1 400 ms de hueco entre pasadas, parece que se
ha colgado.

**El trazo no escala.** En QML son tres `Rectangle` con `radius: width/2` sobre un solo
`NumberAnimation` compartido y un desfase por índice, no tres animaciones. `border.width: 1`
fijo: la escala del `transform` engordaría el trazo y el anillo lejano se vería más grudo que
el cercano.

**La caja de 24 px es obligatoria**: el anillo más lejano mide 19.2 px y sin esa reserva toca
el borde de la tarjeta.

### El eco

Uno de cada tres barridos devuelve un eco: un punto de acento en el radio, que se enciende
cuando el frente lo alcanza y se apaga detrás.

```
barrido = floor(t / 2600)
h       = (barrido · 2654435761 + 1013904223) mod 2³²
si h mod 3 ≠ 0 → sin eco
posición del encuentro: at  = 0.30 + ((h >> 8) mod 100)/100 · 0.45
ángulo:                 ang = ((h >> 16) mod 360)°
radio:                  3 + OutCubic(at) · 6.6 px
vida:                   0.34 del barrido, entrada rápida y apagado lineal
```

**No es aleatorio en ejecución**: el barrido que lo trae, su ángulo y su distancia salen de un
hash del número de barrido, igual que la deriva de los añicos. Se ve irregular y es
reproducible.

**Uno de cada tres es el techo**: más a menudo deja de ser un hallazgo y pasa a ser decoración
que parpadea.

---

## Reducir movimiento

`reduceMotion` apaga los seis motores. Cada pantalla se pinta **en el estado final del
ciclo**, y ninguna pierde información:

| Motor | Estado con movimiento reducido |
|---|---|
| Caída | añicos ocultos, tramo cerrado, sello puesto, frase de resultado visible, tarjeta ya recogida |
| Compresión | tramo en acento y comprimido a cero |
| Cinta | las cuatro tarjetas repartidas en sus posiciones de reposo, sin grano, arco a media luz |
| Interruptores | en su estado final; el recorrido de la lista, en la primera parada |
| Carrusel | primer ejemplo, ya peinado, sin marcas de posición (ni se reserva su hueco) |
| Sónar | anillos a opacidad fija, sin eco |

El sello, la frase de resultado y el texto limpio son **estados finales, no fotogramas**: por
eso se pueden pintar de golpe sin que falte nada.

Es la misma regla que ya cumplen los cuatro componentes animados de hoy, y nada de esto
introduce una excepción.
