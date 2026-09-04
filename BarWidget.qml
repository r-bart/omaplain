import QtQuick
import qs.Commons
import qs.Ui
import "components" as Omaplain
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

    // La marca, no un glifo prestado ([`0020`]). Antes iba el «pegar en
    // claro» de Material Design Icons, que es correcto y no es nuestro:
    // dice lo que hace la aplicación, y en una barra donde todo son iconos
    // de esa misma familia no dice **cuál** es. La marca sí, y es la misma
    // que el lanzador y la cabecera del panel.
    text: ""
    labelVisible: false
    hasVisualContent: true

    // Sin rótulo, el ancho que el kit calcula es el de un texto vacío: dos
    // márgenes y nada en medio. Aquí lo pone el dibujo. En una barra
    // vertical manda el kit, que ya sabe cuadrarla con las demás.
    horizontalMargin: 7.5
    fixedWidth: button.vertical ? -1 : marca.implicitWidth + Style.spaceReal(button.horizontalMargin) * 2
    fixedHeight: button.vertical ? marca.implicitHeight + Style.spaceReal(button.verticalPadding) * 2 : -1

    Omaplain.Mark {
      id: marca
      anchors.centerIn: parent
      // Un cuarto más pequeña que la primera medida. A 21 la onda cruzaba
      // casi todo el hueco y quedaba más ancha que cualquiera de sus
      // vecinas: en una barra de glifos cuadrados, un dibujo 3:1 que abarca
      // lo mismo de ancho pesa el doble. A 15,75 mide como ellas.
      markWidth: Style.spaceReal(15.75)
      // La tinta de la barra, para que acompañe a los demás iconos y siga
      // sus animaciones de color. El punto no: ése va en el acento del
      // tema, y es lo único de la marca que el tema mueve.
      ink: button.foreground
      dot: Color.accent
    }

    Accessible.role: Accessible.Button
    Accessible.name: Strings.t("bar.a11y", Strings.fromLocale(Qt.locale().name))

    // Sólo el izquierdo. El derecho no hace nada, y así se queda ([`0021`]):
    // `pasteClean` reescribe el portapapeles, y al reescribirlo el original
    // deja de existir —OmaPlain no guarda historial—, así que un gesto que se
    // dispara sin querer no puede llevarlo colgado. La acción ya tiene tres
    // vías con la mano puesta encima: el botón del panel, el CLI y el
    // automático.
    onPressed: function(mouseButton) {
      if (!root.bar || mouseButton === Qt.RightButton) return
      root.bar.run("omarchy-shell shell toggle io.github.r-bart.omaplain")
    }
  }
}
