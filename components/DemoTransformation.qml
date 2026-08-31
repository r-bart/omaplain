import QtQuick
import qs.Commons
import qs.Ui
import "Strings.js" as Strings

// A demonstration that never reads the clipboard. Both samples and both
// results are literals, and tests/unit/test_demo_sample.py pushes each
// original through the real transform, so the demo cannot keep promising
// something the engine stopped doing.
Column {
  id: root

  // Idioma heredado del panel: en o es.
  property string lang: "en"

  property int sampleIndex: 0
  property bool revealed: false

  signal focusEntered(Item item)

  // Each sample is one whole URL because that is the only shape the engine
  // rewrites: clean_tracking_url gives up as soon as the text carries a
  // space. Prose with a link inside it is left alone, and a demo built on
  // prose would claim otherwise.
  readonly property var samples: [
    {
      "original": "https://ejemplo.com/pan-de-masa-madre?utm_source=boletin&utm_medium=email&fbclid=IwAR9x&porciones=8#horneado​",
      "cleaned": "https://ejemplo.com/pan-de-masa-madre?porciones=8#horneado",
      "outcome": "Fuera tres parámetros de seguimiento y un carácter invisible que no se veía. La página, las porciones y el punto al que apunta siguen ahí."
    },
    {
      "original": "https://ejemplo.com/factura.pdf?expires=1735689600&signature=ab12cd34",
      "cleaned": "https://ejemplo.com/factura.pdf?expires=1735689600&signature=ab12cd34",
      "outcome": "Sin cambios: esta URL va firmada y recortarla la rompería. Ante la duda, OmaPlain prefiere no tocar nada."
    }
  ]

  readonly property var sample: samples[Math.max(0, Math.min(samples.length - 1, sampleIndex))]
  readonly property string shownText: revealed ? sample.cleaned : sample.original

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
    text: root.sample.outcome
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
