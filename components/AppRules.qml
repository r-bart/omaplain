import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui
import "Strings.js" as Strings

// Una aplicación y sus cuatro reglas.
//
// Antes había dos formularios idénticos —dos campos, dos rótulos que sólo se
// diferenciaban en una palabra, dos botones de «app detectada» que hacían
// cosas distintas y cuatro botones de confirmar— y el usuario tenía que
// elegir la sección antes de saber qué quería. Aquí el sujeto es la
// aplicación: la eliges una vez y decides después.
//
// Las cuatro siguen siendo independientes, que es lo que la `0009` protege:
// cuatro interruptores separados es más separación que dos botones pegados
// de los que Enter elegía uno sin decirlo.
Column {
  id: root

  property string lang: "en"
  property string appClass: ""

  property bool covered: false
  property bool blocked: false
  property bool source: false
  property bool target: false

  // Todavía no está en ninguna lista: la trajo el selector o el campo y no
  // se guardará hasta que se marque una regla. Se dice, en vez de dejar que
  // parezca guardada.
  readonly property bool pending: !covered && !blocked && !source && !target

  signal ruleToggled(string kind, bool next)
  signal removeRequested(string appClass)
  signal focusEntered(Item item)

  spacing: Style.space(8)

  // Una regla fina abre cada tarjeta. Sin ella, el nombre de la aplicación
  // caía a la misma distancia del formulario que del bloque anterior y las
  // cinco piezas de una tarjeta no se leían como una sola cosa. Es la misma
  // regla que separa la cabecera del panel.
  Rectangle {
    width: parent.width
    height: Math.max(1, Style.normalBorderWidth)
    color: Util.alpha(Color.popups.text, 0.14)
  }

  Item {
    width: parent.width
    height: removeButton.height

    Column {
      anchors.left: parent.left
      anchors.right: removeButton.left
      anchors.rightMargin: Style.space(12)
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(2)

      Text {
        id: appName
        width: parent.width
        text: root.appClass
        color: Color.popups.text
        font.family: Style.font.family
        font.pixelSize: Style.font.subtitle
        font.bold: true
        // Por el medio, que es donde una clase larga se distingue: el
        // principio y el final son lo que la identifica.
        elide: Text.ElideMiddle

        // Recortar sin dejar salida esconde justo el dato que hay que
        // comprobar para saber si la regla es la correcta. El nombre entero
        // vive en el rótulo accesible, y el ratón lo saca cuando se ha
        // recortado —sólo entonces, o sería un globo que no dice nada.
        Accessible.role: Accessible.StaticText
        Accessible.name: root.appClass

        HoverHandler { id: appNameHover }

        ToolTip {
          visible: appNameHover.hovered && appName.truncated
          text: root.appClass
          delay: 400
        }
      }

      Text {
        width: parent.width
        visible: root.pending
        text: Strings.t("apps.pending", root.lang)
        color: Util.alpha(Color.popups.text, 0.72)
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        wrapMode: Text.WordWrap
      }
    }

    PanelButton {
      id: removeButton
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      text: Strings.t("apps.remove", root.lang)
      Accessible.name: Strings.f("apps.remove.a11y", root.lang, root.appClass)
      onFocusEntered: function(item) { root.focusEntered(item) }
      onClicked: root.removeRequested(root.appClass)
    }
  }

  // Las dos familias de la `0009`: si se lee y si se limpia. No se mezclan,
  // y ahora se ve que no se mezclan.
  Text {
    text: Strings.t("rules.reading", root.lang)
    color: Util.alpha(Color.popups.text, 0.68)
    font.family: Style.font.family
    font.pixelSize: Style.font.caption
    font.capitalization: Font.AllUppercase
    font.letterSpacing: Style.spaceReal(0.9)
    Accessible.role: Accessible.Heading
    Accessible.name: text
  }

  SettingRow {
    width: parent.width
    label: Strings.t("rules.covered", root.lang)
    checked: root.covered
    onFocusEntered: function(item) { root.focusEntered(item) }
    onClicked: root.ruleToggled("covered", !root.covered)
  }

  SettingRow {
    width: parent.width
    label: Strings.t("rules.blocked", root.lang)
    checked: root.blocked
    onFocusEntered: function(item) { root.focusEntered(item) }
    onClicked: root.ruleToggled("blocked", !root.blocked)
  }

  Text {
    text: Strings.t("rules.cleaning", root.lang)
    color: Util.alpha(Color.popups.text, 0.68)
    font.family: Style.font.family
    font.pixelSize: Style.font.caption
    font.capitalization: Font.AllUppercase
    font.letterSpacing: Style.spaceReal(0.9)
    Accessible.role: Accessible.Heading
    Accessible.name: text
  }

  SettingRow {
    width: parent.width
    label: Strings.t("rules.source", root.lang)
    checked: root.source
    onFocusEntered: function(item) { root.focusEntered(item) }
    onClicked: root.ruleToggled("source", !root.source)
  }

  SettingRow {
    width: parent.width
    label: Strings.t("rules.target", root.lang)
    checked: root.target
    onFocusEntered: function(item) { root.focusEntered(item) }
    onClicked: root.ruleToggled("target", !root.target)
  }
}
