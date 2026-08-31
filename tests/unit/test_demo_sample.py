import re
import unittest
from pathlib import Path

from omaplain_lib.transform import transform


REPO = Path(__file__).resolve().parents[2]
COMPONENT = REPO / "components" / "DemoTransformation.qml"

FIELD = re.compile(
    r'\{\s*"original":\s*"(?P<original>[^"]*)",\s*'
    r'"cleaned":\s*"(?P<cleaned>[^"]*)",\s*'
    r'"outcome":\s*"(?P<outcome>[^"]*)"\s*\}',
    re.DOTALL,
)


def _samples() -> list[dict[str, str]]:
    return [m.groupdict() for m in FIELD.finditer(COMPONENT.read_text(encoding="utf-8"))]


class DemoSampleTests(unittest.TestCase):
    def test_the_component_still_declares_samples(self) -> None:
        self.assertGreaterEqual(len(_samples()), 2)

    def test_every_shown_result_is_what_the_engine_actually_produces(self) -> None:
        # El corazon de la demostracion: si una regla cambia y el resultado
        # rotulado deja de ser el real, la demo pasa a mentirle a alguien que
        # todavia no confia en el plugin. Aqui se rompe antes.
        for index, sample in enumerate(_samples()):
            with self.subTest(sample=index):
                result = transform(sample["original"].encode("utf-8"), "text/plain", {})
                self.assertEqual(result.output.decode("utf-8"), sample["cleaned"])

    def test_the_pair_shows_both_halves_of_the_promise(self) -> None:
        # Una sola muestra que limpia vende la mitad util. La otra mitad, la que
        # gana confianza, es la que el motor se niega a tocar.
        changed = []
        for sample in _samples():
            result = transform(sample["original"].encode("utf-8"), "text/plain", {})
            changed.append(result.changed)
        self.assertIn(True, changed, "ninguna muestra demuestra una limpieza")
        self.assertIn(False, changed, "ninguna muestra demuestra la contencion")

    def test_a_preserved_sample_is_shown_unchanged(self) -> None:
        for index, sample in enumerate(_samples()):
            result = transform(sample["original"].encode("utf-8"), "text/plain", {})
            if not result.changed:
                with self.subTest(sample=index):
                    self.assertEqual(sample["original"], sample["cleaned"])

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
        catalogue = (REPO / "components" / "Strings.js").read_text(encoding="utf-8")
        for key in ("demo.label", "demo.try", "demo.original"):
            with self.subTest(key=key):
                self.assertEqual(catalogue.count(f'"{key}":'), 2, "falta en un idioma")
        self.assertIn("nunca tu portapapeles", catalogue)
        self.assertIn("never your clipboard", catalogue)
        # Y el componente sigue usándolas.
        source = COMPONENT.read_text(encoding="utf-8")
        for key in ("demo.label", "demo.try", "demo.original"):
            self.assertIn(f'"{key}"', source)


if __name__ == "__main__":
    unittest.main()
