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
      // Al comparar, se tacha lo que no sobrevive.
      dropped: root.comparing && root.typesAfter.indexOf(modelData) === -1
      kept: root.comparing && !dropped
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
      kept: true
    }
  }
}
