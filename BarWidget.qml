import QtQuick
import qs.Commons
import qs.Ui
import "components/Strings.js" as Strings

// El icono de la barra: la única forma de abrir el panel sin escribir un
// comando, junto con la entrada `.desktop` del lanzador ([`0010`]).
//
// Declararlo lo hace disponible, no colocado: quien decide si aparece es
// `bar.layout` en `shell.json`, que es el mando que Omarchy ya tiene para
// esto. Aquí no hay ningún ajuste de «mostrar en la barra» porque duplicaría
// ese mando y competiría con él.
//
// No lee el portapapeles ni recibe su contenido. Llama a `toggle` y nada más:
// la frontera de la `0005` no se mueve.
BarWidget {
  id: root
  moduleName: "io.github.r-bart.omaplain"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar

    // Pegar en claro, que es lo que el producto hace. Del rango de Material
    // Design Icons de la Nerd Font, la misma familia que el panel usa para
    // el engranaje y las flechas.
    text: "󰅌"
    horizontalMargin: 7.5

    Accessible.role: Accessible.Button
    Accessible.name: Strings.t("bar.a11y", Strings.fromLocale(Qt.locale().name))

    // Sólo el izquierdo. El derecho queda libre a propósito: `pasteClean`
    // escribe en el portapapeles, y darle un gesto que se dispara sin querer
    // merece su propia decisión.
    onPressed: function(mouseButton) {
      if (!root.bar || mouseButton === Qt.RightButton) return
      root.bar.run("omarchy-shell shell toggle io.github.r-bart.omaplain")
    }
  }
}
