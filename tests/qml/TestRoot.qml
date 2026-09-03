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

    Omaplain.Grain {
      id: grano
      x: 210; y: 150
      width: 180; height: 140
      intensity: 0.6
      motionEnabled: false
    }
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
      raiz.remate()
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
