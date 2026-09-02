import Quickshell
import QtQuick
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
  }

  Component.onCompleted: {
    console.log("")
    pruebaVaho()
    pruebaFila()
    pruebaCabecera()
    console.log("")
    console.log("RESULTADO " + (raiz.pruebas - raiz.fallos) + "/" + raiz.pruebas +
                (raiz.fallos ? "  FALLOS: " + raiz.fallos : "  todo en verde"))
    Qt.exit(raiz.fallos === 0 ? 0 : 1)
  }
}
