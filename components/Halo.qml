import QtQuick
import QtQuick.Shapes
import qs.Commons

// El halo de acento que llevan todas las ilustraciones.
//
// Es un radial de verdad y no un disco, y ésa es toda la diferencia
// ([`0018`]). Al 13-16 % sobre un fondo tan oscuro, un círculo de color
// plano no llega a brillar y sí llega a ensuciar: se lee como un disco
// gris detrás del dibujo. Lo que se necesita es un borde que muera antes
// de llegar al canto, y para eso hace falta `QtQuick.Shapes`:
// `Rectangle.gradient` sólo hace vertical y horizontal.
//
// **Va centrado en el dibujo, no en el recuadro.** Cada composición ocupa
// un trozo distinto de su marco, y un halo centrado «bien» asoma por una
// esquina como una sombra mal puesta. Quien lo monta lo coloca por su
// centro; el componente no lo adivina.
Item {
  id: root

  // El alfa del centro. El paquete de diseño da 0.13-0.16 según el sitio.
  property real intensity: 0.145

  // Dónde se apaga del todo, en fracción del radio. Antes del canto: si
  // llegara al borde de la caja se vería el corte.
  property real spread: 0.67

  property color tint: Color.accent

  Accessible.ignored: true

  Shape {
    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
      // Sin trazo: el halo es relleno y nada más. Un contorno de un píxel
      // sería justo el disco recortado que esto viene a evitar.
      strokeWidth: -1
      fillGradient: RadialGradient {
        centerX: root.width / 2
        centerY: root.height / 2
        centerRadius: Math.max(root.width, root.height) / 2
        focalX: centerX
        focalY: centerY

        GradientStop { position: 0.0; color: Util.alpha(root.tint, root.intensity) }
        GradientStop { position: root.spread; color: Util.alpha(root.tint, 0) }
        GradientStop { position: 1.0; color: Util.alpha(root.tint, 0) }
      }

      PathRectangle {
        x: 0
        y: 0
        width: root.width
        height: root.height
      }
    }
  }
}
