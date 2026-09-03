import QtQuick
import QtQuick.Effects
import qs.Commons

// El grano: lo que se ve de una copia que el control **no lee**.
//
// La tarjeta no cambia —sale por el otro lado exactamente como entró—, es
// que nadie ha mirado dentro. Que es literalmente lo que hace el helper
// con una imagen: mira el tipo de la oferta y se planta.
//
// Son tres capas a tres velocidades distintas, y las tres velocidades son
// el truco: con una sola se lee como una textura puesta encima, no como
// una señal. Las proporciones entre ellas son las del paquete de diseño
// (1/5, 1/9 y −1/24); la base se eligió para que el barrido fino crucera
// como un rastreo y no como un parpadeo.
//
// **No hay modo `screen`.** Qt Quick no tiene modos de fusión sin
// `ShaderEffect`, y el paquete lo descarta ([`0018`]). Sobre un fondo tan
// oscuro la mezcla normal se le acerca mucho, porque `screen` apenas se
// separa de ella cuando el fondo es casi negro; el ruido se pinta blanco
// con el alfa modulado, que es la aproximación que mejor lo imita.
//
// El grano no escala con el espaciado ni con la fuente. Es una textura, no
// una medida: a doble escala se querría el mismo grano sobre una tarjeta
// más grande, no un grano del doble de gordo.
Item {
  id: root

  // 0 = la tarjeta se lee entera; 1 = sólo hay señal.
  property real intensity: 0

  property bool motionEnabled: true

  // El lado de la baldosa de ruido, en píxeles de dibujo.
  readonly property int tile: 120

  // Cuántas veces se ha pintado el ruido. Tiene que quedarse en uno: la
  // textura se calcula al crearse y no se vuelve a tocar, sólo se le anima
  // el desplazamiento. Lo comprueba `tests/qml/TestRoot.qml`.
  property int paintCount: 0
  property string noiseUrl: ""

  // El radio de la tarjeta que cubre. Sin esto el grano llena un
  // rectángulo y le come las esquinas redondeadas: `clip` no vale, porque
  // recorta contra la caja y no contra el radio.
  property real radius: 0

  readonly property int fineStep: 3
  readonly property int wideStep: 9

  property real noisePhase: 0
  property real finePhase: 0
  property real widePhase: 0

  opacity: intensity
  visible: intensity > 0.004
  Accessible.ignored: true

  // El molde de la máscara: hermano de las capas y nunca dentro de ellas,
  // o se enmascararía a sí mismo.
  Rectangle {
    id: mould
    anchors.fill: parent
    radius: root.radius
    color: "black"
    visible: false
    layer.enabled: root.radius > 0
  }

  Item {
    id: layers
    anchors.fill: parent
    clip: true

    layer.enabled: root.radius > 0
    layer.effect: MultiEffect {
      maskEnabled: true
      maskSource: mould
    }

    // La baldosa, pintada una vez. El paquete daba por hecha una textura PNG
    // de 120 × 120 que no existe, y este repositorio no versiona binarios
    // fuera de `docs/images/`: se pinta aquí y se sirve como data URL, que
    // es lo que `Image.Tile` sabe repetir.
    //
    // Los valores salen de los mismos hashes deterministas que la balística
    // de los añicos, no de `Math.random()`: se ve irregular y dos ejecuciones
    // dan la misma imagen, así que una captura de un test puede compararse
    // consigo misma.
    Canvas {
      id: noiseSource
      width: root.tile
      height: root.tile
      visible: false

      // El hash tiene que mezclar las dos coordenadas por separado. La
      // primera versión usaba el multiplicador de Knuth sobre el índice
      // del ráster (`x + 120·y`), que es lineal en `x`: salieron diagonales
      // regulares, no ruido. Un tejido, exactamente lo que el paquete de
      // diseño avisa de que no puede parecer.
      function grain(x, y) {
        var n = (x * 2654435761) ^ (y * 2246822519)
        n = n ^ (n >>> 13)
        n = Math.imul(n, 1274126177)
        n = n ^ (n >>> 16)
        return (n >>> 0) / 4294967296
      }

      onPaint: {
        var ctx = getContext("2d")
        var img = ctx.createImageData(root.tile, root.tile)
        var d = img.data
        for (var y = 0; y < root.tile; y++) {
          for (var x = 0; x < root.tile; x++) {
            // Tres octavas, como la turbulencia fractal del prototipo: el
            // grano fino, y dos escalas que lo agrupan en manchas. Con una
            // sola se lee como una trama impresa y no como una señal.
            var v = 0.50 * noiseSource.grain(x, y)
              + 0.32 * noiseSource.grain(Math.floor(x / 3), Math.floor(y / 3) + 977)
              + 0.18 * noiseSource.grain(Math.floor(x / 7), Math.floor(y / 7) + 4021)
            var k = (x + root.tile * y) * 4
            d[k] = 255; d[k + 1] = 255; d[k + 2] = 255
            // La potencia empuja el grano hacia lo oscuro: sin ella la capa
            // es una niebla plana en vez de puntos. Y el tope no llega a 255
            // porque a plena intensidad el grano cubre la tarjeta entera: a
            // 210 era lo más brillante de la pantalla, por encima del texto
            // del paso que la acompaña, y la ilustración no manda ahí.
            d[k + 3] = Math.round(Math.pow(v, 2.2) * 150)
          }
        }
        ctx.drawImage(img, 0, 0)
        root.paintCount += 1
        root.noiseUrl = noiseSource.toDataURL("image/png")
      }

      Component.onCompleted: requestPaint()
    }

    // Capa 1 · el ruido.
    Image {
      source: root.noiseUrl
      fillMode: Image.Tile
      // Fija la baldosa en píxeles de dibujo: sin esto el ruido sale del
      // doble de gordo en una pantalla de densidad doble, porque el lienzo
      // se guarda a resolución de dispositivo.
      sourceSize: Qt.size(root.tile, root.tile)
      width: root.width
      height: root.height + root.tile
      y: -root.tile + root.noisePhase * root.tile
    }

    // Capa 2 · el barrido fino, a favor y deprisa.
    Item {
      id: fine
      width: root.width
      height: root.height + root.fineStep
      y: -root.fineStep + root.finePhase * root.fineStep

      Repeater {
        model: Math.ceil(fine.height / root.fineStep) + 1
        delegate: Rectangle {
          required property int index
          width: fine.width
          height: 1
          y: index * root.fineStep
          // El prototipo pone 0.42, pero apilado en modo `screen`, que
          // sobre un fondo casi negro casi no oscurece. En mezcla normal
          // ese alfa convierte la tarjeta en una persiana: se baja hasta
          // que el barrido vuelva a ser barrido y no reja ([`0018`]).
          color: Util.alpha(Color.accent, 0.16)
        }
      }
    }

    // Capa 3 · la trama ancha, en contra y despacio. Es la que impide que
    // las otras dos se lean como una sola cosa moviéndose.
    Item {
      id: wide
      width: root.width
      height: root.height + root.wideStep
      y: -root.widePhase * root.wideStep

      Repeater {
        model: Math.ceil(wide.height / root.wideStep) + 1
        delegate: Rectangle {
          required property int index
          width: wide.width
          height: 2
          y: index * root.wideStep
          color: Util.alpha(Color.popups.text, 0.07)
        }
      }
    }
  }

  NumberAnimation {
    target: root; property: "noisePhase"; from: 0; to: 1
    duration: 36000; loops: Animation.Infinite
    running: root.motionEnabled && root.visible
  }

  NumberAnimation {
    target: root; property: "finePhase"; from: 0; to: 1
    duration: 500; loops: Animation.Infinite
    running: root.motionEnabled && root.visible
  }

  NumberAnimation {
    target: root; property: "widePhase"; from: 0; to: 1
    duration: 7200; loops: Animation.Infinite
    running: root.motionEnabled && root.visible
  }
}
