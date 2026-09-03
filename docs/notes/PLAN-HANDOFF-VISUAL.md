# Plan para portar el handoff de diseño

- Estado: **cumplido** (fases 0 a 9; la 10 quedó cortada por decisión)
- Fecha: 3 de septiembre de 2026
- Porta a QML el paquete de
  [`thoughts/design_handoff_omaplain/`](../../thoughts/design_handoff_omaplain/),
  que entró sin revisar en `0b2a7b3`.

## Qué significa «acabado» aquí

Las once pantallas del panel con los activos y el movimiento que describe el
paquete, sobre los componentes que ya existen. Sin dependencias nuevas: los
dos módulos que hacen falta —`QtQuick.Shapes` y `QtQuick.Effects`— ya los usa
el shell de Omarchy, así que caben en «los módulos ya incluidos por Omarchy»
del SPEC §13 sin tocar esa lista.

Fuera de alcance, por decisión del propio paquete: `FogCover` se queda como
está, y la coreografía del carrusel (`0008`) no se toca ni un milisegundo.

## De dónde partimos

`develop` con la suite entera en verde en una máquina con Omarchy: 369
unitarias, benchmark, soak, `qmllint` sobre 20 ficheros y 18/18 del QML
ejecutado dentro de Quickshell.

El paquete da por hechas cinco cosas que Qt Quick no hace de serie. Se
comprobaron ejecutando QML de verdad con el arnés de `tests/qml.sh`, sobre Qt
6.11.2, antes de escribir este plan:

| Lo que el paquete da por hecho | Cómo se resuelve | Medido |
|---|---|---|
| Gradiente a 150° | `QtQuick.Shapes` + `LinearGradient`; `Rectangle.gradient` sólo hace vertical y horizontal | ✅ |
| Halo radial, «nunca un halo plano» | `ShapeRadialGradient` | ✅ |
| Sombra del cristal `0 12px 26px` | `MultiEffect` de `QtQuick.Effects` | ✅ |
| Posición de cada carácter con el texto envuelto | `TextEdit.positionToRectangle()`; 6,594 px de avance, baja de renglón sola | ✅ |
| Que nada de esto ahogue el panel | 62,5 fps en los cuatro casos: la cinta con sombra, once superficies con sombra, el halo radial animado, y **4 096 añicos cayendo con la balística completa** | ✅ |

Los 4 096 son el peor caso absoluto: es el `PEEK_LIMIT` del demonio. Con 54 y
con 500 da lo mismo, así que el motor de caída no es un riesgo de coste.

**Aviso sobre esas cifras**: 62,5 fps es el techo del compositor de esta
máquina, no el margen que sobra. Lo que demuestran es que ninguno de los
cuatro casos se separa del control; si la sombra costara, se vería. En un
portátil lento habrá que volver a medir, y para eso está el criterio de la
fase 1.

---

## Las cinco decisiones que hay que tomar antes

Tres cambian tests con argumento escrito, y dos son elecciones técnicas que
condicionan todo lo demás. Van aquí porque no se resuelven a mitad de una
implementación, y porque conviene que quede escrito quién decidió.

Las dos primeras se preguntaron y se respondieron el 3 de septiembre; las tres
restantes se dan por buenas salvo objeción, porque son correcciones a lo que el
paquete dice y no elecciones de producto.

### 1. Los bucles del tour

`test_the_entrance_plays_once_and_never_loops` prohíbe `loops:`,
`Animation.Infinite` y `running: true` dentro de
`TransformationIllustration.qml`. El paquete mete **dos** bucles justo ahí: la
cinta de 15 600 ms del paso 1 y el recorrido de la lista del paso 3.

El test lleva su motivo escrito: *«un bucle ambiente en una ilustración de
onboarding es decoración, y encima compite con el texto que la acompaña»*. El
paquete argumenta lo contrario para la cinta: *«lento a propósito, esto no
compite con el texto del paso»*.

**Elegido: partir la diferencia.**

- **La cinta sí cicla.** Una cinta que se para deja cuatro tarjetas quietas, que
  es exactamente el problema que el rediseño vino a arreglar («tres tarjetas
  quietas no decían eso: decían aquí hay tres cosas»). El bucle *es* el
  argumento de esa pantalla.
- **El recorrido de la lista no cicla**: una sola ida y vuelta y se queda
  quieto. El argumento —«hay más debajo»— se cumple entero con un viaje. A
  partir del segundo es decoración, y ahí el test tiene razón.

El test pasa de «nunca hay bucles» a «nunca hay bucles fuera del tour», que es
lo que de verdad protegía: el panel frecuente. El bypass sigue quieto por
`motionEnabled: false` y por la `0007`.

Va con decisión numerada (`0017`), porque enmienda un criterio escrito.

**Descartado:** *renunciar a los dos bucles*, que devuelve el paso 1 a la
pantalla que el rediseño existe para sustituir. Y *aceptar los dos*, que gasta
el permiso en el sitio donde el test acierta.

### 2. De dónde salen los tramos de la fila del resultado

`ClipboardRow` recibe `body`, y en `row.would` el body es `peek.cleaned`: el
texto **ya limpio**, sin nada que soltar. El paquete despacha esto en una línea
(«atado a `revealed`») y no dice de dónde salen los caracteres que caen.

`peek` trae `original`, `cleaned`, `applied`, `types`, `typesAfter`, `changed`,
`reason` y `cover`. Ningún rango.

**Elegido: la fila no cae en esta tanda.** El motor de caída entra igualmente
por la demo del tour, que tiene sus tramos en `Strings.js` desde siempre y bajo
test (`test_demo_sample.py`). La fila se queda con el sello, que es lo que hace
hoy.

La opción buena para después es que **el helper devuelva los rangos retirados**:
ya sabe exactamente qué quita, y son índices, no contenido nuevo, así que no
roza la promesa de privacidad. Pero es helper, protocolo, `test_peek.py` y
`test_daemon.py`: un plan aparte, no una fase de éste. Queda apuntada como
fase 9, la primera que se corta si hay que cortar.

**Descartado:** *calcular el diff en QML*. Es O(n²) sobre 4 096 caracteres en el
hilo de la interfaz, y la normalización de comillas **sustituye** en vez de
quitar, así que prefijo y sufijo comunes no bastan en cuanto se retiran varios
tramos sueltos. Enseñaría una caída que no corresponde con lo que hizo el motor.

### 3. Qué dice el mando de la demo sin movimiento

`STRINGS.md` retira `demo.try` y `demo.original`. Pero hoy ese botón es único, y
`demo.try` («Try it with an example») es la vía de quien apagó las animaciones:
pulsa y ve la demostración de golpe. Con `demo.replay` fijo, el botón le diría
«Repetir» a alguien que no ha visto nada todavía.

**Elegido: sale `demo.original`, se queda `demo.try`.** El argumento del paquete
—«prometía una acción, y ahí no hay nada que probar: está ocurriendo»— es cierto
**con** movimiento y falso sin él. El botón conserva las dos caras que ya tiene:
`demo.replay` cuando hay movimiento, `demo.try` cuando no.

Salen seis claves, no siete.

### 4. La variante del bypass

`test_only_the_bypass_states_get_the_drawing` exige `variant: "protect"` en
`Panel.qml`. El paquete quiere ahí **una** tarjeta de 206 × 146 con el grano
quieto al 34 %, que ya no es la cinta del tour.

**Elegido: variante nueva, `unread`.** El nombre sale del propio paquete: el
grano dice que el control *no la lee*. El test pasa a exigir
`variant: "unread"` y `motionEnabled: false`, que es la parte que de verdad
protege la `0007`.

### 5. El gradiente del cristal y la textura de ruido

Dos elecciones técnicas pequeñas y con consecuencias en todo lo demás.

**El relleno del cristal va en gradiente vertical, no a 150°.** Un `Shape` por
superficie para diez puntos de alfa no se paga: en una cinta hay cuatro
moviéndose. `QtQuick.Shapes` entra igualmente, pero **sólo para el halo**, donde
el paquete es explícito en que un disco plano no vale — y un disco plano es
justo lo que hay hoy en `CopySpecimen.qml`.

**El ruido se pinta una vez con `Canvas` y no se repinta nunca.** El paquete da
por hecha una textura PNG de 120 × 120 que no existe, y el repositorio no tiene
un solo binario fuera de `docs/images/`. Un `Canvas` que se pinta al crearse y
no vuelve a llamar a `requestPaint` cumple el espíritu de lo que pedía el
paquete —que no se repinte por cuadro— sin versionar un binario. El ruido sale
de los mismos hashes deterministas de `ANIMACIONES.md`, no de `Math.random()`,
para que una captura de test sea reproducible.

**El modo `screen` de las tres capas no se puede.** Qt Quick no tiene modos de
fusión sin `ShaderEffect`, y el paquete lo descarta. Sobre un fondo tan oscuro
la mezcla normal se le acerca mucho; se acepta la desviación y se anota en el
comentario del componente.

---

## Ficheros

| Fichero | Acción | Para qué |
|---|---|---|
| `docs/decisions/0017-los-bucles-del-tour.md` | Crear | Decisión 1 |
| `docs/decisions/0018-el-material-del-panel.md` | Crear | Decisiones 4 y 5 |
| `components/GlassSurface.qml` | Crear | La receta del cristal sobre `BorderSurface` |
| `components/Halo.qml` | Crear | El radial de acento, centrado en el dibujo |
| `components/Grain.qml` | Crear | Las tres capas de ruido, con su textura pintada una vez |
| `components/TransformationIllustration.qml` | Reescribir | Cuatro variantes: `transform`, `protect`, `control`, `unread` |
| `components/CopySpecimen.qml` | Modificar | Los tres ejemplares bajan a cristal |
| `components/DemoTransformation.qml` | Modificar | El motor de caída |
| `components/MimeChips.qml` | Modificar | El chip que se retira se comprime |
| `components/Chip.qml` | Modificar | Estilo del chip que se va: sin relleno |
| `components/StatusHeader.qml` | Modificar | El sónar, sólo arrancando |
| `components/TourPage.qml` | Modificar | El paso 2 deja de montar ilustración |
| `components/WelcomePage.qml` | Modificar | La ilustración pasa a 464 × 190 |
| `Panel.qml` | Modificar | El bypass monta `unread` |
| `components/Strings.js` | Modificar | Entran 3 claves, salen 6 |
| `tests/qml/TestRoot.qml` | Modificar | Los componentes nuevos, ejecutados |
| `tests/unit/test_ui_contract.py` | Modificar | Los tres guardas que cambian |
| `tests/unit/test_strings.py` | Modificar | Las claves que entran y salen |
| `CHANGELOG.md` | Modificar | Lo que ve quien actualiza |

---

## Fases

Cada fase deja el árbol en verde. Ninguna depende de una posterior.

### Fase 0 · Las decisiones

Escribir `0017` y `0018` con lo acordado arriba. Sin código.

### Fase 1 · El material

`GlassSurface.qml`, `Halo.qml` y `Grain.qml`, con sus tres variantes de cristal
(atenuada, pequeña, hundida) según `TOKENS.md`.

`GlassSurface` extiende `BorderSurface` —que es un `Rectangle`, así que acepta
`gradient` y acepta hijos— con el relleno degradado, el filo de 1 px arriba, el
brillo interior al 46 % de alto y la sombra por `layer.effect`.

**Las alturas escritas a mano se traducen a mínimos, no a constantes.** El
paquete calcula «5 filas de 24 px con 22 de hueco → 208 px» y avisa de que si
cambian las alturas hay que recalcular a mano. `Style.font.*` lo puede cambiar
el usuario con `OMARCHY_MENU_FONT`, y el código de hoy ya evita esa práctica a
propósito (`ClipboardRow`: *«Mínimo, no fijo: con un tamaño de fuente mayor el
rótulo crecería por encima de una altura escrita a mano»*). Se porta el
criterio, no el número.

### Fase 2 · La bienvenida y el motor de compresión

La variante `transform` pasa a las dos tarjetas rectas y alineadas de 304 px
—fuera los naipes rotados, la flecha y el sello— y estrena el motor de
compresión de `ANIMACIONES.md` §2: nombrar 340 ms, comprimir 520 ms, sin sello.

Conducido por bindings sobre `progress`, no por `NumberAnimation` con
`property:`. Eso mantiene el guarda de
`test_the_entrance_animates_nothing_that_costs_a_layout` en verde — pero
**ese guarda hay que ensancharlo igualmente**: la compresión anima `width → 0`
a propósito, que es justo lo que el test existe para impedir, y colarse por su
literalidad sería peor que discutirlo. El test pasa a permitir el ancho de un
tramo que se retira, y a seguir prohibiendo el resto.

### Fase 3 · El carrusel

`CopySpecimen` baja a cristal: los tres ejemplares a 100 × 96, fuera las motas
y el barrido. **La coreografía no se toca** (`0008`). El halo pasa de disco
plano a `Halo.qml`.

### Fase 4 · La demo del tour

El motor de caída (§1) sobre `DemoTransformation`: los 54 caracteres del tramo
se sueltan por posición pintada, rebotan dos veces en el borde inferior de la
tarjeta y se desvanecen.

El tramo pasa a ser un `Repeater` sobre `spare.split("")`, con las posiciones de
un `TextEdit` invisible en `WrapAnywhere` vía `positionToRectangle()`. **El
fuente sigue teniendo una sola cadena en `Strings.js`**, así que
`test_demo_sample.py` sigue comprobando la misma costura sin tocarlo.

El suelo se fija a mano al borde inferior de la tarjeta, y los añicos viven en
una capa hermana con las coordenadas congeladas al soltar.

`TourPage` deja de montar ilustración en el paso 2:
`illustrationVariant` pasa de `["protect", "transform", "control"]` a montar la
ilustración sólo en los pasos 0 y 2.

### Fase 5 · Los chips

El `text/html` tachado se comprime hacia su izquierda (300 ms de retardo, 520 de
recorrido) y los dos siguientes cierran el hueco. `Chip` pierde el relleno
cuando se va: una sola señal para lo que se retira.

### Fase 6 · El sónar

Tres anillos sobre un solo `NumberAnimation` compartido con desfase por índice,
`border.width: 1` sin escalar, caja de `Style.space(24)`, y el eco de uno de
cada tres barridos por hash del número de barrido.

Sólo en «arrancando». Es un bucle, pero vive en el panel frecuente durante
segundos y `StatusHeader` no es la ilustración: el guarda de la `0017` no le
aplica, y conviene que la decisión lo diga explícitamente.

### Fase 7 · El tour: la cinta y los interruptores

Las dos variantes grandes, y las dos con las claves nuevas.

- `protect`: el arco detrás de las tarjetas, cuatro tarjetas desfasadas un
  cuarto de ciclo, opacidad por fracción dentro del marco, y el grano con sus
  tres velocidades. Cicla (decisión `0017`).
- `control`: los cinco ajustes reales con sus valores de fábrica, cuatro
  interruptores encendiéndose escalonados y el quinto quieto para siempre. El
  recorrido de la lista, **una sola ida y vuelta**.

Aquí entran `art.untouched` y `art.decide`.

### Fase 8 · El bypass

La variante `unread`: una tarjeta de 206 × 146 con el dibujo de lo que hay en el
portapapeles y el grano quieto al 34 %. A su derecha el anillo, «Untouched», un
filete y `art.byteForByte`. Fuera el inventario de tres filas.

Quieta siempre, desde `Panel.qml`.

### Fase 9 · El catálogo y los guardas

Las tres claves que entran y las **seis** que salen —`art.copied`, `art.clean`,
`art.automatic`, `art.cleaning`, `art.exclude`, `demo.original`— en los dos
idiomas. **Se retiran al final**, cuando ningún `.qml` las pide ya: al revés,
`test_strings_runtime.py` revienta.

Las cinco son sólo de `TransformationIllustration.qml`, comprobado. Y las
`settings.*` que la variante `control` reutiliza ya existen y las usa
`Panel.qml`, así que no quedan huérfanas.

Los tres guardas que cambian: los bucles (fase 0), el ancho de un tramo que se
retira (fase 2) y la variante del bypass (fase 8).

### Fase 10 · Los tramos de la fila *(cortada)*

El helper devuelve en `peek` los rangos retirados, y `ClipboardRow` estrena el
disparador de §1: cae al llegar el texto **sólo si la fila está descubierta**,
nunca al destapar más tarde, y `locked` lo corta igual que corta el ojo.

Es helper, protocolo y sus tests. Si se queda fuera, la fila conserva el sello y
no falta nada de lo que hay hoy.

---

## Dependencias

```yaml
dependencias:
  0:  []          # las decisiones
  1:  [0]         # el material
  2:  [1]         # bienvenida + compresión
  3:  [1]         # carrusel
  4:  [1]         # demo + caída
  5:  [1]         # chips
  6:  []          # sónar: no usa el material
  7:  [0, 1, 2]   # tour: cinta e interruptores
  8:  [0, 1, 7]   # bypass: reusa el grano de la cinta
  9:  [2, 4, 7, 8]
  10: [4]         # opcional
```

Las fases 2, 3, 4, 5 y 6 son independientes entre sí: se pueden repartir.

---

## Lo que cambió al implementarlo

Seis cosas que el plan no podía saber sin ejecutar el código. Van aquí porque
un plan que se cumple sin una sola sorpresa es un plan que no se contrastó.

**La sombra del cristal necesita un molde opaco.** `MultiEffect` saca la sombra
del alfa de lo que le das. Colgada de la superficie entera pasaban dos cosas:
el relleno es un 15 % de alfa, así que la sombra salía al 15 % de lo pedido y
no se veía; y el texto de dentro proyectaba la suya, un fantasma borroso
legible a través del propio cristal. La proyecta ahora una silueta aparte, del
color del fondo. Se paga con que esa silueta tapa lo que haya detrás, así que
la sombra se puede apagar.

**`TestRoot.qml` no dibujaba nada.** Colgaba de un `ShellRoot` sin ventana, y
sin ventana no hay renderizador: valía para comprobar lógica y no vale para un
lienzo, que sólo pinta si alguien lo pinta. El material vive ahora en una
`PanelWindow` de verdad, en una segunda tanda.

**El chip que se retira se nombra, y se queda.** El paquete lo comprime hasta
cero; al acabar quedaría `text/plain → text/plain`, y ésta es la única pantalla
donde las dos filas de texto salen idénticas. Mismo argumento que la decisión 2
de arriba: la pantalla frecuente informa, y una animación no puede llevarse por
delante la información que da.

**La tarjeta de la demo no se recoge.** El paquete lo pide en `ESTADOS.md` y lo
prohíbe en `ANIMACIONES.md` («la altura la sigue fijando `measure`, **no se
toca**: los botones no se pueden mover»). Se hace caso al segundo, que además
es lo que ya defendía un comentario del componente. El hueco que queda debajo
del texto limpio es justo donde se apilan los añicos.

**El grano se bajó dos veces.** El barrido fino al 42 % de acento cuenta con el
modo `screen`, que aquí no hay: en mezcla normal convertía la tarjeta en una
persiana. Y el tope del ruido, porque a plena intensidad cubre la tarjeta
entera y era lo más brillante de la pantalla, por encima del texto del paso que
acompaña. También hubo que cambiar el hash: el multiplicador de Knuth sobre el
índice del ráster es lineal en `x` y salían diagonales regulares, no ruido.

**El recorrido de la lista vuelve a cero.** El paquete lista las paradas
`0 → −52 → −104 → −52` y se queda en la tercera; su propio texto dice «baja a
donde estaba». Vuelve a cero, que además es donde descansa con el movimiento
apagado: los dos estados finales coinciden.

---

## Riesgos

**Lo medido y descartado.** El coste de la caída, de la sombra, del halo radial
y de la cinta. Ninguno se separa del control en esta máquina.

**Lo que queda vivo:**

- **El techo de 62,5 fps oculta el margen.** Hay que repetir la medición en un
  portátil antes de cerrar la fase 1.
- **El tamaño de fuente.** Toda geometría del paquete escrita como constante es
  un desbordamiento esperando a alguien con `OMARCHY_MENU_FONT` puesto. El
  criterio de la fase 1 lo cubre; el riesgo es que se cuele una constante en las
  fases 7 y 8, que son las que más números traen.
- **`Style.space()` redondea.** Multiplica por `effectiveSpacingScale` y aplica
  `Math.round`. Las relaciones que el paquete calcula a mano —los 13 px de aire
  a cada lado de la tarjeta, la última fila a 122 px contra el velo a 125— se
  conservan proporcionalmente, pero el redondeo puede comerse un píxel justo
  donde el paquete avisa de que se lo juega. Se comprueba mirando, a escala 1 y
  a otra.
- **El grano sin modo `screen`.** Desviación aceptada; si al verla no convence,
  la salida es un `ShaderEffect` de cuatro líneas, no rehacer la pantalla.
- **`Panel.qml` y `Service.qml` siguen sin arnés.** Los tests de `tests/qml/`
  ejecutan componentes; el panel entero sigue siendo cosa de mirar, y las fases
  7 y 8 tocan pantallas que sólo se ven ahí.

---

## Cómo se comprueba

No hay `npm` en este proyecto. La suite es `tests/run.sh`, y `tests/qml.sh`
necesita una sesión Wayland en la que anidar.

```sh
tests/run.sh                       # la suite entera
tests/qmllint.sh                   # sólo el humo del QML
tests/qml.sh                       # sólo el QML ejecutado
omarchy restart shell              # obligatorio tras tocar un .qml
```

`rescanPlugins` **no basta**: Qt conserva el QML ya compilado para esa URL y el
panel sigue enseñando la versión anterior sin dar ningún error.

---

## Criterios de hecho

### Fase 0
- [ ] `0017` y `0018` existen y `test_docs.py` pasa.
- [ ] La `0017` dice qué bucles se permiten y dónde, y por qué el sónar no cuenta.

### Fase 1
- [ ] `GlassSurface`, `Halo` y `Grain` cargan: `tests/qmllint.sh` en verde.
- [ ] Las tres se instancian en `TestRoot.qml` y `tests/qml.sh` las cuenta.
- [ ] El ruido se pinta **una vez**: un contador de `onPaint` en la prueba queda en 1.
- [ ] Ninguna altura de `GlassSurface` es una constante: todas salen de
      `implicitHeight` o de un `Math.max` contra el contenido.
- [ ] Medido en un portátil: los cuatro casos del probe por encima de 50 fps.

### Fase 2
- [ ] La bienvenida enseña dos tarjetas alineadas, sin naipes ni flecha ni sello.
- [ ] Con «Reducir movimiento» puesto, el tramo sale ya en acento y comprimido a
      cero: no falta información.
- [ ] `test_the_entrance_animates_nothing_that_costs_a_layout` ensanchado, con su
      motivo escrito en el propio test.

### Fase 3
- [ ] Los tiempos del carrusel son byte a byte los de hoy: `git diff` sobre
      `EmptyCarousel.qml` no toca ni un número de duración.
- [ ] `test_empty_samples.py` sigue en verde sin tocarlo.

### Fase 4
- [ ] `test_demo_sample.py` pasa **sin modificar**: la costura sigue siendo una
      sola cadena en el catálogo.
- [ ] Ningún añico cae fuera de la tarjeta: se mira con un texto que envuelva a
      tres renglones.
- [ ] Con el movimiento apagado, el botón dice `demo.try` y la demostración
      sigue estando a un clic.
- [ ] El paso 2 del tour no monta ilustración; los pasos 1 y 3 sí.

### Fase 5
- [ ] En «sólo se retira el formato», el chip `text/html` se comprime y los dos
      siguientes cierran el hueco.
- [ ] El chip que se va no es lo más brillante de la fila.

### Fase 6
- [ ] El sónar sólo aparece con el servicio arrancando; con `reduceMotion`, los
      anillos quedan a opacidad fija y sin eco.
- [ ] El trazo no engorda con la escala: se mira ampliado.
- [ ] La insignia de estado no cambia de alto respecto de hoy.

### Fase 7
- [ ] Ninguna tarjeta de la cinta toca un montante: se mira con la cinta parada
      en cada cuarto de ciclo.
- [ ] El quinto interruptor no se mueve nunca.
- [ ] El recorrido va y vuelve **una vez** y se queda quieto.
- [ ] La última fila queda por encima del velo también a otra escala de espaciado.

### Fase 8
- [ ] `test_only_the_bypass_states_get_the_drawing` exige `variant: "unread"` y
      `motionEnabled: false`.
- [ ] El bypass no se mueve al abrir el panel, ni la décima vez.

### Fase 9
- [ ] `test_strings.py` en verde con las tres claves nuevas en los dos idiomas.
- [ ] `test_strings_runtime.py` en verde: ninguna clave retirada la pide un `.qml`.
- [ ] `grep -c` de las seis claves retiradas devuelve 0 en `components/` y en la
      raíz.

### Al final
- [ ] `tests/run.sh` en verde entero, con Omarchy delante.
- [ ] `omarchy restart shell` y las once pantallas miradas una por una en el
      panel real, en los dos idiomas y con «Reducir movimiento» en las dos
      posiciones.
- [ ] `CHANGELOG.md` cuenta qué cambia para quien actualiza, no qué componentes
      se tocaron.
- [ ] Ningún `TODO` ni `FIXME` en lo nuevo.
