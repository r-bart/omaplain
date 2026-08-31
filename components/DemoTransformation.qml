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

  property int sampleIndex: 0
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
  readonly property var samples: [
    { "key": "demo.sample1", "outcome": "demo.outcome1" },
    { "key": "demo.sample2", "outcome": "demo.outcome2" }
  ]

  readonly property var sample: samples[Math.max(0, Math.min(samples.length - 1, sampleIndex))]
  readonly property string shownText: Strings.t(
    root.sample.key + (root.revealed ? ".cleaned" : ".original"), root.lang)

  spacing: Style.space(8)

  function reset() {
    revealed = false
    sampleIndex = 0
  }

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
    implicitHeight: sampleText.implicitHeight + Style.space(22)
    radius: Math.max(0, Style.cornerRadius - Style.space(2))
    color: Style.normalFillFor(Color.popups.text, Color.accent)
    borderSpec: Border.controlSpec("normal", Color.popups.text, Color.accent)

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
      Accessible.name: (root.revealed ? "Resultado: " : "Ejemplo original: ") + root.shownText
    }
  }

  Text {
    width: parent.width
    visible: root.revealed
    text: Strings.t(root.sample.outcome, root.lang)
    color: Util.alpha(Color.popups.text, 0.72)
    font.family: Style.font.family
    font.pixelSize: Style.font.caption
    wrapMode: Text.WordWrap
    Accessible.role: Accessible.StaticText
    Accessible.name: text
  }

  Grid {
    id: demoActions
    width: parent.width
    columns: width < Style.space(360) ? 1 : 2
    columnSpacing: Style.space(8)
    rowSpacing: Style.space(8)

    Button {
      id: revealButton
      width: (demoActions.width - (demoActions.columns - 1) * demoActions.columnSpacing) / demoActions.columns
      implicitHeight: Style.space(44)
      text: root.revealed ? Strings.t("demo.original", root.lang) : Strings.t("demo.try", root.lang)
      focusable: true
      bordered: true
      foreground: Color.popups.text
      Accessible.role: Accessible.Button
      Accessible.name: text
      Accessible.onPressAction: root.revealed = !root.revealed
      onActiveFocusChanged: if (activeFocus) root.focusEntered(revealButton)
      onClicked: root.revealed = !root.revealed
    }

    Button {
      id: cycleButton
      width: (demoActions.width - (demoActions.columns - 1) * demoActions.columnSpacing) / demoActions.columns
      implicitHeight: Style.space(44)
      text: Strings.t("demo.other", root.lang)
      focusable: true
      bordered: true
      foreground: Util.alpha(Color.popups.text, 0.68)
      Accessible.role: Accessible.Button
      Accessible.name: Strings.t("demo.other.a11y", root.lang)
      Accessible.onPressAction: root.nextSample()
      onActiveFocusChanged: if (activeFocus) root.focusEntered(cycleButton)
      onClicked: root.nextSample()
    }
  }

  // Cycling starts each sample at its original, or the second one would open
  // already answered and the button would read Strings.t("demo.original", root.lang) for a
  // result nobody asked to see.
  function nextSample() {
    revealed = false
    sampleIndex = (sampleIndex + 1) % samples.length
  }
}
