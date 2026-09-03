import QtQuick
import QtQuick.Controls as QQC
import qs.Commons
import qs.Ui
import "Strings.js" as Strings

Item {
  id: root

  // Idioma heredado del panel: en o es.
  property string lang: "en"

  property int step: 0
  property bool motionEnabled: true
  property bool replaying: false

  // Lo que mide de verdad, para que el panel pueda ajustarse a ello.
  readonly property real contentHeight: content.implicitHeight + Style.space(56)

  signal backRequested()
  signal nextRequested()
  signal dismissRequested()

  readonly property int stepCount: 3

  // Si el recorrido continúa después de este paso o si termina aquí.
  //
  // La primera vez continúa: el paso siguiente son los ajustes, con su banda
  // y su propia salida, así que el botón nombra a dónde lleva. Desde la
  // pantalla de todos los días no continúa nada — se vuelve de donde se vino,
  // y esa pantalla tiene «Ver cómo funciona» como única acción, así que
  // prometer los ajustes se leía como volver al principio del recorrido.
  //
  // Cuando termina, el botón **termina**: no nombra un destino. Nombrarlo fue
  // el primer arreglo y seguía siendo un botón de navegación al final de un
  // recorrido de tres pasos, que es justo donde se espera «Finalizar».
  property bool endsInSettings: true
  readonly property string stepTitle: [
    Strings.t("tour.1.title", root.lang),
    Strings.t("tour.2.title", root.lang),
    Strings.t("tour.3.title", root.lang)
  ][Math.max(0, Math.min(stepCount - 1, step))]
  readonly property string stepBody: [
    Strings.t("tour.1.body", root.lang),
    Strings.t("tour.2.body", root.lang),
    Strings.t("tour.3.body", root.lang)
  ][Math.max(0, Math.min(stepCount - 1, step))]
  readonly property string stepNote: [
    Strings.t("tour.1.note", root.lang),
    Strings.t("tour.2.note", root.lang),
    Strings.t("tour.3.note", root.lang)
  ][Math.max(0, Math.min(stepCount - 1, step))]
  // El paso 2 no monta ilustración: la preside `DemoTransformation`, y
  // ocupa el sitio que en los otros dos ocupa el dibujo.
  //
  // Hasta hoy montaba `transform` **además** de la demo, así que la
  // pantalla tenía dos activos con caída y repetía la composición de la
  // bienvenida en la pantalla siguiente. Con la ilustración fuera, cada
  // paso del recorrido presenta una cosa distinta.
  readonly property string illustrationVariant: ["protect", "", "control"]
    [Math.max(0, Math.min(stepCount - 1, step))]
  readonly property bool hasIllustration: illustrationVariant !== ""

  function forceInitialFocus() {
    tourScroll.contentY = 0
    nextButton.forceActiveFocus()
  }

  onStepChanged: demo.reset()

  function reveal(item) {
    if (!item) return
    var point = item.mapToItem(content, 0, 0)
    var top = point.y
    var bottom = top + item.height
    if (top < tourScroll.contentY) tourScroll.contentY = Math.max(0, top - Style.space(8))
    else if (bottom > tourScroll.contentY + tourScroll.height)
      tourScroll.contentY = Math.min(
        tourScroll.contentHeight - tourScroll.height,
        bottom - tourScroll.height + Style.space(8))
  }

  Flickable {
    id: tourScroll
    anchors.fill: parent
    contentWidth: width
    contentHeight: content.implicitHeight + Style.space(52)
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    flickableDirection: Flickable.VerticalFlick
    QQC.ScrollBar.vertical: QQC.ScrollBar { policy: QQC.ScrollBar.AsNeeded }

    Column {
      id: content
      x: Style.space(30)
      y: Style.space(28)
      width: tourScroll.width - Style.space(60)
      spacing: Style.space(14)

      Item {
        width: parent.width
        height: Math.max(tourLabel.implicitHeight, stepCounter.implicitHeight)

        Text {
          id: tourLabel
          anchors.left: parent.left
          text: root.replaying ? Strings.t("tour.eyebrow.replay", root.lang) : Strings.t("tour.eyebrow", root.lang)
          color: Color.accent
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          font.bold: true
          font.capitalization: Font.AllUppercase
          font.letterSpacing: Style.spaceReal(0.9)
        }

        Text {
          id: stepCounter
          anchors.right: parent.right
          text: Strings.f("tour.step", root.lang, root.step + 1, root.stepCount)
          color: Util.alpha(Color.popups.text, 0.68)
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          font.bold: true
          font.letterSpacing: Style.spaceReal(0.4)
          Accessible.role: Accessible.AlertMessage
          Accessible.name: Strings.f("tour.step.a11y", root.lang, root.step + 1, root.stepCount, root.stepTitle)
        }
      }

      Row {
        id: progress
        width: parent.width
        spacing: Style.space(6)

        Repeater {
          model: root.stepCount
          delegate: Rectangle {
            required property int index
            width: (progress.width - (root.stepCount - 1) * progress.spacing) / root.stepCount
            height: Style.space(4)
            radius: height / 2
            color: index <= root.step ? Color.accent : Util.alpha(Color.popups.text, 0.16)
          }
        }
      }

      TransformationIllustration {

        lang: root.lang
        motionEnabled: root.motionEnabled
        width: parent.width
        height: Style.space(220)
        variant: root.illustrationVariant
        // Un positionador de QML salta a los hijos invisibles, así que el
        // paso 2 no reserva su hueco ni su `spacing`: no hace falta poner
        // el alto a cero a mano.
        visible: root.hasIllustration
      }

      Text {
        width: parent.width
        height: Math.max(implicitHeight, Style.space(54))
        text: root.stepTitle
        color: Color.popups.text
        font.family: Style.font.family
        font.pixelSize: Style.font.display
        font.bold: true
        font.letterSpacing: -Style.spaceReal(0.4)
        lineHeightMode: Text.ProportionalHeight
        lineHeight: 1.08
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        wrapMode: Text.WordWrap
      }

      Text {
        width: Math.min(parent.width, Style.space(420))
        height: Math.max(implicitHeight, Style.space(64))
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.stepBody
        color: Util.alpha(Color.popups.text, 0.72)
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        lineHeightMode: Text.ProportionalHeight
        lineHeight: 1.5
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignTop
        wrapMode: Text.WordWrap
      }

      // El mismo ancho que la rejilla de acciones de abajo. Estaba topado a
      // `space(420)` y centrado, así que se quedaba unas 48 unidades más
      // estrecho que los botones y sus bordes no llegaban a alinearse con
      // los de nadie: dos cajas casi iguales desalineadas leen peor que dos
      // claramente distintas.
      BorderSurface {
        width: parent.width
        implicitHeight: noteText.implicitHeight + Style.space(22)
        radius: Math.max(0, Style.cornerRadius - Style.space(2))
        color: Style.normalFillFor(Color.popups.text, Color.accent)
        borderSpec: Border.controlSpec("normal", Color.popups.text, Color.accent)

        Row {
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          anchors.leftMargin: Style.space(12)
          anchors.rightMargin: Style.space(12)
          spacing: Style.space(8)

          Rectangle {
            width: Style.space(8)
            height: width
            radius: width / 2
            color: Color.accent
            anchors.verticalCenter: parent.verticalCenter
          }

          Text {
            id: noteText
            width: parent.width - Style.space(20)
            text: root.stepNote
            color: Color.popups.text
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            font.bold: true
            wrapMode: Text.WordWrap
          }
        }
      }

      // Como el callout y la rejilla de acciones: es una superficie, no una
      // columna de lectura, así que sigue el ancho de la pila. El tope de
      // `space(420)` que tenía sólo tiene sentido sobre prosa —el párrafo
      // del paso lo conserva por eso— y aquí dejaba un tercer borde
      // izquierdo distinto en la misma columna.
      DemoTransformation {

        lang: root.lang
        id: demo
        width: parent.width
        motionEnabled: root.motionEnabled
        // Solo el paso 2 promete que se retira algo; en los otros dos la
        // demostracion no ilustra nada de lo que dice el texto.
        visible: root.step === 1
        onFocusEntered: function(item) { root.reveal(item) }
      }

      Grid {
        id: tourActions
        width: parent.width
        columns: width < Style.space(360) ? 1 : 2
        columnSpacing: Style.space(8)
        rowSpacing: Style.space(8)

        PanelButton {
          id: backButton
          width: (tourActions.width - (tourActions.columns - 1) * tourActions.columnSpacing) / tourActions.columns
          text: Strings.t("tour.back", root.lang)
          Accessible.name: root.step === 0 ? Strings.t("tour.back.first.a11y", root.lang) : Strings.t("tour.back.a11y", root.lang)
          onFocusEntered: function(item) { root.reveal(item) }
          onClicked: root.backRequested()
        }

        PrimaryButton {
          id: nextButton
          width: (tourActions.width - (tourActions.columns - 1) * tourActions.columnSpacing) / tourActions.columns
          text: root.step !== root.stepCount - 1
            ? Strings.t("tour.next", root.lang)
            : (root.endsInSettings ? Strings.t("tour.finish", root.lang) : Strings.t("tour.done", root.lang))
          onActiveFocusChanged: if (activeFocus) root.reveal(nextButton)
          onClicked: root.nextRequested()
        }
      }

      PanelButton {
        id: dismissButton
        width: parent.width
        text: root.replaying ? Strings.t("tour.leave", root.lang) : Strings.t("tour.skip", root.lang)
        // Sin borde a propósito: es la salida discreta, no una tercera
        // acción. El anillo de foco sí, o desaparecería del recorrido por
        // teclado justo como desaparecía antes de la `0012`.
        bordered: false
        foreground: Util.alpha(Color.popups.text, 0.68)
        onFocusEntered: function(item) { root.reveal(item) }
        onClicked: root.dismissRequested()
      }
    }
  }
}
