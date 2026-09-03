import QtQuick
import QtQuick.Effects
import qs.Commons
import qs.Ui

// La receta de superficie del panel, en un solo sitio ([`0018`]).
//
// Son cinco declaraciones —relleno degradado, borde tenue, sombra, filo
// claro arriba y un brillo interior que muere a media altura— y estaban
// escritas a mano en diecisiete superficies. Ahí ya se notaba: dos
// ejemplares del carrusel llevaban radios distintos sin que nada lo
// pidiera.
//
// El relleno va en degradado **vertical** y no a 150°. `Rectangle.gradient`
// sólo hace vertical y horizontal; el ángulo pediría un `Shape` por
// superficie, y en la cinta del control hay cuatro moviéndose a la vez.
// Diez puntos de alfa repartidos en diagonal no se pagan con eso.
//
// Ninguna medida de aquí es una constante en píxeles: el filo es una raya
// de un píxel y el brillo es una fracción del alto, así que la superficie
// crece con lo que lleve dentro y con el tamaño de fuente que tenga puesto
// quien la mira.
Item {
  id: root

  // "glass"  la tarjeta de siempre
  // "dimmed" la hoja de detrás: sin filo ni brillo, y menos sombra
  // "small"  las piezas de 100 × 96 del carrusel
  // "sunken" un campo hundido dentro de otra tarjeta
  property string material: "glass"

  property real radius: isSmall ? Math.max(2, Style.cornerRadius - Style.space(2))
                                : Style.cornerRadius

  // La sombra se apaga donde la superficie tenga que dejar ver lo que hay
  // detrás. Ver el molde, más abajo: los dos van juntos y no por capricho.
  property bool shadowEnabled: true

  // El color sobre el que se apoya. Se usa para el molde de la sombra, así
  // que tiene que ser el del fondo que la superficie tiene debajo.
  property color base: Color.popups.background

  readonly property bool isDimmed: material === "dimmed"
  readonly property bool isSmall: material === "small"
  readonly property bool isSunken: material === "sunken"

  // La tinta de la sombra no es un literal: sale del fondo del tema
  // oscurecido. Escrita como `#040a14` sería una mancha negra en cuanto
  // alguien pusiera un tema claro, y una sombra tiene que seguir siendo
  // sombra en los dos.
  readonly property color shadowInk: Qt.darker(Color.background, 2.4)

  readonly property color fillTop: isSunken ? Util.alpha(Color.background, 0.34)
    : Util.alpha(Color.popups.text, isDimmed ? 0.07 : 0.15)
  readonly property color fillBottom: isSunken ? Util.alpha(Color.background, 0.34)
    : Util.alpha(Color.popups.text, isDimmed ? 0.03 : 0.05)

  readonly property real edgeAlpha: isDimmed ? 0.13 : isSunken ? 0.18 : 0.26

  // Filo y brillo son el escalón claro de arriba. La hoja atenuada y el
  // campo hundido no los llevan: uno está detrás y el otro está dentro, y
  // los dos dejarían de leerse como tales con un canto iluminado.
  readonly property real edgeLightAlpha: isDimmed || isSunken ? 0 : isSmall ? 0.07 : 0.08
  readonly property real sheenAlpha: isDimmed || isSunken ? 0 : isSmall ? 0.05 : 0.055
  readonly property real sheenFraction: isSmall ? 0.44 : 0.46

  readonly property real dropOffset: isSmall ? 6 : isDimmed ? 8 : 12
  readonly property real dropBlur: isSmall ? 14 : isDimmed ? 18 : 26
  readonly property real dropAlpha: isSmall ? 0.45 : isDimmed ? 0.40 : 0.50

  readonly property bool casts: shadowEnabled && !isSunken

  // El molde de la sombra, y por qué es opaco.
  //
  // `MultiEffect` saca la sombra del alfa de lo que le das. Colgada de la
  // superficie entera pasaban dos cosas, las dos malas: el relleno del
  // cristal es un 15 % de alfa, así que la sombra salía al 15 % de lo que
  // pedía el diseño y no se veía; y **el texto de dentro proyectaba la
  // suya**, un fantasma borroso que se leía a través del propio cristal.
  //
  // Así que la sombra la proyecta una silueta aparte, opaca y del color
  // del fondo que la superficie tiene debajo. Sobre el panel no se
  // distingue del cristal translúcido de siempre —el panel tiene color
  // plano detrás, que es el supuesto del que parte toda la receta—, y a
  // cambio la sombra sale a su fuerza y sólo de la caja.
  //
  // Donde sí se nota es encima del halo, porque el molde lo tapa. Ahí se
  // apaga la sombra con `shadowEnabled: false` y el cristal vuelve a
  // dejar pasar lo de detrás.
  Rectangle {
    id: molde
    anchors.fill: parent
    radius: root.radius
    color: root.base
    visible: root.casts
    layer.enabled: root.casts
    layer.effect: MultiEffect {
      shadowEnabled: true
      shadowColor: Util.alpha(root.shadowInk, root.dropAlpha)
      shadowVerticalOffset: Style.space(root.dropOffset)
      shadowHorizontalOffset: 0
      blurMax: 32
      shadowBlur: Math.min(1, Style.spaceReal(root.dropBlur) / 32)
    }
  }

  BorderSurface {
    id: cuerpo
    anchors.fill: parent
    radius: root.radius
    borderSpec: Border.flat(Util.alpha(Color.popups.text, root.edgeAlpha),
                            Math.max(1, Style.space(1)))
    clip: true

    gradient: Gradient {
      GradientStop { position: 0.0; color: root.fillTop }
      GradientStop { position: 1.0; color: root.fillBottom }
    }

    // El campo hundido no proyecta sombra: la recibe. Un filete oscuro
    // pegado al borde de arriba es lo que dice «esto está por debajo del
    // plano», y cuesta un rectángulo en vez de una capa de composición.
    Rectangle {
      visible: root.isSunken
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.right: parent.right
      height: Math.max(1, Style.space(3))

      gradient: Gradient {
        GradientStop { position: 0.0; color: Util.alpha(root.shadowInk, 0.45) }
        GradientStop { position: 1.0; color: Util.alpha(root.shadowInk, 0) }
      }
    }

    // El filo: una raya de un píxel siguiendo el canto de arriba. Va
    // metida hacia dentro medio radio para no asomar por las esquinas.
    Rectangle {
      visible: root.edgeLightAlpha > 0
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.topMargin: cuerpo.borderTop
      anchors.leftMargin: root.radius / 2
      anchors.rightMargin: root.radius / 2
      height: 1
      color: Qt.rgba(1, 1, 1, root.edgeLightAlpha)
    }

    // Y el brillo, que muere a media altura. Sin él la tarjeta se lee
    // plana: en un tema oscuro la profundidad sale de un escalón claro
    // arriba, no de un velo por encima.
    Rectangle {
      visible: root.sheenAlpha > 0
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.right: parent.right
      height: parent.height * root.sheenFraction

      gradient: Gradient {
        GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, root.sheenAlpha) }
        GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0) }
      }
    }
  }
}
