import re
import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[2]


def _rgb(value: str) -> tuple[float, float, float]:
    return tuple(int(value[index:index + 2], 16) / 255 for index in (1, 3, 5))


def _luminance(color: tuple[float, float, float]) -> float:
    channels = [
        channel / 12.92 if channel <= 0.04045 else ((channel + 0.055) / 1.055) ** 2.4
        for channel in color
    ]
    return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2]


def _contrast_with_alpha(foreground: str, background: str, alpha: float) -> float:
    fg = _rgb(foreground)
    bg = _rgb(background)
    composite = tuple(fg[index] * alpha + bg[index] * (1 - alpha) for index in range(3))
    light, dark = sorted((_luminance(composite), _luminance(bg)), reverse=True)
    return (light + 0.05) / (dark + 0.05)


def _shows(source: str, phrase: str) -> str | None:
    """Devuelve la línea que *muestra* la frase, ignorando comentarios."""
    for line in source.splitlines():
        code = line.split("//", 1)[0]
        if "text:" in code and phrase in code:
            return line.strip()
    return None


class UiContractTests(unittest.TestCase):
    def test_secondary_text_alpha_passes_reference_palettes(self) -> None:
        palettes = {
            "nightcall": ("#ddd9ef", "#090a16"),
            "periphery": ("#a9c0bf", "#060f12"),
            "dawn": ("#2b2620", "#f4ece0"),
            "quattrocento-light": ("#33291b", "#f0e6d3"),
        }
        for name, (foreground, background) in palettes.items():
            with self.subTest(theme=name):
                self.assertGreaterEqual(_contrast_with_alpha(foreground, background, 0.68), 4.5)

    def test_known_low_contrast_text_opacities_do_not_return(self) -> None:
        files = [
            REPO / "Panel.qml",
            REPO / "components" / "WelcomePage.qml",
            REPO / "components" / "TourPage.qml",
            REPO / "components" / "ExcludedAppRow.qml",
            REPO / "components" / "EmptyState.qml",
            REPO / "components" / "DemoTransformation.qml",
        ]
        low_contrast = re.compile(r"Util\.alpha\(Color\.popups\.text, 0\.(?:58|62|66)\)")
        for path in files:
            with self.subTest(file=path.name):
                self.assertIsNone(low_contrast.search(path.read_text(encoding="utf-8")))

    def test_every_qml_using_a_commons_singleton_imports_it(self) -> None:
        # La 0.1.0 se publicó con los nueve controles del panel invisibles:
        # SettingRow.qml usaba Style.space() sin importar qs.Commons, asi que
        # `Style` no existia y su implicitHeight colapsaba a cero. Ningun test
        # lo vio porque `Style.space(44)` esta perfectamente escrito; lo que
        # faltaba era el import. Esta guardia mira la pareja uso/import, que es
        # lo unico que lo detecta sin abrir el panel.
        singletons = ("Style", "Color", "Util", "Border")
        files = [*REPO.glob("*.qml"), *sorted((REPO / "components").glob("*.qml"))]
        self.assertTrue(files, "no se encontro ningun QML que revisar")
        for path in files:
            source = path.read_text(encoding="utf-8")
            used = [n for n in singletons if re.search(r"\b" + n + r"\s*\.", source)]
            if not used:
                continue
            with self.subTest(file=path.name, uses=",".join(used)):
                self.assertIn("import qs.Commons", source)

    def test_controls_scale_the_minimum_hit_height(self) -> None:
        files = [REPO / "Panel.qml", *sorted((REPO / "components").glob("*.qml"))]
        raw_height = re.compile(r"(?:implicitHeight:\s*44\b|Math\.max\(44\b)")
        for path in files:
            with self.subTest(file=path.name):
                self.assertIsNone(raw_height.search(path.read_text(encoding="utf-8")))

    def test_internal_view_changes_do_not_wait_for_open_timer(self) -> None:
        panel = (REPO / "Panel.qml").read_text(encoding="utf-8")
        handler = re.search(r"onViewModeChanged:\s*\{(?P<body>.*?)\n\s*\}", panel, re.DOTALL)
        self.assertIsNotNone(handler)
        self.assertIn("Qt.callLater(root.applyViewFocus)", handler.group("body"))
        self.assertNotIn("initialFocusTimer.restart()", handler.group("body"))

    def test_welcome_cards_share_a_multicolumn_height(self) -> None:
        welcome = (REPO / "components" / "WelcomePage.qml").read_text(encoding="utf-8")
        self.assertIn("features.columns === 1", welcome)
        self.assertIn(": Style.space(108)", welcome)

    def test_exclusions_render_an_empty_state_only_while_both_lists_are_empty(self) -> None:
        panel = (REPO / "Panel.qml").read_text(encoding="utf-8")
        block = re.search(r"EmptyState \{(?P<body>.*?)\n\s{12}\}", panel, re.DOTALL)
        self.assertIsNotNone(block, "el panel ya no monta un EmptyState")
        body = block.group("body")
        # Ambas listas comparten un solo hueco: mostrarlo con una de las dos ya
        # poblada repetiria la explicacion junto a las filas que la contradicen.
        self.assertIn('root.setting("sourceExclusions", []).length === 0', body)
        self.assertIn('root.setting("targetExclusions", []).length === 0', body)
        self.assertIn("&&", body)
        # El hueco precede a los Repeater, o aparecería debajo de las filas.
        self.assertLess(panel.index("EmptyState {"), panel.index('model: root.setting("sourceExclusions"'))

    def test_empty_state_stays_a_static_text_for_assistive_tools(self) -> None:
        empty = (REPO / "components" / "EmptyState.qml").read_text(encoding="utf-8")
        self.assertIn("Accessible.role: Accessible.StaticText", empty)
        self.assertIn("Accessible.name: root.title", empty)
        self.assertIn("Accessible.description: root.body", empty)
        # Sin foco propio: es un cartel, no una parada del recorrido por teclado.
        self.assertNotIn("focusable: true", empty)

    def test_the_demo_belongs_to_the_step_that_promises_it(self) -> None:
        tour = (REPO / "components" / "TourPage.qml").read_text(encoding="utf-8")
        block = re.search(r"DemoTransformation \{(?P<body>.*?)\n\s{6}\}", tour, re.DOTALL)
        self.assertIsNotNone(block, "el tour ya no monta la demostración")
        # Los pasos 1 y 3 hablan de observar copias y de mantener el control;
        # una demostración de limpieza allí no ilustra su propio texto.
        self.assertIn("visible: root.step === 1", block.group("body"))

    def test_changing_step_returns_the_demo_to_its_question(self) -> None:
        tour = (REPO / "components" / "TourPage.qml").read_text(encoding="utf-8")
        self.assertIn("onStepChanged: demo.reset()", tour)
        demo = (REPO / "components" / "DemoTransformation.qml").read_text(encoding="utf-8")
        reset = re.search(r"function reset\(\) \{(?P<body>.*?)\n  \}", demo, re.DOTALL)
        self.assertIsNotNone(reset)
        self.assertIn("revealed = false", reset.group("body"))
        self.assertIn("sampleIndex = 0", reset.group("body"))

    def test_no_qml_introduces_a_palette_of_its_own(self) -> None:
        """F3.9: todo color sale del tema, para que la app lo siga al 100 %.

        `FogCover` nació incumpliéndolo: llevaba un lavanda escrito a mano
        que sobre un tema verde o ámbar seguía siendo lila. Un color con
        matiz propio es una paleta propia aunque sólo sean dos líneas.

        Se permiten los neutros puros —`Qt.rgba(0,0,0,a)` y
        `Qt.rgba(1,1,1,a)`— porque en un Canvas no eligen color: son la
        plantilla alfa de un `destination-out`.
        """
        hexish = re.compile(r'"#[0-9a-fA-F]{3,8}"')
        rgba = re.compile(r"Qt\.rgba\(\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)")
        files = [*REPO.glob("*.qml"), *sorted((REPO / "components").glob("*.qml"))]
        for path in files:
            source = path.read_text(encoding="utf-8")
            code = "\n".join(line.split("//", 1)[0] for line in source.splitlines())
            with self.subTest(file=path.name):
                self.assertIsNone(hexish.search(code), "color hexadecimal literal")
                for match in rgba.finditer(code):
                    channels = {round(float(v), 4) for v in match.groups()}
                    self.assertEqual(
                        len(channels), 1,
                        f"{path.name}: Qt.rgba con matiz propio -> {match.group(0)}",
                    )

    def test_the_everyday_header_teaches_nothing(self) -> None:
        # 0004 dijo que la primera apertura es educativa y las siguientes van
        # a la accion. No se cumplio: el heroe se quedo fijo en la vista
        # principal repitiendo, palabra por palabra, el titular de la
        # bienvenida. 0007 lo separo; esto vigila que no vuelva.
        header = (REPO / "components" / "StatusHeader.qml").read_text(encoding="utf-8")
        # Se busca en la asignacion, no en el fichero entero: el invariante
        # es sobre lo que se muestra, y el comentario cita la frase retirada
        # justo para explicar por que ya no esta.
        self.assertIsNone(_shows(header, "sin sorpresas"))
        self.assertNotIn("TransformationIllustration {", header)

    def test_the_welcome_headline_lives_in_exactly_one_place(self) -> None:
        files = [*REPO.glob("*.qml"), *sorted((REPO / "components").glob("*.qml"))]
        owners = [p.name for p in files if _shows(p.read_text(encoding="utf-8"), "sin sorpresas")]
        self.assertEqual(owners, ["WelcomePage.qml"], "el titular de bienvenida se repite")

    def test_the_illustration_stays_in_the_first_experience(self) -> None:
        # Ensena la transformacion en abstracto: util una vez, decorativo
        # despues. Solo la bienvenida y el tour tienen esa excusa.
        files = [*REPO.glob("*.qml"), *sorted((REPO / "components").glob("*.qml"))]
        users = sorted(
            p.name for p in files
            if "TransformationIllustration {" in p.read_text(encoding="utf-8")
        )
        self.assertEqual(users, ["TourPage.qml", "WelcomePage.qml"])

    def test_skip_state_label_keeps_button_padding(self) -> None:
        panel = (REPO / "Panel.qml").read_text(encoding="utf-8")
        self.assertIn('"Próxima copia omitida"', panel)
        self.assertNotIn('? "Se omitirá la próxima copia" :', panel)


if __name__ == "__main__":
    unittest.main()
