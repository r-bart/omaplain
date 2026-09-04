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
ICONO = REPO / "io.github.r-bart.omaplain.svg"
MARCA = REPO / "components" / "Mark.qml"
PANEL = REPO / "Panel.qml"

# El nombre se escribe de tres maneras, y cada una tiene su sitio:
#
#   omaplain   el logotipo — cabecera del panel y manifiesto, siempre con la
#              marca delante, que es lo que lo hace un logotipo
#   Omaplain   el lanzador — ahí el nombre se lista junto a «Aether»,
#              «Basecamp» y «Document Viewer», y en esa columna una minúscula
#              no se lee como una marca, se lee como una errata
#   OmaPlain   la prosa — el nombre propio, en las cadenas de los dos idiomas
#
# Los ficheros que las escriben están lejos unos de otros y ninguno importa al
# otro, así que la única forma de que no se separen es un test que los lea a
# la vez.
LOGOTIPO = "omaplain"
LANZADOR = "Omaplain"
PROSA = "OmaPlain"


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
        # La 0021: el derecho no hace nada, y así se queda. `pasteClean`
        # reescribe el portapapeles y al reescribirlo el original deja de
        # existir, porque OmaPlain no guarda historial.
        #
        # Mirar sólo que `Qt.RightButton` aparece —que es lo que este test
        # hacía— pasaría en verde con la acción escrita dos líneas más abajo.
        # Lo que hay que comprobar es que la rama del derecho **sale**, y que
        # el widget no tiene más que una cosa que ejecutar.
        code = self._code()
        rama = [l for l in code.splitlines() if "Qt.RightButton" in l]
        self.assertEqual(len(rama), 1, "el derecho se decide en un solo sitio")
        self.assertIn("return", rama[0], "la rama del derecho no sale")
        self.assertEqual(code.count(".run("), 1,
                         "el widget ejecuta más de una cosa")

    def test_the_right_button_is_a_promise_and_not_a_gap(self) -> None:
        # Un gesto que hoy está muerto y mañana escribe en el portapapeles es
        # justo el cambio que la promesa de la 1.0 existe para impedir. Así
        # que está dicho hacia fuera, en el README, y no sólo en el código.
        readme = " ".join((REPO / "README.md").read_text(encoding="utf-8").split())
        self.assertIn("Right click deliberately does nothing", readme)

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
        self.assertEqual(e["Name"], LANZADOR)
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


class BrandTests(unittest.TestCase):
    """La marca: un dibujo, tres sitios y un solo nombre ([`0020`]).

    El icono de la barra, el del lanzador y el de la cabecera del panel son
    el mismo trazo. Nada del lenguaje lo impone —el lanzador lee un SVG y el
    shell ejecuta QML—, así que lo impone esto.
    """

    def _svg_path(self) -> str:
        svg = ICONO.read_text(encoding="utf-8")
        m = re.search(r'<path d="([^"]+)"', svg)
        assert m, "el icono del lanzador ya no lleva un trazo"
        return m.group(1)

    def _qml_path(self) -> str:
        m = re.search(r'readonly property string path: "([^"]+)"',
                      MARCA.read_text(encoding="utf-8"))
        assert m, "la marca del panel ya no lleva un trazo"
        return m.group(1)

    def test_the_launcher_and_the_shell_draw_the_same_stroke(self) -> None:
        # Carácter por carácter. Los puntos de control de esa curva están
        # calculados para que la curvatura sea la misma a los dos lados de
        # cada nodo, y «redondear un poco» uno de los dos ficheros deja dos
        # marcas parecidas, que es peor que dos marcas distintas.
        self.assertEqual(self._qml_path(), self._svg_path())

    def test_the_shell_draws_the_mark_instead_of_importing_it(self) -> None:
        # Un `Image` del SVG habría sido una línea, y habría traído sus
        # colores dentro: trazo casi negro sobre un panel casi negro. El
        # trazo se pinta en la tinta del sitio y el punto en el acento.
        marca = "\n".join(l for l in MARCA.read_text(encoding="utf-8").splitlines()
                          if not l.strip().startswith("//"))
        self.assertNotIn("Image", marca)
        self.assertNotIn("source:", marca)
        self.assertIn("property color ink", marca)
        self.assertIn("property color dot", marca)
        self.assertIn("Color.accent", marca)

    def test_the_bar_wears_the_mark_and_not_a_borrowed_glyph(self) -> None:
        # El glifo de «pegar en claro» de Material Design Icons es correcto
        # y no es nuestro: en una barra donde todo sale de esa familia dice
        # lo que hace la aplicación y no dice cuál es.
        widget = WIDGET.read_text(encoding="utf-8")
        self.assertIn("Mark {", widget)
        self.assertNotIn("\U000f014c", widget)
        # Y sin rótulo el kit mide un texto vacío: el ancho lo pone el dibujo.
        self.assertIn("labelVisible: false", widget)
        self.assertIn("hasVisualContent: true", widget)
        self.assertIn("fixedWidth:", widget)

    def test_the_logotype_is_lowercase_where_the_mark_is_beside_it(self) -> None:
        m = json.loads(MANIFEST.read_text(encoding="utf-8"))
        self.assertEqual(m["name"], LOGOTIPO)
        self.assertEqual(m["barWidget"]["displayName"], LOGOTIPO)
        panel = PANEL.read_text(encoding="utf-8")
        self.assertIn(f'text: "{LOGOTIPO}"', panel)
        # Y con la marca delante, que es lo que lo hace un logotipo y no un
        # descuido: el `Row` de la cabecera monta la una y luego el otro.
        cabecera = panel.split("id: brand", 1)[1].split(f'text: "{LOGOTIPO}"', 1)[0]
        self.assertIn("Mark {", cabecera)

    def test_the_launcher_capitalises_because_it_is_a_list_of_names(self) -> None:
        """En el lanzador el nombre no es un logotipo: es una fila.

        La marca está ahí, pero en la columna de iconos, igual que la de
        todas las demás. El nombre se lee en una lista junto a «Aether» y
        «Document Viewer», y una minúscula en esa columna no dice «marca»,
        dice «errata».
        """
        self.assertEqual(self._entry_name(), LANZADOR)

    def test_the_three_spellings_are_the_same_word(self) -> None:
        # Tres maneras ya son las que caben. Una cuarta sería un descuido, no
        # una decisión, y desde dentro de cualquiera de los tres ficheros no
        # se ve.
        formas = {LOGOTIPO, LANZADOR, PROSA}
        self.assertEqual(len(formas), 3)
        for forma in formas:
            with self.subTest(forma=forma):
                self.assertEqual(forma.lower(), LOGOTIPO)

    def test_the_wordmark_is_not_the_proper_noun(self) -> None:
        """En la prosa se sigue escribiendo «OmaPlain».

        Un logotipo y un nombre propio son dos cosas distintas: bajar la
        inicial a mitad de frase se lee como una errata, y a principio de
        frase también. El nombre en minúscula vale donde va con el dibujo
        delante, que es lo que lo hace un logotipo y no un descuido.
        """
        catalogo = (REPO / "components" / "Strings.js").read_text(encoding="utf-8")
        self.assertIn(PROSA, catalogo)
        self.assertNotIn(f'"{LOGOTIPO}', catalogo)
        self.assertNotIn(LANZADOR, catalogo)

    def _entry_name(self) -> str:
        c = configparser.ConfigParser(interpolation=None)
        c.optionxform = str
        c.read(DESKTOP, encoding="utf-8")
        return c["Desktop Entry"]["Name"]


class DecisionTests(unittest.TestCase):
    def test_the_decision_is_written_down(self) -> None:
        texto = (REPO / "docs" / "decisions"
                 / "0010-como-se-abre-el-panel.md").read_text(encoding="utf-8")
        # Y dice lo que descartó, que es la mitad que se olvida.
        self.assertIn("Descartado", texto)
        self.assertIn("Hyprland", texto)

    def test_the_free_right_button_has_its_own_decision(self) -> None:
        # La 0010 lo dejó abierto con nombre y apellidos; la 0021 lo cierra.
        texto = (REPO / "docs" / "decisions"
                 / "0021-el-clic-derecho-de-la-barra-queda-libre.md").read_text(encoding="utf-8")
        self.assertIn("## Lo que se descartó", texto)
        # Y dice por qué no es «todavía no lo hemos decidido»: la acción que
        # se le colgaría no se deshace.
        self.assertIn("pasteClean", texto)

    def test_the_mark_has_its_own_decision(self) -> None:
        texto = (REPO / "docs" / "decisions"
                 / "0020-la-marca-se-dibuja.md").read_text(encoding="utf-8")
        self.assertIn("## Lo que se descartó", texto)
        # Y responde a la pregunta que la abrió: el punto sigue al tema
        # donde lo pintamos nosotros, y no en el lanzador.
        self.assertIn("lanzador", texto)
