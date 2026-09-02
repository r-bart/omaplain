import QtQuick
import qs.Commons
import qs.Ui
import "Strings.js" as Strings

// La cubierta de vaho. Tapa el contenido hasta que alguien pide verlo, y
// se puede limpiar arrastrando encima como el vaho de un espejo.
//
// Es opaca a propósito. Una cubierta translúcida deja leer, y entonces no
// cubre nada: este panel se abre encima de lo que el usuario esté
// compartiendo. El aire de vapor lo dan el moteado y el borde suave del
// trazo, no la transparencia.
//
// El barrido se guarda como trazos, no como píxeles, porque cada fotograma
// se repinta entero para que la neblina derive. `docs/notes/SPIKE.md` mide ese
// repintado en 1,5 ms, un 4,5 % del presupuesto a 30 fps.
Canvas {
  id: root

  // Idioma heredado del panel: en o es.
  property string lang: "en"

  // La fase F conducirá esta propiedad. Hasta entonces se queda en true,
  // que es el comportamiento de hoy.
  property bool motionEnabled: true
  property int seed: 7
  property string hint: Strings.t("fog.hint", root.lang)

  signal cleared()

  readonly property real brush: Style.space(34)
  property var strokes: []
  property real phase: 0

  // La rejilla de lo ya limpiado. Cada celda mide medio pincel, y un trazo
  // sólo se guarda si cae en una celda que aún no tenía ninguno: así la
  // lista de trazos queda acotada por la superficie —unas ciento sesenta
  // celdas en una fila— y no por lo que dure el gesto. Antes crecía con
  // cada arrastre y cada fotograma pintaba un gradiente por trazo, treinta
  // veces por segundo, mientras la fila estuviera a la vista.
  //
  // La misma rejilla dice cuánto se ha limpiado, sin leer píxeles: eran
  // ciento cuarenta y siete `getImageData` por cada suelta del ratón.
  readonly property real cell: brush / 2
  property var wiped: ({})
  property int wipedCount: 0

  // 0009: bajo llave la cubierta no escucha. Antes sólo se callaba la
  // señal `cleared`, pero el arrastre seguía abriendo huecos, y por los
  // huecos se leía el texto de debajo: la lista «no destapar nunca» se
  // podía destapar a mano. Ahora el ratón no entra.
  property bool locked: false

  // El remate. Quien ha limpiado un cuarto de la cubierta ya ha dicho
  // que quiere ver; hacerle frotar el resto es trabajo sin información.
  // Al soltar, un círculo crece desde donde estaba el dedo hasta comerse
  // lo que queda, y entonces se avisa. Un clic suelto o un roce no bastan:
  // descubrir sigue siendo un acto, no un accidente.
  readonly property real finishThreshold: 0.25
  property real sweep: 0
  property point sweepOrigin: Qt.point(0, 0)
  readonly property real reach: Math.sqrt(width * width + height * height)

  renderTarget: Canvas.FramebufferObject
  renderStrategy: Canvas.Cooperative

  function reset() {
    finishing.stop()
    strokes = []
    wiped = ({})
    wipedCount = 0
    sweep = 0
    phase = 0
    requestPaint()
  }

  function finish(x, y) {
    sweepOrigin = Qt.point(x, y)
    if (!motionEnabled) {
      sweep = 1
      requestPaint()
      root.cleared()
      return
    }
    finishing.restart()
  }

  onSweepChanged: requestPaint()

  NumberAnimation {
    id: finishing
    target: root
    property: "sweep"
    from: 0
    to: 1
    // Respuesta a una acción: por debajo de los 400 ms, y arrancando
    // despacio para que se vea salir de donde estaba el dedo.
    duration: 380
    easing.type: Easing.InOutCubic
    onFinished: root.cleared()
  }

  // Todo el vaho se deriva de los tokens del tema. La primera versión
  // llevaba un lavanda fijado a mano, que sobre un tema verde o ámbar
  // seguía siendo lila: una paleta propia colada por la puerta de atrás,
  // justo lo que F3.9 prohíbe.
  function mix(a, b, t) {
    return Qt.rgba(a.r + (b.r - a.r) * t,
                   a.g + (b.g - a.g) * t,
                   a.b + (b.b - a.b) * t, 1)
  }

  // A medio camino entre el fondo y el texto del panel: sea cual sea el
  // tema, queda a un tono que ni se confunde con la superficie ni
  // deslumbra, y siempre tapa el texto que hay debajo.
  readonly property color body: mix(Color.popups.background, Color.popups.text, 0.55)

  // La condensación coge la luz, así que el moteado tira siempre hacia el
  // extremo claro del tema, sea el fondo o el texto quien lo tenga.
  readonly property color glint: Color.popups.background.hslLightness > Color.popups.text.hslLightness
    ? Color.popups.background : Color.popups.text
  // Y la pista, hacia el extremo contrario al cuerpo del vaho.
  readonly property color hintInk: body.hslLightness > 0.5
    ? Util.alpha(mix(Color.popups.text, Color.popups.background, 0.15), 0.82)
    : Util.alpha(glint, 0.88)

  onPaint: {
    var ctx = getContext("2d")
    ctx.reset()

    // El fondo no se mueve nunca: es lo que garantiza que tape.
    ctx.fillStyle = root.body
    ctx.fillRect(0, 0, width, height)

    // Dos capas de manchas a distinta velocidad. El desfase entre ambas es
    // lo que lee como profundidad y no como una imagen deslizándose.
    root.mist(ctx, root.phase * 1.0, 26, 0.20, 62)
    root.mist(ctx, -root.phase * 0.62 + 41, 18, 0.14, 104)

    ctx.globalCompositeOperation = "source-atop"
    ctx.fillStyle = root.hintInk
    ctx.font = Style.font.caption + "px " + Style.font.family
    ctx.textAlign = "center"
    ctx.textBaseline = "middle"
    ctx.fillText(root.hint, width / 2, height / 2)

    // Los trazos van al final, sobre todo lo demás, para que la neblina
    // derive por debajo sin volver a tapar lo ya limpiado.
    ctx.globalCompositeOperation = "destination-out"
    for (var i = 0; i < root.strokes.length; i++) {
      var s = root.strokes[i]
      var e = ctx.createRadialGradient(s.x, s.y, 0, s.x, s.y, root.brush)
      e.addColorStop(0, "rgba(0,0,0,1)")
      e.addColorStop(0.62, "rgba(0,0,0,0.94)")
      e.addColorStop(1, "rgba(0,0,0,0)")
      ctx.fillStyle = e
      ctx.beginPath(); ctx.arc(s.x, s.y, root.brush, 0, Math.PI * 2); ctx.fill()
    }
    // El remate: un solo círculo que crece desde el último punto hasta
    // alcanzar la esquina más lejana, con el mismo borde suave que los
    // trazos para que se lea como el mismo gesto que continúa solo.
    if (root.sweep > 0) {
      var radius = root.brush + root.sweep * root.reach
      var f = ctx.createRadialGradient(root.sweepOrigin.x, root.sweepOrigin.y, 0,
                                       root.sweepOrigin.x, root.sweepOrigin.y, radius)
      f.addColorStop(0, "rgba(0,0,0,1)")
      f.addColorStop(0.72, "rgba(0,0,0,0.96)")
      f.addColorStop(1, "rgba(0,0,0,0)")
      ctx.fillStyle = f
      ctx.beginPath(); ctx.arc(root.sweepOrigin.x, root.sweepOrigin.y, radius, 0, Math.PI * 2); ctx.fill()
    }
    ctx.globalCompositeOperation = "source-over"
  }

  function mist(ctx, drift, blobs, alpha, radius) {
    for (var i = 0; i < blobs; i++) {
      // Serie determinista: el moteado no debe reorganizarse en cada
      // repintado, sólo desplazarse.
      var n = (i + 1) * (root.seed + 17)
      var x = ((n * 73 + drift) % (width + 180)) - 90
      var y = ((n * 131) % (height + 180)) - 90
      var r = radius * (0.55 + ((n % 7) / 7) * 0.9)
      var g = ctx.createRadialGradient(x, y, 0, x, y, r)
      var a = alpha * (0.4 + ((n % 5) / 5) * 0.6)
      g.addColorStop(0, Util.alpha(root.glint, a))
      g.addColorStop(0.6, Util.alpha(root.glint, a * 0.35))
      g.addColorStop(1, Util.alpha(root.glint, 0))
      ctx.fillStyle = g
      ctx.beginPath(); ctx.arc(x, y, r, 0, Math.PI * 2); ctx.fill()
    }
  }

  Timer {
    // Ambiente, no respuesta a una acción: 30 fps bastan y se para cuando
    // el movimiento está desactivado o la cubierta no se ve.
    interval: 33
    running: root.motionEnabled && root.visible && root.width > 0
    repeat: true
    onTriggered: { root.phase += 1.6; root.requestPaint() }
  }

  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton
    preventStealing: true
    // Bajo llave no hay gesto; y mientras el remate corre, tampoco.
    enabled: !root.locked && !finishing.running

    property point last: Qt.point(-1, -1)

    function wipe(x, y) {
      var added = false
      if (last.x >= 0) {
        // Interpolar el segmento: un arrastre rápido dejaría huecos.
        var dx = x - last.x, dy = y - last.y
        var steps = Math.max(1, Math.ceil(Math.sqrt(dx * dx + dy * dy) / 11))
        for (var i = 1; i <= steps; i++)
          added = root.stroke(last.x + dx * i / steps, last.y + dy * i / steps) || added
      } else {
        added = root.stroke(x, y)
      }
      last = Qt.point(x, y)
      if (added) root.requestPaint()
    }

    onPressed: function(mouse) { last = Qt.point(-1, -1); wipe(mouse.x, mouse.y) }
    onPositionChanged: function(mouse) { if (pressed) wipe(mouse.x, mouse.y) }
    onReleased: function(mouse) {
      last = Qt.point(-1, -1)
      // Se decide al soltar, no en cada trazo: una vez por gesto. Pasado
      // el umbral, el resto se limpia solo desde donde se soltó.
      if (root.clearedFraction() >= root.finishThreshold) root.finish(mouse.x, mouse.y)
    }
    onCanceled: last = Qt.point(-1, -1)
  }

  // Guarda un trazo si su celda estaba sin limpiar. Devuelve si lo guardó.
  function stroke(x, y) {
    if (root.cell <= 0) return false
    var key = Math.floor(x / root.cell) + "," + Math.floor(y / root.cell)
    if (root.wiped[key] === true) return false
    root.wiped[key] = true
    root.wipedCount += 1
    var next = root.strokes
    next.push({ x: x, y: y })
    root.strokes = next
    return true
  }

  // La parte de la superficie con algún trazo encima, por celdas. El
  // pincel mide dos celdas de radio, así que lo limpiado de verdad es
  // siempre algo más que esto.
  function clearedFraction() {
    if (root.cell <= 0 || width <= 0 || height <= 0) return 0
    var total = Math.ceil(width / root.cell) * Math.ceil(height / root.cell)
    return total === 0 ? 0 : root.wipedCount / total
  }
}
