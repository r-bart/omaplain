# Changelog

Todos los cambios relevantes de OmaPlain se documentan aquí.

## 1.0.0 — 2026-09-04

The first release that makes a promise: **what OmaPlain does not touch today, it
will not touch tomorrow, and your settings survive an update**. It does not
promise there will be no new features — it promises the ones here will not
change underneath you.

It is also the first changelog entry written in English
([`0014`](docs/decisions/0014-el-idioma-del-repositorio.md)). The entries below
`1.0.0` stay in Spanish; rewriting history does not improve it.

Everything in this entry landed after `0.2.0`, most of it out of a full review
of helper, QML, docs and tests carried out on 2 September.

### Fixed

- **The preview follows the clipboard.** It was only requested when the panel
  opened: after *Apply*, after a skip, or after copying something else, the rows
  went on saying "this is what you would get" with the button still enabled. The
  helper now records every event in `status.json` — with automatic cleaning off
  too — and an open panel looks again as soon as it changes.
- **Content dies with the panel.** `Service.forgetPeek` promised it and nobody
  called it: the text stayed in memory, came back to the rows on reopening until
  a fresh peek arrived, and the fog at 30 fps and the carousel kept running
  inside a closed window.
- **Reading the clipboard has a deadline.** A source application that never
  served its offer left the daemon hung forever holding the lock: no events, no
  manual clean, no peek. Two seconds for the read, one for short commands.
- **A screenshot never reached the daemon.** `wl-paste --type text --watch` runs
  nothing when the offer carries no text, so a pure image produced no event at
  all: an open panel went on showing the previous copy, the session counters
  never saw a single image, and the previous copy's source attribution could
  survive and deliver a wrong verdict. There is now a second `wl-paste --watch`,
  typeless, which fires only when the offer carries no text: the two watchers
  split the work by type rather than by clock, so they cannot count the same
  copy twice. The general one never cleans. Measured along the way: a **file**
  copy did arrive, because it offers `text/uri-list` alongside `text/plain`.
- **A "never uncover" row could be uncovered by hand.** The cover silenced the
  "cleaned" signal while the row was locked, but dragging still opened gaps, and
  the text underneath read through the gaps. Under lock the cover now ignores
  the mouse, and a lock arriving mid-rub restores it whole.
- **A peek in flight as the panel closed put the content back in memory**, after
  `forgetPeek` had thrown it away: with the panel shut, the rows existed again
  and the fog animated again. Every forget now opens an epoch, and anything
  arriving from a closed epoch is discarded.
- **A fresh copy onto a half-rubbed covered row** showed the new text through the
  gaps of the old one; arriving during the finishing sweep, it uncovered it
  entirely. New text, new cover.
- **Our own rewrite event was marking "new copy".** The mark went unwritten and
  reached disk on any later write — a skip expiring, a reload — and the panel
  then re-covered the rows you had just uncovered, without you having copied
  anything. That event is no longer marked, and the mark carries a counter
  besides the timestamp, so two events in the same microsecond, or a clock that
  jumps, are not mistaken for "nothing new".
- **Applying with Enter left focus in the void**: the button disappears with the
  action, and the result message's hold went with it. Focus now moves to the
  next live action.
- **"Too large" was recorded as an error** on a loaded machine: the wait on the
  already-killed process had a deadline of its own and could expire.
- Socket client deadlines now cover what the daemon can take with a slow source.
  The 1.5 s default was shorter than the read the daemon itself allows, so the
  panel reported "could not read" for a clipboard that was merely slow. The
  check before rewriting gets half the deadline: the source has already proved
  it serves.
- **Secondary text now carries a contrast floor**
  ([`0022`](docs/decisions/0022-la-tinta-atenuada-lleva-suelo.md)). The panel
  dimmed its labels and prose with a fixed alpha, and a fixed alpha blends
  toward the background without looking at the background — so it cannot promise
  any ratio. Measured across the thirty installed themes, the four dimmed inks
  fell below the 4.5:1 that WCAG AA asks of text on up to fourteen of them, the
  worst always light themes. The requested dimming is now served with a floor
  underneath: twenty-six of thirty themes keep exactly the ink they had, the
  rest are lifted only as far as the floor.
- `hyprctl activewindow` returning something that is not an object took down the
  event thread. So did a JSON request to the socket that is not an object.
- Rewriting for encoding alone — a BOM, UTF-16 text — was reported as "rich
  formatting" in the breakdown; it is now called encoding. And accented Latin-1
  text stopped being skipped as "would grow too much": the cap is measured
  against the original already in UTF-8.
- A clipboard of more than twenty-seven hundred emoji did not fit in the peek
  reply and the panel reported an error.
- `status.json` is written under lock: two threads could leave the older
  snapshot on disk. The watcher's retry ladder returns to the start after a
  healthy minute. Source attribution follows the newest copy even when two
  events run out of order. And it stopped being rewritten twice a second to say
  the same thing: the watcher's supervisor was refreshing it with "running"
  every half second, `fsync` included.
- "Do not paste clean there" counts as a bypass in the session.
- The line "no active rule changes characters" appeared with line endings turned
  on, which do change them.
- Accessibility: covered text leaves the tree in its own item; the
  illustration's decorative text too; a disabled button cannot be pressed from
  the screen reader; a header with no detail no longer reads "OmaPlain, Active. ".
- The fog keeps one stroke per cell and measures what has been cleared by cells,
  instead of piling up strokes with no cap and reading 147 pixels per release.
- `StatusHeader` declared a `state` property on top of the one every `Item`
  already has — QML's own state machine. The new `qmllint` found it; it is now
  `serviceState`.
- The documentation said things the code did not do: that directional marks were
  stripped, that Quickshell never received the content, that "paste clean" did
  nothing in an excluded window. Corrected in the README, the SPEC, SECURITY and
  the decisions affected.

### Changed

- **One mark, drawn, in all three places**
  ([`0020`](docs/decisions/0020-la-marca-se-dibuja.md)). The bar icon used to be
  `󰅌`, a Nerd Font's "paste as plain text": correct, and borrowed. The bar, the
  launcher and the panel header now carry the same stroke, from the same path
  data — a test compares it character by character. Inside the shell it is drawn
  with `QtQuick.Shapes`, so the stroke takes the ink of wherever it sits and the
  dot takes the theme's accent; in the launcher it is still the SVG file, which
  is all the icon system knows how to read.
- **The launcher icon can follow your theme**
  ([`0020`](docs/decisions/0020-la-marca-se-dibuja.md), amendment). An optional
  `theme-set` hook repaints it with the `foreground` and `accent` of the theme
  you just applied, with no tile — just the mark, the same drawing as the bar.
  It writes into `~/.local/share/omaplain/icons/` and changes one line of the
  `.desktop` entry; with no entry installed it does nothing. It changes the
  **path** rather than the contents deliberately: the shell is a long-lived
  process and Qt caches the pixmap by URL, so rewriting the file in place is not
  seen until the next start — both measured in the decision.
- **The logotype writes the name in lower case, always with the drawing beside
  it.** "OmaPlain" in the header was all there was, so it had to shout to
  identify; with the mark in front, the text can lower its voice. In prose it is
  still `OmaPlain` — a logotype and a proper noun are different things — and in
  the launcher, `Omaplain`: there the name is listed beside "Aether" and
  "Document Viewer", and in that column a lower-case initial reads as a typo
  rather than as a brand.
- **The panel's illustrations now show what they say, by moving.** The still
  drawings explained the product with a metaphor; they now demonstrate it with
  the gesture it makes.
  - The **welcome** drops the two rotated cards with their labels and the arrow
    between them, and shows an address and its page, straight and aligned. What
    is going to go is marked first and closed after: you see *what* leaves
    before it leaves.
  - **Tour step 1** goes from three still cards to a queue of copies entering a
    security check, losing their drawing under the noise, and coming out whole
    on the other side. Three still cards did not say "these are not touched":
    they said "here are three things".
  - **Step 2** drops the characters being stripped from a real URL: they fall,
    bounce off the card's edge and fade, and the result is counted once it has
    happened. The string is the one the engine actually cleans.
  - **Step 3** shows the five real settings at their factory values: four switch
    themselves on and the fifth stays off, because nothing is imposed. The list
    rides up to show there is more, and comes back.
  - A **bypass** — an image, some files, a secret — shows a single card with
    still noise on top: that is everything OmaPlain gets to see of it. Instead
    of the three-row inventory, which talked about three things when the
    clipboard holds one.
  - The **carousel specimens** and every card in the panel drop to one glass
    material, with its halo
    ([`0018`](docs/decisions/0018-el-material-del-panel.md)).
  - With **Reduce motion** on, all six paint their final state and none loses
    information.
- **An image now looks like an image.** It was a frame, a sun and two horizontal
  bars, and the whole read as a contact card — and looked too much like the text
  sheet, which is four lines. It now carries a mountain profile resting on the
  frame's inner edge.
- **A bypass screen says one thing once.** The drawing carried a caption —
  "Byte for byte, exactly as you copied it." — twenty pixels below the paragraph
  that already said so, and the stamp floating beside the card. The card now
  takes the full width, the stamp sits inside it and above the grain, and the
  caption is gone. The drawing drops from 160 to 124 tall: this is not a screen
  for learning, it is the one that comes up when you copy an image.
- **"Starting" stops looking like "paused".** Both showed the same still dot with
  only the label changing. Starting now carries three rings that leave and fade:
  the service is not straining, it is listening. It ends on its own, and the
  badge does not change height.
- **The MIME type being dropped stops being the brightest thing in the row.** It
  carried a strikethrough, the accent colour **and** an accent fill at once:
  three signals for the one thing that will not be there. It keeps the colour,
  which arrives as the panel opens so the eye goes to it; in "only formatting is
  removed" the two text rows come out identical and the chips are the only thing
  reporting the change. The survivors return to the panel's normal ink: they are
  precisely what survives.
- **The frequent screen offers no dead button.** With automatic cleaning on, the
  text arrives clean and *Apply* sat greyed out almost always on the most-seen
  screen. It now exists only when there is something to apply
  ([`0015`](docs/decisions/0015-la-pantalla-frecuente-no-ofrece-un-boton-muerto.md)).
- **The fog finishes itself.** Rubbing the whole cover by hand was work without
  information: someone who has cleared a quarter has already said they want to
  see. On release the rest clears with a circle growing from where the finger
  was, in under 400 ms; with reduce motion, at once. A stray click or a short
  brush is not enough.
- **The launcher entry has an icon of its own.** `Icon=edit-paste` borrowed one
  from the theme: it changed with the theme and said nothing about what this
  does.
- **A pass over every string, in both languages.** Twenty-two of them said
  something other than what sat underneath: the "Applications" paragraph
  explained storage — inherited from when that section was called "Privacy" —
  the breakdown chip called "Breaks" what the setting calls "Normalise line
  endings", the English table carried Spanish angle quotes, one message still
  spoke of "excluded" applications when there are rules rather than lists, and
  the empty state showed the acronym "ZWSP" to someone who has just arrived. The
  promise that nothing leaves the machine is back in the panel, at the foot of
  the settings, which is where it had gone missing.
- **Right-clicking the bar icon does nothing, and that is now a promise**
  ([`0021`](docs/decisions/0021-el-clic-derecho-de-la-barra-queda-libre.md)). It
  was left free pending a decision of its own; the decision is that it stays
  free. `pasteClean` rewrites your clipboard, and rewriting it destroys the
  original — there is no history to recover it from, by design. A gesture that
  fires by accident cannot carry that.
- **The README says which Omarchy this was tested against**
  ([`0023`](docs/decisions/0023-a-que-omarchy-se-ata-la-1.0.md)): the 4.x series,
  specifically the `4.0.1-1` package whose shell reports `4.0.0.alpha`. Outside
  4.x nothing is promised — and nothing is blocked either. There is no version
  gate, and there will not be one: the plugin manifest has no field for it, and
  a gate of our own would turn every Omarchy release into a certain failure
  rather than an uncertain one.

### Removed

- **The warning that OmaPlain has stopped watching can no longer be silenced.**
  `notifyOnError` existed in the configuration, worked, and could not be changed:
  no control in Settings and not one test. Looking at what it turned off — the
  only notification this product ever sends, the one saying the clipboard
  watcher has fallen over — it stopped making sense to expose it. This product
  works where you are not looking, and a switch to mute that warning is a switch
  to let it fail in silence. Anyone who does not want it turns the service off,
  which is explicit and visible
  ([`0019`](docs/decisions/0019-el-aviso-de-que-ha-dejado-de-vigilar-no-se-apaga.md)).
- **"Skip the next copy" goes entirely**: from the panel, the IPC, the CLI, the
  helper and the daemon. It asked you to predict the future — arm it before
  copying, and remember it was armed — expired silently after a minute, and
  turning off *Clean automatically* in Settings does the same thing with no
  clock and in plain sight. It was also the only action left on the most-viewed
  screen, so the most marginal thing in the product occupied the place of the
  main one. With it goes the daemon's `tick()`, which existed only to expire it,
  and the branch of the `accept` loop that called it
  ([`0016`](docs/decisions/0016-la-omision-de-una-copia-no-se-gana-su-sitio.md)).
- **"See the original" leaves the tour demonstration.** It went with the card
  that wrapped it — three concentric borders to show one string — and with the
  falling characters the original is now the first thing you see. The button
  that remains is "Play it again" with motion, and "Try it with an example"
  without, which is the only route left to anyone who turned animation off.

### Testing and tooling

- `tests/run.sh` is the whole suite in one command: unit tests with
  `ResourceWarning` as an error, benchmark, soak, `qmllint` over every QML file
  against the installed shell, the QML **executed** inside a real Quickshell,
  and Omarchy's own validator. The last three skip themselves with no Omarchy in
  front, so CI runs the same list.
- The suite goes from 256 tests at `0.2.0` to **409**, plus 68 checks of QML
  running inside a nested Hyprland. `qmltestrunner` cannot load Quickshell's
  types — they are linked inside its binary — so that harness was the only route,
  and it is proven to catch an injected regression. Helper line coverage sits at
  96 %, with all nine CLI subcommands tested end to end against a live daemon.
- **The compatibility matrix is now checked, not just written.** A test reads
  the MIME blocks out of `docs/COMPATIBILITY.md`, runs them through the
  classifier and asserts the documented decision comes back. The four
  applications it cites were confirmed still to be at the versions recorded.
- **Two accessibility defects in Omarchy's own kit are measured and written up**
  for upstream, with the script that reproduces the numbers across every
  installed theme (`docs/notes/UPSTREAM-2026-09-04.md`). Neither affects OmaPlain,
  which draws its own focus ring and its own field hint.

## 0.2.0 — 2026-09-01

Nunca se etiquetó el 31 de agosto: el trabajo del 1 de septiembre —el widget
de barra, la entrada del lanzador, la sección única de aplicaciones— entró
en esta misma versión, y la fecha es la del último cambio.

Esta versión rehace el panel entero. La `0.1.0` funcionaba y no se dejaba
mirar: enseñaba una ilustración donde debía enseñar tu portapapeles, y sus
nueve controles no se veían por un import que faltaba.

### Añadido

- **Previsualización del portapapeles.** La pantalla principal enseña lo que
  tienes copiado y cómo quedaría, cubierto por un vaho que se levanta con el
  ojo o limpiándolo con el dedo. El contenido viaja por el socket y muere con
  la respuesta: no se guarda en ninguna parte ([`0005`](docs/decisions/0005-previsualizacion-del-portapapeles.md)).
- **Privacidad por aplicación.** Dos listas nuevas: las que llegan sin poder
  destaparse y las que OmaPlain ni lee ni enseña. La negativa vive en el
  helper, antes de leer, y no la levanta ninguna acción manual
  ([`0009`](docs/decisions/0009-privacidad-por-aplicacion.md)).
- **Inglés y español**, con selector y `auto` desde el locale del sistema.
- **Estado vacío que enseña.** Con el portapapeles vacío, un carrusel de tres
  ejemplos reales —un enlace con seguimiento, un párrafo con un invisible, una
  copia con formato— pierde lo que sobra delante de ti
  ([`0008`](docs/decisions/0008-el-estado-vacio.md)).
- **Demostración segura en el tour**: transforma texto propio del plugin, nunca
  el portapapeles, y es reversible.
- **Ajuste «Reducir movimiento»** que apaga las animaciones en toda la app.
- **Chips de tipos MIME**, la única forma de enseñar la retirada de formato:
  ahí no cambia ni un carácter.
- **Estado vacío en «Aplicaciones excluidas»**, que explica qué hace excluir
  antes de que haya nada que excluir.
- **Confirmación visual** de la limpieza manual, y el estado «omitir la próxima
  copia» visible en la cabecera.
- **Explicación desplegable** de por qué el original puede seguir en el
  historial de Omarchy.

### Cambiado

- **El titular dice lo que tienes copiado, no lo que le pasa.** Con una imagen
  en el portapapeles, la pantalla decía «Una imagen no se toca» sobre una
  ilustración, y se confundía con el estado vacío: cuatro de sus cinco
  elementos hablaban del producto y sólo el chip del tipo hablaba de ti. Los
  cinco veredictos de bypass nombran ahora lo que hay —«Una imagen en tu
  portapapeles»— y dejan para la frase de debajo qué se hace con ello.
  Con la pantalla explicándose sola, «Ver cómo funciona» se retira de los
  bypass y se queda sólo en el estado vacío: un botón de aprender el producto
  no va en la pantalla que se abre cada vez que haces una captura. Y la nota
  «aquí no hay acción que ofrecer» desaparece del todo — hablaba del panel y no
  de tu portapapeles
  ([`0013`](docs/decisions/0013-el-titular-nombra-lo-que-tienes.md)).
- **Una sola sección de aplicaciones.** «Privacidad» y «Aplicaciones excluidas»
  montaban el mismo formulario dos veces, con dos rótulos que se diferenciaban
  en una palabra y dos botones de «app detectada» que hacían cosas distintas.
  Ahora eliges la aplicación una vez y decides después: cada una lleva sus
  cuatro reglas como cuatro interruptores independientes, agrupados en «Al
  leer» y «Al limpiar». Siete secciones de ajustes pasan a seis y veinticinco
  controles a veinte ([`0011`](docs/decisions/0011-una-sola-seccion-de-aplicaciones.md)).
- **Un selector de ventanas abiertas** sustituye a los botones de «app
  detectada». Ofrece todas las ventanas y no sólo la última enfocada, y la
  clase que da es exactamente la que compara el demonio. No son las
  aplicaciones instaladas a propósito: de 93 entradas `.desktop` de un
  escritorio real, sólo 23 declaran su clase de ventana, así que tres de cada
  cuatro darían una regla que nunca dispara. El título de la ventana no cruza
  la frontera del helper.
- **Enter ya no elige lista a escondidas.** Había dos botones idénticos de
  confirmar y `onAccepted` disparaba uno de los dos sin decir cuál. Ahora el
  formulario tiene una sola acción: traer la aplicación.
- **La primera experiencia enseña; la de todos los días informa.** El titular
  educativo y la ilustración salen de la pantalla frecuente y se quedan en la
  bienvenida y el tour, que es donde tienen trabajo
  ([`0007`](docs/decisions/0007-la-pantalla-frecuente-informa.md)).
- **El panel se parte en dos páginas**: el portapapeles y los ajustes, detrás
  del engranaje.
- El recorrido de primera ejecución pasa por los ajustes, con dos salidas
  visibles ([`0006`](docs/decisions/0006-orden-del-onboarding.md)).
- Los cuatro ajustes de limpieza opcionales van bajo divulgación; los cuatro
  que vienen puestos se quedan a la vista.
- Copy revisado de arriba abajo, en los dos idiomas.
- **El panel se puede abrir sin escribir un comando**
  ([`0010`](docs/decisions/0010-como-se-abre-el-panel.md)). Hasta ahora el
  manifiesto declaraba `service` y `panel`, y un `panel` sólo existe cuando
  alguien lo invoca: no había ninguna superficie desde la que invocarlo. Se
  añade un **widget de barra** —clic izquierdo para abrir y cerrar— y una
  **entrada `.desktop`** para el lanzador. Ninguna de las dos se activa sola:
  el icono lo coloca `bar.layout` en `shell.json`, que es el mando que
  Omarchy ya tiene para esto, y la entrada del lanzador se copia a mano
  porque el plugin no vive en `XDG_DATA_DIRS`. Sigue sin haber atajo global
  ni cambios en la configuración de Hyprland.
- **La cabecera deja de predicar.** De las ocho frases de estado, siete
  informan de algo que está pasando —pausado, va a omitir, se acaba de
  limpiar, falta una dependencia— y la octava describía el producto:
  «OmaPlain ordena el formato y deja intacto todo lo que no puede limpiar
  con seguridad». Era la rama **por defecto**, así que predicaba justo en el
  caso más frecuente, encima de un veredicto que ya dice qué pasa con *tu*
  portapapeles. Es el titular educativo que la `0007` echó de esta pantalla,
  sobrevivido como cadena. Ahora, sin nada que contar, la cabecera de estado
  desaparece entera en vez de dejar su hueco.
- **El dibujo del estado vacío se lee.** La barra de dirección tapaba el 40%
  de la hoja de detrás, líneas de texto incluidas, y las dos formas se veían
  como una sola mancha; y el halo iba a acento del 10% sobre un fondo muy
  oscuro, que no llega a brillar y sí a ensuciar. Baja la barra y sube el
  halo: dos objetos, uno delante del otro.
- **Los estados que no se tocan dejan de ser una pantalla en blanco.** Con
  una imagen, un archivo, algo sensible, algo demasiado grande o una
  aplicación bloqueada, el panel no tiene portapapeles que enseñar —de una
  imagen no se lee ni un byte—, así que la mitad que en los demás estados
  ocupa la previsualización se quedaba vacía, con el veredicto flotando y
  debajo «no hay ninguna acción que ofrecer aquí». Esa pantalla llegó a
  confundirse con el estado vacío. Ahora lleva el dibujo de *Imágenes /
  Archivos / Secretos*, que es lo que ese veredicto afirma, y la salida al
  tour. La nota genérica se calla cuando aparece esa salida, porque decir
  que no hay nada que ofrecer encima de un botón que ofrece algo es falso
  ([enmienda de la `0007`](docs/decisions/0007-la-pantalla-frecuente-informa.md)).
- **Los ajustes vuelven a leerse como secciones.** Los encabezados eran
  `Text` sueltos en una columna de espaciado uniforme, así que recibían el
  mismo aire por los dos lados —21 px arriba y 24 abajo, medidos, y esos dos
  números eran el ascendente y el descendente de la letra, no diseño—.
  Con 19 px entre filas, la página tenía tres valores casi idénticos
  haciendo tres trabajos distintos y se leía como una lista plana de veinte
  filas. Ahora hay un `SectionHeading` que abre su sección: 43 px encima
  contra 24 debajo, y 19 entre filas del mismo grupo.
- **«Reducir movimiento» tiene su propia sección.** Vivía debajo del
  encabezado «Idioma», sin nada que dijera que había salido de él.
- **El onboarding ya no se lee arrastrando.** La tarjeta tenía un techo de
  `space(720)` para que los ajustes no se comieran la pantalla, y el paso 2
  del tour lo tocaba: «Siguiente» y la salida quedaban por debajo del borde,
  de modo que había que desplazar la pantalla para poder continuarla. La
  bienvenida y el tour crecen ahora hasta su contenido, con la pantalla como
  único límite; la vista de todos los días conserva su techo intacto.
- **El paso 2 del tour se enseña solo, y baja de cinco mandos a cuatro.** La
  muestra pierde sus parámetros de seguimiento delante de ti al entrar, en
  vez de esperar a que alguien pulse. Con eso, «Otro ejemplo» sobraba: la
  `0004` pide una acción primaria por vista y ahí la primaria es
  «Siguiente». Queda un solo botón de la demostración, que con movimiento
  sirve para volver a mirar y sin movimiento es quien hace la
  demostración. La segunda muestra —el enlace firmado que no se toca— sigue
  en el catálogo y bajo test: su lección ya la daba con palabras el aviso de
  encima.
- **La cabecera deja de anunciar el estado normal.** Un servicio que está
  corriendo es lo que se espera de él, y rotularlo «ACTIVO» gastaba la
  primera línea en decir que no pasa nada. La insignia aparece sólo cuando
  tiene algo que contar: pausado, omitiendo la próxima copia, arrancando o
  pidiendo atención. El nombre accesible sigue nombrando el estado siempre,
  porque ahí no hay un panel vivo delante del que deducirlo.

### Arreglado

- **Con el icono en la barra, ningún ajuste se guardaba.** `updateEntryInline`
  del shell escribe en `bar.layout` cuando encuentra ahí el id del plugin, y
  sólo entonces deja `plugins[]` en paz; el panel leía siempre de `plugins[]`.
  Desde que OmaPlain declara `bar-widget`, cada ajuste se guardaba en un sitio
  y se leía de otro: ni el idioma, ni el movimiento reducido, ni las cuatro
  listas de privacidad se quedaban puestos, y sin ningún error a la vista.
  Además, mientras el icono está en la barra, `plugins[]` se quedaba congelado
  en el día en que se colocó: quitarlo devolvía los ajustes a los de entonces.
  Ahora se mantiene una copia al día, por la vía que el shell expone
  ([`0012`](docs/decisions/0012-el-anillo-de-foco-y-donde-viven-los-ajustes.md)).
- **Enfocar un control lo apagaba.** El borde de foco del kit sale de
  `focus-border-alpha`, que cae en 0,25 frente al 0,4 del borde normal: medido
  en el panel, 2,79:1 en reposo y **1,82:1 con el foco puesto**. Con veinte
  controles navegables, el recorrido por teclado no dejaba rastro. Todos los
  controles dibujan ahora su propio anillo, neutro y a 6,17:1 — también los del
  recorrido, la bienvenida, la demostración y el ojo de las filas.
- **«Ver los ajustes» no siempre llevaba a los ajustes.** El último botón del
  recorrido prometía lo mismo viniera de donde viniera, y lanzado desde la
  pantalla de todos los días devolvía a esa misma pantalla, cuya única acción
  es «Ver cómo funciona»: se leía como volver al principio del recorrido. El
  botón nombra el destino sólo cuando el recorrido continúa —la primera vez,
  donde el paso siguiente son los ajustes—; cuando termina ahí, dice
  «Finalizar», que es lo que se espera al final de tres pasos.
- **Los nueve controles del panel eran invisibles.** `SettingRow.qml` usaba
  `Style.space()` sin importar `qs.Commons`, así que su altura colapsaba a
  cero. Se publicó así en la `0.1.0`.
- **El ojo se quedaba levantado al cambiar de copia**, de modo que revelar una
  vez enseñaba lo siguiente sin que nadie lo pidiera.
- **Un portapapeles vacío se contaba como error** de inspección.
- **`peek` decía «ya está limpio»** de un portapapeles con formato que sí se
  iba a reescribir.
- **El servicio no formaba su notificación de error**: llamaba al catálogo sin
  importarlo y lanzaba `ReferenceError` en cada arranque.
- La ayuda de la CLI imprimía `==SUPPRESS==` como si fuera un comando.
- **El panel decía «no hay nada que limpiar» de casi todo lo que no sabía
  clasificar.** Reconocía cinco motivos de los diecisiete que el helper puede
  emitir, y el resto caía en «OmaPlain lo ha mirado y lo deja como está»: un
  portapapeles de 1,4 MB que no llegó a leer, bytes que no son texto y —lo
  peor— **una copia de una aplicación bloqueada, justo la pantalla cuyo
  trabajo es demostrar que no la miró**. Cada negativa tiene ahora su titular
  y su explicación, y un test compara las dos listas.
- **Las frases del ojo se componían con la cabecera de la columna**, así que
  el tooltip y el `Accessible.name` decían «Show On the clipboard» y «Mostrar
  Quedaría».
- **La fila bajo llave seguía invitando a destaparse**: el vaho decía
  «arrastra para limpiar» y el lector de pantalla remataba con «o usa el botón
  del ojo», dos gestos que ahí no responden.
- **El botón principal no enseñaba el foco.** Sobre el relleno de acento sólo
  cambiaba 1 px de borde, y encima se oscurecía: enfocado y sin enfocar se
  veían iguales.
- **La demostración del tour estaba escrita en español dentro del QML**, así
  que en inglés la pantalla enseñaba `pan-de-masa-madre` mientras la frase de
  resultado hablaba de «the servings». Y usaba `ejemplo.com`, un dominio real,
  en vez del `example.com` que la RFC 2606 reserva para esto.
- **Tres cadenas estaban en la tabla del idioma equivocado**: el botón que
  cierra el tour y los dos rótulos de exclusión detectada.
- **El botón «Opciones» pisaba la regla de la cabecera.** La fila medía
  `space(38)` y el botón `space(44)`, dos números escritos a mano que se
  contradecían: centrado, sobresalía 3 unidades por arriba y por abajo, de
  modo que su borde inferior cruzaba la línea que cierra la cabecera. Ahora
  la fila la marca su propio control, y la regla pasa a ser hermana de la
  columna, con el mismo aire por arriba que por abajo en vez de quedar
  pegada al botón como si fuera su subrayado.
- **El engranaje vivía dentro de la cadena traducida**, en las dos tablas y
  separado del rótulo por dos espacios literales: se pintaba al tamaño de
  cuerpo en vez del de icono, y ese hueco no escalaba con el tema mientras
  el resto sí. Pasa a `iconText`, que es lo que el kit ofrece y lo que el
  panel ya usa en otros tres sitios. «Saltar» conserva el suyo porque su
  flecha va a la derecha, donde `iconText` no pinta.
- **La frase de estado estaba puesta con valores de rótulo.** El panel usa
  0,68 para rótulos y 0,72 con interlínea 1,45 para prosa que envuelve;
  esta iba con los primeros, más apagada y más apretada que el subtítulo
  que tiene tres líneas más abajo y que dice lo mismo. Medido sobre el
  render: pasa de 5,65:1 a 6,19:1.
- **El tour tenía tres bordes izquierdos distintos en la misma columna.**
  El aviso y la demostración estaban topados a `space(420)` y centrados, y
  la rejilla de acciones iba a ancho completo: 613 px los botones, 560 las
  otras dos cajas. Las superficies pasan a seguir el ancho de la pila. El
  párrafo del paso conserva su tope, que ahí no es una caja mal medida sino
  una columna de lectura: envuelve a unos 57 caracteres.
- **Todas las filas de ajuste medían lo mismo, mirara o no el contenido.**
  `SettingRow` sobreescribía la altura con `Math.max(Style.space(44), 54)` y
  con eso tiraba el cálculo del kit, que es
  `Math.max(54, content.implicitHeight + Style.spacing.huge)`. Las filas con
  descripción de dos líneas iban apretadas contra sus bordes; ahora pasan de
  56 a 75 px y el resto se queda como estaba.
- **Dos rótulos de campo se disfrazaban de encabezado de sección.**
  «Clase de aplicación» iba en negrita a color pleno —11,33:1, exactamente
  lo mismo que «Privacidad», y a un solo escalón de tamaño—, así que abría
  una sección que no existía.
- **Los dos desplegables eran los únicos bloques centrados** de una página
  alineada a la izquierda, y abren texto que sí empieza a la izquierda.
- **El texto de ejemplo del campo daba 4,19:1**, por debajo del 4,5 que pide
  la AA, y ahí no es decoración: es la única pista de qué hay que teclear.
  Pasa a 5,55:1 con el alfa de rótulo que el panel ya usa.
- **Dos párrafos que envuelven iban con el alfa de los rótulos.** El panel
  usa 0,68 para rótulos y foregrounds de control y 0,72 para prosa.
- **Los dos naipes de la ilustración no medían lo mismo.** El de «CLEAN»
  estaba escrito 4 puntos más alto que el de «COPIED» —126 contra 122— sin
  que nada lo pidiera, y como además va relleno a opacidad plena contra el
  0,72 del otro, y una forma más clara sobre fondo oscuro ya se lee más
  grande de por sí, las dos cosas empujaban en la misma dirección. Ahora el
  tamaño se declara una vez y lo comparten.
- **El nombre accesible de la muestra estaba escrito en español dentro del
  QML**, así que en inglés un lector de pantalla decía «Ejemplo original:
  https://…». Es el mismo fallo que la demo ya había tenido con su texto, en
  la única línea que se había quedado sin mirar. Y ahora anuncia el estado
  asentado, no el fotograma: a media animación el texto es un recorte que no
  existe en ninguna parte.
- **La demostración daba dos saltos de maquetación.** La caja de la muestra
  encogía de dos líneas a una al limpiarse, y la frase del resultado
  aparecía de la nada: entre las dos empujaban los botones hacia arriba y
  hacia abajo justo cuando el ojo iba hacia ellos. La caja reserva ahora la
  altura del original, que es el estado más alto, y la frase ocupa su sitio
  siempre.
- **«Omitir la próxima copia» no caducaba por tiempo.** Se prometen sesenta
  segundos; con el escritorio quieto la marca se quedaba puesta
  indefinidamente y la cabecera seguía diciéndolo. La caducidad era perezosa
  y sólo corría al llegar un evento o al pedir `status` **por el socket**, y
  el panel no usa esa vía: relee `status.json` del disco. Nadie despertaba
  al demonio. El bucle de `accept` ya lo hace cada 0,5 s, así que la
  comprobación va ahí, sin temporizador nuevo. El test que existía
  preguntaba justo por el socket, de modo que pasaba con el fallo delante.

### Seguridad

- El contenido del portapapeles puede llegar al panel; **no puede quedar
  escrito en ninguna parte**: ni estado, ni configuración, ni log, ni
  notificación, ni traza, ni truncado, ni resumido.
- `peek` es inerte: no avanza la generación, no consume la omisión, no escribe
  en el portapapeles y no toca el disco.
- De una aplicación bloqueada no se enseña ni la lista de tipos.

## 0.1.0 — 2026-08-31

Primera versión local lista para catálogo.

### Añadido

- Limpieza automática y bajo demanda de texto elegible.
- Retirada de rich text mediante la representación `text/plain`.
- Normalización conservadora de finales de línea, invisibles y URLs completas.
- Transformaciones opcionales independientes.
- `cleanNow`, `pasteClean`, `skipNext`, pausa y exclusiones por clase.
- Servicio, panel e IPC nativos de Omarchy Shell.
- Fail-open, compare-before-write, generaciones, loop guard y límite de 1 MiB.
- Estado privado sin contenido y recuperación con backoff.
- Tests unitarios, propiedades, benchmark, soak e integración Wayland.

### Seguridad

- Bypass de contenido sensible antes de consultar MIME o payload.
- Bypass de imágenes, archivos y formatos estructurales conocidos.
- Cero dependencias de red y cero contenido en logs, estado, IPC o panel.
- Señal de muerte del padre en daemon y watcher para impedir hijos huérfanos tras hot reload o cierre forzoso.

### Limitaciones conocidas

- El historial de Omarchy puede mostrar original y limpio cuando cambian caracteres.
- Los secretos sin marca de sensibilidad requieren una exclusión de aplicación.
- La atribución de origen en Wayland es best effort.
