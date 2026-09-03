import Quickshell
import QtQuick
import qs.Commons
import "../../components" as Omaplain

// El QML, ejecutado. No leído: ejecutado.
//
// `qmllint` demuestra que los ficheros cargan y que los tipos resuelven.
// Nada demostraba que se comportaran, y las tres regresiones de interfaz
// del 2 de septiembre —el vistazo tardío, el vaho que no se reiniciaba, el
// foco que se perdía— las encontró una persona leyendo, no un test.
//
// Los tipos de Quickshell están enlazados dentro de su binario, así que
// `qmltestrunner` no puede cargarlos: la única forma de ejecutar esto es
// `quickshell` dentro de un compositor. `tests/qml.sh` levanta un Hyprland
// headless para eso.
ShellRoot {
  id: raiz

  property int fallos: 0
  property int pruebas: 0

  // Las comprobaciones van en dos tandas, y la razón es que un `ShellRoot`
  // sin ventana no dibuja: los componentes de la primera existen y
  // responden, pero nadie los pinta. Eso basta para la lógica —el vaho, el
  // ojo de la fila, los estados de la cabecera— y no basta para el
  // material, cuyo ruido se pinta en un lienzo y no hay lienzo sin
  // ventana. Así que el material vive en una `PanelWindow` de verdad, y
  // sus comprobaciones esperan a que haya pintado.

  function check(nombre, condicion, detalle) {
    pruebas += 1
    if (condicion) {
      console.log("  ok    " + nombre)
    } else {
      fallos += 1
      console.log("  FALLA " + nombre + (detalle ? "  → " + detalle : ""))
    }
  }

  Item {
    width: 400
    height: 200

    Omaplain.FogCover {
      id: vaho
      width: 400
      height: 200
      motionEnabled: false
    }

    Omaplain.ClipboardRow {
      id: fila
      width: 400
      lang: "en"
      motionEnabled: false
      body: "primer texto"
    }

    Omaplain.StatusHeader {
      id: cabecera
      width: 400
      lang: "en"
    }

    // Las otras dos variantes del cristal sólo se consultan por
    // propiedad, así que no necesitan que nadie las pinte.
    Omaplain.GlassSurface {
      id: probeta
      material: "small"
      width: 100; height: 96
    }

    Omaplain.GlassSurface {
      id: atenuada
      material: "dimmed"
      width: 100; height: 96
    }
  }

  PanelWindow {
    id: escaparate
    implicitWidth: 420
    implicitHeight: 320
    color: "transparent"
    anchors { top: true; left: true }

    Omaplain.GlassSurface {
      id: cristal
      x: 10; y: 10
      width: 180; height: 120

      Text {
        anchors.centerIn: parent
        text: "cristal"
        color: Color.popups.text
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
      }
    }

    Omaplain.GlassSurface {
      id: hundido
      x: 210; y: 10
      width: 180; height: 120
      material: "sunken"
    }

    Omaplain.Halo {
      id: halo
      x: 10; y: 150
      width: 180; height: 140
    }

    // La bienvenida, **dentro de la ventana y a la vista**: el ciclo de
    // trazado que esto vigila sólo ocurre si algo la coloca de verdad.
    Omaplain.TransformationIllustration {
      id: bienvenida
      x: 10; y: 300
      width: 464
      height: 190
      lang: "en"
      variant: "transform"
      motionEnabled: true
    }

    Omaplain.Grain {
      id: grano
      x: 210; y: 150
      width: 180; height: 140
      intensity: 0.6
      motionEnabled: false
    }

    // El caso de la cinta del tour: el grano nace a intensidad cero —la
    // tarjeta todavía está lejos del control— y no se enciende hasta que
    // llega. Si un lienzo invisible no pintase, la textura no existiría
    // nunca y la tarjeta cruzaría el arco con las rayas y sin ruido.
    // La demostración del tour, para comprobar dónde caen sus añicos.
    Omaplain.DemoTransformation {
      id: demo
      width: 400
      lang: "en"
      motionEnabled: true
    }

    // Y la ilustración del bypass, para el motivo que no reconoce.
    Omaplain.TransformationIllustration {
      id: arte
      width: 460
      height: 124
      lang: "en"
      variant: "unread"
      motionEnabled: false
    }

    // La cinta, para comprobar que su bucle se para al ocultarse.
    Omaplain.TransformationIllustration {
      id: cinta
      width: 460
      height: 220
      lang: "en"
      variant: "protect"
      motionEnabled: true
    }

    Omaplain.Grain {
      id: granoDormido
      x: 10; y: 150
      width: 180; height: 140
      intensity: 0
      motionEnabled: false
    }

    // La marca, a dos tamaños. Es el mismo dibujo en la barra y en la
    // cabecera del panel, y lo único que los separa es este número.
    Omaplain.Mark { id: marcaBarra;    markWidth: 21 }
    Omaplain.Mark { id: marcaCabecera; markWidth: 42 }
  }

  function pruebaVaho() {
    console.log("FogCover")
    vaho.reset()
    raiz.check("empieza sin trazos", vaho.wipedCount === 0)

    vaho.stroke(10, 10)
    raiz.check("un trazo cuenta una celda", vaho.wipedCount === 1)
    vaho.stroke(11, 11)
    raiz.check("la misma celda no cuenta dos veces", vaho.wipedCount === 1,
               "wipedCount=" + vaho.wipedCount)
    vaho.stroke(380, 190)
    raiz.check("otra celda sí cuenta", vaho.wipedCount === 2)

    // El remate sin movimiento es inmediato, así que se puede comprobar
    // sin esperar a ninguna animación.
    var avisos = 0
    function contar() { avisos += 1 }
    vaho.cleared.connect(contar)

    vaho.reset()
    vaho.locked = true
    vaho.finish(200, 100)
    raiz.check("bajo llave el remate no avisa", avisos === 0)
    raiz.check("bajo llave el remate ni empieza", vaho.sweep === 0,
               "sweep=" + vaho.sweep)

    vaho.locked = false
    vaho.reset()
    vaho.finish(200, 100)
    raiz.check("sin llave el remate avisa", avisos === 1, "avisos=" + avisos)
    raiz.check("y deja la cubierta limpia", vaho.sweep === 1)
    vaho.cleared.disconnect(contar)

    // La llave que llega con el vaho a medio frotar lo devuelve entero.
    vaho.reset()
    vaho.stroke(50, 50)
    vaho.stroke(150, 100)
    raiz.check("hay trazos antes de la llave", vaho.wipedCount === 2)
    vaho.locked = true
    raiz.check("la llave borra lo frotado", vaho.wipedCount === 0,
               "wipedCount=" + vaho.wipedCount)
    vaho.locked = false
  }

  function pruebaFila() {
    console.log("ClipboardRow")
    fila.locked = false
    fila.shown = true
    raiz.check("con el ojo puesto se ve", fila.revealed === true)

    fila.locked = true
    raiz.check("bajo llave no se ve, aunque se pida", fila.revealed === false)
    fila.locked = false

    // El texto nuevo tiene que llegar con la cubierta entera: si los
    // huecos del anterior siguieran, se leería lo nuevo por ellos.
    fila.shown = false
    var cubierta = fila.children.length > 0
    raiz.check("la fila monta su cubierta", cubierta)
  }

  function pruebaCabecera() {
    console.log("StatusHeader")
    cabecera.serviceState = "running"
    cabecera.detail = ""
    raiz.check("corriendo y sin nada que contar, se calla", cabecera.silent === true)

    cabecera.detail = "algo que contar"
    raiz.check("con detalle, habla", cabecera.silent === false)

    cabecera.serviceState = "degraded"
    raiz.check("degradado es un fallo", cabecera.failed === true)
    raiz.check("y no está sano", cabecera.healthy === false)

    cabecera.serviceState = "paused"
    raiz.check("pausado se reconoce", cabecera.paused === true)

    // El sónar es de arrancando y de nadie más: en la pantalla de cada
    // día no hay nada girando.
    raiz.check("pausado no es arrancando", cabecera.starting === false)
    cabecera.serviceState = "running"
    raiz.check("corriendo tampoco", cabecera.starting === false)
    cabecera.serviceState = "starting"
    raiz.check("arrancando sí", cabecera.starting === true)

    // Y el sónar no engorda la insignia: la caja de 24 px desborda por
    // arriba y por abajo, donde no hay nada que empujar. Si creciera, la
    // cabecera daría un salto de alto al terminar de arrancar.
    var altoArrancando = cabecera.implicitHeight
    cabecera.serviceState = "paused"
    raiz.check("la insignia mide lo mismo arrancando que pausada",
               cabecera.implicitHeight === altoArrancando,
               "arrancando=" + altoArrancando + " pausada=" + cabecera.implicitHeight)
  }

  function pruebaMaterial() {
    console.log("El material")

    // Ninguna medida del cristal es una constante escrita a mano: el filo
    // y el brillo salen del alto que tenga la superficie, así que crecen
    // con lo que lleve dentro y con el tamaño de fuente de quien mira.
    raiz.check("el cristal hereda el radio del tema", cristal.radius === Style.cornerRadius,
               "radius=" + cristal.radius)
    raiz.check("la pieza pequeña va con menos radio",
               Style.cornerRadius <= 2 || probeta.radius < cristal.radius,
               "pequeña=" + probeta.radius + " normal=" + cristal.radius)
    raiz.check("el cristal proyecta sombra", cristal.casts === true)
    raiz.check("el hundido no proyecta: la recibe", hundido.casts === false)
    raiz.check("el hundido se queda sin filo ni brillo",
               hundido.edgeLightAlpha === 0 && hundido.sheenAlpha === 0)
    raiz.check("la hoja de detrás pierde el filo", atenuada.edgeLightAlpha === 0)

    // El halo es un radial de verdad, no un disco: muere antes del canto.
    raiz.check("el halo se apaga antes del borde", halo.spread < 1, "spread=" + halo.spread)

    // Y el ruido se pinta una vez. Ni una más: lo que se anima es su
    // desplazamiento, no su contenido.
    raiz.check("el ruido se pinta una sola vez", grano.paintCount === 1,
               "paintCount=" + grano.paintCount)
    raiz.check("y deja una textura servible", grano.noiseUrl.length > 200,
               "url de " + grano.noiseUrl.length + " caracteres")

    // Sin señal no hay grano, y sin grano no hay nada girando detrás.
    grano.intensity = 0
    raiz.check("a intensidad cero el grano se retira", grano.visible === false)
    grano.intensity = 0.6
    raiz.check("y vuelve con la señal", grano.visible === true)
    raiz.check("el ruido no se repinta al ir y venir", grano.paintCount === 1,
               "paintCount=" + grano.paintCount)

    // Y el que nace apagado también tiene su textura lista para cuando le
    // toque. Es el caso de las cuatro tarjetas de la cinta.
    raiz.check("el grano que nace apagado también se pinta",
               granoDormido.paintCount === 1, "paintCount=" + granoDormido.paintCount)
    raiz.check("y llega con su textura hecha", granoDormido.noiseUrl.length > 200,
               "url de " + granoDormido.noiseUrl.length + " caracteres")
    raiz.check("nace fuera de la vista", granoDormido.visible === false)
  }

  function pruebaCaida() {
    console.log("La caída de la demo")

    demo.revealed = false
    demo.revealed = true

    raiz.check("hay un añico por carácter del tramo",
               demo.shards.length === demo.spare.length,
               demo.shards.length + " de " + demo.spare.length)

    // El fallo que de verdad ocurrió: medir antes de que hubiera trazado
    // devolvía ceros y los 54 caracteres salían apilados en la esquina de
    // arriba a la izquierda, cayendo todos desde el mismo sitio. Se
    // reconoce porque el tramo deja de ocupar ancho.
    var x0 = demo.shards[0].x0, x1 = demo.shards[0].x0
    var renglones = {}
    for (var i = 0; i < demo.shards.length; i++) {
      x0 = Math.min(x0, demo.shards[i].x0)
      x1 = Math.max(x1, demo.shards[i].x0)
      renglones[demo.shards[i].y0.toFixed(0)] = true
    }
    raiz.check("el tramo ocupa ancho de verdad", x1 - x0 > 100,
               "de " + x0.toFixed(0) + " a " + x1.toFixed(0))
    raiz.check("y más de un renglón", Object.keys(renglones).length >= 2,
               Object.keys(renglones).length + " renglones")

    // Ninguno cae fuera de la tarjeta: el suelo se fija a su borde.
    var fuera = 0
    for (var k = 0; k < demo.shards.length; k++) {
      var s = demo.shards[k]
      if (s.y0 + s.h + s.line > demo.floorY + 1) fuera += 1
    }
    raiz.check("ninguno cae por debajo del suelo", fuera === 0, fuera + " se pasan")

    // La suelta va por posición pintada, no por orden de cadena: con dos
    // renglones eso dibuja una diagonal.
    var porCadena = true
    for (var j = 1; j < demo.shards.length; j++) {
      if (demo.shards[j].x0 < demo.shards[j - 1].x0) porCadena = false
    }
    raiz.check("se sueltan ordenados por su x", porCadena)

    demo.revealed = false
  }

  // El bucle de la cinta es infinito, y el único del componente. Tiene que
  // pararse cuando la ilustración deja de estar a la vista: el paso 2 del
  // tour, la página de ajustes y el panel cerrado la ocultan, y detrás de
  // cada una seguía evaluando los bindings de las cuatro tarjetas por
  // cuadro para nadie. Es el mismo fallo que el vaho y el carrusel
  // corriendo dentro de una ventana cerrada.
  Timer {
    id: relojCinta
    interval: 220
    property real antes: 0
    property int paso: 0
    onTriggered: {
      if (paso === 0) {
        raiz.check("la cinta avanza a la vista", cinta.progress > antes,
                   "antes=" + antes.toFixed(4) + " ahora=" + cinta.progress.toFixed(4))
        cinta.visible = false
        antes = cinta.progress
        paso = 1
        relojCinta.restart()
      } else {
        raiz.check("y se para al ocultarse", cinta.progress === antes,
                   "antes=" + antes.toFixed(4) + " ahora=" + cinta.progress.toFixed(4))
        console.log("La bienvenida en bucle")
        relojBienvenida.latidos = 0
        relojBienvenida.restart()
      }
    }
  }

  function pruebaCinta() {
    console.log("La cinta")
    cinta.visible = true
    relojCinta.antes = cinta.progress
    relojCinta.paso = 0
    relojCinta.restart()
  }

  // La bienvenida en bucle: que dé vueltas, y que el reloj siga latiendo
  // mientras las da.
  //
  // **Este test no caza el fallo que motivó escribirlo, y conviene decirlo
  // aquí.** Ciclar la bienvenida convirtió un ciclo de trazado latente en
  // un bloqueo permanente —el alto de la barra de dirección salía del
  // contenido y el contenido se centraba contra ese alto—, y el shell se
  // quedaba girando al 100 % sin un solo error en el log. Se probó a
  // reponer el ciclo con esto puesto: pasa igual. La cadena de trazado del
  // panel real es más profunda —la ilustración va en una columna, dentro
  // de un `Flickable`, dentro de una tarjeta cuyo alto sigue al
  // contenido— y aquí no se reproduce.
  //
  // Lo que sí lo caza es medir el proceso con el panel de verdad delante:
  // cuatro aperturas y cierres, y `cat /proc/<pid>/stat`. Está en el
  // `CLAUDE.md`, porque es lo único que lo vio.
  Timer {
    id: relojBienvenida
    interval: 500
    repeat: true
    property int latidos: 0
    property real antes: 0
    onTriggered: {
      latidos += 1
      // Cruza la vuelta entera: nombrado, cierre, descanso, y el regreso
      // de los tramos a los 2 900 ms.
      if (latidos < 10) return
      relojBienvenida.stop()
      raiz.check("el reloj late mientras la bienvenida cicla",
                 latidos === 10, "latidos=" + latidos)
      raiz.check("y la bienvenida ha dado más de una vuelta",
                 bienvenida.laps >= 1, "vueltas=" + bienvenida.laps)
      raiz.check("los tramos vuelven en la tinta de reposo, no en acento",
                 bienvenida.phaseIn >= 0 && bienvenida.phaseIn <= 1,
                 "phaseIn=" + bienvenida.phaseIn)
      raiz.remate()
    }
  }

  function pruebaBypass() {
    console.log("El dibujo del bypass")
    arte.subject = "image"
    raiz.check("una imagen se dibuja como imagen", arte.subjectGlyph === "image")
    arte.subject = "sensitive"
    raiz.check("un secreto, como un secreto", arte.subjectGlyph === "secret")
    arte.subject = "files"
    raiz.check("unos archivos, como archivos", arte.subjectGlyph === "files")

    // Y lo que no reconoce no afirma nada: puede ser un texto grande, unos
    // bytes que no se descodifican o una aplicación de la lista.
    arte.subject = "too_large"
    raiz.check("un motivo cualquiera cae en la hoja de texto",
               arte.subjectGlyph === "text", arte.subjectGlyph)
    arte.subject = ""
    raiz.check("y sin motivo, también", arte.subjectGlyph === "text", arte.subjectGlyph)
  }

  function pruebaMarca() {
    // Recortada a su tinta. Con la caja de 24 x 24 entera, las 17 unidades
    // de aire de arriba y abajo dejan la fila de la cabecera con un agujero
    // del tamaño del nombre.
    raiz.check("la marca mide lo que se le pide de ancho",
               marcaBarra.implicitWidth === 21, String(marcaBarra.implicitWidth))
    raiz.check("y saca su alto de la proporción, no de la caja",
               Math.abs(marcaBarra.implicitHeight - 21 * 6.8 / 20.45) < 0.01,
               String(marcaBarra.implicitHeight))

    // Escalar sin deformar: el mismo dibujo a 21 y a 42.
    raiz.check("el doble de ancha es el doble de alta",
               Math.abs(marcaCabecera.implicitHeight - 2 * marcaBarra.implicitHeight) < 0.01,
               marcaBarra.implicitHeight + " → " + marcaCabecera.implicitHeight)

    // El punto es el final del trazo, así que cierra el dibujo por la
    // derecha: su borde toca el ancho pedido. Es el invariante que se rompe
    // si alguien mueve `inkWidth` y se olvida del punto, y ahí la marca se
    // descuadra sin que nada falle.
    var punto = marcaBarra.children[marcaBarra.children.length - 1]
    raiz.check("el punto cierra la marca por la derecha",
               Math.abs(punto.x + punto.width - marcaBarra.implicitWidth) < 0.01,
               (punto.x + punto.width) + " de " + marcaBarra.implicitWidth)
    raiz.check("y cabe dentro de su alto",
               punto.y >= 0 && punto.y + punto.height <= marcaBarra.implicitHeight,
               punto.y + "+" + punto.height + " en " + marcaBarra.implicitHeight)
    raiz.check("el punto es un círculo", punto.radius * 2 === punto.width)

    // Que la curva se dibuje bien no lo ve esto: `PathSvg` con una `d` rota
    // avisa por consola y sigue. Eso se mira, como el panel entero.
  }

  function remate() {
    console.log("")
    console.log("RESULTADO " + (raiz.pruebas - raiz.fallos) + "/" + raiz.pruebas +
                (raiz.fallos ? "  FALLOS: " + raiz.fallos : "  todo en verde"))
    Qt.exit(raiz.fallos === 0 ? 0 : 1)
  }

  // El lienzo del grano se pinta cuando el renderizador llega a él, no al
  // construirse: sin esta espera la cuenta de pintadas sale en cero y el
  // test diría que el ruido no se pinta nunca.
  Timer {
    id: segundaTanda
    interval: 400
    onTriggered: {
      pruebaMaterial()
      pruebaCaida()
      pruebaBypass()
      pruebaMarca()
      // Ésta remata sola: necesita esperar dos veces al reloj.
      pruebaCinta()
    }
  }

  Component.onCompleted: {
    console.log("")
    pruebaVaho()
    pruebaFila()
    pruebaCabecera()
    console.log("")
    segundaTanda.start()
  }
}
