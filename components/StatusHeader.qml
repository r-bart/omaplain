import QtQuick
import qs.Commons
import qs.Ui
import "Strings.js" as Strings

// El estado del servicio en la pantalla frecuente. Nada más.
//
// Antes esto era un héroe: llevaba «Texto limpio, sin sorpresas» —el mismo
// titular, palabra por palabra, que la pantalla de bienvenida— más la
// ilustración de transformación, ocupando el tercio superior de un panel
// pequeño y de uso diario.
//
// La decisión 0007 se llevó ambas cosas a donde tienen trabajo. La primera
// experiencia enseña; ésta informa. El producto se explica solo enseñando
// qué va a hacer con tu contenido, que es mejor profesor que un dibujo que
// ya viste en el tour.
Item {
  id: root

  // Idioma heredado del panel: en o es.
  property string lang: "en"

  // `serviceState` y no `state`: `state` ya existe en todo Item —es la
  // máquina de estados de QML— y declararlo encima lo sombreaba.
  property string serviceState: "starting"
  property string detail: Strings.t("state.preparing", root.lang)
  readonly property bool healthy: serviceState === "running"
  readonly property bool paused: serviceState === "paused"
  readonly property bool failed: ["degraded", "missing_dependencies", "config_error", "stopped"].indexOf(serviceState) !== -1
  readonly property string stateLabel: failed
    ? Strings.t("state.attention", root.lang)
    : (paused
      ? Strings.t("state.paused", root.lang)
      : (healthy ? Strings.t("state.active", root.lang) : Strings.t("state.starting", root.lang)))
  // Con el servicio corriendo, sin omisión pendiente y sin nada que contar,
  // la cabecera de estado no tiene contenido: ni insignia ni frase. Sin esto
  // dejaría su hueco y su `spacing` en la columna, que es peor que la frase
  // que se acaba de quitar.
  readonly property bool silent: detail === "" && healthy

  readonly property color stateColor: failed ? Color.urgent : (healthy ? Color.accent : Color.muted)

  implicitWidth: Style.space(460)
  implicitHeight: lines.implicitHeight

  Accessible.role: Accessible.StaticText
  // Sin detalle, sin el punto y el hueco que dejaba «OmaPlain, Activo. ».
  Accessible.name: detail !== ""
    ? Strings.f("state.a11y", root.lang, stateLabel, detail)
    : Strings.f("state.a11y.short", root.lang, stateLabel)

  Column {
    id: lines
    anchors.left: parent.left
    anchors.right: parent.right
    spacing: Style.space(4)

    // El estado normal no se anuncia. Un servicio que está corriendo es lo
    // que se espera de él, y rotularlo «ACTIVO» gasta la primera línea de la
    // cabecera en decir que no pasa nada. La insignia sólo aparece cuando
    // hay algo que contar: pausado, arrancando o pidiendo atención.
    //
    // El `Accessible.name` de la raíz sí sigue nombrando el estado siempre:
    // ahí no hay un panel vivo delante del que deducirlo.
    Row {
      visible: !root.healthy
      spacing: Style.space(7)

      Rectangle {
        width: Style.space(8)
        height: width
        radius: width / 2
        color: root.stateColor
        anchors.verticalCenter: parent.verticalCenter
        Accessible.ignored: true
      }

      Text {
        text: root.stateLabel
        color: root.stateColor
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        font.bold: true
        font.capitalization: Font.AllUppercase
        font.letterSpacing: Style.spaceReal(0.8)
      }
    }

    // Un párrafo que envuelve, no un rótulo. El panel ya distingue las dos
    // cosas —0,68 para rótulos y foregrounds de control, 0,72 para prosa
    // que envuelve, y 1,45 de interlínea— y esta frase estaba puesta con
    // los valores de rótulo, que es lo que la dejaba más apagada y más
    // apretada que el subtítulo del veredicto que tiene tres líneas más
    // abajo. Medido sobre el render: 5,65:1 frente a 6,20:1.
    Text {
      width: parent.width
      visible: root.detail !== ""
      text: root.detail
      color: Util.alpha(Color.popups.text, 0.72)
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
      lineHeightMode: Text.ProportionalHeight
      lineHeight: 1.45
      wrapMode: Text.WordWrap
    }
  }
}
