import QtQuick
import qs.Commons
import qs.Ui
import "Strings.js" as Strings

// A demonstration that never reads the clipboard. Both samples and both
// results come from the bilingual catalogue, and
// tests/unit/test_demo_sample.py pushes each original through the real
// transform once per language, so the demo cannot keep promising something
// the engine stopped doing.
Column {
  id: root

  // Idioma heredado del panel: en o es.
  property string lang: "en"

  // Antes esto no llegaba hasta aquí: la demo no se movía, así que no había
  // nada que apagar. Ahora sí, y el ajuste manda igual que en el resto.
  property bool motionEnabled: true

  property int sampleIndex: 0

  // El estado lógico. El reloj de la caída lo sigue, animado o de golpe.
  property bool revealed: false

  signal focusEntered(Item item)

  // Cada muestra es una URL entera porque es la única forma que el motor
  // reescribe: `clean_tracking_url` se rinde en cuanto el texto lleva un
  // espacio. Prosa con un enlace dentro se queda intacta, y una demo hecha
  // de prosa afirmaría lo contrario.
  //
  // Eso sostiene además el trazado: el texto se pinta con formato, y el
  // motor de texto con formato colapsa las series de espacios. Sin
  // espacios no hay nada que colapsar, y `test_demo_sample.py` lo sujeta
  // sin saberlo — una muestra con un espacio dejaría de limpiarse y el
  // test caería antes de que el trazado se enterase.
  //
  // Las muestras salen del catálogo, no de aquí. Escritas en el QML se
  // quedaron en un solo idioma: la interfaz en inglés enseñaba
  // `pan-de-masa-madre` y la frase de resultado hablaba de «the servings»
  // señalando un `porciones=8` que su lector no podía leer.
  //
  // `tests/unit/test_demo_sample.py` empuja cada original por el motor real,
  // una vez por idioma, así que la demo no puede prometer una limpieza que
  // el producto haya dejado de hacer en ninguno de los dos.
  //
  // El tour enseña sólo la primera. La segunda —un enlace firmado que no se
  // toca— sigue en el catálogo y bajo test porque documenta la contención
  // del motor, pero su lección ya la da con palabras el aviso de encima
  // («ante la duda, conserva el original») y no valía un segundo botón en
  // el paso con más cosas pulsables del tour.
  readonly property var samples: [
    { "key": "demo.sample1", "outcome": "demo.outcome1" }
  ]

  readonly property var sample: samples[Math.max(0, Math.min(samples.length - 1, sampleIndex))]

  // El texto en tres tramos: lo que se queda delante, lo que sobra y lo que
  // se queda detrás. El catálogo los guarda por separado y
  // `test_demo_sample.py` comprueba las dos costuras —cabeza+sobra+cola es
  // el original, cabeza+cola es lo que el motor devuelve—, así que la
  // animación no puede enseñar un recorte distinto del que hace el producto.
  //
  // **El fuente sigue teniendo una sola cadena por tramo.** Que el QML lo
  // pinte carácter a carácter no parte el catálogo en 54 trozos que traducir.
  readonly property string head: Strings.t(root.sample.key + ".head", root.lang)
  readonly property string spare: Strings.t(root.sample.key + ".spare", root.lang)
  readonly property string tail: Strings.t(root.sample.key + ".tail", root.lang)

  readonly property string originalText: Strings.t(root.sample.key + ".original", root.lang)
  readonly property string cleanedText: Strings.t(root.sample.key + ".cleaned", root.lang)

  // Sólo las muestras que pierden algo llevan tramos, y la comprobación es
  // la propia costura: si los tres no recomponen el original —porque no
  // existen, porque el catálogo cambió a medias— no se anima nada y se
  // enseña el estado entero, que nunca puede estar mal.
  readonly property bool animatable:
    root.spare.length > 0 && (root.head + root.spare + root.tail) === root.originalText

  // ---------------------------------------------------------------
  // El motor de caída (`ANIMACIONES.md` §1)
  // ---------------------------------------------------------------
  //
  // Aquí la caída se gana el sitio: la cadena es real, los caracteres que
  // se van son los que se irían, y el resultado se cuenta cuando ya ha
  // pasado. En una ilustración no —ahí no hay 54 letras, hay una idea de
  // que sobra algo—, y por eso el carrusel y la bienvenida comprimen.
  //
  // Cada carácter necesita su propia posición, así que el texto lo pinta un
  // `TextEdit` y las posiciones salen de su `positionToRectangle()`. El
  // tramo que sobra va dentro de un `<font color="transparent">`: ocupa su
  // hueco exacto —el trazado es el del original, con sus mismos saltos de
  // línea— y no pinta ni un píxel, así que los añicos son los únicos que lo
  // dibujan. Sin eso habría dos copias del mismo glifo, y al soltarse la de
  // arriba quedaría la de abajo.
  //
  // Las posiciones se miden **una vez** y se guardan: `positionToRectangle`
  // es una función, no una propiedad, así que un binding sobre ella no se
  // reevalúa cuando el trazado cambia y devuelve ceros para siempre.
  readonly property int t0: 200
  readonly property int releaseSpan: 420
  readonly property int closeSpan: 160
  // 1400 px/s², en las unidades del reloj.
  readonly property real gravity: 0.0014

  // El reloj del gesto, en milisegundos. Uno solo para los 54 añicos: cada
  // uno saca su posición de una fórmula cerrada, sin integrar por cuadro.
  property real fallClock: 0

  property var shards: []
  property real lastSettle: 0
  // El ciclo, contado desde el arranque del gesto:
  //
  //   0 → asiento+400   la caída y la frase de resultado
  //   → +2 200          quieto, con la copia limpia, para que se lea
  //   → +200            la cadena vuelve: el hueco se reabre
  //   → +200            y los caracteres que sobran aparecen en su sitio
  //   → +700            quieto, con la copia entera, y otra vez
  //
  // **La vuelta no es un rebobinado.** Los añicos no suben volando del
  // suelo: se apagan al asentarse, saltan a su sitio mientras nadie los ve
  // y aparecen ahí. Verlos volver por donde bajaron leería «deshacer», y
  // aquí lo que llega es otra copia.
  // Cuando el suelo queda limpio, lo que queda del enlace **baja al centro
  // de la tarjeta**. Antes se quedaba pegado arriba con el hueco muerto
  // debajo, que es donde acababan de caer los añicos: la caja parecía
  // esperar algo que ya no iba a venir.
  //
  // Baja con un muelle de dos rebotes que se apagan. No es adorno: la
  // caída fue física, y que el texto se asiente con la misma física es lo
  // que ata las dos mitades del gesto. Un `OutCubic` lo dejaría caer como
  // un panel, no como algo que pesa.
  readonly property int dropAt: root.lastSettle + 120
  readonly property int dropMs: 620

  function spring(t) {
    if (t <= 0) return 0
    if (t >= 1) return 1
    return 1 - Math.exp(-5.5 * t) * Math.cos(2 * Math.PI * 1.8 * t)
  }

  readonly property real dropped: root.animatable
    ? spring(clamp((root.fallClock - root.dropAt) / root.dropMs)) * (1 - root.reopened)
    : 0

  // El asiento no es sólo el de la frase: es el más tardío de los dos, o
  // sin movimiento la tarjeta se quedaría con el muelle a medio rebote.
  readonly property real settledAt: Math.max(root.lastSettle + 220 + 180,
                                             root.dropAt + root.dropMs)
  readonly property int holdMs: 2200
  readonly property int reopenMs: 200
  readonly property int refillMs: 200
  readonly property real returnAt: root.settledAt + root.holdMs
  readonly property real totalMs: root.returnAt + root.reopenMs + root.refillMs + 700

  // 0 mientras la copia limpia está a la vista; 1 con la siguiente ya
  // entera. El hueco se reabre primero y los caracteres llegan después,
  // porque al revés se verían encima del texto que todavía no ha hecho
  // sitio.
  readonly property real reopened: clamp((root.fallClock - root.returnAt) / root.reopenMs)
  readonly property real refilled: clamp(
    (root.fallClock - (root.returnAt + root.reopenMs)) / root.refillMs)

  // Deterministas, no `Math.random()`: se ve irregular y es reproducible,
  // que es lo que necesita una captura de test.
  function hash(i) { return ((i * 2654435761) % 1000) / 1000 }
  function hash2(i) { return ((i * 40503 + 17) % 997) / 997 }
  function hash3(i) { return ((i * 69069 + 5) % 991) / 991 }

  function escapeMarkup(s) {
    return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
  }

  function outCubic(t) { var k = 1 - t; return 1 - k * k * k }
  function clamp(t) { return Math.max(0, Math.min(1, t)) }

  // El cierre llega **detrás** del frente, no a la vez: empieza cuando el
  // último añico ya se ha soltado.
  readonly property real closed: outCubic(clamp(
    (root.fallClock - (root.t0 + root.releaseSpan)) / root.closeSpan))
    * (1 - outCubic(root.reopened))
  readonly property int spareShown: root.animatable
    ? Math.round(root.spare.length * (1 - root.closed)) : 0

  // La frase de resultado **no cuelga del progreso de la limpieza**: cuelga
  // del asiento. Colgada de la limpieza contaría el desenlace en mitad del
  // vuelo, mientras todavía está ocurriendo.
  readonly property real outcomeIn: root.animatable
    ? clamp((root.fallClock - (root.lastSettle + 220)) / 180) * (1 - root.reopened)
    : (root.revealed ? 1 : 0)

  function measureShards() {
    if (!root.animatable || layout.width <= 0 || root.spare.length === 0) {
      root.shards = []
      root.lastSettle = 0
      return
    }

    var base = root.head.length
    var raw = []
    for (var i = 0; i < root.spare.length; i++) {
      var r = layout.positionToRectangle(base + i)
      raw.push({
        ch: root.spare.charAt(i),
        x0: layout.x + r.x,
        y0: layout.y + r.y,
        line: r.height
      })
    }

    // El frente de suelta va por **posición pintada**, no por orden en la
    // cadena. Con varios renglones eso dibuja una diagonal, que es lo que
    // hace un barrido; por orden de cadena bajaría renglón a renglón.
    var order = raw.slice().sort(function (a, b) { return a.x0 - b.x0 })
    var step = root.releaseSpan / order.length
    var tope = 0

    for (var k = 0; k < order.length; k++) {
      var s = order[k]
      s.release = root.t0 + k * step
      // El suelo es el borde inferior de la tarjeta, fijado a mano. Sin
      // eso los caracteres seguirían cayendo al hueco de debajo, sueltos
      // sobre el panel: la pieza envuelve más que la tarjeta.
      s.h = Math.max(1, root.floorY - s.line - s.y0)
      s.t1 = Math.sqrt(2 * s.h / root.gravity)
      // Restitución propia de cada añico: es lo que hace que el conjunto
      // no se lea como una cortina bajando.
      s.e = 0.10 + root.hash2(k) * 0.20
      s.h1 = s.h * s.e
      s.h2 = s.h1 * s.e
      s.d1 = 2 * Math.sqrt(2 * s.h1 / root.gravity)
      s.d2 = 2 * Math.sqrt(2 * s.h2 / root.gravity)
      s.rest = s.t1 + s.d1 + s.d2
      // Deriva y giro, sólo durante la caída libre: durante los rebotes el
      // añico ya está en el suelo y girar ahí sería un baile.
      //
      // Los dos signos salen de **hashes distintos**. Sacarlos del mismo
      // multiplicador de Knuth sobre `k` no era un hash: 2654435761 es
      // impar, así que el resto entre dos es la paridad de `k` y los
      // signos alternaban uno sí y uno no. Peor todavía, el del giro salía
      // de `k + 1`, con lo que cada añico giraba siempre al revés de como
      // derivaba. Se veía regular, que es justo lo contrario de lo que la
      // irregularidad determinista viene a conseguir.
      s.drift = (root.hash(k) < 0.5 ? 1 : -1) * (1 + root.hash3(k) * 6)
      s.spin = (root.hash2(k) < 0.5 ? 1 : -1) * (8 + root.hash3(k) * 26)
      tope = Math.max(tope, s.release + s.rest)
    }

    root.shards = order
    root.lastSettle = tope
  }

  // Dónde está un añico a los `tau` ms de su suelta. Forma cerrada: dos
  // rebotes y para. Un tercero no se ve y cuesta lo mismo.
  function dropOf(s, tau) {
    if (tau <= 0) return 0
    if (tau < s.t1) { var u = tau / s.t1; return s.h * u * u }
    var t = tau - s.t1
    if (t < s.d1) { var a = t / s.d1; return s.h - 4 * s.h1 * a * (1 - a) }
    t -= s.d1
    if (t < s.d2) { var b = t / s.d2; return s.h - 4 * s.h2 * b * (1 - b) }
    return s.h
  }

  // El aplastado del primer impacto, con el área conservada. Va con un seno
  // y no con un escalón plano de 70 ms: un escalón se ve como un salto de
  // tamaño, y esto es un golpe.
  function squashOf(s, tau) {
    var t = tau - s.t1
    if (t < 0 || t > 70) return 1
    return 1 - 0.16 * Math.sin(Math.PI * (t / 70))
  }

  readonly property real floorY: card.height - Style.space(4)

  spacing: Style.space(8)

  NumberAnimation {
    id: fallRun
    target: root
    property: "fallClock"
    from: 0
    to: root.totalMs
    duration: Math.max(1, root.totalMs)
    easing.type: Easing.Linear
    // Cicla, como las tres ilustraciones del onboarding ([`0017`]): una
    // demostración que se reproduce una vez se queda muerta el resto del
    // tiempo que el paso está delante, y este paso se lee despacio.
    loops: Animation.Infinite
  }

  onRevealedChanged: {
    if (!revealed) { fallRun.stop(); fallClock = 0; return }
    measureShards()
    // Sin movimiento se planta en el asiento y no al final del ciclo: el
    // final del ciclo es la copia **siguiente**, entera otra vez, y quien
    // apagó las animaciones pulsó el botón para ver el resultado.
    if (!motionEnabled) { fallRun.stop(); fallClock = settledAt; return }
    fallRun.restart()
  }

  // Con movimiento, la transformación se enseña sola tras un respiro: se ve
  // primero qué hay y luego qué sobra, el mismo orden que el carrusel. Sin
  // movimiento no se dispara nada y queda el original con su botón, que es
  // la demostración de siempre sin una sola animación.
  Timer {
    id: autoPlay
    interval: 700
    repeat: false
    onTriggered: root.revealed = true
  }

  function reset() {
    autoPlay.stop()
    fallRun.stop()
    fallClock = 0
    revealed = false
    sampleIndex = 0
    if (motionEnabled && visible) autoPlay.restart()
  }

  onVisibleChanged: {
    if (visible) {
      reset()
    } else {
      // El reloj de la caída también. Es finito, pero no hay razón para
      // que siga contando detrás de una pantalla que ya no está.
      autoPlay.stop()
      fallRun.stop()
    }
  }
  onMotionEnabledChanged: reset()
  // Las posiciones de los añicos se congelan al soltar, así que un cambio
  // de idioma a media caída dejaría cayendo los caracteres de la muestra
  // anterior sobre el texto de la nueva. Se rebobina.
  onLangChanged: reset()

  Text {
    width: parent.width
    text: Strings.t("demo.label", root.lang)
    color: Color.accent
    font.family: Style.font.family
    font.pixelSize: Style.font.caption
    font.bold: true
    font.capitalization: Font.AllUppercase
    font.letterSpacing: Style.spaceReal(0.9)
    wrapMode: Text.WordWrap
  }

  GlassSurface {
    id: card
    width: parent.width
    // La altura la fija el original, que es el estado más alto. Atada al
    // texto en curso, la caja encogía de tres renglones a dos en mitad de
    // la animación y empujaba hacia arriba todo lo que hay debajo, botones
    // incluidos: un blanco móvil justo donde hay que pulsar.
    //
    // El paquete de diseño pide en un sitio que la tarjeta se recoja de 88
    // a 68 al terminar, y en otro que esto no se toque «porque los botones
    // no se pueden mover». Se hace caso al segundo: el hueco que queda
    // debajo del texto limpio es justo donde se apilan los añicos.
    //
    // **Y tres renglones como mínimo**, que son los 88 px del paquete. En
    // un panel ancho la muestra entera cabe en dos, y entonces los añicos
    // se soltaban con un renglón de caída: se posaban pegados al borde de
    // abajo y la caja del carácter invisible lo rozaba. El suelo tiene que
    // estar lo bastante lejos para que la caída se vea caer.
    readonly property real lineHeight: measure.lineCount > 0
      ? measure.implicitHeight / measure.lineCount : measure.implicitHeight
    height: Math.max(measure.implicitHeight, layout.implicitHeight,
                     3 * card.lineHeight) + Style.space(22)
    clip: true
    onHeightChanged: if (root.fallClock === 0) root.measureShards()

    // Sólo mide: nunca se pinta ni se anuncia.
    Text {
      id: measure
      visible: false
      width: layout.width
      text: root.originalText
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
      wrapMode: Text.WrapAnywhere
      Accessible.ignored: true
    }

    // El texto, anclado arriba: al cerrarse el tramo la cola sube y el
    // hueco queda abajo, que es donde caen los añicos. Centrado, el bloque
    // entero se movería al perder un renglón.
    TextEdit {
      id: layout
      x: Style.space(12)
      // Arriba mientras hay algo que soltar, y en el centro cuando ya no.
      // Leer `card.height` desde aquí no cierra ningún ciclo: el alto de la
      // tarjeta sale de `implicitHeight`, y `implicitHeight` no depende de
      // dónde esté puesto el texto.
      y: Style.space(11) + (card.height - Style.space(22) - layout.implicitHeight)
         / 2 * root.dropped
      width: card.width - Style.space(24)
      padding: 0
      readOnly: true
      // Es un cartel, no un campo: ni se selecciona ni toma el foco. Un
      // `TextEdit` de sólo lectura activa la selección por teclado él
      // solo, y ahí no hay nada que copiar.
      selectByMouse: false
      selectByKeyboard: false
      activeFocusOnPress: false
      activeFocusOnTab: false
      textFormat: TextEdit.RichText
      text: root.animatable
        ? root.escapeMarkup(root.head)
          + '<font color="transparent">'
          + root.escapeMarkup(root.spare.substring(0, root.spareShown))
          + '</font>'
          + root.escapeMarkup(root.tail)
        : root.escapeMarkup(root.revealed ? root.cleanedText : root.originalText)
      color: Color.popups.text
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
      wrapMode: TextEdit.WrapAnywhere

      Accessible.role: Accessible.StaticText
      // Iba en español dentro del QML, así que en inglés un lector de
      // pantalla decía «Ejemplo original: https://…». Y se anuncia el
      // estado asentado, no el fotograma: a media animación el texto es un
      // recorte que no existe en ninguna parte.
      Accessible.name: Strings.f(
        root.revealed ? "demo.a11y.after" : "demo.a11y.before",
        root.lang,
        root.revealed ? root.cleanedText : root.originalText)

      // Se vuelve a medir cada vez que la geometría se mueve y el gesto no
      // está en marcha. Medir sólo al construirse daba posiciones de
      // cuando la tarjeta aún no tenía su alto: los añicos salían con el
      // suelo a media altura y se paraban en el aire.
      onWidthChanged: if (root.fallClock === 0) root.measureShards()
      onImplicitHeightChanged: if (root.fallClock === 0) root.measureShards()
      onTextChanged: if (root.fallClock === 0) root.measureShards()
      Component.onCompleted: root.measureShards()
    }

    // Los añicos, en su propia capa y con las coordenadas congeladas al
    // soltar. **No roban el foco ni cambian el orden de tabulación**: son
    // dibujo, y desaparecen.
    //
    // Cada uno hereda el color de donde salió. Sin eso, los caracteres que
    // se van caerían del color del texto que se queda, y eso rompe el
    // idioma entero: acento es lo que se va.
    Item {
      anchors.fill: parent
      Accessible.ignored: true

      Repeater {
        model: root.shards

        delegate: Item {
          id: shard
          required property var modelData

          readonly property real tau: root.fallClock - modelData.release
          // La deriva y el giro sólo cuentan durante la caída libre.
          readonly property real flight: Math.max(0, Math.min(tau, modelData.t1))
          readonly property real fade: root.clamp((tau - modelData.rest) / 200)

          readonly property bool returning: root.reopened > 0

          x: modelData.x0 + (shard.returning ? 0 : modelData.drift * shard.flight / 1000)
          y: modelData.y0 + (shard.returning ? 0 : root.dropOf(modelData, shard.tau))
          width: glyph.implicitWidth > 0 ? glyph.implicitWidth : Style.space(9)
          height: modelData.line
          rotation: shard.returning ? 0 : modelData.spin * shard.flight / 1000
          transformOrigin: Item.Center
          opacity: shard.returning ? root.refilled : 1 - shard.fade
          visible: opacity > 0.01

          // El aplastado del primer impacto conserva el área: lo que se
          // hunde de alto se gana de ancho.
          readonly property real squash: shard.returning ? 1 : root.squashOf(modelData, shard.tau)
          transform: Scale {
            origin.x: shard.width / 2
            origin.y: shard.height
            xScale: 2 - shard.squash
            yScale: shard.squash
          }

          Text {
            id: glyph
            anchors.centerIn: parent
            text: modelData.ch
            color: Color.accent
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            visible: glyph.implicitWidth > 0
          }

          // El carácter que no tiene glifo no se ve caer, y es justo el que
          // más importa que se vea irse. Se le dibuja una caja vacía, como
          // la que dibuja `CopySpecimen` para el mismo carácter.
          //
          // **Pero sólo mientras cae.** Un carácter de ancho cero no ocupa
          // sitio en el renglón, así que en reposo la caja se plantaba
          // encima de la letra siguiente: la cadena se leía
          // `IwAR9x&▢ervings` y parecía un error de trazado.
          //
          // Y contarlo así es además más fiel: un carácter invisible **no
          // se ve**. Aparece al soltarse, que es el único momento en que
          // hay algo que enseñar, y ésa es la frase que la pantalla dice
          // debajo — «y un carácter invisible que no podías ver».
          Rectangle {
            visible: glyph.implicitWidth <= 0
            // Con el desvanecido pegado a la suelta todavía se materializaba
            // un instante encima de la letra siguiente. Sesenta milisegundos
            // de retraso son dieciséis píxeles de caída: cuando se ve, ya
            // está en el aire y no en el renglón.
            opacity: shard.returning ? 0 : root.clamp((shard.tau - 60) / 90)
            anchors.centerIn: parent
            width: Style.space(8)
            height: Style.space(10)
            radius: Style.space(2)
            color: "transparent"
            border.color: Color.accent
            border.width: Math.max(1, Style.space(1))
          }
        }
      }
    }
  }

  // Ocupa su sitio siempre. Apareciendo y desapareciendo, empujaba los
  // botones hacia abajo justo cuando el ojo iba hacia ellos.
  Text {
    width: parent.width
    opacity: root.outcomeIn
    text: Strings.t(root.sample.outcome, root.lang)
    color: Util.alpha(Color.popups.text, 0.72)
    font.family: Style.font.family
    font.pixelSize: Style.font.caption
    wrapMode: Text.WordWrap
    Accessible.role: Accessible.StaticText
    Accessible.name: text
    Accessible.ignored: !root.revealed
  }

  // Un solo mando. La `0004` pide una acción primaria por vista y aquí la
  // primaria es «Siguiente»; con dos botones más los suyos, este paso
  // llegaba a cinco cosas pulsables.
  //
  // Con movimiento el botón es para volver a mirar; sin movimiento es el
  // que hace la demostración, que es la única vía que le queda a quien
  // apagó las animaciones. «Ver el original» se retira: la tarjeta que lo
  // envolvía se fue con él, y con la caída el original ya se ha visto.
  PanelButton {
    id: revealButton
    width: parent.width
    text: root.motionEnabled
      ? Strings.t("demo.replay", root.lang)
      : Strings.t("demo.try", root.lang)
    onFocusEntered: function(item) { root.focusEntered(item) }
    onClicked: root.toggle()
  }

  // Pulsar cancela la reproducción pendiente: si alguien va más rápido que
  // el respiro de 700 ms, el temporizador no debe deshacer lo que acaba de
  // pedir.
  function toggle() {
    autoPlay.stop()
    if (!motionEnabled) { revealed = !revealed; return }
    // Rebobina y suelta otra vez, que es lo que «volver a mirar» quiere
    // decir cuando lo que hay que ver es un recorrido.
    revealed = false
    revealed = true
  }
}
