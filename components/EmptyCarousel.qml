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
Item {
  id: root

  property string lang: "en"
  property bool motionEnabled: true

  readonly property int dwell: 2600
  readonly property int move: 620

  // Cada ejemplo se parte en tres: lo que se queda, lo que sobra, y el
  // resto. Sin ajuste de línea y con altura fija, porque si cada elemento
  // midiera distinto el panel entero cambiaría de tamaño cada 2,6 segundos.
  readonly property var samples: [
    { kind: "empty.kind.link", art: "link",
      head: "tienda.ejemplo.com/zapatillas?",
      spare: "utm_source=boletin&utm_medium=email&",
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
  // Alta lo justo para la tarjeta y su aire: el hueco muerto era el motivo
  // por el que esta pantalla se rehízo.
  implicitHeight: Style.space(124)

  Accessible.role: Accessible.StaticText
  Accessible.name: Strings.t("empty.art.a11y", root.lang)

  function reset() {
    index = 0
    combed = motionEnabled ? 0 : 1
    if (motionEnabled) entrance.restart()
  }

  // 0 = recién llegado, 1 = ya peinado.
  property real combed: motionEnabled ? 0 : 1

  SequentialAnimation {
    id: entrance
    PauseAnimation { duration: Math.round(root.move * 0.45) }
    NumberAnimation {
      target: root; property: "combed"; from: 0; to: 1
      duration: root.move; easing.type: Easing.OutCubic
    }
  }

  Timer {
    interval: root.dwell
    running: root.motionEnabled && root.visible
    repeat: true
    onTriggered: {
      root.index = (root.index + 1) % root.samples.length
      root.combed = 0
      entrance.restart()
    }
  }

  onMotionEnabledChanged: reset()
  onVisibleChanged: if (visible) reset()

  BorderSurface {
    id: card
    anchors.centerIn: parent
    width: parent.width
    height: Math.max(specimen.implicitHeight + Style.space(22),
                     kind.implicitHeight + body.implicitHeight + Style.space(30))
    radius: Style.cornerRadius
    color: Style.normalFillFor(Color.popups.text, Color.accent)
    borderSpec: Border.controlSpec("normal", Color.popups.text, Color.accent)
    clip: true

    // La tarjeta entra entera; sólo lo que sobra se peina después.
    opacity: root.motionEnabled ? Math.min(1, root.combed * 3 + 0.35) : 1

    // El dibujo a la izquierda, pegado al texto que describe: los dos
    // pierden lo que sobra con el mismo `combed`, en un solo gesto.
    CopySpecimen {
      id: specimen
      anchors.left: parent.left
      anchors.leftMargin: Style.space(12)
      anchors.verticalCenter: parent.verticalCenter
      kind: root.sample.art
      combed: root.combed
    }

    Column {
      anchors.left: specimen.right
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(14)
      anchors.rightMargin: Style.space(14)
      spacing: Style.space(7)

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

  // Tres marcas de posición, para que se vea que hay un ciclo y por dónde va.
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
        width: Style.space(index === root.index ? 14 : 5)
        height: Style.space(5)
        radius: height / 2
        color: index === root.index ? Color.accent : Util.alpha(Color.popups.text, 0.2)
        Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
      }
    }
  }
}
