"""Los ejemplos del estado vacío, atados al motor.

La pantalla que ve alguien con el portapapeles vacío enseña qué retiraría
OmaPlain de tres copias típicas. Si una regla cambia y el ejemplo se queda,
esa pantalla pasa a prometer una limpieza que ya no ocurre — justo delante
de quien todavía no confía en el plugin. Es el mismo riesgo que cubre
`test_demo_sample.py`, y se cubre igual.
"""

from __future__ import annotations

import re
import unittest
from pathlib import Path

from omaplain_lib.transform import transform

REPO = Path(__file__).resolve().parents[2]
COMPONENT = REPO / "components" / "EmptyCarousel.qml"

SAMPLE = re.compile(
    r'\{\s*kind:\s*"(?P<kind>[^"]+)",\s*art:\s*"(?P<art>[^"]+)",\s*'
    r'head:\s*"(?P<head>(?:[^"\\]|\\.)*)",\s*'
    r'spare:\s*"(?P<spare>(?:[^"\\]|\\.)*)",\s*'
    r'tail:\s*"(?P<tail>(?:[^"\\]|\\.)*)"\s*\}',
    re.DOTALL,
)


def _samples() -> list[dict[str, str]]:
    return [m.groupdict() for m in SAMPLE.finditer(COMPONENT.read_text(encoding="utf-8"))]


class EmptySampleTests(unittest.TestCase):
    def test_the_carousel_still_declares_its_examples(self) -> None:
        self.assertEqual(len(_samples()), 3)

    def test_the_link_example_loses_exactly_what_it_shows_losing(self) -> None:
        # El único de los tres que el motor reescribe sobre el texto. Lo que
        # la tarjeta pinta en acento tiene que ser lo que de verdad se va.
        link = _samples()[0]
        dirty = link["head"] + link["spare"] + link["tail"]
        clean = link["head"] + link["tail"]
        result = transform(("https://" + dirty).encode("utf-8"), "text/plain", {})
        self.assertEqual(result.output.decode("utf-8"), "https://" + clean)
        self.assertTrue(result.changed)

    def test_what_survives_is_shown_surviving(self) -> None:
        link = _samples()[0]
        self.assertIn("talla=42", link["tail"], "el parámetro que sobrevive no se enseña")
        self.assertNotIn("talla", link["spare"], "se enseña como retirado algo que se queda")

    def test_every_example_marks_something_as_spare(self) -> None:
        for index, sample in enumerate(_samples()):
            with self.subTest(sample=index):
                self.assertTrue(sample["spare"].strip(), "un ejemplo sin nada que retirar")

    def test_the_carousel_has_a_reduced_motion_path(self) -> None:
        source = COMPONENT.read_text(encoding="utf-8")
        self.assertIn("property bool motionEnabled", source)
        # Quieto, se queda en el primer ejemplo ya peinado: la pantalla
        # cuenta lo mismo sin moverse.
        self.assertIn("motionEnabled ? 0 : 1", source)
        self.assertIn("running: root.motionEnabled", source)

    def test_the_card_height_does_not_depend_on_the_example(self) -> None:
        # Con altura variable, cada vuelta del ciclo redimensionaría el panel
        # entero cada 2,6 segundos. Lo que se vigila es esa dependencia, no
        # un número concreto: fijarlo hacía que el test fallara al crecer la
        # tarjeta por un motivo perfectamente legítimo.
        source = COMPONENT.read_text(encoding="utf-8")

        root_height = re.search(r"^  implicitHeight: (?P<v>.+)$", source, re.MULTILINE)
        self.assertIsNotNone(root_height, "el componente ya no fija su alto")
        self.assertNotIn("sample", root_height.group("v"))

        card_height = re.search(r"height: Math\.max\((?P<v>.*?)\)\n", source, re.DOTALL)
        self.assertIsNotNone(card_height, "el alto de la tarjeta cambió de forma")
        self.assertNotIn("sample", card_height.group("v"))

        # Y el cuerpo va en una línea: envolviendo, un ejemplo largo crecería
        # y devolvería la dependencia por la puerta de atrás.
        self.assertNotIn("wrapMode", source)

if __name__ == "__main__":
    unittest.main()
