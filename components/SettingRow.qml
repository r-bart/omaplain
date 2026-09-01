import QtQuick
import qs.Ui

Toggle {
  id: root

  signal focusEntered(Item item)

  // Sin `implicitHeight` propio. El kit ya calcula el suyo —`Toggle.qml`
  // hace `Math.max(54, content.implicitHeight + Style.spacing.huge)`— y
  // nuestro `Math.max(Style.space(44), 54)` lo tiraba: dejaba todas las filas
  // a la misma altura sin mirar el contenido, así que las que llevan una
  // descripción de dos líneas iban apretadas contra sus bordes. El suelo de
  // 54 del kit ya cubre de sobra el área táctil de 44.
  Accessible.role: Accessible.CheckBox
  Accessible.name: label
  Accessible.description: description
  Accessible.checked: checked
  Accessible.onPressAction: root.clicked()

  onActiveFocusChanged: if (activeFocus) focusEntered(root)
}
