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
//
// Tres siluetas distintas, para que de un vistazo se sepa que son tres
// cosas distintas y no el mismo icono con otro pie: una barra de
// dirección sobre su página, una hoja de párrafo, y dos copias
// superpuestas de las que se retira la de arriba.
Item {
  id: root

  // "link" | "text" | "rich"
  property string kind: "link"
  // 0 = recién llegado, 1 = ya peinado.
  property real combed: 0
  // 1 = asentado en su sitio. El carrusel lo baja a 0 al entrar, y las
  // hojas aterrizan un grado en vez de aparecer ya colocadas.
  property real landed: 1

  implicitWidth: Style.space(108)
  implicitHeight: Style.space(96)
  Accessible.ignored: true

  // El peine pasa una vez y a mitad de recorrido: termina antes que el
  // encogido, para que se lea como causa y no como acompañamiento.
  readonly property real sweep: Math.max(0, Math.min(1, root.combed / 0.86))
  readonly property real settle: 1 - Math.max(0, Math.min(1, root.landed))

  // De dónde salen las motas: del sitio exacto donde desaparece lo que
  // sobra, o serían confeti.
  readonly property point spark: root.kind === "link"
    ? Qt.point(Style.space(88), Style.space(54))
    : root.kind === "text" ? Qt.point(Style.space(30), Style.space(48))
    : Qt.point(Style.space(40), Style.space(40))

  // El halo de la familia: el mismo círculo suave que en la bienvenida.
  // Da un único empujón cuando pasa el peine.
  //
  // Va centrado en el dibujo, no en el recuadro: cada composición ocupa
  // un trozo distinto, y un halo centrado «bien» asomaba por una esquina
  // como si fuera una sombra mal puesta.
  readonly property point haloAt: root.kind === "link"
    ? Qt.point(Style.space(53), Style.space(40))
    : root.kind === "text" ? Qt.point(Style.space(55), Style.space(47))
    : Qt.point(Style.space(62), Style.space(42))

  Rectangle {
    width: Style.space(82)
    height: width
    radius: width / 2
    x: root.haloAt.x - width / 2
    y: root.haloAt.y - height / 2
    color: Util.alpha(Color.accent, 0.10)
    scale: 1 + 0.11 * Math.sin(Math.PI * root.sweep)
    transformOrigin: Item.Center
  }

  // ---------- Un enlace: la cola de seguimiento se recorta ----------
  Item {
    anchors.fill: parent
    visible: root.kind === "link"

    // La página de la que se copia, detrás y a media luz.
    BorderSurface {
      x: Style.space(18)
      y: Style.space(4)
      width: Style.space(78)
      height: Style.space(60)
      rotation: -8 + 3 * root.settle
      transformOrigin: Item.Center
      radius: Math.max(2, Style.cornerRadius - Style.space(3))
      color: Util.alpha(Color.popups.text, 0.34)
      borderSpec: Border.controlSpec("normal", Color.popups.background, Color.accent)

      Column {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: Style.space(11)
        spacing: Style.space(6)

        Repeater {
          model: [0.62, 0.44, 0.54]
          delegate: Rectangle {
            required property real modelData
            width: Style.space(56) * modelData
            height: Style.space(4)
            radius: height / 2
            color: Util.alpha(Color.popups.background, 0.7)
          }
        }
      }
    }

    // La barra de dirección, delante: es donde vive lo que sobra.
    BorderSurface {
      x: Style.space(2)
      y: Style.space(40)
      width: Style.space(102)
      height: Style.space(36)
      rotation: 2 - 2.5 * root.settle - 1.2 * root.combed
      transformOrigin: Item.Center
      radius: Math.max(2, Style.cornerRadius - Style.space(2))
      color: Color.popups.text
      borderSpec: Border.controlSpec("normal", Color.popups.background, Color.accent)
      clip: true

      Row {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: Style.space(9)
        spacing: Style.space(5)

        Rectangle {
          width: Style.space(8)
          height: width
          radius: width / 2
          color: Util.alpha(Color.popups.background, 0.5)
          anchors.verticalCenter: parent.verticalCenter
        }

        // El dominio, que se queda.
        Rectangle {
          width: Style.space(30)
          height: Style.space(6)
          radius: height / 2
          color: Color.popups.background
          anchors.verticalCenter: parent.verticalCenter
        }

        // La cola: lo que el peine se lleva.
        Rectangle {
          width: Style.space(34) * (1 - root.combed)
          height: Style.space(6)
          radius: height / 2
          color: Color.accent
          opacity: 1 - root.combed * 0.35
          anchors.verticalCenter: parent.verticalCenter
        }
      }
    }
  }

  // ---------- Un párrafo: el invisible que se cuela entre renglones ----------
  Item {
    anchors.fill: parent
    visible: root.kind === "text"

    BorderSurface {
      x: Style.space(32)
      y: Style.space(2)
      width: Style.space(68)
      height: Style.space(74)
      rotation: 9 - 3 * root.settle
      transformOrigin: Item.Center
      radius: Math.max(2, Style.cornerRadius - Style.space(3))
      color: Util.alpha(Color.popups.text, 0.3)
      borderSpec: Border.controlSpec("normal", Color.popups.background, Color.accent)
    }

    BorderSurface {
      x: Style.space(10)
      y: Style.space(12)
      width: Style.space(76)
      height: Style.space(80)
      rotation: -4 + 3 * root.settle + 1.4 * root.combed
      transformOrigin: Item.Center
      radius: Math.max(2, Style.cornerRadius - Style.space(3))
      color: Color.popups.text
      borderSpec: Border.controlSpec("normal", Color.popups.background, Color.accent)
      clip: true

      Column {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: Style.space(12)
        spacing: Style.space(6)

        Rectangle { width: Style.space(54); height: Style.space(5); radius: height / 2; color: Color.popups.background }
        Rectangle { width: Style.space(44); height: Style.space(5); radius: height / 2; color: Color.popups.background }

        // El carácter que no se ve, dibujado como lo que es: una caja
        // vacía, sin glifo dentro. Al retirarse cierra su propio hueco y
        // los renglones de abajo suben — que es justo lo que pasa.
        Item {
          width: Style.space(13)
          height: Style.space(13) * (1 - root.combed)
          clip: true

          Rectangle {
            width: Style.space(13)
            height: Style.space(13)
            radius: Style.space(3)
            color: "transparent"
            border.color: Color.accent
            border.width: Math.max(1, Style.space(2))
            opacity: 1 - root.combed * 0.3
          }
        }

        Rectangle { width: Style.space(50); height: Style.space(5); radius: height / 2; color: Color.popups.background }
        Rectangle { width: Style.space(36); height: Style.space(5); radius: height / 2; color: Color.popups.background }
      }
    }
  }

  // ---------- Texto con formato: la copia de arriba se retira ----------
  Item {
    anchors.fill: parent
    visible: root.kind === "rich"

    // Debajo, la de texto plano: la que se queda.
    BorderSurface {
      x: Style.space(24)
      y: Style.space(6)
      width: Style.space(76)
      height: Style.space(72)
      rotation: 7 - 3 * root.settle - 2 * root.combed
      transformOrigin: Item.Center
      radius: Math.max(2, Style.cornerRadius - Style.space(3))
      color: Color.popups.text
      borderSpec: Border.controlSpec("normal", Color.popups.background, Color.accent)
      clip: true

      Column {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: Style.space(12)
        spacing: Style.space(7)

        Repeater {
          model: [0.78, 0.6, 0.7, 0.44]
          delegate: Rectangle {
            required property real modelData
            width: Style.space(52) * modelData
            height: Style.space(5)
            radius: height / 2
            color: Color.popups.background
          }
        }
      }
    }

    // Y encima la copia con formato, que se levanta y se va entera:
    // ni un carácter cambia, y aun así hay algo que retirar.
    BorderSurface {
      x: Style.space(6) - Style.space(12) * root.combed
      y: Style.space(18) - Style.space(12) * root.combed
      width: Style.space(76)
      height: Style.space(72)
      rotation: -6 - 9 * root.combed + 3 * root.settle
      scale: 1 - 0.06 * root.combed
      opacity: 1 - root.combed
      transformOrigin: Item.Center
      radius: Math.max(2, Style.cornerRadius - Style.space(3))
      color: Util.alpha(Color.accent, 0.88)
      borderSpec: Border.controlSpec("normal", Color.popups.background, Color.accent)
      clip: true

      Column {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: Style.space(12)
        spacing: Style.space(7)

        // Un titular en negrita y una cita: el formato que sobra, dibujado.
        Rectangle { width: Style.space(40); height: Style.space(9); radius: Style.space(2); color: Color.background }
        Rectangle { width: Style.space(54); height: Style.space(5); radius: height / 2; color: Util.alpha(Color.background, 0.8) }

        Row {
          spacing: Style.space(6)

          Rectangle { width: Style.space(4); height: Style.space(21); radius: width / 2; color: Color.background }

          Column {
            spacing: Style.space(6)
            anchors.verticalCenter: parent.verticalCenter
            Rectangle { width: Style.space(42); height: Style.space(5); radius: height / 2; color: Util.alpha(Color.background, 0.8) }
            Rectangle { width: Style.space(32); height: Style.space(5); radius: height / 2; color: Util.alpha(Color.background, 0.8) }
          }
        }
      }
    }
  }

  // ---------- Lo que el peine levanta ----------
  //
  // Tres motas, no un puñado: salen de donde desaparece lo que sobra y se
  // apagan enseguida. Con más, la tarjeta pasaría a ser una fiesta.
  Repeater {
    model: [
      { dx: 17, dy: -19, size: 5, delay: 0.0 },
      { dx: 25, dy: -5, size: 4, delay: 0.09 },
      { dx: 13, dy: 13, size: 3, delay: 0.17 }
    ]

    delegate: Rectangle {
      required property var modelData
      readonly property real flight: Math.max(0, Math.min(1,
        (root.combed - modelData.delay) / Math.max(0.01, 0.76 - modelData.delay)))

      width: Style.space(modelData.size)
      height: width
      radius: width / 2
      color: Color.accent
      x: root.spark.x + Style.space(modelData.dx) * flight
      y: root.spark.y + Style.space(modelData.dy) * flight
      opacity: Math.sin(Math.PI * flight) * 0.85
      visible: opacity > 0.01
    }
  }

  // ---------- El paso del peine ----------
  //
  // Una banda de luz que cruza la escena justo mientras lo que sobra se
  // encoge. Es lo que ata dibujo y frase: se ve por qué desaparece.
  Item {
    anchors.fill: parent
    clip: true
    visible: root.sweep > 0 && root.sweep < 1

    Rectangle {
      width: Style.space(32)
      height: parent.height * 1.9
      anchors.verticalCenter: parent.verticalCenter
      x: -width + (parent.width + 2 * width) * root.sweep
      rotation: -14
      transformOrigin: Item.Center
      opacity: Math.sin(Math.PI * root.sweep) * 0.7

      gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0.0; color: Util.alpha(Color.accent, 0) }
        GradientStop { position: 0.5; color: Util.alpha(Color.accent, 0.5) }
        GradientStop { position: 1.0; color: Util.alpha(Color.accent, 0) }
      }
    }
  }
}
