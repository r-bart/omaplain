import QtQuick
import qs.Commons
import qs.Ui
import "Strings.js" as Strings

// Una de las dos tarjetas del antes y el después. Rótulo a la izquierda,
// ojo al final, y el contenido cubierto hasta que alguien pide verlo.
//
// La altura es fija y la misma en ambas: descubrir no mueve nada, y las
// dos filas quedan alineadas para poder compararlas.
Item {
  id: root

  // Idioma heredado del panel: en o es.
  property string lang: "en"

  property string label: ""
  property string body: ""
  property bool shown: false
  // 0009: viene de una aplicación de la lista «no destapar nunca». El vaho
  // no se levanta aquí, ni con el ojo ni con el gesto.
  property bool locked: false

  // Lo que de verdad decide qué se ve. `shown` es lo que pide el panel;
  // esto es lo que se concede. Que la negativa no dependa de que quien
  // llama se acuerde es justo el punto de una lista de privacidad.
  readonly property bool revealed: root.shown && !root.locked
  property int seed: 7
  property bool motionEnabled: true

  signal revealRequested()
  signal hideRequested()
  signal focusEntered(Item item)

  implicitWidth: Style.space(460)
  implicitHeight: header.height + Style.space(104)

  BorderSurface {
    anchors.fill: parent
    radius: Style.cornerRadius
    color: Style.normalFillFor(Color.popups.text, Color.accent)
    borderSpec: Border.controlSpec("normal", Color.popups.text, Color.accent)
    clip: true

    Item {
      id: header
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      // Mínimo, no fijo: con un tamaño de fuente mayor el rótulo crecería
      // por encima de una altura escrita a mano.
      height: Math.max(Style.space(32), headerLabel.implicitHeight + Style.space(12))

      Text {
        id: headerLabel
        anchors.left: parent.left
        anchors.leftMargin: Style.space(10)
        anchors.verticalCenter: parent.verticalCenter
        text: root.label
        color: Util.alpha(Color.popups.text, 0.68)
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        font.capitalization: Font.AllUppercase
        font.letterSpacing: Style.spaceReal(0.8)
      }

      Button {
        id: eye
        anchors.right: parent.right
        anchors.rightMargin: Style.space(6)
        anchors.verticalCenter: parent.verticalCenter
        implicitHeight: Style.space(44)
        implicitWidth: Style.space(44)
        text: root.locked ? "󰌾" : (root.revealed ? "◉" : "◎")
        tooltipText: root.locked
          ? Strings.f("row.locked", root.lang, root.label)
          : Strings.f(root.revealed ? "row.hide" : "row.show", root.lang, root.label)
        focusable: true
        enabled: !root.locked
        foreground: root.revealed ? Color.accent : Util.alpha(Color.popups.text, 0.68)
        Accessible.role: Accessible.Button
        Accessible.name: root.locked
          ? Strings.f("row.locked", root.lang, root.label)
          : Strings.f(root.revealed ? "row.hide" : "row.show", root.lang, root.label)
        Accessible.onPressAction: root.toggle()
        onActiveFocusChanged: if (activeFocus) root.focusEntered(eye)
        onClicked: root.toggle()
      }

      Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: Math.max(1, Style.normalBorderWidth)
        color: Util.alpha(Color.popups.text, 0.14)
      }
    }

    Item {
      id: well
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: header.bottom
      anchors.bottom: parent.bottom

      Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: bodyText.implicitHeight + Style.space(20)
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        // Mientras hay cubierta el texto no se anuncia: lo que se ve y lo
        // que oye un lector de pantalla tienen que coincidir.
        Accessible.ignored: !root.revealed

        Text {
          id: bodyText
          x: Style.space(10)
          y: Math.max(Style.space(10), (well.height - implicitHeight) / 2)
          width: parent.width - Style.space(20)
          text: root.body
          color: Color.popups.text
          font.family: Style.font.family
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.WrapAnywhere
          Accessible.role: Accessible.StaticText
          Accessible.name: root.revealed ? root.body : ""
        }
      }

      FogCover {

        lang: root.lang
        anchors.fill: parent
        visible: !root.revealed
        seed: root.seed
        motionEnabled: root.motionEnabled
        Accessible.role: Accessible.StaticText
        Accessible.name: Strings.t("row.covered.a11y", root.lang)
        // Bajo llave el gesto tampoco vale: la cubierta ni siquiera escucha.
        onCleared: if (!root.locked) root.revealRequested()
        onVisibleChanged: if (visible) { reset() }
      }
    }
  }

  function toggle() {
    if (root.locked) return
    if (root.revealed) root.hideRequested()
    else root.revealRequested()
  }
}
