import QtQuick
import qs.Ui

Toggle {
  id: root

  signal focusEntered(Item item)

  implicitHeight: Math.max(44, contentHeight)
  Accessible.role: Accessible.CheckBox
  Accessible.name: label
  Accessible.description: description
  Accessible.checked: checked
  Accessible.onPressAction: root.clicked()

  readonly property real contentHeight: 54

  onActiveFocusChanged: if (activeFocus) focusEntered(root)
}

