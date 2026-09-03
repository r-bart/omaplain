"""La demostración del tour.

Las muestras vivían escritas en el QML, en español. La interfaz en inglés
enseñaba `pan-de-masa-madre` y la frase de resultado hablaba de «the
servings» señalando un `porciones=8`. Ahora salen del catálogo y se
comprueban contra el motor **una vez por idioma**, que es la única forma de
que ninguno de los dos se quede prometiendo una limpieza que ya no ocurre.
"""

from __future__ import annotations

import json
import re
import unittest
from pathlib import Path

from omaplain_lib.transform import transform


REPO = Path(__file__).resolve().parents[2]
COMPONENT = REPO / "components" / "DemoTransformation.qml"
CATALOGUE = REPO / "components" / "Strings.js"


def _table(name: str) -> dict[str, str]:
    source = CATALOGUE.read_text(encoding="utf-8")
    body = re.search(rf"var {name} = \{{(?P<body>.*?)\n\}};", source, re.DOTALL)
    assert body, f"no encuentro la tabla {name}"
    pairs = re.findall(r'"([^"]+)":\s*"((?:[^"\\]|\\.)*)"', body.group("body"))
    return {k: json.loads(f'"{v}"') for k, v in pairs}


def _keys() -> list[str]:
    """Las muestras que el componente declara, en su orden."""
    source = COMPONENT.read_text(encoding="utf-8")
    return re.findall(r'"key":\s*"([^"]+)"', source)


def _catalogue_keys() -> list[str]:
    """Las muestras que el catálogo guarda, se enseñen o no.

    El tour dejó de ofrecer la segunda —el enlace firmado que no se toca— al
    quitarle un botón al paso. La lección la sigue dando el aviso de encima
    con palabras, pero la muestra se queda aquí y bajo test: documenta la
    contención del motor, y una regla nueva que empezara a recortar enlaces
    firmados tiene que romper algo.
    """
    table = _table("EN")
    keys = sorted({k.rsplit(".", 1)[0] for k in table if k.startswith("demo.sample")})
    assert keys, "el catálogo no guarda ninguna muestra"
    return keys


def _samples(lang: str) -> list[tuple[str, str]]:
    table = _table(lang)
    return [(table[f"{k}.original"], table[f"{k}.cleaned"]) for k in _catalogue_keys()]


def _runs(lang: str) -> list[tuple[str, str, str, str, str]]:
    """Sólo las muestras que pierden algo llevan tramos.

    Una muestra que el motor no toca no tiene nada que encoger, y guardarle
    tramos vacíos rompería dos invariantes del catálogo a la vez: que ninguna
    clave queda en blanco y que el español no es una copia del inglés.
    """
    table = _table(lang)
    return [
        (table[f"{k}.head"], table[f"{k}.spare"], table[f"{k}.tail"],
         table[f"{k}.original"], table[f"{k}.cleaned"])
        for k in _catalogue_keys()
        if f"{k}.spare" in table
    ]


class DemoSampleTests(unittest.TestCase):
    def test_the_component_shows_samples_the_catalogue_knows(self) -> None:
        shown = _keys()
        self.assertGreaterEqual(len(shown), 1)
        for key in shown:
            self.assertIn(key, _catalogue_keys())

    def test_the_catalogue_still_keeps_both_lessons(self) -> None:
        # Una que se limpia y una que no. Perder la segunda dejaría la
        # contención del motor sin nada que la sujete.
        self.assertGreaterEqual(len(_catalogue_keys()), 2)

    def test_every_shown_result_is_what_the_engine_actually_produces(self) -> None:
        # El corazón de la demostración: si una regla cambia y el resultado
        # rotulado deja de ser el real, la demo pasa a mentirle a alguien que
        # todavía no confía en el plugin. Aquí se rompe antes.
        for lang in ("EN", "ES"):
            for index, (original, cleaned) in enumerate(_samples(lang)):
                with self.subTest(lang=lang, sample=index):
                    result = transform(original.encode("utf-8"), "text/plain", {})
                    self.assertEqual(result.output.decode("utf-8"), cleaned)

    def test_the_pair_shows_both_halves_of_the_promise(self) -> None:
        # Una sola muestra que limpia vende la mitad útil. La otra mitad, la
        # que gana confianza, es la que el motor se niega a tocar.
        for lang in ("EN", "ES"):
            changed = [
                transform(original.encode("utf-8"), "text/plain", {}).changed
                for original, _ in _samples(lang)
            ]
            with self.subTest(lang=lang):
                self.assertIn(True, changed, "ninguna muestra demuestra una limpieza")
                self.assertIn(False, changed, "ninguna muestra demuestra la contención")

    def test_a_preserved_sample_is_shown_unchanged(self) -> None:
        for lang in ("EN", "ES"):
            for index, (original, cleaned) in enumerate(_samples(lang)):
                result = transform(original.encode("utf-8"), "text/plain", {})
                if not result.changed:
                    with self.subTest(lang=lang, sample=index):
                        self.assertEqual(original, cleaned)

    def test_the_examples_use_a_domain_reserved_for_examples(self) -> None:
        # `ejemplo.com` es un dominio real que pertenece a alguien, y la demo
        # le colgaba un enlace con seguimiento y una factura firmada. La RFC
        # 2606 reserva `example.com` justo para esto.
        for lang in ("EN", "ES"):
            for index, (original, _) in enumerate(_samples(lang)):
                with self.subTest(lang=lang, sample=index):
                    host = re.match(r"https://([^/]+)/", original)
                    self.assertIsNotNone(host, f"la muestra no es una URL: {original}")
                    self.assertEqual(
                        host.group(1), "example.com",
                        "dominio real en un ejemplo inventado",
                    )

    def test_the_two_languages_show_the_same_lesson(self) -> None:
        # Traducir la frase de resultado y no la muestra fue el fallo
        # original. Si una limpia y la otra no, la lección deja de ser la
        # misma para la mitad de la gente.
        lecciones = {}
        for lang in ("EN", "ES"):
            lecciones[lang] = [
                transform(original.encode("utf-8"), "text/plain", {}).changed
                for original, _ in _samples(lang)
            ]
        self.assertEqual(lecciones["EN"], lecciones["ES"])

    def test_the_samples_are_actually_translated(self) -> None:
        # Las mismas cadenas en las dos tablas significan que alguien copió
        # y no tradujo, que es exactamente como estaban antes.
        en, es = _table("EN"), _table("ES")
        for key in _keys():
            with self.subTest(key=key):
                self.assertNotEqual(
                    en[f"{key}.original"], es[f"{key}.original"],
                    "la muestra es idéntica en los dos idiomas: sin traducir",
                )

    def test_the_cleaning_sample_carries_the_invisible_it_promises(self) -> None:
        # La frase de resultado dice que retira «un carácter invisible».
        for lang in ("EN", "ES"):
            originals = [o for o, _ in _samples(lang)]
            with self.subTest(lang=lang):
                self.assertTrue(
                    any("​" in o for o in originals),
                    "ninguna muestra lleva el invisible que la demo promete",
                )

    def test_the_demo_never_reaches_for_the_clipboard(self) -> None:
        # La promesa rotulada es "nunca tu portapapeles". Nada de servicio,
        # IPC ni procesos dentro del componente lo puede contradecir.
        source = COMPONENT.read_text(encoding="utf-8")
        for forbidden in ("service", "Process", "cleanNow", "pasteClean", "IPC", "socket"):
            with self.subTest(token=forbidden):
                self.assertNotIn(forbidden, source)

    def test_the_demo_is_labelled_as_a_demonstration(self) -> None:
        # La copia se mudó al catálogo bilingüe, así que la promesa se
        # comprueba ahí y en los dos idiomas: rotularla sólo en uno la
        # dejaría a medias para la mitad de la gente.
        #
        # `demo.original` («Ver el original») ya no está: se fue con la
        # tarjeta que lo envolvía, y con la caída el original se ve de
        # todos modos —es lo primero que enseña la pantalla—. `demo.try`
        # sí se queda: es el rótulo del botón para quien apagó las
        # animaciones, y a ése hay que seguir ofreciéndole la demostración.
        catalogue = CATALOGUE.read_text(encoding="utf-8")
        for key in ("demo.label", "demo.try"):
            with self.subTest(key=key):
                self.assertEqual(catalogue.count(f'"{key}":'), 2, "falta en un idioma")
        self.assertIn("nunca tu portapapeles", catalogue)
        self.assertIn("never your clipboard", catalogue)
        # Y el componente sigue usándolas.
        source = COMPONENT.read_text(encoding="utf-8")
        for key in ("demo.label", "demo.try"):
            self.assertIn(f'"{key}"', source)

    def test_no_sample_is_left_written_into_the_component(self) -> None:
        # El fallo de fondo: si alguien vuelve a escribir una URL en el QML,
        # se queda en un idioma otra vez.
        source = COMPONENT.read_text(encoding="utf-8")
        for line in source.splitlines():
            code = line.split("//", 1)[0]
            with self.subTest(line=code.strip()[:60]):
                self.assertNotIn("https://", code, "muestra escrita fuera del catálogo")




class DemoRunTests(unittest.TestCase):
    """Las dos costuras del tramo que la animación se come.

    La animación borra `spare` carácter a carácter. Si los tres tramos no
    recomponen exactamente el original y lo que queda no es exactamente lo
    que el motor devuelve, la pantalla enseña un recorte que el producto no
    hace, que es la misma mentira que estos tests existen para impedir.
    """

    def test_the_three_runs_rebuild_the_original(self) -> None:
        for lang in ("EN", "ES"):
            for index, (head, spare, tail, original, _) in enumerate(_runs(lang)):
                with self.subTest(lang=lang, sample=index):
                    self.assertEqual(head + spare + tail, original)

    def test_what_survives_is_what_the_engine_returns(self) -> None:
        for lang in ("EN", "ES"):
            for index, (head, spare, tail, original, cleaned) in enumerate(_runs(lang)):
                with self.subTest(lang=lang, sample=index):
                    self.assertEqual(head + tail, cleaned)
                    result = transform(original.encode("utf-8"), "text/plain", {})
                    self.assertEqual(result.output.decode("utf-8"), head + tail)

    def test_the_removed_run_is_one_continuous_piece(self) -> None:
        # El original tiene que llevar `spare` entero y de una pieza: si el
        # recorte fuera discontinuo, comérselo por un extremo se llevaría por
        # delante texto que sobrevive.
        for lang in ("EN", "ES"):
            for index, (head, spare, tail, original, _) in enumerate(_runs(lang)):
                with self.subTest(lang=lang, sample=index):
                    if not spare:
                        continue
                    self.assertEqual(original.count(spare), 1)
                    self.assertTrue(original.startswith(head + spare))

    def test_the_demo_speaks_through_the_catalogue(self) -> None:
        # El nombre accesible de la muestra iba escrito en español dentro del
        # QML, así que en inglés un lector de pantalla decía «Ejemplo
        # original: https://…».
        source = COMPONENT.read_text(encoding="utf-8")
        code = "\n".join(
            line for line in source.splitlines() if not line.strip().startswith("//"))
        for spanish in ("Resultado:", "Ejemplo original:"):
            self.assertNotIn(spanish, code)

    def test_every_sample_that_changes_carries_its_runs(self) -> None:
        # Y sólo ésas. Sin tramos la animación no puede correr; con tramos en
        # una muestra que no cambia, enseñaría desaparecer algo que se queda.
        for lang in ("EN", "ES"):
            table = _table(lang)
            for key in _catalogue_keys():
                changes = table[f"{key}.original"] != table[f"{key}.cleaned"]
                with self.subTest(lang=lang, sample=key):
                    self.assertEqual(changes, f"{key}.spare" in table)


if __name__ == "__main__":
    unittest.main()
