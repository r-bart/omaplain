import QtQuick
import qs.Commons
import qs.Ui
import "Ink.js" as Ink

// A quiet placeholder for a list that has nothing in it yet. It says what the
// list would hold, so an untouched section reads as a deliberate default
// rather than as a section that failed to load.
BorderSurface {
  id: root

  property string title: ""
  property string body: ""

  implicitWidth: Style.space(460)
  implicitHeight: lines.implicitHeight + Style.space(28)
  radius: Style.cornerRadius
  color: Style.normalFillFor(Color.popups.text, Color.accent)
  borderSpec: Border.controlSpec("normal", Color.popups.text, Color.accent)

  Accessible.role: Accessible.StaticText
  Accessible.name: root.title
  Accessible.description: root.body

  Column {
    id: lines
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.leftMargin: Style.space(14)
    anchors.rightMargin: Style.space(14)
    anchors.verticalCenter: parent.verticalCenter
    spacing: Style.space(4)

    Text {
      width: parent.width
      text: root.title
      color: Color.popups.text
      font.family: Style.font.family
      font.pixelSize: Style.font.body
      wrapMode: Text.WordWrap
    }

    Text {
      width: parent.width
      text: root.body
      color: Ink.secondary(Color.popups.text, Color.popups.background)
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      wrapMode: Text.WordWrap
    }
  }
}
