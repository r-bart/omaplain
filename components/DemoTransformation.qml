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

  // El estado lógico. `combed` lo sigue, animado o de golpe.
  property bool revealed: false

  signal focusEntered(Item item)

  // Cada muestra es una URL entera porque es la única forma que el motor
  // reescribe: `clean_tracking_url` se rinde en cuanto el texto lleva un
  // espacio. Prosa con un enlace dentro se queda intacta, y una demo hecha
  // de prosa afirmaría lo contrario.
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
  readonly property string head: Strings.t(root.sample.key + ".head", root.lang)
  readonly property string spare: Strings.t(root.sample.key + ".spare", root.lang)
  readonly property string tail: Strings.t(root.sample.key + ".tail", root.lang)

  readonly property string originalText: Strings.t(root.sample.key + ".original", root.lang)
  readonly property string cleanedText: Strings.t(root.sample.key + ".cleaned", root.lang)

  // 0 = original entero, 1 = peinado. Se come el tramo que sobra por la
  // derecha, así que la cola se cierra hacia atrás y se ve *qué* se va, no
  // sólo que algo cambió.
  //
  // Va sobre el texto y no sobre un `Item` con `clip`, que es como lo hace
  // el carrusel del estado vacío: allí la muestra cabe en una línea y aquí
  // no, y un `Row` de tres textos no envuelve. Comiendo caracteres, el
  // `Text` envuelve solo y la cola sube de línea al cerrarse el hueco.
  property real combed: root.revealed ? 1 : 0
  Behavior on combed {
    enabled: root.motionEnabled
    NumberAnimation { duration: 620; easing.type: Easing.InOutCubic }
  }

  // Sólo las muestras que pierden algo llevan tramos, y la comprobación es
  // la propia costura: si los tres no recomponen el original —porque no
  // existen, porque el catálogo cambió a medias— no se anima nada y se
  // enseña el estado entero, que nunca puede estar mal.
  readonly property bool animatable:
    root.spare.length > 0 && (root.head + root.spare + root.tail) === root.originalText

  readonly property string shownText: root.animatable
    ? root.head
      + root.spare.substring(0, Math.round(root.spare.length * (1 - root.combed)))
      + root.tail
    : (root.revealed ? root.cleanedText : root.originalText)

  spacing: Style.space(8)

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
    // `combed` no se toca a mano: es un binding sobre `revealed`, y asignarle
    // un valor aquí lo rompía para siempre. El síntoma era que el botón y la
    // frase pasaban a «limpio» mientras el texto se quedaba entero con sus
    // parámetros, prometiendo una limpieza que la pantalla no enseñaba.
    revealed = false
    sampleIndex = 0
    if (motionEnabled && visible) autoPlay.restart()
  }

  onVisibleChanged: if (visible) reset(); else autoPlay.stop()
  onMotionEnabledChanged: reset()

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

  BorderSurface {
    width: parent.width
    // La altura la fija el original, que es el estado más alto. Atada al
    // texto en curso, la caja encogía de dos líneas a una en mitad de la
    // animación y empujaba hacia arriba todo lo que hay debajo, botones
    // incluidos: un blanco móvil justo donde hay que pulsar.
    implicitHeight: Math.max(measure.implicitHeight, sampleText.implicitHeight) + Style.space(22)
    radius: Math.max(0, Style.cornerRadius - Style.space(2))
    color: Style.normalFillFor(Color.popups.text, Color.accent)
    borderSpec: Border.controlSpec("normal", Color.popups.text, Color.accent)

    // Sólo mide: nunca se pinta ni se anuncia.
    Text {
      id: measure
      visible: false
      width: sampleText.width
      text: root.originalText
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
      wrapMode: Text.WrapAnywhere
      Accessible.ignored: true
    }

    Text {
      id: sampleText
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(12)
      anchors.rightMargin: Style.space(12)
      text: root.shownText
      color: Color.popups.text
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
      wrapMode: Text.WrapAnywhere
      Accessible.role: Accessible.StaticText
      // Iba en español dentro del QML, así que en inglés un lector de
      // pantalla decía «Ejemplo original: https://…». Y se anuncia el
      // estado asentado, no el fotograma: a media animación el texto es un
      // recorte que no existe en ninguna parte.
      Accessible.name: Strings.f(
        root.revealed ? "demo.a11y.after" : "demo.a11y.before",
        root.lang,
        root.revealed ? root.cleanedText : root.originalText)
    }
  }

  // Ocupa su sitio siempre. Apareciendo y desapareciendo, empujaba los
  // botones hacia abajo justo cuando el ojo iba hacia ellos.
  Text {
    width: parent.width
    // Llega con el peinado, no antes. Atada a `revealed` aparecía en cuanto
    // arrancaba la animación y contaba el desenlace mientras todavía estaba
    // ocurriendo. Colgada de `combed` entra en el último tercio, y con el
    // movimiento apagado sale entera y de golpe, que es lo que `combed` hace
    // cuando no hay animación que seguir.
    opacity: Math.max(0, Math.min(1, (root.combed - 0.55) / 0.35))
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
  // llegaba a cinco cosas pulsables. Con movimiento el botón es para
  // volver a mirar; sin movimiento es el que hace la demostración, que es
  // la única vía que le queda a quien apagó las animaciones.
  Button {
    id: revealButton
    width: parent.width
    implicitHeight: Style.space(44)
    text: root.revealed
      ? Strings.t("demo.original", root.lang)
      : (root.motionEnabled ? Strings.t("demo.replay", root.lang) : Strings.t("demo.try", root.lang))
    focusable: true
    bordered: true
    foreground: Color.popups.text
    Accessible.role: Accessible.Button
    Accessible.name: text
    Accessible.onPressAction: root.toggle()
    onActiveFocusChanged: if (activeFocus) root.focusEntered(revealButton)
    onClicked: root.toggle()
  }

  // Pulsar cancela la reproducción pendiente: si alguien va más rápido que
  // el respiro de 700 ms, el temporizador no debe deshacer lo que acaba de
  // pedir.
  function toggle() {
    autoPlay.stop()
    revealed = !revealed
  }
}
