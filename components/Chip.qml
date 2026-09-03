import QtQuick
import qs.Commons
import qs.Ui

// Una pastilla de metadato: un tipo MIME, el ajuste que gobierna una regla.
// Nunca lleva contenido del portapapeles, sólo cómo está hecho.
BorderSurface {
  id: root

  property string label: ""

  // El que no sobrevive a la limpieza.
  property bool dropped: false

  // Nombrar, la primera mitad del motor de compresión: el chip pasa de la
  // tinta del panel al acento **sin moverse**. Uno = ya nombrado.
  property real named: 1

  readonly property real mark: dropped ? Math.max(0, Math.min(1, named)) : 0

  // El tono va del texto del panel al acento. Los que se quedan van en la
  // tinta normal y no en `Color.muted`: son justamente lo que sobrevive, y
  // apagarlos decía lo contrario.
  readonly property color hue: Qt.rgba(
    Color.popups.text.r + (Color.accent.r - Color.popups.text.r) * mark,
    Color.popups.text.g + (Color.accent.g - Color.popups.text.g) * mark,
    Color.popups.text.b + (Color.accent.b - Color.popups.text.b) * mark,
    1)
  readonly property color ink: Util.alpha(hue, 0.68 + 0.07 * mark)

  implicitWidth: text.implicitWidth + Style.space(16)
  implicitHeight: text.implicitHeight + Style.space(8)
  radius: implicitHeight / 2

  // **Sin relleno, tampoco el que se va.** Llevaba fondo de acento al 12%
  // además del tachado y del color, y eso lo convertía en lo más brillante
  // de la fila: tres señales para lo único que no va a estar. Una basta.
  color: "transparent"
  borderSpec: Border.flat(Util.alpha(root.hue, 0.30 + 0.02 * root.mark),
                          Math.max(1, Style.normalBorderWidth))

  Text {
    id: text
    anchors.centerIn: parent
    text: root.label
    color: root.ink
    font.family: Style.font.family
    font.pixelSize: Style.font.caption
    // Tachar lo que se va: el mismo gesto que en las URLs del antes. Llega
    // con el nombrado y no antes, para que se vea aparecer.
    font.strikeout: root.mark > 0.5
  }
}
