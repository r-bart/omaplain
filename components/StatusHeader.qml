import QtQuick
import qs.Commons
import qs.Ui
import "Strings.js" as Strings
import "Ink.js" as Ink

// El estado del servicio en la pantalla frecuente. Nada más.
//
// Antes esto era un héroe: llevaba «Texto limpio, sin sorpresas» —el mismo
// titular, palabra por palabra, que la pantalla de bienvenida— más la
// ilustración de transformación, ocupando el tercio superior de un panel
// pequeño y de uso diario.
//
// La decisión 0007 se llevó ambas cosas a donde tienen trabajo. La primera
// experiencia enseña; ésta informa. El producto se explica solo enseñando
// qué va a hacer con tu contenido, que es mejor profesor que un dibujo que
// ya viste en el tour.
Item {
  id: root

  // Idioma heredado del panel: en o es.
  property string lang: "en"

  // `serviceState` y no `state`: `state` ya existe en todo Item —es la
  // máquina de estados de QML— y declararlo encima lo sombreaba.
  property string serviceState: "starting"

  // Heredado del panel. Con él en falso el sónar se queda quieto, con sus
  // tres anillos repartidos y sin eco: sigue diciendo «a la escucha» sin
  // que se mueva nada.
  property bool motionEnabled: true
  property string detail: Strings.t("state.preparing", root.lang)
  readonly property bool healthy: serviceState === "running"
  readonly property bool paused: serviceState === "paused"
  readonly property bool failed: ["degraded", "missing_dependencies", "config_error", "stopped"].indexOf(serviceState) !== -1
  readonly property bool starting: !healthy && !paused && !failed
  readonly property string stateLabel: failed
    ? Strings.t("state.attention", root.lang)
    : (paused
      ? Strings.t("state.paused", root.lang)
      : (healthy ? Strings.t("state.active", root.lang) : Strings.t("state.starting", root.lang)))
  // Con el servicio corriendo, sin omisión pendiente y sin nada que contar,
  // la cabecera de estado no tiene contenido: ni insignia ni frase. Sin esto
  // dejaría su hueco y su `spacing` en la columna, que es peor que la frase
  // que se acaba de quitar.
  readonly property bool silent: detail === "" && healthy

  readonly property color stateColor: failed ? Color.urgent : (healthy ? Color.accent : Color.muted)

  implicitWidth: Style.space(460)
  implicitHeight: lines.implicitHeight

  Accessible.role: Accessible.StaticText
  // Sin detalle, sin el punto y el hueco que dejaba «OmaPlain, Activo. ».
  Accessible.name: detail !== ""
    ? Strings.f("state.a11y", root.lang, stateLabel, detail)
    : Strings.f("state.a11y.short", root.lang, stateLabel)

  Column {
    id: lines
    anchors.left: parent.left
    anchors.right: parent.right
    spacing: Style.space(4)

    // El estado normal no se anuncia. Un servicio que está corriendo es lo
    // que se espera de él, y rotularlo «ACTIVO» gasta la primera línea de la
    // cabecera en decir que no pasa nada. La insignia sólo aparece cuando
    // hay algo que contar: pausado, arrancando o pidiendo atención.
    //
    // El `Accessible.name` de la raíz sí sigue nombrando el estado siempre:
    // ahí no hay un panel vivo delante del que deducirlo.
    Row {
      visible: !root.healthy
      spacing: Style.space(7)

      // La insignia. Arrancando es un sónar; en cualquier otro estado, el
      // punto de siempre.
      //
      // **El alto no cambia.** El sónar necesita una caja de 24 px para que
      // el anillo lejano no toque nada, pero el hueco que ocupa en la fila
      // sigue midiendo lo que medía el punto: la caja se ensancha y los
      // anillos desbordan por arriba y por abajo, donde no hay nada que
      // empujar. Si el hueco creciera, la cabecera daría un salto de alto
      // cada vez que el servicio termina de arrancar.
      Item {
        id: insignia
        width: root.starting ? Style.space(24) : Style.space(8)
        height: Style.space(8)
        anchors.verticalCenter: parent.verticalCenter
        Accessible.ignored: true

        Rectangle {
          visible: !root.starting
          anchors.fill: parent
          radius: width / 2
          color: root.stateColor
        }

        // El sónar, y por qué es un sónar y no un latido: el servicio no
        // está haciendo esfuerzo, está **a la escucha** del portapapeles.
        // Un anillo que sale y se pierde dice eso; uno que crece y se
        // encoge dice que algo se cansa.
        //
        // Es un bucle, y la 0017 lo ampara por dos razones que hacen falta
        // las dos: no es una ilustración —lo que representa es literalmente
        // una espera— y se acaba solo, en cuanto el demonio atiende.
        Item {
          id: sonar
          width: Style.space(24)
          height: width
          anchors.centerIn: parent
          visible: root.starting

          readonly property int cycle: 2600
          // Quieto, los tres anillos se reparten a mano. Con la fase
          // congelada en un número cualquiera, alguno cae siempre en su
          // nacimiento o en su muerte y se pierde.
          property real phase: 0

          function outCubic(t) { var k = 1 - t; return 1 - k * k * k }

          // El eco: uno de cada tres barridos devuelve un punto en el
          // radio, que se enciende cuando el frente lo alcanza y se apaga
          // detrás. Más a menudo deja de ser un hallazgo y pasa a ser
          // decoración que parpadea.
          //
          // El barrido que lo trae, su ángulo y su distancia salen de un
          // hash del número de barrido, no de `Math.random()`: se ve
          // irregular y es reproducible, igual que la deriva de los añicos.
          // Los desplazamientos van con divisiones y no con `>>`, que en
          // JavaScript trunca a 32 bits con signo y devolvería negativos
          // justo en la mitad de los barridos.
          property int sweep: 0
          property real lastPhase: 0
          onPhaseChanged: {
            if (phase < lastPhase) sweep += 1
            lastPhase = phase
          }

          readonly property real echoHash: (sweep * 2654435761 + 1013904223) % 4294967296
          readonly property bool echoes: (echoHash % 3) === 0
          readonly property real echoAt: 0.30 + (Math.floor(echoHash / 256) % 100) / 100 * 0.45
          readonly property real echoAngle: (Math.floor(echoHash / 65536) % 360) * Math.PI / 180
          readonly property real echoReach: Style.spaceReal(3) + outCubic(echoAt) * Style.spaceReal(6.6)
          readonly property real echoLife: (phase - echoAt) / 0.34
          readonly property real echoOpacity: root.motionEnabled && echoes
            && echoLife >= 0 && echoLife < 1
            ? Math.min(1, echoLife * 6) * (1 - echoLife) : 0

          Repeater {
            model: [0, 0.34, 0.68]

            // El trazo **no escala**. Lo que crece es el ancho del anillo,
            // no un `scale` sobre él: con la escala, el anillo lejano se
            // vería más gordo que el cercano, que es al revés de lo que
            // hace la distancia.
            delegate: Rectangle {
              required property int index
              required property real modelData

              readonly property real u: (sonar.phase - modelData + 1) % 1
              readonly property real eased: root.motionEnabled
                ? sonar.outCubic(u) : index * 0.36

              width: Style.space(6) * (1 + 2.2 * eased)
              height: width
              radius: width / 2
              anchors.centerIn: parent
              color: "transparent"
              border.width: Math.max(1, Style.space(1))
              border.color: root.stateColor
              // El último factor evita el destello de entrada: sin él, el
              // anillo nace ya a plena luz en el sitio del núcleo.
              opacity: root.motionEnabled
                ? 0.85 * (1 - eased) * Math.min(1, u * 9)
                : 0.55 - index * 0.2
            }
          }

          Rectangle {
            width: Style.space(4)
            height: width
            radius: width / 2
            anchors.centerIn: parent
            color: root.stateColor
          }

          Rectangle {
            width: Style.space(3)
            height: width
            radius: width / 2
            x: sonar.width / 2 + sonar.echoReach * Math.cos(sonar.echoAngle) - width / 2
            y: sonar.height / 2 + sonar.echoReach * Math.sin(sonar.echoAngle) - height / 2
            color: Color.accent
            opacity: sonar.echoOpacity
            visible: opacity > 0.01
          }

          // Un solo recorrido compartido con desfase por índice, no tres
          // animaciones: tres relojes independientes se separan.
          NumberAnimation {
            target: sonar; property: "phase"; from: 0; to: 1
            duration: sonar.cycle; loops: Animation.Infinite
            running: root.motionEnabled && sonar.visible
          }
        }
      }

      Text {
        text: root.stateLabel
        color: root.stateColor
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        font.bold: true
        font.capitalization: Font.AllUppercase
        font.letterSpacing: Style.spaceReal(0.8)
      }
    }

    // Un párrafo que envuelve, no un rótulo. El panel ya distingue las dos
    // cosas —0,68 para rótulos y foregrounds de control, 0,72 para prosa
    // que envuelve, y 1,45 de interlínea— y esta frase estaba puesta con
    // los valores de rótulo, que es lo que la dejaba más apagada y más
    // apretada que el subtítulo del veredicto que tiene tres líneas más
    // abajo. Medido sobre el render: 5,65:1 frente a 6,20:1.
    Text {
      width: parent.width
      visible: root.detail !== ""
      text: root.detail
      color: Ink.prose(Color.popups.text, Color.popups.background)
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
      lineHeightMode: Text.ProportionalHeight
      lineHeight: 1.45
      wrapMode: Text.WordWrap
    }
  }
}
