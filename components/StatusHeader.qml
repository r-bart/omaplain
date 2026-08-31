import QtQuick
import qs.Commons
import qs.Ui

// El estado del servicio en la pantalla frecuente. Nada más.
//
// Antes esto era un héroe: llevaba «Texto limpio, sin sorpresas» —el mismo
// titular, palabra por palabra, que la pantalla de bienvenida— más la
// ilustración de transformación, ocupando el tercio superior de un panel
// pequeño y de uso diario.
//
// La decisión 0007 se llevó ambas cosas a donde tienen trabajo. La primera
// experiencia enseña; ésta informa. El producto se explica solo enseñando
// qué va a hacer con tu contenido, que es mejor profesor que un dibujo que
// ya viste en el tour.
Item {
  id: root

  property string state: "starting"
  property string detail: "Preparando el servicio…"

  readonly property bool healthy: state === "running"
  readonly property bool paused: state === "paused"
  readonly property bool failed: ["degraded", "missing_dependencies", "config_error", "stopped"].indexOf(state) !== -1
  readonly property string stateLabel: failed ? "Necesita atención" : (paused ? "Pausado" : (healthy ? "Activo" : "Iniciando"))
  readonly property color stateColor: failed ? Color.urgent : (healthy ? Color.accent : Color.muted)

  implicitWidth: Style.space(460)
  implicitHeight: lines.implicitHeight

  Accessible.role: Accessible.StaticText
  Accessible.name: "OmaPlain, " + stateLabel + ". " + detail

  Column {
    id: lines
    anchors.left: parent.left
    anchors.right: parent.right
    spacing: Style.space(4)

    Row {
      spacing: Style.space(7)

      Rectangle {
        width: Style.space(8)
        height: width
        radius: width / 2
        color: root.stateColor
        anchors.verticalCenter: parent.verticalCenter
        Accessible.ignored: true
      }

      Text {
        text: root.stateLabel
        color: root.stateColor
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        font.bold: true
        font.capitalization: Font.AllUppercase
        font.letterSpacing: Style.spaceReal(0.8)
      }
    }

    Text {
      width: parent.width
      text: root.detail
      color: Util.alpha(Color.popups.text, 0.68)
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
      lineHeightMode: Text.ProportionalHeight
      lineHeight: 1.4
      wrapMode: Text.WordWrap
    }
  }
}
