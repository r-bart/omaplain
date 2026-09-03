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
  readonly property real sceneWidth: variant === "transform" ? Style.space(464) : Style.space(460)
  readonly property real sceneHeight: variant === "transform" ? Style.space(190) : Style.space(220)

  // Y cada una tiene su propio reloj. `progress` es siempre 0 → 1; lo que
  // cambia es cuánto dura y si vuelve a empezar.
  //
  // Va todo colgado de una sola propiedad animada a propósito: el guarda
  // `test_the_entrance_animates_nothing_that_costs_a_layout` vigila qué se
  // anima aquí, y meter un reloj por variante lo dejaría sin sentido.
  readonly property int runMs: variant === "protect" ? 15600
    : variant === "control" ? 10200 : 940
  readonly property int leadMs: variant === "transform" ? 250 : 0
  // La cinta cicla; nada más lo hace. La 0017 lo argumenta: el bucle **es**
  // lo que el paso 1 afirma, y tres tarjetas quietas decían «aquí hay tres
  // cosas», no «no se tocan».
  readonly property bool cycles: variant === "protect"

  readonly property real clockMs: progress * runMs

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
      PauseAnimation { duration: root.leadMs }
      NumberAnimation {
        target: root; property: "progress"; from: 0; to: 1
        duration: root.runMs; easing.type: Easing.Linear
        loops: root.cycles ? Animation.Infinite : 1
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
      width: root.variant === "transform" ? Style.space(460) : Style.space(420)
      height: width
      x: Style.space(230) - width / 2
      y: (root.variant === "transform" ? Style.space(92) : Style.space(100)) - height / 2
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

    // ---------- El control de seguridad: pasan y salen enteras ----------
    //
    // Tres tarjetas quietas y sin acento no decían «no se tocan»: decían
    // «aquí hay tres cosas». Lo que lo afirma es verlas entrar en el
    // control, perder el dibujo bajo el grano y **salir por el otro lado
    // exactamente como entraron**.
    //
    // El arco va DETRÁS de las tarjetas. En una cinta continua hay siempre
    // una encima de un montante, y lo tiene que resolver la oclusión: la
    // tarjeta tapa el montante, nunca al revés. Un filo de acento cruzando
    // una tarjeta se lee como un corte, que es exactamente lo contrario de
    // lo que dice esta pantalla.
    //
    // Fuera el rombo de acento con el ✓ gigante rotado 45°: tapaba la
    // palabra «Secrets», tocaba el borde derecho, y su ✓ era el mismo glifo
    // del sello — dos cosas distintas con la misma cara.
    Item {
      id: belt
      anchors.fill: parent
      visible: root.variant === "protect"

      readonly property real postLeft: Style.space(149)
      readonly property real postRight: Style.space(308)
      readonly property real postWidth: Math.max(1, Style.space(3))
      readonly property real archTop: Style.space(6)
      readonly property real archHeight: Style.space(184)
      readonly property real cardWidth: Style.space(130)
      readonly property real cardHeight: Style.space(152)
      readonly property real cardTop: Style.space(22)
      // El centro del hueco, que es donde el control mira.
      readonly property real gateX: (postLeft + postWidth + postRight) / 2
      readonly property real reach: Style.space(108)

      // El recorrido: de fuera del marco por la izquierda a fuera por la
      // derecha, y el paso entre una tarjeta y la siguiente sale de
      // repartir ese recorrido entre cuatro. `4 × 0.25 = 1` es lo que hace
      // que la cinta sea continua y sin huecos muertos.
      readonly property real travel: root.sceneWidth + Style.space(152)
      function laneX(u) { return -Style.space(142) + u * travel }

      // Lo único que reacciona es la luz del arco, y reacciona **a la
      // presencia, no al contenido**.
      readonly property real gateProximity: {
        if (!root.motionEnabled) return 0
        var best = 0
        for (var i = 0; i < 4; i++) {
          var u = (root.progress + i * 0.25) % 1
          var centre = belt.laneX(u) + belt.cardWidth / 2
          best = Math.max(best, Math.max(0, 1 - Math.abs(centre - belt.gateX) / belt.reach))
        }
        return best
      }

      // La luz del control. Va debajo del arco y de las tarjetas.
      Rectangle {
        x: belt.postLeft + belt.postWidth
        y: belt.archTop
        width: belt.postRight - belt.postLeft - belt.postWidth
        height: belt.archHeight
        color: Util.alpha(Color.accent, 0.06 + 0.34 * belt.gateProximity)
      }

      // El arco: dos montantes y un dintel, detrás de todo lo que pasa.
      Item {
        anchors.fill: parent
        opacity: 0.5 + 0.5 * belt.gateProximity

        Rectangle {
          x: belt.postLeft; y: belt.archTop
          width: belt.postWidth; height: belt.archHeight
          color: Color.accent
        }
        Rectangle {
          x: belt.postRight; y: belt.archTop
          width: belt.postWidth; height: belt.archHeight
          color: Color.accent
        }
        Rectangle {
          x: belt.postLeft; y: belt.archTop
          width: belt.postRight + belt.postWidth - belt.postLeft
          height: belt.postWidth
          color: Color.accent
        }
      }

      // La cinta: un riel que cruza el marco y un tramo de acento entre los
      // montantes, que es el trozo que el control vigila.
      Rectangle {
        x: 0
        y: Style.space(183)
        width: parent.width
        height: Math.max(1, Style.space(2))
        color: Util.alpha(Color.popups.text, 0.16)
      }
      Rectangle {
        x: belt.postLeft
        y: Style.space(182)
        width: belt.postRight + belt.postWidth - belt.postLeft
        height: Math.max(1, Style.space(4))
        color: Util.alpha(Color.accent, 0.55)
      }

      // Y la cola de copias. Cuatro tarjetas, tres tipos: una imagen, unos
      // archivos, un secreto y otra imagen.
      Repeater {
        model: [
          { kind: "image", label: "art.images", phase: 0.0 },
          { kind: "files", label: "art.files", phase: 0.25 },
          { kind: "secret", label: "art.secrets", phase: 0.5 },
          { kind: "image", label: "art.images", phase: 0.75 }
        ]

        delegate: Item {
          id: parcel
          required property var modelData

          readonly property real u: (root.progress + modelData.phase) % 1
          readonly property real centre: belt.laneX(parcel.u) + belt.cardWidth / 2
          readonly property real proximity: root.motionEnabled
            ? Math.max(0, 1 - Math.abs(parcel.centre - belt.gateX) / belt.reach) : 0
          readonly property real signal: Math.min(1, parcel.proximity * 1.35)

          x: belt.laneX(parcel.u)
          y: belt.cardTop
          width: belt.cardWidth
          height: belt.cardHeight

          // La opacidad va por **fracción de la tarjeta dentro del marco**,
          // no por una banda fija de píxeles: con una banda, una tarjeta a
          // medio entrar sigue a plena luz y el borde la corta en seco.
          opacity: Math.max(0, Math.min(1,
            (Math.min(root.sceneWidth, parcel.x + width) - Math.max(0, parcel.x)) / width))
          visible: opacity > 0.01

          // El temblor es de un píxel y medio y sale de un seno del reloj:
          // señal inestable, no tarjeta rota.
          transform: Translate {
            x: Math.sin(root.clockMs / 38) * Style.spaceReal(1.5) * parcel.signal
          }

          GlassSurface {
            id: parcelCard
            anchors.fill: parent
            clip: true

            // El dibujo de lo que hay dentro. Se apaga casi del todo al
            // pasar por el control: **la tarjeta no cambia**, es que el
            // control no la lee.
            Item {
              anchors.fill: parent
              opacity: 1 - 0.9 * parcel.signal

              Column {
                anchors.centerIn: parent
                spacing: Style.space(14)

                // Una imagen: marco, horizonte y sol.
                Item {
                  visible: parcel.modelData.kind === "image"
                  width: Style.space(70)
                  height: Style.space(54)
                  anchors.horizontalCenter: parent.horizontalCenter

                  Rectangle {
                    anchors.fill: parent
                    radius: Style.space(4)
                    color: "transparent"
                    border.width: Math.max(1, Style.space(2))
                    border.color: root.fillerInk
                  }
                  Rectangle {
                    width: Style.space(12); height: width; radius: width / 2
                    x: Style.space(12); y: Style.space(10)
                    color: root.fillerInk
                  }
                  Rectangle {
                    width: Style.space(46); height: Style.space(3); radius: height / 2
                    x: Style.space(12); y: Style.space(36)
                    color: root.fillerInk
                  }
                  Rectangle {
                    width: Style.space(28); height: Style.space(3); radius: height / 2
                    x: Style.space(12); y: Style.space(43)
                    color: root.fillerInk
                  }
                }

                // Unos archivos: dos hojas, una detrás de la otra.
                Item {
                  visible: parcel.modelData.kind === "files"
                  width: Style.space(70)
                  height: Style.space(54)
                  anchors.horizontalCenter: parent.horizontalCenter

                  Rectangle {
                    x: Style.space(14); y: 0
                    width: Style.space(46); height: Style.space(44)
                    radius: Style.space(3)
                    color: "transparent"
                    border.width: Math.max(1, Style.space(2))
                    border.color: Util.alpha(Color.popups.text, 0.2)
                  }
                  Rectangle {
                    x: 0; y: Style.space(10)
                    width: Style.space(46); height: Style.space(44)
                    radius: Style.space(3)
                    color: "transparent"
                    border.width: Math.max(1, Style.space(2))
                    border.color: root.fillerInk
                  }
                }

                // Un secreto: lo que se ve de una contraseña.
                Row {
                  visible: parcel.modelData.kind === "secret"
                  anchors.horizontalCenter: parent.horizontalCenter
                  spacing: Style.space(7)

                  Repeater {
                    model: 5
                    delegate: Rectangle {
                      required property int index
                      width: Style.space(9); height: width; radius: width / 2
                      color: root.fillerInk
                    }
                  }
                }

                Text {
                  // Decorativo: la raíz ya se ignora, pero el `ignored` no baja a los hijos.
                  Accessible.ignored: true
                  anchors.horizontalCenter: parent.horizontalCenter
                  text: Strings.t(parcel.modelData.label, root.lang)
                  color: Util.alpha(Color.popups.text, 0.6)
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  font.capitalization: Font.AllUppercase
                  font.letterSpacing: Style.spaceReal(0.9)
                }
              }
            }

            // Y el grano: lo único que el control llega a ver de ella.
            Grain {
              anchors.fill: parent
              intensity: parcel.signal
              motionEnabled: root.motionEnabled
            }
          }
        }
      }

      // El rótulo, colgando del arco. Un anillo y nada más: el ✓ que había
      // aquí era el mismo glifo del sello de la limpieza, y esto no es una
      // limpieza — es lo contrario.
      Row {
        anchors.horizontalCenter: parent.horizontalCenter
        y: belt.archTop + belt.archHeight + Style.space(8)
        spacing: Style.space(8)

        Rectangle {
          width: Style.space(14)
          height: width
          radius: width / 2
          color: "transparent"
          border.width: Math.max(1, Style.space(2))
          border.color: Color.accent
          anchors.verticalCenter: parent.verticalCenter
        }

        Text {
          // Decorativo: la raíz ya se ignora, pero el `ignored` no baja a los hijos.
          Accessible.ignored: true
          text: Strings.t("art.untouched", root.lang)
          color: Color.accent
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          font.bold: true
          font.capitalization: Font.AllUppercase
          font.letterSpacing: Style.spaceReal(0.9)
          anchors.verticalCenter: parent.verticalCenter
        }
      }
    }

    // ---------- Ya viene configurado, y tú decides ----------
    //
    // Los interruptores van **dentro** de una tarjeta de cristal, y eso
    // invierte una decisión anterior («fuera el recuadro, los interruptores
    // ya son la ilustración»). Con la familia de cristal puesta es lo
    // correcto: la caja ya no es un recuadro de más, es el mismo objeto que
    // en los dos pasos anteriores. Tres pasos, tres cosas distintas hechas
    // del mismo material.
    //
    // Las cinco filas son los **ajustes reales** con sus valores de
    // fábrica, así que esta ilustración no necesita ni una clave propia.
    Item {
      id: panelCard
      anchors.fill: parent
      visible: root.variant === "control"

      readonly property real padX: Style.space(20)
      readonly property real padY: Style.space(18)
      readonly property real veil: Style.space(22)
      readonly property real rowGap: Style.space(22)

      // El encendido escalonado: 420, 600, 780 y 960 ms, 300 cada uno. Es
      // la frase «ya viene configurado» dicha con el pulgar, no un
      // interruptor por decisión de nadie.
      function switchAt(i) {
        if (i >= 4) return 0
        return root.outCubic(root.clamp((root.clockMs - (420 + i * 180)) / 300))
      }

      // El recorrido de la lista: va, enseña lo que hay debajo, y **vuelve
      // a donde estaba**. Una sola ida y vuelta, por la 0017: el argumento
      // —«hay más»— se cumple entero con un viaje, y a partir del segundo
      // es decoración.
      //
      // Las paradas van en fracción del recorrido, no en píxeles. El
      // paquete de diseño escribe −52 y −104 y avisa de que «si cambias
      // alturas de fila o de tarjeta, recalcula esto o la última fila se
      // queda debajo del velo para siempre». No se puede recalcular a mano
      // lo que el usuario cambia en tiempo de ejecución, así que se deriva.
      readonly property var stops: [
        { at: 0, to: 0.0 },
        { at: 1400, to: 0.5 },
        { at: 4020, to: 1.0 },
        { at: 6640, to: 0.5 },
        { at: 9260, to: 0.0 }
      ]

      // Lo profundo que llega el recorrido: lo justo para que el fondo de
      // la última fila quede **por encima** del techo del velo.
      readonly property real deepest: Math.min(0,
        (card.height - panelCard.veil - Style.space(4)) - (panelCard.padY + rows.implicitHeight))

      readonly property real scrolled: {
        var ms = root.clockMs
        var plan = panelCard.stops
        for (var i = 1; i < plan.length; i++) {
          if (ms < plan[i].at) return plan[i - 1].to * panelCard.deepest
          if (ms < plan[i].at + 620) {
            var u = root.inOutCubic((ms - plan[i].at) / 620)
            return (plan[i - 1].to + (plan[i].to - plan[i - 1].to) * u) * panelCard.deepest
          }
        }
        return plan[plan.length - 1].to * panelCard.deepest
      }

      GlassSurface {
        id: card
        x: Style.space(70)
        y: Style.space(20)
        width: Style.space(320)
        // La tarjeta es más corta que su contenido a propósito: eso es lo
        // que el velo dice. Pero nunca tanto como para enseñar menos de
        // tres filas, o dejaría de leerse como una lista.
        height: Math.max(Style.space(148),
                         3 * (rows.rowHeight + panelCard.rowGap) + 2 * panelCard.padY)
        clip: true

        Column {
          id: rows
          x: panelCard.padX
          y: panelCard.padY + panelCard.scrolled
          width: card.width - 2 * panelCard.padX
          spacing: panelCard.rowGap

          // Mínimo, no fijo: con un tamaño de fuente mayor el rótulo
          // crecería por encima de una altura escrita a mano.
          readonly property real rowHeight: Style.space(24)

          Repeater {
            model: [
              { key: "settings.automatic", on: true },
              { key: "settings.formatting", on: true },
              { key: "settings.tracking", on: true },
              { key: "settings.invisible", on: true },
              // El quinto se queda apagado **y no se mueve nunca**. Es el
              // argumento de la pantalla —no viene nada impuesto— y
              // animarlo diría lo contrario.
              { key: "settings.quotes", on: false }
            ]

            delegate: Item {
              id: settingRow
              required property int index
              required property var modelData

              width: rows.width
              height: Math.max(rows.rowHeight, label.implicitHeight, track.height)

              readonly property real lit: settingRow.modelData.on
                ? panelCard.switchAt(settingRow.index) : 0

              Text {
                id: label
                // Decorativo: la raíz ya se ignora, pero el `ignored` no baja a los hijos.
                Accessible.ignored: true
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - track.width - Style.space(12)
                text: Strings.t(settingRow.modelData.key, root.lang)
                color: Util.alpha(Color.popups.text, 0.68)
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                elide: Text.ElideRight
              }

              Rectangle {
                id: track
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: Style.space(34)
                height: Style.space(18)
                radius: height / 2
                color: Qt.rgba(
                  Util.alpha(Color.popups.text, 0.16).r + (Color.accent.r - Util.alpha(Color.popups.text, 0.16).r) * settingRow.lit,
                  Util.alpha(Color.popups.text, 0.16).g + (Color.accent.g - Util.alpha(Color.popups.text, 0.16).g) * settingRow.lit,
                  Util.alpha(Color.popups.text, 0.16).b + (Color.accent.b - Util.alpha(Color.popups.text, 0.16).b) * settingRow.lit,
                  0.16 + 0.84 * settingRow.lit)

                Rectangle {
                  width: Style.space(14)
                  height: width
                  radius: width / 2
                  anchors.verticalCenter: parent.verticalCenter
                  x: Style.space(2) + (parent.width - width - 2 * Style.space(2)) * settingRow.lit
                  color: Qt.rgba(
                    Color.popups.text.r + (Color.background.r - Color.popups.text.r) * settingRow.lit,
                    Color.popups.text.g + (Color.background.g - Color.popups.text.g) * settingRow.lit,
                    Color.popups.text.b + (Color.background.b - Color.popups.text.b) * settingRow.lit,
                    0.55 + 0.45 * settingRow.lit)
                }
              }
            }
          }
        }

        // El velo: veintidós píxeles al pie que dicen que hay más debajo.
        Rectangle {
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          height: panelCard.veil

          gradient: Gradient {
            GradientStop { position: 0.0; color: Util.alpha(Color.popups.background, 0) }
            GradientStop { position: 1.0; color: Util.alpha(Color.popups.background, 0.78) }
          }
        }
      }

      // Y el pie. Fuera el ✓ flotando en la esquina: pisaba el recuadro sin
      // decir a qué se refería, y era la tercera aparición del mismo glifo
      // en tres variantes.
      Text {
        // Decorativo: la raíz ya se ignora, pero el `ignored` no baja a los hijos.
        Accessible.ignored: true
        anchors.horizontalCenter: parent.horizontalCenter
        y: card.y + card.height + Style.space(14)
        text: Strings.t("art.decide", root.lang)
        color: Color.accent
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        font.bold: true
        font.capitalization: Font.AllUppercase
        font.letterSpacing: Style.spaceReal(0.9)
      }
    }
  }
}
