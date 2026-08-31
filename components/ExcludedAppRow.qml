import QtQuick
import qs.Commons
import qs.Ui

Item {
  id: root

  property string appClass: ""
  property string scopeLabel: "Origen"
  signal removeRequested(string appClass)
  signal focusEntered(Item item)

  implicitWidth: Style.space(460)
  implicitHeight: Math.max(44, appLabels.implicitHeight + Style.space(12))

  Accessible.role: Accessible.StaticText
  Accessible.name: scopeLabel + ": " + appClass

  Column {
    id: appLabels
    anchors.left: parent.left
    anchors.right: removeButton.left
    anchors.rightMargin: Style.space(12)
    anchors.verticalCenter: parent.verticalCenter
    spacing: Style.space(2)

    Text {
      width: parent.width
      text: root.appClass
      color: Color.popups.text
      font.family: Style.font.family
      font.pixelSize: Style.font.body
      elide: Text.ElideMiddle
    }

    Text {
      width: parent.width
      text: root.scopeLabel
      color: Util.alpha(Color.popups.text, 0.62)
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
    }
  }

  Button {
    id: removeButton
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    implicitHeight: 44
    text: "Quitar"
    tooltipText: "Quitar " + root.appClass
    focusable: true
    bordered: true
    foreground: Color.popups.text
    Accessible.role: Accessible.Button
    Accessible.name: "Quitar " + root.appClass
    Accessible.onPressAction: root.removeRequested(root.appClass)
    onActiveFocusChanged: if (activeFocus) root.focusEntered(removeButton)
    onClicked: root.removeRequested(root.appClass)
  }
}

