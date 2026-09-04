import QtQuick
import qs.Commons
import qs.Ui
import "Strings.js" as Strings
import "Ink.js" as Ink

// Una de las dos tarjetas del antes y el después. Rótulo a la izquierda,
// ojo al final, y el contenido cubierto hasta que alguien pide verlo.
//
// La altura es fija y la misma en ambas: descubrir no mueve nada, y las
// dos filas quedan alineadas para poder compararlas.
Item {
  id: root

  // Idioma heredado del panel: en o es.
  property string lang: "en"

  // El rótulo que se ve en la cabecera de la fila: «Now», «Would be».
  property string label: ""
  // Y cómo se llama la fila dentro de una frase. Son cosas distintas: con
  // el rótulo, «Show %1» salía «Show Now».
  property string name: ""
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
  // F.3: se acaba de limpiar de verdad. El sello conecta el clic con el
  // resultado sin depender sólo del mensaje de texto de más abajo.
  property bool confirmed: false

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
        color: Ink.secondary(Color.popups.text, Color.popups.background)
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        font.capitalization: Font.AllUppercase
        font.letterSpacing: Style.spaceReal(0.8)
      }

      PanelButton {
        id: eye
        anchors.right: parent.right
        anchors.rightMargin: Style.space(6)
        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: Style.space(44)
        text: root.locked ? "󰌾" : (root.revealed ? "◉" : "◎")
        tooltipText: root.locked
          ? Strings.t("row.locked", root.lang)
          : Strings.f(root.revealed ? "row.hide" : "row.show", root.lang, root.name)
        // El ojo va sin borde: vive dentro de la fila, que ya es su marco.
        bordered: false
        enabled: !root.locked
        foreground: root.revealed ? Color.accent : Ink.secondary(Color.popups.text, Color.popups.background)
        Accessible.name: root.locked
          ? Strings.t("row.locked", root.lang)
          : Strings.f(root.revealed ? "row.hide" : "row.show", root.lang, root.name)
        onFocusEntered: function(item) { root.focusEntered(item) }
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
          // Fuera del árbol de accesibilidad mientras está cubierto, en el
          // propio ítem: el `ignored` del Flickable de arriba no baja a
          // los hijos, y un nombre vacío no garantiza nada —Qt puede caer
          // al `text` del ítem cuando el nombre adjunto no cuenta.
          Accessible.ignored: !root.revealed
          Accessible.name: root.revealed ? root.body : ""
        }
      }

      // Sólo opacidad y escala, y por debajo de 220 ms: esto responde a una
      // acción, así que va en el tope de las respuestas, no en el de las
      // demostraciones.
      Rectangle {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Style.space(10)
        width: Style.space(30)
        height: width
        radius: width / 2
        color: Color.accent
        z: 2
        visible: opacity > 0.01
        opacity: root.confirmed ? 1 : 0
        scale: root.confirmed ? 1 : 0.92
        transformOrigin: Item.Center
        Accessible.ignored: true

        Behavior on opacity { NumberAnimation { duration: root.motionEnabled ? 180 : 0; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: root.motionEnabled ? 180 : 0; easing.type: Easing.OutCubic } }

        Text {
          anchors.centerIn: parent
          text: "✓"
          color: Color.background
          font.family: Style.font.family
          font.pixelSize: Style.font.title
          font.bold: true
        }
      }

      FogCover {
        id: fog

        lang: root.lang
        anchors.fill: parent
        visible: !root.revealed
        seed: root.seed
        motionEnabled: root.motionEnabled
        // La llave llega a la cubierta, no sólo a la señal: sin esto el
        // arrastre abría huecos y el texto se leía por ellos.
        locked: root.locked
        Accessible.role: Accessible.StaticText
        // Bajo llave no se invita a nada: el arrastre no responde y el ojo
        // es un candado deshabilitado. Decirlo igualmente eran dos
        // instrucciones falsas seguidas para quien usa lector de pantalla.
        hint: root.locked ? "" : Strings.t("fog.hint", root.lang)
        Accessible.name: Strings.t(
          root.locked ? "row.covered.locked.a11y" : "row.covered.a11y", root.lang)
        // Bajo llave el gesto tampoco vale: la cubierta ni siquiera escucha.
        onCleared: if (!root.locked) root.revealRequested()
        onVisibleChanged: if (visible) { reset() }
      }
    }
  }

  // Texto nuevo, cubierta nueva. Si llega otra copia con la fila cubierta
  // y a medio frotar, los huecos —o el remate en marcha— enseñarían lo
  // nuevo sin que nadie lo hubiera pedido.
  onBodyChanged: fog.reset()

  function toggle() {
    if (root.locked) return
    if (root.revealed) root.hideRequested()
    else root.revealRequested()
  }
}
