import QtQuick
import qs.Commons
import qs.Ui

BorderSurface {
  id: root

  property string state: "starting"
  property string detail: "Preparando el servicio…"

  readonly property bool healthy: state === "running"
  readonly property bool paused: state === "paused"
  readonly property bool failed: ["degraded", "missing_dependencies", "config_error", "stopped"].indexOf(state) !== -1
  readonly property string stateLabel: failed ? "Necesita atención" : (paused ? "Pausado" : (healthy ? "Activo" : "Iniciando"))
  readonly property color stateColor: failed ? Color.urgent : (healthy ? Color.accent : Color.muted)

  implicitWidth: Style.space(460)
  implicitHeight: Math.max(Style.space(80), content.implicitHeight + Style.space(32))
  radius: Style.cornerRadius
  color: Style.normalFillFor(Color.popups.text, Color.accent)
  borderSpec: Border.controlSpec("normal", Color.popups.text, Color.accent)

  Accessible.role: Accessible.StaticText
  Accessible.name: "OmaPlain, " + stateLabel + ". " + detail

  Row {
    id: content
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    anchors.leftMargin: root.borderLeft + Style.space(16)
    anchors.rightMargin: root.borderRight + Style.space(16)
    spacing: Style.space(12)

    Rectangle {
      width: Style.space(10)
      height: width
      radius: width / 2
      color: root.stateColor
      anchors.verticalCenter: parent.verticalCenter
    }

    Column {
      width: parent.width - Style.space(22)
      spacing: Style.space(4)

      Row {
        width: parent.width
        spacing: Style.space(8)

        Text {
          text: "OmaPlain"
          color: Color.popups.text
          font.family: Style.font.family
          font.pixelSize: Style.font.title
          font.bold: true
        }

        Text {
          text: "· " + root.stateLabel
          color: root.stateColor
          font.family: Style.font.family
          font.pixelSize: Style.font.subtitle
          anchors.baseline: parent.children[0].baseline
        }
      }

      Text {
        width: parent.width
        text: root.detail
        color: Util.alpha(Color.popups.text, 0.7)
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
        wrapMode: Text.WordWrap
      }
    }
  }
}
