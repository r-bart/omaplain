"""Las dos formas de abrir el panel: el icono de la barra y el lanzador.

Hasta la `0.2.0` sólo se abría escribiendo un comando. La `0010` añade las dos
superficies y decide que ninguna es obligatoria: el icono se coloca desde
`bar.layout` en `shell.json`, que es el mando que Omarchy ya tiene, y la
entrada `.desktop` se copia a mano porque el plugin no vive en `XDG_DATA_DIRS`.
"""

from __future__ import annotations

import configparser
import json
import re
import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[2]
MANIFEST = REPO / "manifest.json"
WIDGET = REPO / "BarWidget.qml"
DESKTOP = REPO / "io.github.r-bart.omaplain.desktop"


class ManifestTests(unittest.TestCase):
    def _manifest(self) -> dict:
        return json.loads(MANIFEST.read_text(encoding="utf-8"))

    def test_the_bar_widget_is_declared_with_its_entry_point(self) -> None:
        m = self._manifest()
        self.assertIn("bar-widget", m["kinds"])
        self.assertEqual(m["entryPoints"]["barWidget"], "BarWidget.qml")
        self.assertTrue(WIDGET.exists())

    def test_the_bar_block_is_complete(self) -> None:
        bloque = self._manifest()["barWidget"]
        for clave in ("displayName", "description", "category", "allowMultiple"):
            self.assertIn(clave, bloque)
        self.assertFalse(bloque["allowMultiple"], "un solo icono basta")

    def test_the_service_and_panel_survive(self) -> None:
        # Añadir una superficie no puede llevarse las dos que ya había.
        m = self._manifest()
        for kind in ("service", "panel"):
            self.assertIn(kind, m["kinds"])
            self.assertIn(kind, m["entryPoints"])


class BarWidgetTests(unittest.TestCase):
    def _code(self) -> str:
        source = WIDGET.read_text(encoding="utf-8")
        return "\n".join(l for l in source.splitlines() if not l.strip().startswith("//"))

    def test_the_widget_only_opens_the_panel(self) -> None:
        # La frontera de la 0005 no se mueve: el icono no lee el portapapeles
        # ni recibe su contenido. Llama a `toggle` y nada más.
        code = self._code()
        self.assertIn("shell toggle io.github.r-bart.omaplain", code)
        for prohibido in ("peek", "cleanNow", "pasteClean", "wl-paste", "wl-copy",
                          "clipboard"):
            with self.subTest(forbidden=prohibido):
                self.assertNotIn(prohibido, code)

    def test_the_widget_carries_no_visibility_setting_of_its_own(self) -> None:
        # Quien decide si aparece es `bar.layout`. Un ajuste nuestro duplicaría
        # el mando de la plataforma y competiría con él.
        code = self._code()
        for prohibido in ("showInBar", "barVisible", "updateSetting"):
            with self.subTest(forbidden=prohibido):
                self.assertNotIn(prohibido, code)

    def test_the_right_button_stays_free(self) -> None:
        # `pasteClean` escribe en el portapapeles. Un gesto que se dispara sin
        # querer merece su propia decisión.
        self.assertIn("Qt.RightButton", self._code())

    def test_the_widget_is_named_for_a_screen_reader(self) -> None:
        code = self._code()
        self.assertIn("Accessible.name", code)
        catalogue = (REPO / "components" / "Strings.js").read_text(encoding="utf-8")
        self.assertEqual(catalogue.count('"bar.a11y"'), 2, "falta en un idioma")


class DesktopEntryTests(unittest.TestCase):
    def _entry(self) -> configparser.SectionProxy:
        c = configparser.ConfigParser(interpolation=None)
        c.optionxform = str
        c.read(DESKTOP, encoding="utf-8")
        return c["Desktop Entry"]

    def test_the_entry_has_what_the_spec_requires(self) -> None:
        e = self._entry()
        self.assertEqual(e["Type"], "Application")
        self.assertEqual(e["Name"], "OmaPlain")
        self.assertTrue(e["Exec"])

    def test_the_exec_line_carries_no_reserved_character(self) -> None:
        # `desktop-file-validate` rechaza las comillas simples en `Exec`, y el
        # panel ignora el payload de todas formas: `toggle` funciona sin él.
        exec_line = self._entry()["Exec"]
        for reservado in "\"'`$<>~|&;*?#()":
            with self.subTest(char=reservado):
                self.assertNotIn(reservado, exec_line)

    def test_the_launcher_finds_it_in_both_languages(self) -> None:
        palabras = self._entry()["Keywords"].lower()
        for palabra in ("clipboard", "paste", "portapapeles", "pegar"):
            with self.subTest(keyword=palabra):
                self.assertIn(palabra, palabras)

    def test_the_entry_opens_the_same_thing_the_icon_does(self) -> None:
        exec_line = self._entry()["Exec"]
        widget = WIDGET.read_text(encoding="utf-8")
        orden = "shell toggle io.github.r-bart.omaplain"
        self.assertIn(orden, exec_line)
        self.assertIn(orden, widget)


class DecisionTests(unittest.TestCase):
    def test_the_decision_is_written_down(self) -> None:
        texto = (REPO / "docs" / "decisions"
                 / "0010-como-se-abre-el-panel.md").read_text(encoding="utf-8")
        # Y dice lo que descartó, que es la mitad que se olvida.
        self.assertIn("Descartado", texto)
        self.assertIn("Hyprland", texto)
