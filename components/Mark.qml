import QtQuick
import QtQuick.Shapes
import qs.Commons

// La marca: el mismo trazo que el icono del lanzador, dibujado.
//
// **No es el SVG.** Traer `io.github.r-bart.omaplain.svg` con un `Image`
// habría sido una línea, pero un fichero llega con sus colores dentro: el
// trazo en `#1B201E` y el punto en `#3E8E79`, que sobre un tema oscuro es
// tinta negra sobre fondo negro. Dibujado, el trazo sale en la tinta del
// sitio donde se pone —la barra o la cabecera— y el punto en el acento del
// tema ([`0020`]).
//
// La geometría es la del SVG palabra por palabra: la misma `d`, la misma
// caja de 24 × 24, el mismo grosor. `tests/unit/test_launch_surfaces.py`
// compara las dos cadenas, así que el lanzador y el panel no pueden
// separarse sin que un test lo diga.
//
// Lo que sí cambia es el encuadre. El dibujo ocupa 20,45 × 6,8 de esa caja
// —es tres veces más ancho que alto—, y las 17 unidades de aire que sobran
// por arriba y por abajo convierten cualquier `Row` en una fila con un
// agujero. Así que la caja se recorta a la tinta y se coloca por su ancho.
Item {
  id: root

  // El trazo. Por defecto la tinta de la barra; en el panel se le pasa la
  // de los popups.
  property color ink: Color.foreground

  // El punto. Va en el acento y no en la tinta a propósito: es la única
  // parte de la marca que el tema puede mover, y en los temas que no
  // declaran acento vale lo mismo que el trazo y se lee como un final
  // engordado, que es exactamente lo que es.
  property color dot: Color.accent

  // Se pide por el ancho, que es la dimensión que manda en un dibujo 3:1.
  // El alto sale solo: aplastarlo o estirarlo lo rompe.
  property real markWidth: Style.space(24)

  // La `d` del SVG, sin tocar una coma.
  //
  // Los nodos caen en la cresta y en el valle, cada uno entra y sale en
  // horizontal, y el reparto 1.61 / 2.28 iguala la curvatura a los dos
  // lados de cada nodo. Nada de eso se puede redondear «para que quede más
  // limpio»: el fichero SVG lo explica largo y aquí vale igual.
  readonly property string path: "M2.65 12c1.61 0 2.42-2.5 4.03-2.5c2.28 0 3.42 5 5.7 5c1.61 0 2.42-2.5 4.03-2.5h1.4"

  // La caja de tinta dentro de las 24 × 24, tapas redondas incluidas: el
  // trazo asoma media anchura (0,9) por cada extremo, y el punto llega
  // hasta 20,95 + 1,25.
  readonly property real inkX: 1.75
  readonly property real inkY: 8.6
  readonly property real inkWidth: 20.45
  readonly property real inkHeight: 6.8

  readonly property real k: markWidth / inkWidth

  implicitWidth: markWidth
  implicitHeight: inkHeight * k

  // Decorativa: quien la acompaña ya dice el nombre.
  Accessible.ignored: true

  Shape {
    // Las 24 × 24 enteras, corridas para que la tinta empiece en el origen.
    x: -root.inkX * root.k
    y: -root.inkY * root.k
    width: 24
    height: 24

    // Escalar la caja y no reescribir la `d`: es lo que mantiene la
    // geometría comparable con la del fichero. Y con el trazador de curvas
    // la escala no cuesta nitidez —teselar a 24 y estirar sí la costaría—,
    // que es justo lo que hace falta aquí: la misma marca a 20 px en la
    // barra y a 20 px en la cabecera, sin dos juegos de números.
    preferredRendererType: Shape.CurveRenderer
    transform: Scale { xScale: root.k; yScale: root.k }

    ShapePath {
      strokeColor: root.ink
      strokeWidth: 1.8
      fillColor: "transparent"
      capStyle: ShapePath.RoundCap
      joinStyle: ShapePath.RoundJoin
      PathSvg { path: root.path }
    }
  }

  // El punto, aparte. Un círculo de verdad y no un arco en la misma
  // `Shape`: un `Rectangle` redondeado lo resuelve el mismo nodo de
  // escena que ya dibuja el resto del panel, y aquí no hay curva que
  // igualar.
  Rectangle {
    x: (20.95 - 1.25 - root.inkX) * root.k
    y: (12 - 1.25 - root.inkY) * root.k
    width: 2.5 * root.k
    height: width
    radius: width / 2
    color: root.dot
    antialiasing: true
  }
}
