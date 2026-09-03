import QtQuick
import qs.Commons
import qs.Ui

// La pieza gráfica de cada ejemplo del carrusel.
//
// Baja a cristal ([`0018`]): tres tarjetas pequeñas de 100 × 96 en el
// mismo material que el resto del panel, en vez de las hojas opacas de
// color tinta que había. Y comparte el mismo `combed` que el texto de al
// lado, así que el dibujo y la frase pierden lo que sobra en el mismo
// gesto en vez de contar dos historias a destiempo.
//
// Tres siluetas distintas, para que de un vistazo se sepa que son tres
// cosas distintas y no el mismo icono con otro pie: una barra de
// dirección sobre su página, una hoja de párrafo, y dos copias
// superpuestas de las que se retira el formato.
//
// **Lo que sobra se comprime, no cae** (`ANIMACIONES.md` §1 y §2). Un
// tramo de una ilustración no es un carácter real: no hay 34 letras ahí,
// hay una idea de que sobra algo. Se nombra y se cierra.
//
// Fuera las motas y el barrido que tenía la versión anterior. Ataban
// dibujo y frase cuando el dibujo no se explicaba solo; ahora sí. Y cada
// uno costaba un `Repeater` y un gradiente animado repintándose veintitrés
// veces por minuto, para siempre, en un panel que también corre en
// portátiles.
Item {
  id: root

  // "link" | "text" | "rich"
  property string kind: "link"
  // 0 = recién llegado, 1 = ya peinado.
  property real combed: 0
  // 1 = asentado en su sitio. El carrusel lo baja a 0 al entrar, y las
  // hojas aterrizan un grado en vez de aparecer ya colocadas.
  property real landed: 1

  implicitWidth: Style.space(100)
  implicitHeight: Style.space(96)
  Accessible.ignored: true

  // Estos tres viven **dentro** de la tarjeta del carrusel, así que no
  // proyectan sombra. El molde que la proyecta tiene que ser de un color
  // plano, y aquí el suelo es el fondo del panel más el relleno de esa
  // tarjeta: un molde del color del panel pintaría un rectángulo más
  // oscuro que su alrededor, con el canto marcado.
  //
  // Se gana algo a cambio: sin molde el cristal es translúcido de verdad,
  // y el halo se ve **a través** de las hojas en vez de sólo asomar por
  // los bordes.

  // El peine pasa una vez y a mitad de recorrido: termina antes que el
  // encogido, para que se lea como causa y no como acompañamiento.
  readonly property real sweep: Math.max(0, Math.min(1, root.combed / 0.86))
  readonly property real settle: 1 - Math.max(0, Math.min(1, root.landed))

  // Nombrar y comprimir, los dos tiempos del motor de compresión, dentro
  // del único recorrido de 620 ms que el carrusel ya tenía. Primero el
  // tramo pasa al acento **sin moverse** —se ve *qué* se va—, y sólo
  // después se cierra. Al revés sería un tramo desapareciendo, que no
  // explica nada.
  readonly property real naming: Math.max(0, Math.min(1, root.combed / 0.36))
  readonly property real squeeze: Math.max(0, Math.min(1, (root.combed - 0.42) / 0.58))

  // La tinta de reposo de un tramo que va a marcarse, interpolada hasta el
  // acento sobre el progreso del nombrado.
  readonly property color restInk: Util.alpha(Color.popups.text, 0.45)
  readonly property color markInk: Qt.rgba(
    restInk.r + (Color.accent.r - restInk.r) * root.naming,
    restInk.g + (Color.accent.g - restInk.g) * root.naming,
    restInk.b + (Color.accent.b - restInk.b) * root.naming,
    restInk.a + (1 - restInk.a) * root.naming)

  // Los renglones que se quedan. Sobre cristal van en tinta del panel a un
  // tercio: son relleno de ilustración, no texto que alguien vaya a leer.
  readonly property color fillerInk: Util.alpha(Color.popups.text, 0.32)

  // El halo de la familia. Va centrado en el dibujo, no en el recuadro:
  // cada composición ocupa un trozo distinto, y un halo centrado «bien»
  // asomaba por una esquina como si fuera una sombra mal puesta.
  readonly property point haloAt: root.kind === "link"
    ? Qt.point(Style.space(48), Style.space(40))
    : root.kind === "text" ? Qt.point(Style.space(53), Style.space(47))
    : Qt.point(Style.space(58), Style.space(42))

  // Ancho de sobra a propósito: las tarjetas son opacas por debajo —el
  // molde de su sombra lo es—, así que un halo del tamaño del dibujo
  // queda entero debajo y no se ve. Lo que tiene que verse es el borde,
  // rodeándolas.
  Halo {
    width: Style.space(150)
    height: width
    x: root.haloAt.x - width / 2
    y: root.haloAt.y - height / 2
    intensity: 0.16
    // El único empujón de escala del carrusel, cuando pasa el peine.
    scale: 1 + 0.11 * Math.sin(Math.PI * root.sweep)
    transformOrigin: Item.Center
  }

  // ---------- Un enlace: la cola de seguimiento se recorta ----------
  Item {
    anchors.fill: parent
    visible: root.kind === "link"

    // La página de la que se copia, detrás y a media luz.
    GlassSurface {
      shadowEnabled: false
      x: Style.space(14)
      y: Style.space(2) + Style.space(4) * root.settle
      width: Style.space(80)
      height: Style.space(48)
      material: "dimmed"

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
            color: root.fillerInk
          }
        }
      }
    }

    // La barra de dirección, delante: es donde vive lo que sobra. Es la
    // misma pieza de la bienvenida a un tercio de tamaño, y por eso se
    // reconoce sin rótulo.
    GlassSurface {
      shadowEnabled: false
      x: Style.space(1)
      y: Style.space(52) - Style.space(3) * root.settle
      width: Style.space(98)
      height: Style.space(30)
      material: "small"
      radius: height / 2
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
          color: Util.alpha(Color.popups.text, 0.45)
          anchors.verticalCenter: parent.verticalCenter
        }

        // El dominio, que se queda.
        Rectangle {
          width: Style.space(30)
          height: Style.space(6)
          radius: height / 2
          color: Util.alpha(Color.popups.text, 0.72)
          anchors.verticalCenter: parent.verticalCenter
        }

        // La cola: cuatro tramos, y son cuatro y no uno para que se lea
        // como una ristra de parámetros pegados detrás de la dirección.
        // **Van más gruesos que el dominio** —6 contra 6 de alto pero con
        // el acento encima— porque hay que saber qué mirar antes de que
        // empiece a irse.
        Row {
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(3) * (1 - root.squeeze)

          Repeater {
            model: 4
            delegate: Item {
              // La caja se estrecha, y eso es lo que hace que el resto
              // del renglón cierre el hueco. Sólo con el contenido
              // aplastado quedaría un agujero.
              width: Style.space(6) * (1 - root.squeeze)
              height: Style.space(6)
              clip: true

              Rectangle {
                width: Style.space(6)
                height: parent.height
                radius: height / 2
                color: root.markInk
                // Y el contenido se aplasta contra su borde izquierdo,
                // que es lo que se lee como «comprimirse». Sólo con la
                // caja, el tramo se leería recortado por la derecha.
                transformOrigin: Item.Left
                scale: 1 - root.squeeze
                opacity: 1 - 0.35 * root.squeeze
              }
            }
          }
        }
      }
    }
  }

  // ---------- Un párrafo: el invisible que se cuela entre renglones ----------
  Item {
    anchors.fill: parent
    visible: root.kind === "text"

    GlassSurface {
      shadowEnabled: false
      x: Style.space(9)
      y: Style.space(4) + Style.space(4) * root.settle
      width: Style.space(82)
      height: Style.space(88)
      clip: true

      Column {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: Style.space(12)
        spacing: Style.space(6)

        Rectangle { width: Style.space(54); height: Style.space(5); radius: height / 2; color: root.fillerInk }
        Rectangle { width: Style.space(44); height: Style.space(5); radius: height / 2; color: root.fillerInk }

        // El carácter que no se ve, dibujado como lo que es: una caja
        // vacía, sin glifo dentro. Es la única forma de que se vea irse
        // algo que por definición no se ve.
        //
        // Cierra por el eje vertical, y por eso los renglones de abajo
        // suben — que es justo lo que pasa en el texto de verdad.
        Item {
          width: Style.space(13)
          height: Style.space(13) * (1 - root.squeeze)
          clip: true

          Rectangle {
            width: Style.space(13)
            height: Style.space(13)
            radius: Style.space(3)
            color: "transparent"
            // Si el tramo es una caja vacía, el nombrado va en el borde
            // y no en el relleno: no hay relleno que teñir.
            border.color: root.markInk
            border.width: Math.max(1, Style.space(2))
            transformOrigin: Item.Top
            scale: 1 - 0.35 * root.squeeze
            opacity: 1 - 0.3 * root.squeeze
          }
        }

        Rectangle { width: Style.space(50); height: Style.space(5); radius: height / 2; color: root.fillerInk }
        Rectangle { width: Style.space(36); height: Style.space(5); radius: height / 2; color: root.fillerInk }
      }
    }
  }

  // ---------- Texto con formato: el formato se retira, la letra no ----------
  Item {
    anchors.fill: parent
    visible: root.kind === "rich"

    // Debajo, la de texto plano: la que se queda.
    GlassSurface {
      shadowEnabled: false
      x: Style.space(20)
      y: Style.space(6) + Style.space(4) * root.settle
      width: Style.space(76)
      height: Style.space(72)
      material: "dimmed"

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
            color: root.fillerInk
          }
        }
      }
    }

    // Y delante la copia con formato. **No se levanta y se va**: ni un
    // carácter cambia, así que lo que se retira son las marcas —el
    // titular en negrita y el filete de la cita—, no la hoja. Enseñar la
    // hoja entera yéndose decía que se pierde el texto, que es lo
    // contrario de lo que hace el producto.
    GlassSurface {
      shadowEnabled: false
      x: Style.space(4)
      y: Style.space(18) - Style.space(3) * root.settle
      width: Style.space(76)
      height: Style.space(72)
      clip: true

      Column {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: Style.space(12)
        spacing: Style.space(7)

        // La barra de titular: cierra por el eje vertical y el resto de la
        // hoja sube a ocupar su sitio.
        Item {
          width: Style.space(42)
          height: Style.space(9) * (1 - root.squeeze)
          clip: true

          Rectangle {
            width: Style.space(42)
            height: Style.space(9)
            radius: Style.space(2)
            color: root.markInk
            transformOrigin: Item.Top
            scale: 1 - 0.4 * root.squeeze
            opacity: 1 - 0.35 * root.squeeze
          }
        }

        Rectangle { width: Style.space(54); height: Style.space(5); radius: height / 2; color: root.fillerInk }

        Row {
          spacing: Style.space(6)

          // El filete de la cita.
          Item {
            width: Style.space(4)
            height: Style.space(17) * (1 - root.squeeze)
            clip: true

            Rectangle {
              width: Style.space(4)
              height: Style.space(17)
              radius: width / 2
              color: root.markInk
              transformOrigin: Item.Top
              scale: 1 - 0.4 * root.squeeze
              opacity: 1 - 0.35 * root.squeeze
            }
          }

          Column {
            spacing: Style.space(6)
            anchors.verticalCenter: parent.verticalCenter
            Rectangle { width: Style.space(42); height: Style.space(5); radius: height / 2; color: root.fillerInk }
            Rectangle { width: Style.space(32); height: Style.space(5); radius: height / 2; color: root.fillerInk }
          }
        }
      }
    }
  }
}
