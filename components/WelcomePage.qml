import QtQuick
import QtQuick.Controls as QQC
import qs.Commons
import qs.Ui
import "Strings.js" as Strings

Item {
  id: root

  // Idioma heredado del panel: en o es.
  property string lang: "en"

  property bool returning: false
  property bool motionEnabled: true

  // Lo que mide de verdad, para que el panel pueda ajustarse a ello.
  readonly property real contentHeight: content.implicitHeight + Style.space(56)

  signal startRequested()
  signal dismissRequested()

  function forceInitialFocus() {
    welcomeScroll.contentY = 0
    startButton.forceActiveFocus()
  }

  function reveal(item) {
    if (!item) return
    var point = item.mapToItem(content, 0, 0)
    var top = point.y
    var bottom = top + item.height
    if (top < welcomeScroll.contentY) welcomeScroll.contentY = Math.max(0, top - Style.space(8))
    else if (bottom > welcomeScroll.contentY + welcomeScroll.height)
      welcomeScroll.contentY = Math.min(
        welcomeScroll.contentHeight - welcomeScroll.height,
        bottom - welcomeScroll.height + Style.space(8))
  }

  Flickable {
    id: welcomeScroll
    anchors.fill: parent
    contentWidth: width
    contentHeight: content.implicitHeight + Style.space(52)
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    flickableDirection: Flickable.VerticalFlick
    QQC.ScrollBar.vertical: QQC.ScrollBar { policy: QQC.ScrollBar.AsNeeded }

    Column {
      id: content
      x: Style.space(28)
      y: Style.space(26)
      width: welcomeScroll.width - Style.space(56)
      spacing: Style.space(14)

      TransformationIllustration {

        lang: root.lang
        motionEnabled: root.motionEnabled
        width: parent.width
        height: Style.space(190)
        variant: "transform"
      }

      Text {
        width: parent.width
        text: root.returning ? Strings.t("welcome.eyebrow.return", root.lang) : Strings.t("welcome.eyebrow.first", root.lang)
        color: Color.accent
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        font.bold: true
        font.capitalization: Font.AllUppercase
        font.letterSpacing: Style.spaceReal(0.9)
        horizontalAlignment: Text.AlignHCenter
      }

      Text {
        width: parent.width
        text: Strings.t("welcome.title", root.lang)
        color: Color.popups.text
        font.family: Style.font.family
        font.pixelSize: Style.font.displayLarge
        font.bold: true
        font.letterSpacing: -Style.spaceReal(0.5)
        lineHeightMode: Text.ProportionalHeight
        lineHeight: 1.06
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
      }

      Text {
        width: Math.min(parent.width, Style.space(420))
        anchors.horizontalCenter: parent.horizontalCenter
        text: Strings.t("welcome.body", root.lang)
        color: Util.alpha(Color.popups.text, 0.72)
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        lineHeightMode: Text.ProportionalHeight
        lineHeight: 1.5
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
      }

      Grid {
        id: features
        width: parent.width
        columns: width < Style.space(420) ? 1 : 3
        columnSpacing: Style.space(8)
        rowSpacing: Style.space(8)

        Repeater {
          model: [
            { title: Strings.t("welcome.card1.title", root.lang), body: Strings.t("welcome.card1.body", root.lang) },
            { title: Strings.t("welcome.card2.title", root.lang), body: Strings.t("welcome.card2.body", root.lang) },
            { title: Strings.t("welcome.card3.title", root.lang), body: Strings.t("welcome.card3.body", root.lang) }
          ]

          delegate: BorderSurface {
            required property var modelData
            width: (features.width - (features.columns - 1) * features.columnSpacing) / features.columns
            // Alto mínimo para que las tres midan igual en una fila, pero
            // nunca menor que su contenido: una altura fija a secas se
            // rompe en cuanto alguien sube el tamaño de fuente del tema.
            implicitHeight: Math.max(
              featureCopy.implicitHeight + Style.space(24),
              features.columns === 1 ? 0 : Style.space(108))
            radius: Math.max(0, Style.cornerRadius - Style.space(2))
            color: Style.normalFillFor(Color.popups.text, Color.accent)
            borderSpec: Border.controlSpec("normal", Color.popups.text, Color.accent)

            Column {
              id: featureCopy
              anchors.left: parent.left
              anchors.right: parent.right
              // Anclado arriba, no centrado: centrando, cada tarjeta coloca
              // su texto según lo que ocupe, y los tres cuerpos acababan a
              // alturas distintas dentro de una misma fila.
              anchors.top: parent.top
              anchors.topMargin: Style.space(12)
              anchors.leftMargin: Style.space(12)
              anchors.rightMargin: Style.space(12)
              spacing: Style.space(4)

              Text {
                id: featureTitle
                width: parent.width
                // Reserva las dos líneas del título más largo, de modo que
                // los cuerpos arranquen a la misma altura en las tres.
                height: features.columns === 1
                  ? implicitHeight
                  : Math.max(implicitHeight, Math.round(font.pixelSize * 2.6))
                text: modelData.title
                color: Color.popups.text
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                font.bold: true
                verticalAlignment: Text.AlignTop
                wrapMode: Text.WordWrap
              }

              Text {
                width: parent.width
                text: modelData.body
                color: Util.alpha(Color.popups.text, 0.72)
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                lineHeightMode: Text.ProportionalHeight
                lineHeight: 1.4
                wrapMode: Text.WordWrap
              }
            }
          }
        }
      }

      Grid {
        id: welcomeActions
        width: parent.width
        columns: width < Style.space(360) ? 1 : 2
        columnSpacing: Style.space(8)
        rowSpacing: Style.space(8)

        PrimaryButton {
          id: startButton
          width: (welcomeActions.width - (welcomeActions.columns - 1) * welcomeActions.columnSpacing) / welcomeActions.columns
          text: Strings.t("welcome.start", root.lang)
          iconText: "→"
          onActiveFocusChanged: if (activeFocus) root.reveal(startButton)
          onClicked: root.startRequested()
        }

        PanelButton {
          id: dismissButton
          width: (welcomeActions.width - (welcomeActions.columns - 1) * welcomeActions.columnSpacing) / welcomeActions.columns
          text: root.returning ? Strings.t("welcome.return", root.lang) : Strings.t("welcome.enter", root.lang)
          onFocusEntered: function(item) { root.reveal(item) }
          onClicked: root.dismissRequested()
        }
      }

      Text {
        width: parent.width
        text: Strings.t("welcome.again", root.lang)
        color: Util.alpha(Color.popups.text, 0.68)
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
      }
    }
  }
}
