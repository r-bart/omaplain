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

  // El ciclo de la bienvenida, en milisegundos desde t₀:
  //
  //     0 →  340   nombrar     el tramo pasa al acento **sin moverse**
  //   420 →  940   comprimir   se cierra y el renglón cierra el hueco
  //   940 → 2900   quieto      la copia limpia, para que se lea
  //  2900 → 3260   la siguiente copia llega, con lo que sobra otra vez
  //  3260 → 4200   quieto      y vuelve a empezar
  //
  // Nombrar antes de retirar es lo que convierte el gesto en explicación:
  // se ve *qué* se va, y luego se va.
  //
  // **La vuelta no es un deshacer.** El tramo reaparece en la tinta de
  // reposo, no en acento, y en 360 ms contra los 520 del cierre: no se lee
  // como que la limpieza se rebobina, sino como que llega otra copia. Que
  // es lo que dice la pantalla — «convierte las copias que puede».
  readonly property int cycleReturn: 2900
  readonly property int cycleReturnMs: 360

  readonly property real phaseIn: root.variant === "transform"
    ? 1 - outCubic(clamp((clockMs - cycleReturn) / cycleReturnMs)) : 1

  readonly property real naming: outCubic(clamp(clockMs / 340)) * phaseIn
  readonly property real squeeze: root.variant === "transform"
    ? inOutCubic(clamp((clockMs - 420) / 520)) * phaseIn
    : inOutCubic(clamp((clockMs - 420) / 520))

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
  readonly property real sceneHeight: variant === "transform" ? Style.space(190)
    : variant === "unread" ? Style.space(160) : Style.space(220)

  // Y cada una tiene su propio reloj. `progress` es siempre 0 → 1; lo que
  // cambia es cuánto dura y si vuelve a empezar.
  //
  // Va todo colgado de una sola propiedad animada a propósito: el guarda
  // `test_the_entrance_animates_nothing_that_costs_a_layout` vigila qué se
  // anima aquí, y meter un reloj por variante lo dejaría sin sentido.
  readonly property int runMs: variant === "protect" ? 10800
    : variant === "control" ? 7480 : variant === "transform" ? 4200 : 940
  readonly property int leadMs: variant === "transform" ? 250 : 0

  // **Ciclan las tres del onboarding, y ninguna del panel de cada día.**
  // Es la regla de la 0017 tras verlas correr: una ilustración que se
  // reproduce una vez se queda muerta el resto del tiempo que la pantalla
  // está delante, y estas pantallas se leen despacio. La que no cicla es
  // `unread`, que vive en el panel frecuente y va quieta por la 0007.
  readonly property bool cycles: variant !== "unread"

  readonly property real clockMs: progress * runMs

  // Cuántas vueltas lleva dadas. Los interruptores del paso 3 se encienden
  // en la primera y se quedan: «ya viene configurado» es una frase que se
  // dice una vez, y apagarlos para volver a encenderlos diría que alguien
  // los está tocando. Lo que sí cicla ahí es el recorrido de la lista.
  property int laps: 0
  property real lastProgress: 0
  onProgressChanged: {
    if (progress < lastProgress) laps += 1
    lastProgress = progress
  }

  // De qué es la copia que se está enseñando. La cinta del tour trae los
  // tres tipos que el helper no toca; el bypass trae el que hay ahora
  // mismo en el portapapeles, traducido del motivo del rechazo.
  //
  // Cualquier motivo que no sea de los tres cae en la hoja de texto, que
  // no afirma nada: puede ser un texto demasiado grande, unos bytes que no
  // se dejan descodificar o una aplicación de la lista. El dibujo no puede
  // decir más de lo que se sabe.
  property string subject: "text"

  readonly property string subjectGlyph: ["image", "files", "secret"].indexOf(subject) !== -1
    ? subject : (subject === "sensitive" ? "secret" : "text")

  // El dibujo de una copia. En línea y no repetido: lo montan la cinta del
  // paso 1 y la tarjeta del bypass, y dos copias del mismo dibujo acaban
  // siendo dos dibujos distintos.
  component CopyGlyph: Item {
    id: glyph
    property string kind: "image"
    property color ink: "white"

    implicitWidth: Style.space(70)
    implicitHeight: Style.space(54)
    Accessible.ignored: true

    // Una imagen: marco, sol y horizonte.
    Item {
      anchors.fill: parent
      visible: glyph.kind === "image"

      Rectangle {
        anchors.fill: parent
        radius: Style.space(4)
        color: "transparent"
        border.width: Math.max(1, Style.space(2))
        border.color: glyph.ink
      }
      Rectangle {
        width: Style.space(12); height: width; radius: width / 2
        x: Style.space(12); y: Style.space(10)
        color: glyph.ink
      }
      Rectangle {
        width: Style.space(46); height: Style.space(3); radius: height / 2
        x: Style.space(12); y: Style.space(36)
        color: glyph.ink
      }
      Rectangle {
        width: Style.space(28); height: Style.space(3); radius: height / 2
        x: Style.space(12); y: Style.space(43)
        color: glyph.ink
      }
    }

    // Unos archivos: dos hojas, una detrás de la otra.
    Item {
      anchors.fill: parent
      visible: glyph.kind === "files"

      Rectangle {
        x: Style.space(14); y: 0
        width: Style.space(46); height: Style.space(44)
        radius: Style.space(3)
        color: "transparent"
        border.width: Math.max(1, Style.space(2))
        border.color: Util.alpha(glyph.ink, 0.55)
      }
      Rectangle {
        x: 0; y: Style.space(10)
        width: Style.space(46); height: Style.space(44)
        radius: Style.space(3)
        color: "transparent"
        border.width: Math.max(1, Style.space(2))
        border.color: glyph.ink
      }
    }

    // Un secreto: lo que se ve de una contraseña, que es lo que se ve de
    // una contraseña.
    Row {
      anchors.centerIn: parent
      visible: glyph.kind === "secret"
      spacing: Style.space(7)

      Repeater {
        model: 5
        delegate: Rectangle {
          width: Style.space(9); height: width; radius: width / 2
          color: glyph.ink
        }
      }
    }

    // Y una hoja de texto, para todo lo demás.
    Column {
      anchors.centerIn: parent
      visible: glyph.kind === "text"
      spacing: Style.space(7)

      Repeater {
        model: [0.95, 0.72, 0.86, 0.5]
        delegate: Rectangle {
          required property real modelData
          width: Style.space(62) * modelData
          height: Style.space(4)
          radius: height / 2
          color: glyph.ink
        }
      }
    }
  }

  function play() {
    laps = 0
    lastProgress = 0
    if (!motionEnabled) { progress = 1; enterFactor = 1; return }
    enterFactor = 0
    progress = 0
    sequence.restart()
  }

  Component.onCompleted: play()
  onMotionEnabledChanged: play()
  // **Y al ocultarse, se para.** El recorrido de la cinta es infinito: sin
  // esto seguía corriendo detrás del paso 2 del tour, de la página de
  // ajustes y del panel cerrado, evaluando los bindings de las cuatro
  // tarjetas en cada cuadro para nadie. Es el mismo fallo que el vaho y el
  // carrusel corriendo dentro de una ventana cerrada, y se arregla igual.
  onVisibleChanged: {
    if (visible) play()
    else sequence.stop()
  }
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
      x: (root.variant === "unread" ? Style.space(112) : Style.space(230)) - width / 2
      y: (root.variant === "transform" ? Style.space(92)
          : root.variant === "unread" ? Style.space(80) : Style.space(100)) - height / 2
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
      id: welcome
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
        //
        // **El mínimo vive en el contenido, no en la caja**, y eso no es
        // una preferencia de estilo: es lo que rompe un ciclo de trazado.
        // Escrito como `Math.max(space(42), barContent.implicitHeight + …)`
        // con el contenido centrado contra este mismo alto, el alto sale
        // del hijo y el hijo se coloca contra el alto. Qt no converge y se
        // queda girando en el hilo de interfaz — con la compresión de una
        // sola pasada duraba 940 ms y no se notaba; ciclando, cuelga el
        // shell entero sin dar un solo error.
        //
        // Así la caja sale del contenido y el contenido no mira hacia
        // arriba para colocarse.
        height: barContent.height + Style.space(16)
        material: "small"
        radius: height / 2
        clip: true

        Row {
          id: barContent
          height: Math.max(Style.space(26), implicitHeight)
          anchors.top: parent.top
          anchors.topMargin: Style.space(8)
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

      // Los dos renglones que llevan tramos son **más altos** que los de
      // texto corrido, y su alto va escrito y no medido.
      //
      // Medido —dejándoselo al positionador— el renglón encoge en cuanto el
      // tramo llega a ancho cero: un positionador de QML no cuenta a un
      // hijo sin ancho, así que su alto deja de mandar y las cuatro líneas
      // se juntan verticalmente al limpiarse. La limpieza retira lo que
      // sobra; no recoloca lo que se queda.
      readonly property real spareRowHeight: Style.space(11)
      readonly property real voidRowHeight: Style.space(13)

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
            height: welcome.spareRowHeight

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
                  width: Style.space(34) * (1 - root.squeeze)
                  height: welcome.spareRowHeight
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
            height: welcome.voidRowHeight

            Rectangle {
              width: Style.space(84); height: Style.space(5)
              radius: height / 2; color: root.fillerInk
              anchors.verticalCenter: parent.verticalCenter
            }

            Item {
              width: Style.space(13) * (1 - root.squeeze)
              height: welcome.voidRowHeight
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
      readonly property real postWidth: Math.max(1, Style.space(2))
      readonly property real archTop: Style.space(6)
      // Dónde apoya la cinta. El arco **termina justo ahí**, derivado y no
      // escrito: con un alto propio, los montantes sobresalían cuatro
      // píxeles por debajo del riel y quedaban dos patitas colgando.
      readonly property real beltY: Style.space(182)
      readonly property real beltWidth: Math.max(1, Style.space(4))
      readonly property real archHeight: beltY - archTop
      readonly property real cardWidth: Style.space(130)
      readonly property real cardHeight: Style.space(152)
      readonly property real cardTop: Style.space(22)
      // El centro del hueco, que es donde el control mira.
      readonly property real gateX: (postLeft + postWidth + postRight) / 2
      readonly property real reach: Style.space(108)

      // El recorrido: de fuera del marco por la izquierda a fuera por la
      // derecha, y el paso entre una tarjeta y la siguiente sale de
      // repartir ese recorrido entre cuatro. `4 × 0.25 = 1` es lo que hace
      // que la cinta no tenga huecos muertos.
      readonly property real travel: root.sceneWidth + Style.space(152)
      function laneX(u) { return -Style.space(142) + u * travel }

      // **La cinta avanza a tirones, no de corrido.** Arranca, frena, y se
      // queda quieta con una tarjeta centrada bajo el arco mientras la
      // miran; entonces arranca otra vez con la siguiente.
      //
      // Es la diferencia entre contar un tránsito y contar una decisión.
      // De corrido, las tarjetas sólo pasaban; parándose bajo el arco se
      // ve que a cada una **se la mira y se la deja pasar**, que es
      // exactamente lo que hace el helper con la oferta del portapapeles.
      // Y es además lo que hace un escáner de verdad.
      readonly property int stops: 4
      // Dos tercios quieta, un tercio moviéndose. Al revés se lee como una
      // cinta que titubea en vez de como una que se para a mirar.
      readonly property real moveShare: 0.34

      // Dónde tiene que quedarse parada. **Se deriva**: es la posición en
      // la que el centro de una tarjeta cae en el centro del hueco. Escrita
      // a mano dejaría la tarjeta descentrada en cuanto cambiara el ancho
      // del arco, de la tarjeta o de la escala.
      readonly property real restU:
        (belt.gateX - belt.cardWidth / 2 + Style.space(142)) / belt.travel

      readonly property real pos: {
        var s = root.progress * belt.stops
        var k = Math.floor(s)
        var f = s - k
        var dwell = 1 - belt.moveShare
        var e = f < dwell ? 0 : root.inOutCubic((f - dwell) / belt.moveShare)
        return (belt.restU + (k + e) / belt.stops) % 1
      }

      // Lo único que reacciona es la luz del arco, y reacciona **a la
      // presencia, no al contenido**.
      readonly property real gateProximity: {
        if (!root.motionEnabled) return 0
        var best = 0
        for (var i = 0; i < 4; i++) {
          var u = (belt.pos + i * 0.25) % 1
          var centre = belt.laneX(u) + belt.cardWidth / 2
          best = Math.max(best, Math.max(0, 1 - Math.abs(centre - belt.gateX) / belt.reach))
        }
        return best
      }

      // **El arco es un marco, no un panel.** El paquete de diseño pinta el
      // hueco con una luz de acento que sube con la presencia, y a tamaño
      // real eso no se lee como un arco de control: se lee como un rectángulo
      // amarillo detrás de la tarjeta. Un arco de aeropuerto es dos montantes
      // y un dintel, y por dentro no hay nada — se ve lo que hay al otro
      // lado.
      //
      // La reacción a la presencia se queda, pero en el propio marco: es lo
      // que ya hacía además de la luz, y ahora es lo único que hace.
      // **Un marco tenue.** A plena luz el arco era lo más brillante de la
      // pantalla y le robaba el sitio a la tarjeta, que es el sujeto. Sigue
      // reaccionando a la presencia; lo que baja es de dónde parte y hasta
      // dónde llega.
      Item {
        anchors.fill: parent
        opacity: 0.3 + 0.4 * belt.gateProximity

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
        y: belt.beltY + Math.max(1, Style.space(1))
        width: parent.width
        height: Math.max(1, Style.space(2))
        color: Util.alpha(Color.popups.text, 0.16)
      }
      Rectangle {
        x: belt.postLeft
        y: belt.beltY
        width: belt.postRight + belt.postWidth - belt.postLeft
        height: belt.beltWidth
        color: Util.alpha(Color.accent, 0.45)
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

          readonly property real u: (belt.pos + modelData.phase) % 1
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

          // **Sin temblor.** El paquete de diseño mueve la tarjeta píxel y
          // medio con un seno del reloj, para que se lea como señal
          // inestable. Con la cinta de corrido colaba; parada bajo el arco
          // no se lee como señal, se lee como una imagen que vibra. Lo que
          // dice que ahí no se lee nada es el grano, y ése se queda.

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

                CopyGlyph {
                  anchors.horizontalCenter: parent.horizontalCenter
                  kind: parcel.modelData.kind
                  ink: root.fillerInk
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
              radius: parcelCard.radius
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
        if (root.laps > 0) return 1
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
      // Los reposos son de 1 200 ms y no de los 2 000 del paquete de
      // diseño. Con 2 000 la vuelta entera se iba a 10,2 s, y a esa
      // velocidad el recorrido no se lee como algo que cicla: se lee como
      // una lista quieta que de vez en cuando se mueve sola. Mil
      // doscientos siguen dando tiempo de sobra a leer las tres filas que
      // hay a la vista, que es para lo que existía el reposo.
      //
      // El primero es más largo porque no es un reposo: es la espera a que
      // los cuatro interruptores terminen de encenderse, a los 1 260 ms.
      readonly property var stops: [
        { at: 0, to: 0.0 },
        { at: 1400, to: 0.5 },
        { at: 3220, to: 1.0 },
        { at: 5040, to: 0.5 },
        { at: 6860, to: 0.0 }
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
        // que el velo dice, y de ahí salen las dos filas y media que se
        // ven a escala normal.
        //
        // El mínimo es un suelo para una fuente grande —dos filas enteras,
        // o deja de leerse como una lista— y **no** una medida que mande.
        // Escrito con tres filas y sus tres huecos subía la tarjeta de 148
        // a 174 a escala normal, y ahí el recorrido se quedaba corto: la
        // lista apenas se movía porque casi no le sobraba contenido.
        height: Math.max(Style.space(148),
                         2 * rows.rowHeight + panelCard.rowGap + 2 * panelCard.padY)
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
    // ---------- El bypass: una sola tarjeta, y nadie la ha leído ----------
    //
    // Fuera el inventario de tres filas. Es del tour, y aquí sobraba dos
    // tercios: esta pantalla habla de **una** cosa concreta, la que tienes
    // en el portapapeles ahora. Y «Untouched» colgando debajo de la lista
    // se leía como una cuarta fila del inventario; ahora rotula la tarjeta.
    //
    // Variante propia y no la cinta del tour ([`0018`]): una cinta ciclando
    // en la pantalla más vista es justo lo que la 0007 no quiere. Aquí el
    // grano está quieto, y es lo único que OmaPlain llega a ver de esta
    // copia — miró el tipo de la oferta y se plantó.
    Item {
      anchors.fill: parent
      visible: root.variant === "unread"

      GlassSurface {
        id: unreadCard
        x: Style.space(4)
        y: Style.space(7)
        width: Style.space(206)
        height: Style.space(146)
        clip: true

        // El dibujo pesa más aquí que en la cinta, y va más grande.
        //
        // A la tinta de relleno del tour —0,32— quedaba justo al mismo peso
        // que el grano que lo cubre, así que no se leía: la tarjeta era un
        // rectángulo de ruido con un icono perdido dentro. Y esta pantalla
        // existe precisamente para decir **qué** tienes en el portapapeles,
        // así que el dibujo tiene que ganarle al ruido, no empatar.
        //
        // Grande porque la tarjeta es de 206 × 146 y el dibujo de la cinta
        // mide 70 × 54: ahí dentro sobraba media tarjeta de ruido.
        CopyGlyph {
          anchors.centerIn: parent
          kind: root.subjectGlyph
          // Los tres pesos se compararon puestos uno al lado del otro. A
          // 0,32 el dibujo no se lee; a 0,55 gana tanto que la tarjeta deja
          // de decir «no la hemos leído» y pasa a decir «mira lo que
          // tienes». Aquí se leen las dos cosas, que es lo que hace falta.
          ink: Util.alpha(Color.popups.text, 0.45)
          scale: 1.35
        }

        // Al 34%: lo justo para que se vea que hay algo debajo y que nadie
        // lo ha mirado. Quieto siempre — el panel le pasa
        // `motionEnabled: false` y la 0007 es la razón.
        Grain {
          anchors.fill: parent
          radius: unreadCard.radius
          intensity: 0.34
          motionEnabled: root.motionEnabled
        }
      }

      Column {
        x: Style.space(230)
        width: root.sceneWidth - Style.space(234)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(12)

        Row {
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

        Rectangle {
          width: Style.space(44)
          height: 1
          color: Util.alpha(Color.popups.text, 0.14)
        }

        Text {
          // Decorativo: la raíz ya se ignora, pero el `ignored` no baja a los hijos.
          Accessible.ignored: true
          width: parent.width
          text: Strings.t("art.byteForByte", root.lang)
          // Prosa que envuelve, no un rótulo: 0,72 y su interlínea.
          color: Util.alpha(Color.popups.text, 0.72)
          font.family: Style.font.family
          font.pixelSize: Style.font.bodySmall
          lineHeightMode: Text.ProportionalHeight
          lineHeight: 1.45
          wrapMode: Text.WordWrap
        }
      }
    }

  }
}
