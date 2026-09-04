import QtQuick
import qs.Commons
import qs.Ui
import "Ink.js" as Ink

// El botón secundario del panel: el del kit, más lo que en el panel se
// repetía once veces —alto mínimo, `focusable`, `bordered`, el color de
// una superficie de popup y los tres renglones de accesibilidad— y un
// anillo de foco que se ve.
//
// El del kit no se ve. `focus-border-alpha` cae por defecto en
// `hover-cursor-border-alpha`, que vale 0,25 frente al 0,4 del borde
// normal, así que tomar el foco **apaga** el contorno. Medido en el panel
// real, sobre este tema: 2,79:1 en reposo y 1,82:1 enfocado, con un relleno
// de foco a 1,16:1 del fondo. Es el mismo defecto que ya obligó a
// [`PrimaryButton`] a dibujar el suyo, y aquí afecta a los veinticinco
// controles de los ajustes.
//
// El anillo va por dentro, en el color del texto al 0,68 —el alfa de
// rótulo que el panel ya usa, sin inventar un número— y mide 6,17:1 contra
// el fondo y 5,31:1 contra el relleno de foco sobre el que se pinta. Neutro
// a propósito: un anillo de marca competiría con el acento, que aquí ya
// significa «elegido».
Button {
  id: root

  signal focusEntered(Item item)

  implicitHeight: Style.space(44)
  focusable: true
  bordered: true
  foreground: Color.popups.text

  Accessible.role: Accessible.Button
  Accessible.name: root.text
  // Con el mismo guardia que el clic: un lector de pantalla no debe poder
  // pulsar lo que el ratón no puede.
  Accessible.onPressAction: if (root.enabled) root.clicked()

  onActiveFocusChanged: if (activeFocus) root.focusEntered(root)

  Rectangle {
    anchors.fill: parent
    anchors.margins: Style.space(3)
    radius: Math.max(0, root.radius - Style.space(3))
    color: "transparent"
    border.color: Ink.ring(Color.popups.text, Color.popups.background)
    border.width: Math.max(2, Style.space(2))
    visible: root.focusable && root.activeFocus
  }
}
