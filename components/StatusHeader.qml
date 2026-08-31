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
  readonly property bool narrow: width < Style.space(410)

  implicitWidth: Style.space(460)
  implicitHeight: narrow ? Style.space(292) : Style.space(176)
  radius: Style.cornerRadius
  color: Style.normalFillFor(Color.popups.text, Color.accent)
  borderSpec: Border.controlSpec("normal", Color.popups.text, Color.accent)
  clip: true

  Accessible.role: Accessible.StaticText
  Accessible.name: "OmaPlain, " + stateLabel + ". " + detail

  Rectangle {
    width: Style.space(172)
    height: width
    radius: width / 2
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.rightMargin: -Style.space(44)
    anchors.topMargin: -Style.space(62)
    color: Util.alpha(Color.accent, 0.07)
    Accessible.ignored: true
  }

  Grid {
    id: heroGrid
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    anchors.leftMargin: root.borderLeft + Style.space(18)
    anchors.rightMargin: root.borderRight + Style.space(18)
    columns: root.narrow ? 1 : 2
    columnSpacing: Style.space(12)
    rowSpacing: Style.space(8)

    Column {
      id: heroCopy
      width: root.narrow
        ? heroGrid.width
        : Math.round((heroGrid.width - heroGrid.columnSpacing) * 0.48)
      spacing: Style.space(7)

      Row {
        width: parent.width
        spacing: Style.space(7)

        Rectangle {
          width: Style.space(8)
          height: width
          radius: width / 2
          color: root.stateColor
          anchors.verticalCenter: parent.verticalCenter
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
        text: "Texto limpio,\nsin sorpresas."
        color: Color.popups.text
        font.family: Style.font.family
        font.pixelSize: Style.font.display
        font.bold: true
        font.letterSpacing: -Style.spaceReal(0.4)
        lineHeightMode: Text.ProportionalHeight
        lineHeight: 1.05
        wrapMode: Text.WordWrap
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

    TransformationIllustration {
      width: root.narrow
        ? heroGrid.width
        : heroGrid.width - heroCopy.width - heroGrid.columnSpacing
      height: root.narrow ? Style.space(126) : Style.space(142)
      variant: "transform"
    }
  }
}
