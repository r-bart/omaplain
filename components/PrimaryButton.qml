import QtQuick
import qs.Commons
import qs.Ui

BorderSurface {
  id: root

  property string text: ""
  property string iconText: ""
  property bool focusable: true

  signal clicked()

  readonly property bool hot: pointer.containsMouse
  readonly property bool pressed: pointer.pressed

  activeFocusOnTab: focusable
  implicitWidth: labelRow.implicitWidth + Style.space(32)
  implicitHeight: Math.max(Style.space(44), labelRow.implicitHeight + Style.space(18))
  radius: Style.cornerRadius
  color: enabled ? Color.accent : Util.alpha(Color.muted, 0.38)
  borderSpec: activeFocus
    ? Border.controlSpec("focus", Color.popups.text, Color.accent)
    : Border.controlSpec("normal", Color.popups.background, Color.accent)

  Accessible.role: Accessible.Button
  Accessible.name: text
  Accessible.onPressAction: if (root.enabled) root.clicked()

  Keys.onReturnPressed: if (focusable && enabled) root.clicked()
  Keys.onEnterPressed: if (focusable && enabled) root.clicked()
  Keys.onSpacePressed: if (focusable && enabled) root.clicked()

  Rectangle {
    anchors.fill: parent
    radius: root.radius
    color: root.pressed
      ? Util.alpha(Color.popups.text, 0.18)
      : (root.hot ? Util.alpha(Color.popups.text, 0.10) : "transparent")

    Behavior on color { ColorAnimation { duration: 120 } }
  }

  // El foco no puede vivir sólo en el borde. Sobre un relleno de acento
  // saturado, el borde de foco de la paleta **se oscurece** —medido en el
  // panel real: rgb(114,112,129) sin foco, rgb(88,87,103) con foco—, así
  // que pierde contraste contra el fondo justo cuando debería ganarlo.
  // Enfocado y sin enfocar se veían iguales.
  //
  // El anillo va por dentro y en el mismo color que el texto del botón,
  // que es el que ya contrasta con el relleno en los dos temas. Radio
  // concéntrico: el de fuera menos el hueco.
  Rectangle {
    anchors.fill: parent
    anchors.margins: Style.space(3)
    radius: Math.max(0, root.radius - Style.space(3))
    color: "transparent"
    border.color: Color.background
    border.width: Math.max(2, Style.space(2))
    visible: root.focusable && root.activeFocus
  }

  Row {
    id: labelRow
    anchors.centerIn: parent
    spacing: Style.space(7)

    Text {
      visible: root.iconText !== ""
      text: root.iconText
      color: Color.background
      opacity: root.enabled ? 1 : 0.64
      font.family: Style.font.family
      font.pixelSize: Style.font.icon
      anchors.verticalCenter: parent.verticalCenter
    }

    Text {
      text: root.text
      color: Color.background
      opacity: root.enabled ? 1 : 0.64
      font.family: Style.font.family
      font.pixelSize: Style.font.body
      font.bold: true
      anchors.verticalCenter: parent.verticalCenter
    }
  }

  MouseArea {
    id: pointer
    anchors.fill: parent
    enabled: root.enabled
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: {
      if (root.focusable) root.forceActiveFocus()
      root.clicked()
    }
  }
}
