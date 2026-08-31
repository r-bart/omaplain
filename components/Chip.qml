import QtQuick
import qs.Commons
import qs.Ui

// Una pastilla de metadato: un tipo MIME, el ajuste que gobierna una regla.
// Nunca lleva contenido del portapapeles, sólo cómo está hecho.
BorderSurface {
  id: root

  property string label: ""
  property bool dropped: false
  property bool kept: false

  readonly property color ink: dropped ? Color.accent
    : (kept ? Color.muted : Util.alpha(Color.popups.text, 0.68))

  implicitWidth: text.implicitWidth + Style.space(16)
  implicitHeight: text.implicitHeight + Style.space(8)
  radius: implicitHeight / 2
  color: dropped ? Util.alpha(Color.accent, 0.12) : "transparent"
  borderSpec: Border.flat(Util.alpha(root.ink, dropped ? 0.5 : 0.28),
                          Math.max(1, Style.normalBorderWidth))

  Text {
    id: text
    anchors.centerIn: parent
    text: root.label
    color: root.ink
    font.family: Style.font.family
    font.pixelSize: Style.font.caption
    // Tachar lo que se va: el mismo gesto que en las URLs del antes.
    font.strikeout: root.dropped
  }
}
