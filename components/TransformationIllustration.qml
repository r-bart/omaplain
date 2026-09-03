import QtQuick
import qs.Commons
import qs.Ui
import "Strings.js" as Strings

Item {
  id: root

  // Idioma heredado del panel: en o es.
  property string lang: "en"

  property string variant: "transform"

  // Un solo momento orquestado, no cinco efectos sueltos. Es la promesa
  // del producto contada en movimiento.
  //
  // Con `motionEnabled` en falso todo se pinta ya en su estado final, sin
  // recorrido, y ninguna variante pierde información al pararse.
  property bool motionEnabled: true

  // 0 = recién llegado, 1 = transformación consumada.
  property real progress: motionEnabled ? 0 : 1

  readonly property real entered: motionEnabled ? enterFactor : 1
  property real enterFactor: 0

  // El motor de compresión (`ANIMACIONES.md` §2), con sus dos tiempos
  // dentro de un solo recorrido lineal de 940 ms.
  //
  // Va así y no con dos animaciones porque las curvas son distintas
  // —`OutCubic` para nombrar, `InOutCubic` para cerrar— y encadenarlas
  // como propiedades separadas metería dos nombres más en el guarda que
  // vigila qué se anima aquí. Un solo `progress` lineal, y las curvas
  // aplicadas donde se leen.
  function outCubic(t) { var k = 1 - t; return 1 - k * k * k }
  function inOutCubic(t) {
    return t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2
  }
  function clamp(t) { return Math.max(0, Math.min(1, t)) }

  // Nombrar: 0 → 340 ms de los 940. El tramo pasa de la tinta de reposo al
  // acento **sin moverse**. Es lo que convierte el gesto en explicación: se
  // ve *qué* se va, y luego se va.
  readonly property real naming: outCubic(clamp(progress / 0.362))
  // Comprimir: 420 → 940 ms. Empieza después de que el nombrado termine.
  readonly property real squeeze: inOutCubic(clamp((progress - 0.447) / 0.553))

  readonly property color restInk: Util.alpha(Color.popups.text, 0.45)
  readonly property color markInk: Qt.rgba(
    restInk.r + (Color.accent.r - restInk.r) * naming,
    restInk.g + (Color.accent.g - restInk.g) * naming,
    restInk.b + (Color.accent.b - restInk.b) * naming,
    restInk.a + (1 - restInk.a) * naming)
  readonly property color fillerInk: Util.alpha(Color.popups.text, 0.32)

  // Cada variante ocupa el marco que le da su pantalla. La bienvenida
  // reparte 464 × 190; el tour, 460 × 220.
  readonly property real sceneWidth: variant === "transform" ? Style.space(464) : Style.space(248)
  readonly property real sceneHeight: variant === "transform" ? Style.space(190) : Style.space(168)

  function play() {
    if (!motionEnabled) { progress = 1; enterFactor = 1; return }
    enterFactor = 0
    progress = 0
    sequence.restart()
  }

  Component.onCompleted: play()
  onMotionEnabledChanged: play()
  onVisibleChanged: if (visible) play()
  // El tour cambia la variante con la ilustración ya visible: sin esto la
  // transformación corría en el paso 0, con su capa oculta, y el paso que
  // de verdad la enseña llegaba con el recorrido ya consumido.
  onVariantChanged: play()

  ParallelAnimation {
    id: sequence
    // Entrada: nunca desde scale(0); la escena siempre tiene forma.
    NumberAnimation {
      target: root; property: "enterFactor"; from: 0; to: 1
      duration: 260; easing.type: Easing.OutCubic
    }
    // Y la transformación, que es lo único que de verdad cuenta algo. Su
    // t₀ son los 250 ms del paquete, contados desde que entra la pantalla
    // y no desde que la entrada termina: se solapan a propósito, para que
    // el nombrado ya esté ocurriendo cuando el ojo llega.
    SequentialAnimation {
      PauseAnimation { duration: 250 }
      NumberAnimation {
        target: root; property: "progress"; from: 0; to: 1
        duration: 940; easing.type: Easing.Linear
      }
    }
  }

  implicitWidth: root.sceneWidth
  implicitHeight: root.sceneHeight
  Accessible.ignored: true

  Item {
    id: scene
    width: root.sceneWidth
    height: root.sceneHeight
    anchors.centerIn: parent
    scale: Math.min(1, root.width / width, root.height / height) * (0.965 + 0.035 * root.entered)
    opacity: root.entered
    transformOrigin: Item.Center

    // El halo de la familia, centrado en el dibujo y no en el recuadro:
    // cada variante ocupa un trozo distinto del marco, y uno centrado
    // «bien» asoma por una esquina como una sombra mal puesta.
    Halo {
      width: root.variant === "transform" ? Style.space(460) : Style.space(200)
      height: width
      x: (root.variant === "transform" ? Style.space(232) : Style.space(124)) - width / 2
      y: (root.variant === "transform" ? Style.space(92) : Style.space(84)) - height / 2
      intensity: 0.15
    }

    // ---------- La bienvenida: una copia de verdad, perdiendo lo que sobra ----------
    //
    // Dos tarjetas rectas y alineadas: una barra de dirección encima y su
    // página debajo. Se leen como **un objeto** —un navegador—, no como
    // dos dibujos cerca.
    //
    // Fuera los dos naipes rotados y la flecha del medio. Eran la manera
    // de contar «antes → después» en un dibujo quieto; con movimiento
    // sobran, porque la transformación *ocurre*. Y dos naipes de 116 × 122
    // en 248 px de ancho no dejaban respirar nada.
    //
    // Fuera también el sello ✓: la prueba es el hueco cerrado, y un visto
    // encima repetía en un glifo lo que la propia línea acaba de
    // demostrar.
    Item {
      anchors.fill: parent
      visible: root.variant === "transform"

      // La barra de dirección. Los tramos que sobran van **más gruesos**
      // que el texto que se queda —12 contra 5— para que se sepa qué mirar
      // antes de que empiecen a irse.
      GlassSurface {
        id: addressBar
        x: Style.space(80)
        y: Style.space(14)
        width: Style.space(304)
        // Mínimo, no fijo: el contenido manda si crece con la escala.
        height: Math.max(Style.space(42), barContent.implicitHeight + Style.space(16))
        material: "small"
        radius: height / 2
        clip: true

        Row {
          id: barContent
          anchors.verticalCenter: parent.verticalCenter
          anchors.left: parent.left
          anchors.leftMargin: Style.space(18)
          spacing: Style.space(10)

          Rectangle {
            width: Style.space(10)
            height: width
            radius: width / 2
            color: Util.alpha(Color.popups.text, 0.45)
            anchors.verticalCenter: parent.verticalCenter
          }

          // El dominio: lo que se queda.
          Rectangle {
            width: Style.space(96)
            height: Style.space(5)
            radius: height / 2
            color: Util.alpha(Color.popups.text, 0.72)
            anchors.verticalCenter: parent.verticalCenter
          }

          // Y la cola de seguimiento: cuatro parámetros pegados detrás.
          Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(4) * (1 - root.squeeze)

            Repeater {
              model: 4
              delegate: Item {
                required property int index
                // La caja se estrecha, y eso es lo que hace que el renglón
                // cierre el hueco. Sólo con el contenido aplastado
                // quedaría un agujero; sólo con la caja, el tramo se
                // leería recortado por la derecha.
                width: Style.space(14) * (1 - root.squeeze)
                height: Style.space(12)
                clip: true

                Rectangle {
                  width: Style.space(14)
                  height: parent.height
                  radius: Style.space(2)
                  color: root.markInk
                  transformOrigin: Item.Left
                  scale: 1 - root.squeeze
                  opacity: 1 - 0.35 * root.squeeze
                }
              }
            }
          }
        }
      }

      // La página. Nueve píxeles de hueco contra la barra: lo justo para
      // que sean dos piezas del mismo objeto y no dos objetos.
      GlassSurface {
        id: page
        x: addressBar.x
        y: addressBar.y + addressBar.height + Style.space(9)
        width: addressBar.width
        height: Math.max(Style.space(104), pageContent.implicitHeight + Style.space(36))
        clip: true

        Column {
          id: pageContent
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.margins: Style.space(18)
          spacing: Style.space(10)

          Rectangle {
            width: Style.space(240); height: Style.space(5)
            radius: height / 2; color: root.fillerInk
          }

          // El renglón con tres tramos que sobran.
          Row {
            spacing: Style.space(8)

            Rectangle {
              width: Style.space(60); height: Style.space(5)
              radius: height / 2; color: root.fillerInk
              anchors.verticalCenter: parent.verticalCenter
            }

            Row {
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(5) * (1 - root.squeeze)

              Repeater {
                model: 3
                delegate: Item {
                  required property int index
                  width: Style.space(34) * (1 - root.squeeze)
                  height: Style.space(11)
                  clip: true

                  Rectangle {
                    width: Style.space(34)
                    height: parent.height
                    radius: Style.space(2)
                    color: root.markInk
                    transformOrigin: Item.Left
                    scale: 1 - root.squeeze
                    opacity: 1 - 0.35 * root.squeeze
                  }
                }
              }
            }

            Rectangle {
              width: Style.space(46); height: Style.space(5)
              radius: height / 2; color: root.fillerInk
              anchors.verticalCenter: parent.verticalCenter
            }
          }

          // Y el renglón con el carácter que no se ve, dibujado como lo
          // que es: una caja vacía, sin glifo dentro. Es la única forma de
          // que se vea irse algo que por definición no se ve.
          Row {
            spacing: Style.space(8)

            Rectangle {
              width: Style.space(84); height: Style.space(5)
              radius: height / 2; color: root.fillerInk
              anchors.verticalCenter: parent.verticalCenter
            }

            Item {
              width: Style.space(13) * (1 - root.squeeze)
              height: Style.space(13)
              anchors.verticalCenter: parent.verticalCenter
              clip: true

              Rectangle {
                width: Style.space(13)
                height: parent.height
                radius: Style.space(3)
                color: "transparent"
                // Si el tramo es una caja vacía, el nombrado va en el
                // borde y no en el relleno: no hay relleno que teñir.
                border.color: root.markInk
                border.width: Math.max(1, Style.space(2))
                transformOrigin: Item.Left
                scale: 1 - root.squeeze
                opacity: 1 - 0.3 * root.squeeze
              }
            }

            Rectangle {
              width: Style.space(52); height: Style.space(5)
              radius: height / 2; color: root.fillerInk
              anchors.verticalCenter: parent.verticalCenter
            }
          }

          Rectangle {
            width: Style.space(180); height: Style.space(5)
            radius: height / 2; color: root.fillerInk
          }
        }
      }
    }

    Item {
      anchors.fill: parent
      visible: root.variant === "protect"

      BorderSurface {
        width: Style.space(184)
        height: Style.space(116)
        anchors.centerIn: parent
        radius: Style.cornerRadius
        color: Style.normalFillFor(Color.popups.text, Color.accent)
        borderSpec: Border.controlSpec("normal", Color.popups.text, Color.accent)

        Column {
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          anchors.leftMargin: Style.space(16)
          spacing: Style.space(9)

          Repeater {
            model: [Strings.t("art.images", root.lang), Strings.t("art.files", root.lang), Strings.t("art.secrets", root.lang)]
            delegate: Row {
              required property string modelData
              spacing: Style.space(8)

              Rectangle {
                width: Style.space(8)
                height: width
                radius: width / 2
                color: Color.muted
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                // Decorativo: la raíz ya se ignora, pero el `ignored` no baja a los hijos.
                Accessible.ignored: true
                text: modelData
                color: Color.popups.text
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
              }
            }
          }
        }
      }

      Rectangle {
        width: Style.space(74)
        height: width
        radius: Style.space(18)
        x: Style.space(142)
        y: Style.space(47)
        rotation: 45
        color: Color.accent

        Text {
          // Decorativo: la raíz ya se ignora, pero el `ignored` no baja a los hijos.
          Accessible.ignored: true
          anchors.centerIn: parent
          rotation: -45
          text: "✓"
          color: Color.background
          font.family: Style.font.family
          font.pixelSize: Style.font.display
          font.bold: true
        }
      }
    }

    Item {
      anchors.fill: parent
      visible: root.variant === "control"

      BorderSurface {
        width: Style.space(200)
        height: Style.space(126)
        anchors.centerIn: parent
        radius: Style.cornerRadius
        color: Style.normalFillFor(Color.popups.text, Color.accent)
        borderSpec: Border.controlSpec("normal", Color.popups.text, Color.accent)

        Column {
          anchors.fill: parent
          anchors.margins: Style.space(14)
          spacing: Style.space(9)

          Repeater {
            model: [
              { label: Strings.t("art.automatic", root.lang), active: true },
              { label: Strings.t("art.cleaning", root.lang), active: true },
              { label: Strings.t("art.exclude", root.lang), active: false }
            ]
            delegate: Row {
              required property var modelData
              width: parent.width
              spacing: Style.space(8)

              Text {
                // Decorativo: la raíz ya se ignora, pero el `ignored` no baja a los hijos.
                Accessible.ignored: true
                width: parent.width - Style.space(42)
                text: modelData.label
                color: Color.popups.text
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
              }

              Rectangle {
                width: Style.space(28)
                height: Style.space(15)
                radius: height / 2
                color: modelData.active ? Color.accent : Util.alpha(Color.popups.text, 0.18)

                Rectangle {
                  width: Style.space(11)
                  height: width
                  radius: width / 2
                  anchors.verticalCenter: parent.verticalCenter
                  x: modelData.active ? parent.width - width - Style.space(2) : Style.space(2)
                  color: modelData.active ? Color.background : Color.popups.text
                }
              }
            }
          }
        }
      }

      Rectangle {
        width: Style.space(34)
        height: width
        radius: width / 2
        x: Style.space(190)
        y: Style.space(16)
        color: Color.accent

        Text {
          // Decorativo: la raíz ya se ignora, pero el `ignored` no baja a los hijos.
          Accessible.ignored: true
          anchors.centerIn: parent
          text: "✓"
          color: Color.background
          font.family: Style.font.family
          font.pixelSize: Style.font.title
          font.bold: true
        }
      }
    }

  }
}
