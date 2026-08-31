import QtQuick
import QtQuick.Controls as QQC
import qs.Commons
import qs.Ui

Item {
  id: root

  property int step: 0
  property bool replaying: false

  signal backRequested()
  signal nextRequested()
  signal dismissRequested()

  readonly property int stepCount: 3
  readonly property string stepTitle: [
    "Copia como siempre",
    "Limpia sólo lo que sobra",
    "Tú mantienes el control"
  ][Math.max(0, Math.min(stepCount - 1, step))]
  readonly property string stepBody: [
    "OmaPlain observa las nuevas copias de texto y las limpia automáticamente cuando es seguro. No necesitas cambiar de atajo.",
    "Retira formato enriquecido, parámetros de seguimiento de URLs completas y caracteres invisibles no semánticos.",
    "Limpia manualmente, omite la próxima copia o excluye una aplicación. El historial sigue siendo el de Omarchy."
  ][Math.max(0, Math.min(stepCount - 1, step))]
  readonly property string stepNote: [
    "Imágenes y archivos pasan intactos.",
    "Ante una duda, conserva el original.",
    "Todo ocurre en este equipo."
  ][Math.max(0, Math.min(stepCount - 1, step))]
  readonly property string illustrationVariant: ["protect", "transform", "control"]
    [Math.max(0, Math.min(stepCount - 1, step))]

  function forceInitialFocus() {
    tourScroll.contentY = 0
    nextButton.forceActiveFocus()
  }

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
          text: root.replaying ? "Repaso rápido" : "Cómo funciona"
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
          text: (root.step + 1) + " de " + root.stepCount
          color: Util.alpha(Color.popups.text, 0.68)
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          font.bold: true
          font.letterSpacing: Style.spaceReal(0.4)
          Accessible.role: Accessible.AlertMessage
          Accessible.name: "Paso " + (root.step + 1) + " de " + root.stepCount + ". " + root.stepTitle
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
        width: parent.width
        height: Style.space(220)
        variant: root.illustrationVariant
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

      BorderSurface {
        width: Math.min(parent.width, Style.space(420))
        implicitHeight: noteText.implicitHeight + Style.space(22)
        anchors.horizontalCenter: parent.horizontalCenter
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

      Grid {
        id: tourActions
        width: parent.width
        columns: width < Style.space(360) ? 1 : 2
        columnSpacing: Style.space(8)
        rowSpacing: Style.space(8)

        Button {
          id: backButton
          width: (tourActions.width - (tourActions.columns - 1) * tourActions.columnSpacing) / tourActions.columns
          implicitHeight: Style.space(44)
          text: "Volver"
          iconText: "←"
          focusable: true
          bordered: true
          foreground: Color.popups.text
          Accessible.role: Accessible.Button
          Accessible.name: root.step === 0 ? "Volver a la pantalla anterior" : "Volver al paso anterior"
          Accessible.onPressAction: root.backRequested()
          onActiveFocusChanged: if (activeFocus) root.reveal(backButton)
          onClicked: root.backRequested()
        }

        PrimaryButton {
          id: nextButton
          width: (tourActions.width - (tourActions.columns - 1) * tourActions.columnSpacing) / tourActions.columns
          text: root.step === root.stepCount - 1 ? "Abrir OmaPlain" : "Siguiente"
          iconText: root.step === root.stepCount - 1 ? "✓" : "→"
          onActiveFocusChanged: if (activeFocus) root.reveal(nextButton)
          onClicked: root.nextRequested()
        }
      }

      Button {
        id: dismissButton
        width: parent.width
        implicitHeight: Style.space(44)
        text: root.replaying ? "Salir del repaso" : "Saltar el tour"
        focusable: true
        foreground: Util.alpha(Color.popups.text, 0.68)
        Accessible.role: Accessible.Button
        Accessible.name: text
        Accessible.onPressAction: root.dismissRequested()
        onActiveFocusChanged: if (activeFocus) root.reveal(dismissButton)
        onClicked: root.dismissRequested()
      }
    }
  }
}
