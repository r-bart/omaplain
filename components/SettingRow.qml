import QtQuick
import qs.Commons
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

  // El panel es una superficie de popup, y el kit da por defecto el
  // `foreground` global. Donde el tema los separa, la fila se salía de su
  // propia paleta.
  foreground: Color.popups.text

  Accessible.role: Accessible.CheckBox
  Accessible.name: label
  Accessible.description: description
  Accessible.checked: checked
  Accessible.onPressAction: root.clicked()

  onActiveFocusChanged: if (activeFocus) focusEntered(root)

  // El mismo anillo que [`PanelButton`], y por el mismo motivo: el borde de
  // foco del kit es más tenue que el de reposo, así que enfocar una fila la
  // apagaba. Con catorce filas en los ajustes, el recorrido por teclado se
  // quedaba sin rastro visible.
  Rectangle {
    anchors.fill: parent
    anchors.margins: Style.space(3)
    radius: Math.max(0, root.radius - Style.space(3))
    color: "transparent"
    border.color: Util.alpha(Color.popups.text, 0.68)
    border.width: Math.max(2, Style.space(2))
    visible: root.activeFocus
  }
}
