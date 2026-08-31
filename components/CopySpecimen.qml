import QtQuick
import qs.Commons
import qs.Ui

// La pieza gráfica de cada ejemplo del carrusel, en el mismo lenguaje que
// la ilustración de la bienvenida: hojas, renglones y un acento reservado
// para lo que sobra.
//
// Comparte el mismo `combed` que el texto de al lado, así que el dibujo y
// la frase pierden lo que sobra en el mismo gesto en vez de contar dos
// historias a destiempo.
Item {
  id: root

  // "link" | "text" | "rich"
  property string kind: "link"
  // 0 = recién llegado, 1 = ya peinado.
  property real combed: 0

  implicitWidth: Style.space(74)
  implicitHeight: Style.space(64)
  Accessible.ignored: true

  // El halo de la familia: el mismo círculo suave que en la bienvenida.
  Rectangle {
    width: Style.space(58)
    height: width
    radius: width / 2
    anchors.centerIn: parent
    color: Util.alpha(Color.accent, 0.09)
  }

  // ---------- Un enlace: la cola de seguimiento se recorta ----------
  BorderSurface {
    anchors.centerIn: parent
    visible: root.kind === "link"
    width: Style.space(62)
    height: Style.space(40)
    rotation: -4
    radius: Math.max(2, Style.cornerRadius - Style.space(3))
    color: Color.popups.text
    borderSpec: Border.controlSpec("normal", Color.popups.background, Color.accent)
    clip: true

    Row {
      anchors.centerIn: parent
      spacing: Style.space(3)

      Rectangle {
        width: Style.space(22); height: Style.space(5); radius: height / 2
        color: Color.popups.background
        anchors.verticalCenter: parent.verticalCenter
      }
      // La cola: lo que el peine se lleva.
      Rectangle {
        width: Style.space(18) * (1 - root.combed)
        height: Style.space(5); radius: height / 2
        color: Color.accent
        opacity: 1 - root.combed * 0.4
        anchors.verticalCenter: parent.verticalCenter
      }
    }
  }

  // ---------- Un párrafo: el invisible que se cuela entre renglones ----------
  BorderSurface {
    anchors.centerIn: parent
    visible: root.kind === "text"
    width: Style.space(56)
    height: Style.space(46)
    rotation: 3
    radius: Math.max(2, Style.cornerRadius - Style.space(3))
    color: Color.popups.text
    borderSpec: Border.controlSpec("normal", Color.popups.background, Color.accent)
    clip: true

    Column {
      anchors.centerIn: parent
      spacing: Style.space(5)

      Rectangle { width: Style.space(32); height: Style.space(4); radius: height / 2; color: Color.popups.background }
      Row {
        spacing: Style.space(2)
        Rectangle { width: Style.space(14); height: Style.space(4); radius: height / 2; color: Color.popups.background }
        // El carácter que no se ve, marcado hasta que se va.
        Rectangle {
          width: Style.space(6) * (1 - root.combed)
          height: Style.space(4); radius: height / 2
          color: Color.accent
          opacity: 1 - root.combed * 0.4
        }
        Rectangle { width: Style.space(10); height: Style.space(4); radius: height / 2; color: Color.popups.background }
      }
      Rectangle { width: Style.space(26); height: Style.space(4); radius: height / 2; color: Color.popups.background }
    }
  }

  // ---------- Texto con formato: la copia de debajo desaparece ----------
  Item {
    anchors.centerIn: parent
    visible: root.kind === "rich"
    width: Style.space(64)
    height: Style.space(46)

    // La versión con formato, detrás: es la que se va entera.
    BorderSurface {
      x: Style.space(9); y: Style.space(2)
      width: Style.space(52); height: Style.space(40)
      rotation: 7
      radius: Math.max(2, Style.cornerRadius - Style.space(3))
      color: Util.alpha(Color.accent, 0.9)
      borderSpec: Border.controlSpec("normal", Color.popups.background, Color.accent)
      opacity: 1 - root.combed
      scale: 1 - root.combed * 0.08
      transformOrigin: Item.Center
    }

    // La de texto plano, delante: la que se queda.
    BorderSurface {
      x: 0; y: Style.space(5)
      width: Style.space(52); height: Style.space(40)
      rotation: -3
      radius: Math.max(2, Style.cornerRadius - Style.space(3))
      color: Color.popups.text
      borderSpec: Border.controlSpec("normal", Color.popups.background, Color.accent)
      clip: true

      Column {
        anchors.centerIn: parent
        spacing: Style.space(4)
        Rectangle { width: Style.space(28); height: Style.space(4); radius: height / 2; color: Color.popups.background }
        Rectangle { width: Style.space(20); height: Style.space(4); radius: height / 2; color: Color.popups.background }
        Rectangle { width: Style.space(24); height: Style.space(4); radius: height / 2; color: Color.popups.background }
      }
    }
  }
}
