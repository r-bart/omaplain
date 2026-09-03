import QtQuick
import qs.Commons
import qs.Ui
import "Strings.js" as Strings

// Los tipos que ofrece el portapapeles, en pastillas.
//
// Existe por un caso que la comparación de textos no sabe contar: cuando
// sólo se retira el formato enriquecido, el texto no cambia ni un carácter
// y las dos filas salen idénticas. Lo que desaparece es el `text/html`, así
// que ahí el antes y el después son los tipos.
//
// También es lo único que se puede enseñar de un bypass: de una imagen o de
// un secreto marcado no se muestra contenido, pero sí de qué está hecho.
Flow {
  id: root

  property string lang: "en"

  property var types: []
  property var typesAfter: []
  readonly property bool comparing: typesAfter && typesAfter.length > 0

  property bool motionEnabled: true

  // El chip que se va **se nombra, y se queda**.
  //
  // El paquete de diseño lo comprime hasta cero, y ahí no se puede seguir:
  // ésta es la única pantalla donde las dos filas de texto salen idénticas,
  // así que los chips son lo único que cuenta qué ha cambiado. Un chip que
  // se cierra deja `text/plain → text/plain`, y quien mire el panel un
  // minuto después no tiene forma de saber que había un `text/html`.
  //
  // Es el mismo argumento por el que la fila del resultado conserva su
  // sello: la pantalla frecuente informa, y una animación no puede
  // llevarse por delante la información que da ([`0007`], [`0016`]).
  //
  // Del motor se queda la mitad que sí explica: nombrar. El chip llega en
  // la tinta del panel y a los 300 ms pasa al acento con su tachado, que
  // es lo que hace que el ojo vaya ahí en vez de a las dos filas iguales.
  property real named: motionEnabled ? 0 : 1

  function play() {
    if (!motionEnabled) { named = 1; return }
    named = 0
    naming.restart()
  }

  Component.onCompleted: play()
  onMotionEnabledChanged: play()
  onTypesAfterChanged: play()
  onVisibleChanged: if (visible) play()

  SequentialAnimation {
    id: naming
    PauseAnimation { duration: 300 }
    NumberAnimation {
      target: root; property: "named"; from: 0; to: 1
      duration: 340; easing.type: Easing.OutCubic
    }
  }

  spacing: Style.space(6)

  Accessible.role: Accessible.StaticText
  Accessible.name: comparing
    ? Strings.f("chips.a11y", root.lang, types.join(", "), typesAfter.join(", "))
    : Strings.f("chips.plain.a11y", root.lang, types.join(", "))

  Repeater {
    model: root.types
    delegate: Chip {
      required property string modelData
      label: modelData
      // Al comparar, se nombra lo que no sobrevive.
      dropped: root.comparing && root.typesAfter.indexOf(modelData) === -1
      named: root.named
    }
  }

  Text {
    visible: root.comparing
    text: "→"
    color: Util.alpha(Color.popups.text, 0.68)
    font.family: Style.font.family
    font.pixelSize: Style.font.bodySmall
    Accessible.ignored: true
  }

  Repeater {
    model: root.comparing ? root.typesAfter : []
    delegate: Chip {
      required property string modelData
      label: modelData
    }
  }
}
