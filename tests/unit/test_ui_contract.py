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

    def test_every_qml_using_the_catalogue_imports_it(self) -> None:
        # Misma pareja uso/import que la guardia de arriba, y mismo desenlace:
        # `Service.qml` llamaba a `Strings.fromLocale` sin importar el
        # catálogo, así que resolver el idioma lanzaba `ReferenceError` y la
        # notificación de error del servicio no llegaba a formarse. Sólo se
        # veía en el journal del shell, nunca en los tests, porque el fichero
        # está perfectamente escrito: lo que faltaba era la línea de import.
        files = [*REPO.glob("*.qml"), *sorted((REPO / "components").glob("*.qml"))]
        for path in files:
            source = path.read_text(encoding="utf-8")
            if not re.search(r"\bStrings\s*\.", source):
                continue
            with self.subTest(file=path.name):
                self.assertRegex(source, r'import "(?:components/)?Strings\.js" as Strings')

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

    def test_the_first_run_ends_in_settings_with_a_visible_way_out(self) -> None:
        # 0006: los ajustes se enseñan, no se imponen. Sin salida rotulada
        # y visible dejarían de ser un paso y pasarían a ser una barrera.
        panel = (REPO / "Panel.qml").read_text(encoding="utf-8")
        advance = re.search(r"function advanceTour\(\) \{(?P<body>.*?)\n  \}", panel, re.DOTALL)
        self.assertIsNotNone(advance)
        self.assertIn("showOnboardingSettings()", advance.group("body"))
        self.assertIn('learningOrigin === "first-run"', advance.group("body"))

        # Dos salidas: el control de la cabecera y el botón del final.
        self.assertIn('"nav.skip"', panel)
        self.assertIn('onClicked: root.finishOnboarding()', panel)

        # Y ambas terminan en la pantalla principal, no en los ajustes.
        finish = re.search(r"function finishOnboarding\(\) \{(?P<body>.*?)\n  \}", panel, re.DOTALL)
        self.assertIsNotNone(finish)
        self.assertIn('panelPage = "clipboard"', finish.group("body"))
        self.assertIn("markOnboardingComplete()", finish.group("body"))

    def test_the_onboarding_marker_moves_when_the_screen_does(self) -> None:
        # La pantalla principal es otra cosa desde 0007, así que quien venía
        # de la 0.1.0 tiene que ver una vez qué ha cambiado.
        panel = (REPO / "Panel.qml").read_text(encoding="utf-8")
        self.assertIn("readonly property int onboardingVersion: 2", panel)

    def test_the_illustration_has_a_reduced_motion_path(self) -> None:
        art = (REPO / "components" / "TransformationIllustration.qml").read_text(encoding="utf-8")
        self.assertIn("property bool motionEnabled", art)
        # Con el movimiento apagado se pinta ya en su estado final, no a
        # medio recorrido: la ilustración tiene que contar lo mismo quieta.
        self.assertIn("motionEnabled ? 0 : 1", art)
        for user in ("WelcomePage.qml", "TourPage.qml"):
            with self.subTest(file=user):
                source = (REPO / "components" / user).read_text(encoding="utf-8")
                self.assertIn("motionEnabled: root.motionEnabled", source)

    def test_the_entrance_plays_once_and_never_loops(self) -> None:
        # Un bucle ambiente en una ilustración de onboarding es decoración,
        # y encima compite con el texto que la acompaña.
        art = (REPO / "components" / "TransformationIllustration.qml").read_text(encoding="utf-8")
        code = "\n".join(line.split("//", 1)[0] for line in art.splitlines())
        self.assertNotIn("loops:", code)
        self.assertNotIn("Animation.Infinite", code)
        self.assertNotIn("running: true", code)

    def test_the_entrance_animates_nothing_that_costs_a_layout(self) -> None:
        # transform y opacity van en la GPU; animar x, y o anchors obliga a
        # recomponer en cada fotograma.
        art = (REPO / "components" / "TransformationIllustration.qml").read_text(encoding="utf-8")
        animated = re.findall(r'property:\s*"(?P<name>[^"]+)"', art)
        allowed = {"enterFactor", "progress"}
        for name in animated:
            with self.subTest(property=name):
                self.assertIn(name, allowed)

    def test_welcome_cards_line_up_their_bodies(self) -> None:
        # Centrando el contenido, cada tarjeta lo colocaba según lo que
        # ocupara su título, y los tres cuerpos caían a alturas distintas.
        welcome = (REPO / "components" / "WelcomePage.qml").read_text(encoding="utf-8")
        self.assertIn("anchors.top: parent.top", welcome)
        self.assertIn("Math.round(font.pixelSize * 2.6)", welcome)
        # Y el alto de la tarjeta es un mínimo, no un número: si alguien
        # sube el tamaño de fuente del tema, el texto no se sale.
        self.assertIn("implicitHeight: Math.max(", welcome)

    def test_no_qml_carries_an_escaped_quote_where_a_string_should_be(self) -> None:
        """QML no es JavaScript dentro de una cadena de Python.

        Migrar el texto al catálogo se hizo con un script, y un `\\"` se
        coló en ocho componentes: `property string lang: \\"en\\"`. El QML
        dejó de compilar y el panel no montaba. Contar llaves no lo vio
        —estaban equilibradas— y ningún test lo vio tampoco, porque todos
        leen el fichero como texto. Lo cazó el shell al cargarlo.
        """
        files = [*REPO.glob("*.qml"), *sorted((REPO / "components").glob("*.qml"))]
        for path in files:
            source = path.read_text(encoding="utf-8")
            for number, line in enumerate(source.splitlines(), 1):
                code = line.split("//", 1)[0]
                # `\n` y `\"` dentro de una cadena ya abierta son legítimos;
                # lo que no lo es nunca es abrir la cadena con `\"`.
                with self.subTest(file=path.name, line=number):
                    self.assertNotRegex(code, r':\s*\\"', "cadena abierta con comilla escapada")

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
        # Con el catálogo, «una sola vez» pasa a ser «una sola clave»: sólo
        # la bienvenida puede pedir welcome.title.
        files = [*REPO.glob("*.qml"), *sorted((REPO / "components").glob("*.qml"))]
        owners = [p.name for p in files if '"welcome.title"' in p.read_text(encoding="utf-8")]
        self.assertEqual(owners, ["WelcomePage.qml"], "el titular de bienvenida se repite")
        # Y nadie escribe la frase a pelo en el QML.
        for path in files:
            with self.subTest(file=path.name):
                self.assertIsNone(_shows(path.read_text(encoding="utf-8"), "sin sorpresas"))

    def test_the_illustration_stays_in_the_first_experience(self) -> None:
        # Ensena la transformacion en abstracto: util una vez, decorativo
        # despues. Solo la bienvenida y el tour tienen esa excusa.
        files = [*REPO.glob("*.qml"), *sorted((REPO / "components").glob("*.qml"))]
        users = sorted(
            p.name for p in files
            if "TransformationIllustration {" in p.read_text(encoding="utf-8")
        )
        self.assertEqual(users, ["TourPage.qml", "WelcomePage.qml"])

    def test_what_teaches_on_the_everyday_screen_is_gated_to_the_empty_state(self) -> None:
        # 0007 admite enseñar cuando no hay nada que informar, y 0008 puso
        # ahí el carrusel. La excepción es esa condición, no ese componente:
        # el guarda comprueba que todo lo que enseñe en el panel esté atado
        # al portapapeles vacío.
        panel = (REPO / "Panel.qml").read_text(encoding="utf-8")
        for name in ("TransformationIllustration", "EmptyCarousel"):
            for block in re.finditer(name + r" \{(?P<body>.*?)\n\s{14}\}", panel, re.DOTALL):
                with self.subTest(component=name):
                    self.assertIn("visible: root.peekEmpty", block.group("body"))

    def test_skip_state_label_keeps_button_padding(self) -> None:
        # La etiqueta larga desbordaba el padding del botón. Vive ahora en
        # el catálogo, y la restricción aplica a los dos idiomas.
        catalogue = (REPO / "components" / "Strings.js").read_text(encoding="utf-8")
        self.assertIn('"action.skipped": "Próxima copia omitida"', catalogue)
        self.assertIn('"action.skipped": "Next copy skipped"', catalogue)
        for label in re.findall(r'"action\.skipped":\s*"([^"]+)"', catalogue):
            with self.subTest(label=label):
                self.assertLessEqual(len(label), 26, "no cabe en el botón")


if __name__ == "__main__":
    unittest.main()
