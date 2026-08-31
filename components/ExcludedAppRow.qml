import QtQuick
import qs.Commons
import qs.Ui
import "Strings.js" as Strings

Item {
  id: root

  // Idioma heredado del panel: en o es.
  property string lang: "en"

  property string appClass: ""
  property string scopeLabel: "Origen"
  signal removeRequested(string appClass)
  signal focusEntered(Item item)

  implicitWidth: Style.space(460)
  implicitHeight: Math.max(Style.space(44), appLabels.implicitHeight + Style.space(12))

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
      color: Util.alpha(Color.popups.text, 0.68)
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
    }
  }

  Button {
    id: removeButton
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    implicitHeight: Style.space(44)
    text: Strings.t("excl.remove", root.lang)
    tooltipText: Strings.f("excl.remove.a11y", root.lang, root.appClass)
    focusable: true
    bordered: true
    foreground: Color.popups.text
    Accessible.role: Accessible.Button
    Accessible.name: Strings.f("excl.remove.a11y", root.lang, root.appClass)
    Accessible.onPressAction: root.removeRequested(root.appClass)
    onActiveFocusChanged: if (activeFocus) root.focusEntered(removeButton)
    onClicked: root.removeRequested(root.appClass)
  }
}
