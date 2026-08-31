"""Los ejemplos del estado vacío, atados al motor y a los dos idiomas.

La pantalla que ve alguien con el portapapeles vacío enseña qué retiraría
OmaPlain de tres copias típicas. Si una regla cambia y el ejemplo se queda,
esa pantalla pasa a prometer una limpieza que ya no ocurre — justo delante
de quien todavía no confía en el plugin. Es el mismo riesgo que cubre
`test_demo_sample.py`, y se cubre igual.

Los ejemplos vivían escritos en el QML, y allí se quedaron en español: la
guardia que caza prosa fuera del catálogo usa el acento como señal, y
`El pan de masa madre` no lleva ninguno. Ahora salen del catálogo, así que
se comprueban una vez por idioma.
"""

from __future__ import annotations

import json
import re
import unittest
from pathlib import Path

from omaplain_lib.classify import classify
from omaplain_lib.transform import transform

REPO = Path(__file__).resolve().parents[2]
COMPONENT = REPO / "components" / "EmptyCarousel.qml"
CATALOGUE = REPO / "components" / "Strings.js"

SAMPLE = re.compile(
    r'\{\s*kind:\s*"(?P<kind>[^"]+)",\s*art:\s*"(?P<art>[^"]+)",\s*'
    r'text:\s*"(?P<text>[^"]+)"\s*\}'
)

ZWSP = "​"


def _declared() -> list[dict[str, str]]:
    return [m.groupdict() for m in SAMPLE.finditer(COMPONENT.read_text(encoding="utf-8"))]


def _table(name: str) -> dict[str, str]:
    source = CATALOGUE.read_text(encoding="utf-8")
    body = re.search(rf"var {name} = \{{(?P<body>.*?)\n\}};", source, re.DOTALL)
    assert body, f"no encuentro la tabla {name}"
    pairs = re.findall(r'"([^"]+)":\s*"((?:[^"\\]|\\.)*)"', body.group("body"))
    return {k: json.loads(f'"{v}"') for k, v in pairs}


def _parts(table: dict[str, str], prefix: str) -> tuple[str, str, str]:
    return tuple(table[f"{prefix}.{name}"] for name in ("head", "spare", "tail"))


class EmptySampleTests(unittest.TestCase):
    def setUp(self) -> None:
        self.samples = _declared()
        self.tables = {"en": _table("EN"), "es": _table("ES")}

    def test_the_carousel_still_declares_its_examples(self) -> None:
        self.assertEqual(len(self.samples), 3)

    def test_the_examples_carry_no_text_of_their_own(self) -> None:
        # Escribirlos aquí es cómo se quedaron sin traducir la primera vez.
        for index, sample in enumerate(self.samples):
            with self.subTest(sample=index):
                self.assertTrue(sample["text"].startswith("empty.sample."))

    def test_every_part_exists_in_both_languages(self) -> None:
        for sample in self.samples:
            for lang, table in self.tables.items():
                for name in ("head", "spare", "tail"):
                    key = f"{sample['text']}.{name}"
                    with self.subTest(lang=lang, key=key):
                        self.assertIn(key, table, "el carrusel pide una clave que no existe")

    def test_the_link_example_loses_exactly_what_it_shows_losing(self) -> None:
        # El único de los tres que el motor reescribe sobre el texto. Lo que
        # la tarjeta pinta en acento tiene que ser lo que de verdad se va,
        # y eso vale para la URL inglesa igual que para la española.
        for lang, table in self.tables.items():
            head, spare, tail = _parts(table, "empty.sample.link")
            with self.subTest(lang=lang):
                result = transform(("https://" + head + spare + tail).encode("utf-8"), "text/plain", {})
                self.assertEqual(result.output.decode("utf-8"), "https://" + head + tail)
                self.assertTrue(result.changed)

    def test_what_survives_is_shown_surviving(self) -> None:
        # Media promesa es peor que ninguna: hay que ver que algo se queda,
        # no sólo que algo se va. En el enlace ese algo es el parámetro de
        # después, y tiene que sobrevivir a la limpieza de verdad.
        for lang, table in self.tables.items():
            head, spare, tail = _parts(table, "empty.sample.link")
            with self.subTest(lang=lang):
                self.assertTrue(tail.strip(), "el ejemplo no enseña nada que sobreviva")
                cleaned = transform(
                    ("https://" + head + spare + tail).encode("utf-8"), "text/plain", {},
                ).output.decode("utf-8")
                self.assertIn(tail, cleaned, "se enseña sobreviviendo algo que se va")
                self.assertNotIn(spare, cleaned, "se enseña como retirado algo que se queda")

    def test_the_paragraph_example_loses_the_character_it_marks(self) -> None:
        # La tarjeta dibuja el invisible con una etiqueta, porque un ZWSP no
        # se puede enseñar. Lo que sí se puede comprobar es que el motor lo
        # retira de esa misma frase, que es lo que la tarjeta promete.
        for lang, table in self.tables.items():
            head, _, tail = _parts(table, "empty.sample.text")
            with self.subTest(lang=lang):
                result = transform((head + ZWSP + tail).encode("utf-8"), "text/plain", {})
                self.assertEqual(result.output.decode("utf-8"), head + tail)
                self.assertTrue(result.changed)

    def test_the_formatted_example_is_still_a_case_the_product_handles(self) -> None:
        # Aquí no cambia ni un carácter: lo que se retira es la
        # representación con formato. Lo comprueba la clasificación, que es
        # donde vive esa decisión.
        verdict = classify(["text/html", "text/plain;charset=utf-8"])
        self.assertTrue(verdict.eligible)
        self.assertTrue(verdict.rich, "el producto ya no trata el html como formato a retirar")

    def test_every_example_marks_something_as_spare(self) -> None:
        for sample in self.samples:
            for lang, table in self.tables.items():
                with self.subTest(sample=sample["art"], lang=lang):
                    self.assertTrue(table[f"{sample['text']}.spare"].strip(),
                                    "un ejemplo sin nada que retirar")

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
