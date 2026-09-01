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


def _blocks(source: str, name: str) -> list[str]:
    """Cada bloque `Nombre { ... }` del QML, contando llaves.

    Las expresiones regulares con sangría fija se rompen en cuanto un bloque
    cambia de sitio, y peor: siguen encontrando *otro* bloque y el test pasa
    hablando de algo que no es.
    """
    blocks = []
    for start in range(len(source)):
        if not source.startswith(name + " {", start):
            continue
        depth = 0
        for index in range(start + len(name) + 1, len(source)):
            if source[index] == "{":
                depth += 1
            elif source[index] == "}":
                depth -= 1
                if depth == 0:
                    blocks.append(source[start:index + 1])
                    break
    return blocks


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

    def test_no_source_smuggles_an_invisible_character_outside_a_string(self) -> None:
        """Un producto que retira invisibles no puede llevarlos dentro.

        Escribiendo un comentario se coló un guion suave en `CopySpecimen`.
        No rompe nada y no se ve —ese es justo el problema: nadie lo iba a
        encontrar leyendo. Dentro de una cadena sí son legítimos, porque el
        ejemplo del tour lleva un ZWSP a propósito: es lo que enseña.
        """
        invisible = re.compile("[\u00ad\u200b-\u200f\u2060\ufeff]")
        literal = re.compile(r'"(?:[^"\\]|\\.)*"')
        files = [
            *REPO.glob("*.qml"),
            *sorted((REPO / "components").glob("*.qml")),
            REPO / "components" / "Strings.js",
        ]
        for path in files:
            for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
                with self.subTest(file=path.name, line=number):
                    self.assertIsNone(invisible.search(literal.sub("", line)))

    def test_the_cycling_text_never_reaches_a_screen_reader(self) -> None:
        """El carrusel se anuncia una vez, no tres veces cada ocho segundos.

        Los ejemplos cambian solos cada 2,6 s y no hay forma de pararlos, así
        que exponer su texto convierte la pantalla en un goteo de anuncios sin
        control. Lo que se anuncia es el resumen del `root`, que no cambia; el
        texto de dentro queda fuera del árbol.
        """
        source = (REPO / "components" / "EmptyCarousel.qml").read_text(encoding="utf-8")
        self.assertIn("Accessible.role: Accessible.StaticText", source)
        self.assertIn('Accessible.name: Strings.t("empty.art.a11y"', source)

        lines = source.splitlines()
        openings = [n for n, line in enumerate(lines) if line.rstrip().endswith("Text {")]
        self.assertTrue(openings, "el carrusel ya no monta texto")
        for number in openings:
            window = "\n".join(lines[number + 1:number + 4])
            with self.subTest(line=number + 1):
                self.assertIn("Accessible.ignored: true", window)

    def test_a_locked_row_cannot_be_uncovered_by_anyone(self) -> None:
        """0009: la negativa no depende de que quien llama se acuerde.

        El panel podría olvidarse de no pedir el revelado, o llegar un
        `shown: true` de cualquier otro sitio. La fila calcula lo que
        concede a partir de lo que le piden y de si está bajo llave, y todo
        lo que enseña cuelga de lo concedido.
        """
        row = (REPO / "components" / "ClipboardRow.qml").read_text(encoding="utf-8")
        self.assertIn("readonly property bool revealed: root.shown && !root.locked", row)
        # Nada de lo que se ve puede colgar de `shown` a secas.
        for line in row.splitlines():
            code = line.split("//", 1)[0]
            if "property bool shown" in code or "revealed:" in code:
                continue
            with self.subTest(line=code.strip()[:60]):
                self.assertNotIn("root.shown", code, "algo se enseña sin mirar la llave")
        # Y el gesto de limpiar el vaho tampoco levanta la fila bloqueada.
        self.assertIn("onCleared: if (!root.locked) root.revealRequested()", row)

    def test_the_eye_goes_back_down_with_every_new_answer(self) -> None:
        # Revelar una fila y copiar otra cosa enseñaba lo nuevo sin que nadie
        # lo pidiera. La cubierta existe justo para impedir eso.
        panel = (REPO / "Panel.qml").read_text(encoding="utf-8")
        handler = re.search(r"onPeekChanged: \{(?P<body>.*?)\n  \}", panel, re.DOTALL)
        self.assertIsNotNone(handler, "el panel ya no reinicia el ojo")
        self.assertIn("showBefore = false", handler.group("body"))
        self.assertIn("showAfter = false", handler.group("body"))

    def test_every_animated_component_is_driven_by_the_motion_setting(self) -> None:
        # F.1: la propiedad existía en cinco componentes y no la conducía
        # nadie, así que la vía de movimiento reducido no se podía alcanzar.
        panel = (REPO / "Panel.qml").read_text(encoding="utf-8")
        self.assertIn('readonly property bool motionEnabled: !setting("reduceMotion", false)', panel)
        for name in ("WelcomePage", "TourPage", "EmptyCarousel", "ClipboardRow"):
            with self.subTest(component=name):
                for block in _blocks(panel, name):
                    self.assertIn("motionEnabled: root.motionEnabled", block)

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

    def test_each_pair_of_lists_renders_its_own_empty_state(self) -> None:
        # Ambas listas de una sección comparten un solo hueco: mostrarlo con
        # una de las dos ya poblada repetiría la explicación justo al lado de
        # las filas que la contradicen.
        #
        # Buscar «el primer EmptyState» dejó de valer al añadir la sección de
        # privacidad: el test seguía en verde porque el bloque que encontraba
        # abarcaba los dos. Ahora se localiza cada uno por sus propias listas.
        panel = (REPO / "Panel.qml").read_text(encoding="utf-8")
        pairs = {
            "exclusiones": ("sourceExclusions", "targetExclusions"),
            "privacidad": ("alwaysCovered", "blockedApps"),
        }
        for section, (first, second) in pairs.items():
            with self.subTest(section=section):
                block = next(
                    (b for b in _blocks(panel, "EmptyState") if first in b and second in b),
                    None,
                )
                self.assertIsNotNone(block, f"{section} no monta su propio EmptyState")
                self.assertIn(f'root.setting("{first}", []).length === 0', block)
                self.assertIn(f'root.setting("{second}", []).length === 0', block)
                self.assertIn("&&", block)
                # Y precede a sus Repeater, o aparecería debajo de las filas.
                self.assertLess(panel.index(block), panel.index(f'model: root.setting("{first}"'))

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

    # ------------------------------------------------------------------
    # Toda negativa del helper tiene su propia frase en el panel
    # ------------------------------------------------------------------

    @staticmethod
    def _peek_refusal_reasons() -> set[str]:
        """Los motivos por los que `peek` puede negarse, sacados del helper.

        No es una lista escrita a mano: se deriva de los tres módulos que
        emiten motivos. Escrita a mano se quedaría vieja en cuanto alguien
        añadiera un `TransformBypass`, que es exactamente como el panel
        acabó diciendo «Nothing to clean here» de un portapapeles de 1,4 MB
        y de una aplicación bloqueada.
        """
        clasificar = (REPO / "helper" / "omaplain_lib" / "classify.py").read_text(encoding="utf-8")
        transformar = (REPO / "helper" / "omaplain_lib" / "transform.py").read_text(encoding="utf-8")
        demonio = (REPO / "helper" / "omaplain_lib" / "daemon.py").read_text(encoding="utf-8")

        reasons = set(re.findall(r'Classification\(\s*False,\s*"([a-z_]+)"', clasificar))
        reasons |= set(re.findall(r'TransformBypass\(\s*"([a-z_]+)"', transformar))

        # `peek` llama a `_inspect_and_transform` con `automatic=False`, así
        # que las salidas que cuelgan de `if automatic and ...` no le llegan.
        cuerpo = re.search(
            r"def _inspect_and_transform\(.*?\n    def ", demonio, re.DOTALL,
        )
        assert cuerpo, "no encuentro _inspect_and_transform"
        guarda = ""
        for linea in cuerpo.group(0).splitlines():
            desnuda = linea.split("#", 1)[0]
            if re.match(r"\s*if\b", desnuda):
                guarda = desnuda
            hallado = re.search(r'OperationResult\(\s*"(?:bypassed|error)",\s*"([a-z_]+)"', desnuda)
            if hallado and "automatic and" not in guarda:
                reasons.add(hallado.group(1))

        # Y la negativa que `peek` se guarda para sí: el texto que no decodifica.
        peek = re.search(r"def peek\(.*?\n    def ", demonio, re.DOTALL)
        assert peek, "no encuentro peek"
        for motivo, elegible in re.findall(
            r'"reason":\s*"([a-z_]+)"[^}]*?"eligible":\s*(False|True)', peek.group(0),
        ):
            if elegible == "False":
                reasons.add(motivo)
        return reasons

    def test_every_refusal_the_helper_can_utter_has_its_own_words(self) -> None:
        panel = (REPO / "Panel.qml").read_text(encoding="utf-8")
        tabla = re.search(r"readonly property var refusals: \(\{(?P<body>.*?)\}\)", panel, re.DOTALL)
        self.assertIsNotNone(tabla, "el panel ya no tiene tabla de negativas")
        cubiertos = set(re.findall(r'"([a-z_]+)":\s*\{', tabla.group("body")))

        for motivo in sorted(self._peek_refusal_reasons()):
            with self.subTest(reason=motivo):
                self.assertIn(
                    motivo, cubiertos,
                    f"el helper puede negarse por «{motivo}» y el panel lo contaría "
                    "como «no hay nada que limpiar»",
                )

    def test_the_last_resort_never_claims_omaplain_looked(self) -> None:
        """El respaldo se usa cuando el motivo no se conoce.

        Un motivo desconocido puede ser justo aquel en el que no se miró
        —una aplicación bloqueada lo era—, así que la frase de respaldo no
        puede afirmar que se ha mirado nada.
        """
        catalogue = (REPO / "components" / "Strings.js").read_text(encoding="utf-8")
        for frase in re.findall(r'"detail\.nothing":\s*"([^"]+)"', catalogue):
            with self.subTest(frase=frase):
                self.assertNotIn("looked at it", frase)
                self.assertNotIn("ha mirado", frase)
        self.assertEqual(len(re.findall(r'"detail\.nothing":', catalogue)), 2)

    def test_each_refusal_names_strings_that_exist(self) -> None:
        panel = (REPO / "Panel.qml").read_text(encoding="utf-8")
        catalogue = (REPO / "components" / "Strings.js").read_text(encoding="utf-8")
        tabla = re.search(r"readonly property var refusals: \(\{(?P<body>.*?)\}\)", panel, re.DOTALL)
        claves = re.findall(r'(?:verdict|detail):\s*"([a-z.A-Z]+)"', tabla.group("body"))
        self.assertTrue(claves)
        for clave in sorted(set(claves)):
            with self.subTest(clave=clave):
                # una vez por idioma
                self.assertEqual(
                    len(re.findall(rf'"{re.escape(clave)}":', catalogue)), 2,
                    f"«{clave}» no está en las dos tablas",
                )

    # ------------------------------------------------------------------
    # Las frases compuestas tienen que leerse como frases
    # ------------------------------------------------------------------

    def test_the_row_composes_sentences_with_a_name_not_a_column_heading(self) -> None:
        """«Show %1» con el rótulo de la fila daba «Show On the clipboard».

        Los rótulos son cabeceras de columna —«Now», «Would be»— y llevan
        mayúscula. Metidos en una plantilla salían a media frase con la
        mayúscula puesta, en los dos idiomas, y no sólo en el tooltip: la
        misma cadena es el `Accessible.name` del botón.
        """
        row = (REPO / "components" / "ClipboardRow.qml").read_text(encoding="utf-8")
        for llamada in re.findall(r'Strings\.f\("row\.(?:show|hide)"[^)]*\)', row):
            with self.subTest(llamada=llamada):
                self.assertIn("root.name", llamada)
                self.assertNotIn("root.label", llamada, "vuelve a componer con la cabecera")
        # Y el rótulo no se cuela por ninguna otra plantilla.
        self.assertNotIn('Strings.f("row.locked"', row, "row.locked ya no lleva argumento")

    def test_every_name_meant_for_mid_sentence_starts_lowercase(self) -> None:
        catalogue = (REPO / "components" / "Strings.js").read_text(encoding="utf-8")
        nombres = re.findall(r'"row\.name\.[a-z]+":\s*"([^"]+)"', catalogue)
        self.assertEqual(len(nombres), 6, "tres nombres por idioma")
        for nombre in nombres:
            with self.subTest(nombre=nombre):
                self.assertTrue(
                    nombre[0].islower(),
                    f"«{nombre}» lleva mayúscula y va dentro de una frase",
                )

    def test_the_locked_sentence_never_starts_with_a_substitution(self) -> None:
        # Con «%1 stays covered» el rótulo caía al principio de la frase, que
        # es el único sitio donde su mayúscula no delataba nada... y donde
        # además decía «Now stays covered».
        catalogue = (REPO / "components" / "Strings.js").read_text(encoding="utf-8")
        frases = re.findall(r'"row\.locked":\s*"([^"]+)"', catalogue)
        self.assertEqual(len(frases), 2)
        for frase in frases:
            with self.subTest(frase=frase):
                self.assertNotIn("%1", frase)

    def test_a_locked_row_invites_nothing_it_will_not_answer(self) -> None:
        """El arrastre no responde y el ojo es un candado deshabilitado.

        El vaho seguía rotulado «Drag to clear» y el lector de pantalla
        seguía diciendo «or use the eye button»: dos instrucciones falsas
        seguidas en la fila cuyo trabajo es no destaparse.
        """
        row = (REPO / "components" / "ClipboardRow.qml").read_text(encoding="utf-8")
        self.assertIn('hint: root.locked ? "" : Strings.t("fog.hint", root.lang)', row)
        self.assertIn('root.locked ? "row.covered.locked.a11y" : "row.covered.a11y"', row)

        catalogue = (REPO / "components" / "Strings.js").read_text(encoding="utf-8")
        frases = re.findall(r'"row\.covered\.locked\.a11y":\s*"([^"]+)"', catalogue)
        self.assertEqual(len(frases), 2, "falta en un idioma")
        for frase in frases:
            with self.subTest(frase=frase):
                for invitacion in ("eye button", "botón del ojo", "Drag across", "Arrástralo"):
                    self.assertNotIn(invitacion, frase)

    def test_every_control_of_ours_shows_focus_with_more_than_a_border(self) -> None:
        """El botón principal señalaba el foco con 1 px de borde.

        Y sobre su relleno de acento el borde de foco se **oscurece**:
        rgb(114,112,129) sin foco contra rgb(88,87,103) con foco, medido en
        el panel real. Los dos estados se veían iguales, y es el único
        control de la pantalla de bienvenida que alguien navegando con
        teclado querría encontrar.

        La regla vale para cualquier control propio que entre en el orden
        de tabulación, no sólo para éste.
        """
        propios = [
            ruta for ruta in (REPO / "components").glob("*.qml")
            if "activeFocusOnTab" in ruta.read_text(encoding="utf-8")
        ]
        self.assertTrue(propios, "ningún control propio entra en el orden de tabulación")
        for ruta in propios:
            source = ruta.read_text(encoding="utf-8")
            señales = [
                line.split("//", 1)[0] for line in source.splitlines()
                if "activeFocus" in line.split("//", 1)[0]
                and not line.split("//", 1)[0].lstrip().startswith(("borderSpec:", "activeFocusOnTab:"))
                and "onActiveFocusChanged" not in line
            ]
            with self.subTest(control=ruta.name):
                self.assertTrue(
                    señales,
                    f"{ruta.name} sólo cambia el borde al recibir el foco",
                )


if __name__ == "__main__":
    unittest.main()


class PanelHeightTests(unittest.TestCase):
    """El techo de la tarjeta, que no es el mismo en las dos vidas del panel."""

    def _ceiling(self) -> str:
        panel = (REPO / "Panel.qml").read_text(encoding="utf-8")
        block = re.search(
            r"readonly property real ceiling:(?P<body>.*?)\n        height:",
            panel, re.DOTALL)
        assert block, "no encuentro el techo de la tarjeta"
        return block.group("body")

    def test_the_everyday_view_keeps_its_ceiling(self) -> None:
        # Los ajustes, con los desplegables abiertos, se comerían la pantalla.
        # Subir el techo del onboarding no puede llevarse esto por delante.
        self.assertIn("Style.space(720)", self._ceiling())
        self.assertIn('viewMode === "main"', self._ceiling())

    def test_the_onboarding_is_bounded_by_the_screen_and_not_by_a_number(self) -> None:
        # Se ve una vez en la vida, se lee de arriba abajo y su acción
        # primaria vive al final. Cortarlo por un número dejaba «Siguiente» y
        # la salida del tour por debajo del borde.
        onboarding = self._ceiling().split(":")[1] if ":" in self._ceiling() else self._ceiling()
        self.assertIn("parent.height", onboarding)
        self.assertNotIn("Style.space(720)", onboarding)

    def test_the_screen_still_has_the_last_word(self) -> None:
        panel = (REPO / "Panel.qml").read_text(encoding="utf-8")
        self.assertIn(
            "height: Math.min(ceiling, contentHeight, parent.height - Style.space(32))",
            panel)

