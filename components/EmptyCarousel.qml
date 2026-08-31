import QtQuick
import qs.Commons
import qs.Ui
import "Strings.js" as Strings

// Lo que ve alguien con el portapapeles vacío: una cosa copiable cada vez,
// con lo que sobra encogiéndose hasta desaparecer en su sitio. Decisión 0008.
//
// Los ejemplos son los mismos que valida `tests/unit/test_empty_samples.py`
// contra el motor real, para que esta pantalla no prometa una limpieza que
// el producto haya dejado de hacer.
//
// El ciclo es una sola coreografía por ejemplo, no cuatro efectos sueltos:
// llega, se peina, se queda a la vista, y se va hacia arriba para dejar
// sitio al siguiente. Cada fase tiene su curva —entrada que frena, salida
// que acelera— y la barra de la posición actual se llena mientras tanto,
// así que el cambio se ve venir en vez de sorprender a media lectura.
Item {
  id: root

  property string lang: "en"
  property bool motionEnabled: true

  readonly property int dwell: 2600
  readonly property int enterMs: 300
  // El texto entra un pelo detrás del dibujo. Llegando a la vez se lee como
  // un bloque que se mueve; escalonado, como algo que se coloca.
  readonly property int textDelay: 70
  readonly property int settleMs: 80
  readonly property int combMs: 620
  readonly property int leaveMs: 190
  // La curva que se eligió en el prototipo y que la implementación no
  // llegó a usar: arranca fuerte y frena largo. `OutCubic` frena antes y
  // la llegada se quedaba a medio camino de lo decidido.
  readonly property var entryCurve: [0.32, 0.72, 0, 1, 1, 1]
  readonly property int restMs: dwell - enterMs - textDelay - settleMs - combMs - leaveMs

  // Cada ejemplo se parte en tres: lo que se queda, lo que sobra, y el
  // resto. Sin ajuste de línea y con altura fija, porque si cada elemento
  // midiera distinto el panel entero cambiaría de tamaño cada 2,6 segundos.
  readonly property var samples: [
    { kind: "empty.kind.link", art: "link",
      head: "tienda.com/zapatillas?",
      spare: "utm_source=boletin&",
      tail: "talla=42" },
    { kind: "empty.kind.text", art: "text",
      head: "El pan de masa madre",
      spare: "·ZWSP·",
      tail: " necesita 12 horas." },
    { kind: "empty.kind.rich", art: "rich",
      head: "Resumen ejecutivo  ",
      spare: "+ text/html",
      tail: "" }
  ]

  property int index: 0
  readonly property var sample: samples[index % samples.length]

  implicitWidth: Style.space(460)
  // Alta lo justo para la tarjeta y sus marcas de posición: el hueco
  // muerto era el motivo por el que esta pantalla se rehízo. Quieta no
  // hay marcas que alojar, así que tampoco se reserva su sitio.
  implicitHeight: card.height + Style.space(motionEnabled ? 20 : 0)

  Accessible.role: Accessible.StaticText
  Accessible.name: Strings.t("empty.art.a11y", root.lang)

  // 0 = recién llegado, 1 = ya peinado.
  property real combed: motionEnabled ? 0 : 1
  // +1 = esperando abajo, 0 = en su sitio, -1 = ya se ha ido por arriba.
  // La tarjeta no se mueve: es el escenario. Lo que entra y sale es su
  // contenido, así que el borde no parpadea tres veces cada ocho segundos.
  property real slide: motionEnabled ? 1 : 0
  property real slideText: motionEnabled ? 1 : 0

  // Invisible del todo antes de llegar al final del recorrido, que es
  // donde se cambia de ejemplo: el relevo no se ve, sólo la llegada.
  function fade(offset) { return Math.max(0, 1 - Math.abs(offset) * 1.7) }
  // Lo que lleva recorrido el ejemplo actual de su turno.
  property real ride: 0

  function reset() {
    index = 0
    combed = motionEnabled ? 0 : 1
    slide = motionEnabled ? 1 : 0
    slideText = motionEnabled ? 1 : 0
    ride = 0
  }

  onMotionEnabledChanged: reset()
  onVisibleChanged: if (visible) reset()

  ParallelAnimation {
    running: root.motionEnabled && root.visible
    loops: Animation.Infinite

    // La barra de posición va por libre: mide el turno entero, no una fase.
    NumberAnimation {
      target: root; property: "ride"; from: 0; to: 1
      duration: root.dwell; easing.type: Easing.Linear
    }

    SequentialAnimation {
      // Llega desde abajo y frena. Nunca desde el borde: un empujón corto
      // se lee como colocar algo, uno largo como un carrusel de anuncios.
      ParallelAnimation {
        NumberAnimation {
          target: root; property: "slide"; from: 1; to: 0
          duration: root.enterMs
          easing.type: Easing.Bezier; easing.bezierCurve: root.entryCurve
        }
        SequentialAnimation {
          PauseAnimation { duration: root.textDelay }
          NumberAnimation {
            target: root; property: "slideText"; from: 1; to: 0
            duration: root.enterMs
            easing.type: Easing.Bezier; easing.bezierCurve: root.entryCurve
          }
        }
      }
      PauseAnimation { duration: root.settleMs }
      // Y sólo entonces se peina: primero se ve qué hay, luego qué sobra.
      NumberAnimation {
        target: root; property: "combed"; from: 0; to: 1
        duration: root.combMs; easing.type: Easing.InOutCubic
      }
      PauseAnimation { duration: root.restMs }
      // Se va más rápido de lo que vino, y entero: una salida escalonada
      // llama la atención sobre algo que ya no interesa.
      ParallelAnimation {
        NumberAnimation {
          target: root; property: "slide"; from: 0; to: -1
          duration: root.leaveMs; easing.type: Easing.InCubic
        }
        NumberAnimation {
          target: root; property: "slideText"; from: 0; to: -1
          duration: root.leaveMs; easing.type: Easing.InCubic
        }
      }
      // El relevo ocurre con la tarjeta invisible, así que no se ve el
      // cambio de contenido: sólo se ve llegar al siguiente.
      ScriptAction {
        script: {
          root.index = (root.index + 1) % root.samples.length
          root.combed = 0
          root.slide = 1
          root.slideText = 1
        }
      }
    }
  }

  BorderSurface {
    id: card
    width: parent.width
    height: Math.max(specimen.implicitHeight + Style.space(18),
                     kind.implicitHeight + body.implicitHeight + Style.space(34))
    radius: Style.cornerRadius
    color: Style.normalFillFor(Color.popups.text, Color.accent)
    borderSpec: Border.controlSpec("normal", Color.popups.text, Color.accent)
    clip: true

    // El dibujo a la izquierda, pegado al texto que describe: los dos
    // pierden lo que sobra con el mismo `combed`, en un solo gesto.
    CopySpecimen {
      id: specimen
      anchors.left: parent.left
      anchors.leftMargin: Style.space(10)
      anchors.verticalCenter: parent.verticalCenter
      kind: root.sample.art
      combed: root.combed
      landed: 1 - Math.min(1, Math.abs(root.slide))

      // Con transform y opacidad, que van en la GPU: mover el dibujo por
      // `y` obligaría a recolocar la columna de al lado en cada cuadro.
      opacity: root.fade(root.slide)
      transform: Translate { y: root.slide * Style.space(14) }
    }

    Column {
      anchors.left: specimen.right
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(12)
      anchors.rightMargin: Style.space(14)
      spacing: Style.space(8)

      opacity: root.fade(root.slideText)
      transform: Translate { y: root.slideText * Style.space(14) }

      Text {
        id: kind
        text: Strings.t(root.sample.kind, root.lang)
        color: Util.alpha(Color.popups.text, 0.68)
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        font.capitalization: Font.AllUppercase
        font.letterSpacing: Style.spaceReal(0.8)
      }

      Row {
        id: body
        width: parent.width
        spacing: 0

        Text {
          text: root.sample.head
          color: Color.popups.text
          font.family: Style.font.family
          font.pixelSize: Style.font.bodySmall
        }

        // Lo que sobra: se encoge hasta nada, y el resto se cierra detrás.
        // `clip` es lo que convierte el ancho en un recorte en vez de en un
        // reajuste de la tipografía.
        Item {
          width: spare.implicitWidth * (1 - root.combed)
          height: spare.implicitHeight
          clip: true
          Text {
            id: spare
            text: root.sample.spare
            color: Color.accent
            opacity: 1 - root.combed * 0.5
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
          }
        }

        Text {
          text: root.sample.tail
          color: Color.popups.text
          font.family: Style.font.family
          font.pixelSize: Style.font.bodySmall
        }
      }
    }
  }

  // Tres marcas de posición. La del ejemplo en curso es además su reloj:
  // se llena mientras dura el turno, así que el relevo se ve venir.
  Row {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    spacing: Style.space(5)
    visible: root.motionEnabled
    Accessible.ignored: true

    Repeater {
      model: root.samples.length
      delegate: Rectangle {
        required property int index
        readonly property bool current: index === root.index

        width: Style.space(current ? 20 : 5)
        height: Style.space(5)
        radius: height / 2
        color: current ? Util.alpha(Color.accent, 0.28) : Util.alpha(Color.popups.text, 0.2)
        clip: true

        Behavior on width { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

        Rectangle {
          width: parent.current ? parent.width * root.ride : 0
          height: parent.height
          radius: height / 2
          color: Color.accent
        }
      }
    }
  }
}
