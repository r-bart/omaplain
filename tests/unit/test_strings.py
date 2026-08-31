"""El catálogo bilingüe.

Ni el shell de Omarchy ni ningún plugin usan `qsTr`, y sin ficheros `.qm`
compilados devuelve la cadena tal cual. El catálogo propio evita esa
maquinaria inútil, pero se paga con un riesgo: que las dos tablas se
desincronicen en silencio. De eso va este fichero.
"""

from __future__ import annotations

import json
import re
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
CATALOGUE = REPO / "components" / "Strings.js"


def _table(name: str) -> dict[str, str]:
    source = CATALOGUE.read_text(encoding="utf-8")
    body = re.search(rf"var {name} = \{{(?P<body>.*?)\n\}};", source, re.DOTALL)
    assert body, f"no encuentro la tabla {name}"
    pairs = re.findall(r'"([^"]+)":\s*"((?:[^"\\]|\\.)*)"', body.group("body"))
    return {k: json.loads(f'"{v}"') for k, v in pairs}


class CatalogueTests(unittest.TestCase):
    def setUp(self) -> None:
        self.en = _table("EN")
        self.es = _table("ES")

    def test_both_languages_carry_the_same_keys(self) -> None:
        self.assertEqual(
            sorted(self.en), sorted(self.es),
            "las tablas se han desincronizado: "
            f"sólo en EN {sorted(set(self.en) - set(self.es))}, "
            f"sólo en ES {sorted(set(self.es) - set(self.en))}",
        )

    def test_nothing_is_left_blank(self) -> None:
        for lang, table in (("en", self.en), ("es", self.es)):
            for key, value in table.items():
                with self.subTest(lang=lang, key=key):
                    self.assertTrue(value.strip(), "cadena vacía")

    def test_placeholders_match_between_languages(self) -> None:
        # Una traducción que pierde un %1 deja un hueco en la frase; una que
        # inventa uno imprime el marcador tal cual delante del usuario.
        for key in self.en:
            with self.subTest(key=key):
                self.assertEqual(
                    sorted(re.findall(r"%\d", self.en[key])),
                    sorted(re.findall(r"%\d", self.es[key])),
                    f"los marcadores de «{key}» no coinciden",
                )

    # Las que coinciden de verdad, una por una y con su motivo. Una lista
    # explícita envejece mejor que una regex que las esconda a todas.
    LEGITIMATELY_IDENTICAL = {
        "app.name": "la marca",
        "state.a11y": "sólo la marca y los marcadores",
        "setting.invisible": "«Invisibles» se escribe igual en los dos idiomas",
    }

    def test_spanish_is_not_a_copy_of_english(self) -> None:
        same = sorted(
            k for k in self.en
            if self.en[k] == self.es[k] and k not in self.LEGITIMATELY_IDENTICAL
        )
        self.assertEqual(same, [], f"sin traducir: {same}")

    def test_the_identical_list_has_no_leftovers(self) -> None:
        # Si una de esas cadenas cambia y deja de coincidir, la excepción
        # sobra y hay que retirarla en vez de dejarla acumulando polvo.
        stale = sorted(k for k in self.LEGITIMATELY_IDENTICAL if self.en[k] != self.es[k])
        self.assertEqual(stale, [], f"excepciones que ya no hacen falta: {stale}")

    def test_no_qml_speaks_spanish_behind_the_catalogue(self) -> None:
        """Ninguna cadena visible puede quedarse fuera del catálogo.

        La migración se hizo buscando una lista de propiedades, y las que
        no estaban en ella se escaparon enteras: `description:`, los
        `outcome` de la demostración, la pista del campo de exclusión y
        una etiqueta de la ilustración. Todas se quedaron en español, y en
        inglés se habrían visto tal cual.

        El acento es la señal: si una cadena del QML lleva uno, es prosa
        para leer y le toca estar en `Strings.js`.
        """
        accented = re.compile(r'"[^"]*[áéíóúüñÁÉÍÓÚÑ¿¡][^"]*"')
        files = [*REPO.glob("*.qml"), *sorted((REPO / "components").glob("*.qml"))]
        for path in files:
            for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
                code = line.split("//", 1)[0]
                if "Strings." in code:
                    continue
                with self.subTest(file=path.name, line=number):
                    self.assertIsNone(
                        accented.search(code),
                        f"español fuera del catálogo: {code.strip()[:70]}",
                    )

    def test_the_locale_maps_to_one_of_the_two(self) -> None:
        source = CATALOGUE.read_text(encoding="utf-8")
        self.assertIn("function fromLocale", source)
        self.assertIn('indexOf("es") === 0', source)

    def test_a_missing_spanish_key_falls_back_instead_of_blanking(self) -> None:
        source = CATALOGUE.read_text(encoding="utf-8")
        self.assertIn("if (value === undefined) value = EN[key]", source)


if __name__ == "__main__":
    unittest.main()
