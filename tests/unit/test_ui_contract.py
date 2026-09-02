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
            REPO / "components" / "AppRules.qml",
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
        #
        # Los comentarios no cuentan como uso. Mencionar `Style.space()` al
        # explicar por qué un fichero dejó de usarlo obligaba a mantener un
        # import muerto para no romper esta guardia, que es justo al revés de
        # lo que la guardia quiere.
        singletons = ("Style", "Color", "Util", "Border")
        files = [*REPO.glob("*.qml"), *sorted((REPO / "components").glob("*.qml"))]
        self.assertTrue(files, "no se encontro ningun QML que revisar")
        for path in files:
            source = path.read_text(encoding="utf-8")
            code = "\n".join(
                line.split("//")[0] for line in source.splitlines())
            used = [n for n in singletons if re.search(r"\b" + n + r"\s*\.", code)]
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
                blocks = list(_blocks(panel, name))
                # Sin bloques el bucle pasaba en vacío: un componente que
                # desapareciera del panel «cumplía».
                self.assertTrue(blocks, f"{name} ya no está en el panel")
                for block in blocks:
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

    def test_the_only_empty_state_speaks_for_the_four_lists(self) -> None:
        # Hubo un hueco por sección, cuando eran dos. La `0011` las funde: hay
        # un solo formulario, así que hay un solo hueco, y tiene que mirar las
        # cuatro listas o se enseñaría con alguna ya poblada.
        #
        # Buscar «el primer EmptyState» no vale: la página monta más de uno.
        # Éste se localiza por lo único que le pertenece, `ruledApps()`.
        panel = (REPO / "Panel.qml").read_text(encoding="utf-8")
        block = next(
            (b for b in _blocks(panel, "EmptyState") if "ruledApps()" in b),
            None,
        )
        self.assertIsNotNone(block, "la sección de aplicaciones no monta su hueco")
        self.assertIn("visible: root.ruledApps().length === 0", block)

        # Y `ruledApps()` mira las cuatro, o el hueco mentiría.
        cuerpo = panel.split("function ruledApps()", 1)[1].split("\n  }", 1)[0]
        for lista in ("alwaysCovered", "blockedApps", "sourceExclusions", "targetExclusions"):
            with self.subTest(lista=lista):
                self.assertIn(lista, cuerpo)

        # Precede a las tarjetas, o aparecería debajo de ellas.
        self.assertLess(panel.index(block), panel.index("id: appsList"))

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
        #
        # Y el panel, desde la enmienda de la 0007, en los estados que no
        # pueden enseñar el portapapeles. Allí el motivo original —que el
        # contenido es mejor profesor que un dibujo— no llega, porque de una
        # imagen no se lee ni un byte. El guarda de abajo comprueba con qué
        # condición y con qué variante entra.
        files = [*REPO.glob("*.qml"), *sorted((REPO / "components").glob("*.qml"))]
        users = sorted(
            p.name for p in files
            if "TransformationIllustration {" in p.read_text(encoding="utf-8")
        )
        self.assertEqual(users, ["Panel.qml", "TourPage.qml", "WelcomePage.qml"])

    def test_what_teaches_on_the_everyday_screen_is_gated_to_the_empty_state(self) -> None:
        # 0007 admite enseñar cuando no hay nada que informar, y 0008 puso
        # ahí el carrusel. La excepción es esa condición, no ese componente:
        # el guarda comprueba que todo lo que enseñe en el panel esté atado
        # al portapapeles vacío.
        #
        # La enmienda de la 0007 añade una segunda condición y sólo una: los
        # estados de bypass, que tampoco tienen nada que informar porque no
        # pueden leer el portapapeles. Sigue sin haber una tercera, y el
        # carrusel sigue atado al vacío: enseña una limpieza, y en una
        # pantalla cuyo veredicto es «esto no se toca» la contradiría.
        panel = (REPO / "Panel.qml").read_text(encoding="utf-8")
        permitido = {
            "TransformationIllustration": "visible: root.peekBypass",
            "EmptyCarousel": "visible: root.peekEmpty",
        }
        for name, condicion in permitido.items():
            bloques = list(re.finditer(name + r" \{(?P<body>.*?)\n\s{14}\}", panel, re.DOTALL))
            with self.subTest(component=name):
                self.assertTrue(bloques, f"{name} ya no está en la página del portapapeles")
                for block in bloques:
                    self.assertIn(condicion, block.group("body"))

    def test_skip_labels_fit_a_full_width_line(self) -> None:
        # 0015: la omisión vive en una línea secundaria de ancho completo,
        # así que las dos etiquetas tienen aire; lo que no pueden es crecer
        # hasta envolver, porque el kit no envuelve el texto de un botón.
        catalogue = (REPO / "components" / "Strings.js").read_text(encoding="utf-8")
        labels = re.findall(r'"action\.skip(?:ped)?":\s*"([^"]+)"', catalogue)
        self.assertEqual(len(labels), 4)
        for label in labels:
            with self.subTest(label=label):
                self.assertLessEqual(len(label), 44, "no cabe en una línea")

    def test_apply_only_exists_when_there_is_something_to_apply(self) -> None:
        # 0015: con el automático puesto el texto llega limpio, y el
        # primario vivía gris casi siempre en la pantalla más vista.
        panel = (REPO / "Panel.qml").read_text(encoding="utf-8")
        blocks = [b for b in _blocks(panel, "PrimaryButton") if "id: applyButton" in b]
        self.assertEqual(len(blocks), 1)
        self.assertIn("visible: root.peekChanges", blocks[0])
        self.assertIn("width: parent.width", blocks[0])

    def test_skip_is_its_own_line_and_only_with_automatic_on(self) -> None:
        panel = (REPO / "Panel.qml").read_text(encoding="utf-8")
        blocks = [b for b in _blocks(panel, "PanelButton") if "id: skipButton" in b]
        self.assertEqual(len(blocks), 1)
        skip = blocks[0]
        self.assertIn('visible: root.peekReady && root.setting("automatic", true)', skip)
        self.assertIn("leftAlign: true", skip)
        self.assertIn("bordered: false", skip)
        # Ya no comparte fila con «aplicar»: no queda ninguna rejilla de
        # acciones en la página del portapapeles.
        self.assertNotIn("id: clipboardActions", panel)
        # Y el foco de entrada tiene a dónde ir cuando no hay primario.
        self.assertIn("else if (skipButton.visible) skipButton.forceActiveFocus()", panel)
        self.assertIn("else optionsButton.forceActiveFocus()", panel)

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



class SettingsHarmonyTests(unittest.TestCase):
    """Lo que la revisión de los ajustes dejó atado.

    Todo esto se midió sobre el panel real antes de tocarlo, y todo vuelve
    solo en cuanto alguien añade una sección copiando y pegando la anterior.
    """

    def _panel(self) -> str:
        return (REPO / "Panel.qml").read_text(encoding="utf-8")

    def test_every_section_title_goes_through_the_heading(self) -> None:
        # Sueltos en la columna recibían el mismo aire por arriba que por
        # abajo —21 y 24 px medidos, y esos números eran la letra, no el
        # diseño— así que la página se leía como una lista plana.
        panel = self._panel()
        sueltos = re.findall(
            r"Text \{[^}]*font\.pixelSize: Style\.font\.subtitle[^}]*font\.bold: true[^}]*\}",
            panel, re.DOTALL)
        self.assertEqual(sueltos, [], "un encabezado de sección sin SectionHeading")
        self.assertGreaterEqual(panel.count("SectionHeading {"), 6)

    def test_the_heading_opens_the_section_it_titles(self) -> None:
        heading = (REPO / "components" / "SectionHeading.qml").read_text(encoding="utf-8")
        self.assertIn("topPadding:", heading)
        self.assertIn("Accessible.role: Accessible.Heading", heading)

    def test_the_row_lets_the_kit_size_it(self) -> None:
        # `Toggle.qml` ya hace Math.max(54, content.implicitHeight + huge).
        # Nuestro override lo tiraba y dejaba apretadas las filas cuya
        # descripción ocupa dos líneas.
        row = (REPO / "components" / "SettingRow.qml").read_text(encoding="utf-8")
        code = "\n".join(l for l in row.splitlines() if not l.strip().startswith("//"))
        self.assertNotIn("implicitHeight", code)
        self.assertNotIn("contentHeight", code)

    def test_a_field_label_is_not_dressed_as_a_section(self) -> None:
        panel = self._panel()
        for ident in ("classFieldLabel",):
            bloque = panel.split(f"id: {ident}", 1)[1].split("}", 1)[0]
            with self.subTest(label=ident):
                self.assertNotIn("font.bold: true", bloque)
                self.assertIn("Util.alpha(Color.popups.text, 0.68)", bloque)

    def test_the_disclosures_share_the_left_edge(self) -> None:
        panel = self._panel()
        for ident in ("historyWhyButton", "optionalButton"):
            bloque = panel.split(f"id: {ident}", 1)[1].split("onClicked:", 1)[0]
            with self.subTest(button=ident):
                self.assertIn("leftAlign: true", bloque)

    def test_the_placeholder_is_not_left_to_the_kit(self) -> None:
        # El del kit mide 4,19:1 contra el relleno del campo, por debajo del
        # 4,5 de la AA, y aquí es la única pista de qué hay que teclear.
        panel = self._panel()
        self.assertGreater(panel.count("placeholderText:"), 0)
        self.assertEqual(panel.count("placeholderText:"),
                         panel.count("placeholderTextColor:"))

    def test_wrapping_prose_uses_the_prose_alpha(self) -> None:
        # 0,68 es para rótulos y foregrounds de control; la prosa que
        # envuelve va a 0,72.
        panel = self._panel()
        for clave in ("root.historyDetail()", 'Strings.t("apps.note", root.lang)'):
            bloque = panel.split(clave, 1)[1].split("}", 1)[0]
            with self.subTest(text=clave):
                self.assertIn("0.72", bloque)


class BypassScreenTests(unittest.TestCase):
    """El dibujo de los estados que no pueden enseñar el portapapeles.

    Enmienda de la `0007`: la regla «ni titular ni ilustración» se mantiene
    donde hay portapapeles que enseñar y se levanta donde no lo hay.
    """

    def _panel(self) -> str:
        return (REPO / "Panel.qml").read_text(encoding="utf-8")

    def _block(self, needle: str, end: str = "\n              }") -> str:
        panel = self._panel()
        return panel.split(needle, 1)[1].split(end, 1)[0]

    def test_the_bypass_states_are_one_flag(self) -> None:
        panel = self._panel()
        self.assertIn("readonly property bool peekBypass:", panel)
        # Vacío no es bypass: tiene su carrusel y su propia pantalla.
        bandera = self._block("readonly property bool peekBypass:", "\n\n")
        self.assertIn('!== "empty"', bandera)

    def test_only_the_bypass_states_get_the_drawing(self) -> None:
        bloque = self._block("TransformationIllustration {")
        self.assertIn("visible: root.peekBypass", bloque)
        self.assertIn('variant: "protect"', bloque)

    def test_the_drawing_never_moves_on_the_everyday_screen(self) -> None:
        # Se abre muchas veces al día. Una animación de entrada en cada
        # apertura es lo que no se le hace a un gesto frecuente.
        bloque = self._block("TransformationIllustration {")
        self.assertIn("motionEnabled: false", bloque)

    def test_the_way_out_belongs_to_the_empty_screen_only(self) -> None:
        # Estuvo también en los bypass, cuando allí no había nada que leer.
        # Con la `0013` la pantalla dice qué tienes y qué no le hacemos, y un
        # bypass se ve muchas veces al día: es justo donde la `0007` no quiere
        # un botón de aprender el producto.
        bloque = self._block("id: emptyHowButton")
        self.assertIn("visible: root.peekEmpty", bloque)
        self.assertNotIn("peekBypass", bloque)

    def test_the_generic_note_is_gone_for_good(self) -> None:
        # «Aquí no hay acción que ofrecer» es una frase sobre el panel, no
        # sobre tu portapapeles. Nunca era el momento de decirla: en el vacío
        # iba debajo de un botón que sí ofrecía una, y en un bypass la pantalla
        # ya se explica sola.
        panel = self._panel()
        self.assertIn("visible: !root.peekGenericNote", panel)
        self.assertNotIn("footnote.nothing", panel)
        catalogo = (REPO / "components" / "Strings.js").read_text(encoding="utf-8")
        self.assertNotIn("footnote.nothing", catalogo)

    def test_the_notes_that_inform_are_not_silenced(self) -> None:
        # Sólo se calla la genérica: «ya está limpio», la de aplicación
        # bloqueada y la de contenido sensible dicen algo que no está en
        # ninguna otra parte de la pantalla. Y un `feedback` nunca se calla.
        bandera = self._block("readonly property bool peekGenericNote:", "\n\n")
        for guardia in ('feedback === ""', "!peekReady", "!peekBlocked", '"sensitive"'):
            self.assertIn(guardia, bandera)
        panel = self._panel()
        for clave in ("footnote.safe", "privacy.blockedState", "footnote.sensitive"):
            with self.subTest(nota=clave):
                self.assertIn(f'Strings.t("{clave}", root.lang)', panel)

    def test_the_carousel_stays_out_of_the_bypass_states(self) -> None:
        # Enseña una limpieza. En una pantalla cuyo veredicto es «esto no se
        # toca» contradiría el veredicto.
        bloque = self._block("EmptyCarousel {")
        self.assertIn("visible: root.peekEmpty", bloque)
        self.assertNotIn("peekBypass", bloque)

    def test_the_amendment_is_written_down(self) -> None:
        texto = (REPO / "docs" / "decisions"
                 / "0007-la-pantalla-frecuente-informa.md").read_text(encoding="utf-8")
        self.assertIn("## Enmienda", texto)
        self.assertIn("bypass", texto.lower())


class EverydayHeaderTests(unittest.TestCase):
    """La cabecera de la pantalla frecuente informa, no predica."""

    def test_the_status_line_has_no_product_pitch(self) -> None:
        # Siete ramas de `statusDetail()` informan de algo que está pasando.
        # La octava describía el producto —«OmaPlain ordena el formato y deja
        # intacto todo lo que no puede limpiar»— y era la rama por defecto,
        # así que predicaba justo en el caso más frecuente de todos. Es el
        # titular educativo que la 0007 echó de esta pantalla, sobrevivido
        # como cadena.
        panel = (REPO / "Panel.qml").read_text(encoding="utf-8")
        cuerpo = panel.split("function statusDetail()", 1)[1].split("\n  }", 1)[0]
        code = "\n".join(l for l in cuerpo.splitlines() if not l.strip().startswith("//"))
        self.assertIn('return ""', code)
        self.assertNotIn("status.idle", code)

    def test_the_pitch_is_gone_from_both_tables(self) -> None:
        catalogue = (REPO / "components" / "Strings.js").read_text(encoding="utf-8")
        self.assertNotIn('"status.idle"', catalogue)

    def test_the_header_disappears_when_it_has_nothing_to_say(self) -> None:
        # Sin insignia y sin frase seguía ocupando su hueco y su `spacing`,
        # que es peor que la frase que se acaba de quitar.
        header = (REPO / "components" / "StatusHeader.qml").read_text(encoding="utf-8")
        self.assertIn("readonly property bool silent:", header)
        panel = (REPO / "Panel.qml").read_text(encoding="utf-8")
        self.assertIn("!statusLine.silent", panel)

    def test_the_lines_that_inform_are_all_still_there(self) -> None:
        # Quitar la que predica no puede llevarse por delante las que avisan.
        catalogue = (REPO / "components" / "Strings.js").read_text(encoding="utf-8")
        for clave in ("status.unavailable", "status.deps", "status.degraded",
                      "status.restarting", "status.paused", "status.willskip",
                      "status.done"):
            with self.subTest(key=clave):
                self.assertEqual(catalogue.count(f'"{clave}"'), 2, "falta en un idioma")


class FogCoverTests(unittest.TestCase):
    """La cubierta de vaho: bajo llave no escucha, y se remata sola."""

    def setUp(self) -> None:
        self.fog = (REPO / "components" / "FogCover.qml").read_text(encoding="utf-8")
        self.row = (REPO / "components" / "ClipboardRow.qml").read_text(encoding="utf-8")

    def test_a_locked_row_cannot_be_wiped_by_hand(self) -> None:
        # Antes sólo se callaba `cleared`; el arrastre seguía abriendo
        # huecos y el texto se leía por ellos.
        self.assertIn("property bool locked", self.fog)
        areas = _blocks(self.fog, "MouseArea")
        self.assertEqual(len(areas), 1)
        self.assertIn("enabled: !root.locked", areas[0])
        fog_in_row = _blocks(self.row, "FogCover")
        self.assertEqual(len(fog_in_row), 1)
        self.assertIn("locked: root.locked", fog_in_row[0])

    def test_the_sweep_finishes_from_the_release_point_and_then_clears(self) -> None:
        self.assertIn("root.finish(mouse.x, mouse.y)", self.fog)
        # Con su guarda: la llave puede llegar con el remate en marcha.
        self.assertIn("onFinished: if (!root.locked) root.cleared()", self.fog)
        # Sin movimiento no hay recorrido: se descubre de golpe.
        self.assertIn("if (!motionEnabled) {", self.fog)
        # Y el umbral es un cuarto: un clic suelto no descubre nada.
        self.assertIn("finishThreshold: 0.25", self.fog)


class PeekLifetimeTests(unittest.TestCase):
    """El contenido muere con el panel, también con un vistazo en vuelo."""

    def test_a_late_peek_from_a_closed_epoch_is_dropped(self) -> None:
        service = (REPO / "Service.qml").read_text(encoding="utf-8")
        self.assertIn("property int peekEpoch", service)
        forget = _blocks(service, "function forgetPeek()")
        self.assertEqual(len(forget), 1)
        self.assertIn("peekEpoch += 1", forget[0])
        self.assertIn("peekPending = false", forget[0])
        self.assertIn("if (root.peekIssuedIn !== root.peekEpoch) {", service)

    def test_an_action_does_not_ask_for_a_second_peek(self) -> None:
        panel = (REPO / "Panel.qml").read_text(encoding="utf-8")
        handler = _blocks(panel, "function onLastActionJsonChanged()")
        self.assertEqual(len(handler), 1)
        self.assertNotIn("refreshPeek()", handler[0])
        self.assertIn("function onStatusChanged() { root.maybeRefreshPeek() }", panel)

    def test_the_stamp_starts_with_the_event_counter(self) -> None:
        panel = (REPO / "Panel.qml").read_text(encoding="utf-8")
        self.assertIn('String(service.status.eventSeq || 0) + "|"', panel)

    def test_focus_settles_when_apply_disappears_under_it(self) -> None:
        panel = (REPO / "Panel.qml").read_text(encoding="utf-8")
        apply = [b for b in _blocks(panel, "PrimaryButton") if "id: applyButton" in b][0]
        self.assertIn("onActiveFocusChanged: if (!activeFocus && !visible && root.opened) Qt.callLater(root.settleFocus)", apply)
        skip = [b for b in _blocks(panel, "PanelButton") if "id: skipButton" in b][0]
        # Armada sigue viva: si se deshabilitara, el foco no tendría sitio.
        self.assertIn("enabled: service && !service.actionBusy\n", skip)

    def test_a_new_body_gets_a_fresh_cover(self) -> None:
        row = (REPO / "components" / "ClipboardRow.qml").read_text(encoding="utf-8")
        self.assertIn("onBodyChanged: fog.reset()", row)
        fog = (REPO / "components" / "FogCover.qml").read_text(encoding="utf-8")
        self.assertIn("onFinished: if (!root.locked) root.cleared()", fog)
        self.assertIn("onLockedChanged: if (locked) reset()", fog)


class CopyTests(unittest.TestCase):
    """Que cada frase hable de lo que hay debajo de ella."""

    def setUp(self) -> None:
        self.catalogue = (REPO / "components" / "Strings.js").read_text(encoding="utf-8")

    def _value(self, key: str) -> list[str]:
        return re.findall(rf'"{re.escape(key)}":\s*"((?:[^"\\]|\\.)*)"', self.catalogue)

    def test_the_english_table_uses_english_punctuation(self) -> None:
        # Las comillas angulares se colaron del español a la tabla inglesa.
        english = self.catalogue.split("var ES", 1)[0]
        for line in english.splitlines():
            code = line.split("//", 1)[0]
            with self.subTest(line=code.strip()[:60]):
                self.assertNotIn("«", code)
                self.assertNotIn("»", code)

    def test_the_chip_names_the_setting_that_governs_the_rule(self) -> None:
        # El chip del desglose y el rótulo del ajuste hablaban de lo mismo
        # con tres nombres distintos.
        for chip, row in (("setting.trailing_whitespace", "settings.trim"),
                          ("setting.tracking", "settings.tracking"),
                          ("setting.rich_text", "settings.formatting"),
                          ("setting.line_endings", "settings.endings")):
            with self.subTest(chip=chip):
                for short, long in zip(self._value(chip), self._value(row), strict=True):
                    palabras = {p.strip(".,").lower() for p in short.split()}
                    self.assertTrue(
                        palabras & {p.strip(".,").lower() for p in long.split()},
                        f"«{short}» no comparte ni una palabra con «{long}»",
                    )

    def test_the_applications_section_talks_about_applications(self) -> None:
        # Heredado de cuando la sección se llamaba «Privacidad»: explicaba
        # el almacenamiento bajo el título de las reglas por aplicación.
        for body in self._value("apps.body"):
            with self.subTest(body=body[:40]):
                self.assertNotIn("network", body.lower())
                self.assertNotIn("historial", body.lower())
                self.assertNotIn("history", body.lower())

    def test_the_privacy_promise_is_somewhere_in_the_panel(self) -> None:
        # Y no sólo en la bienvenida, que se ve una vez en la vida.
        panel = (REPO / "Panel.qml").read_text(encoding="utf-8")
        self.assertIn('Strings.t("settings.privacy"', panel)
        for promise in self._value("settings.privacy"):
            with self.subTest(promise=promise[:40]):
                self.assertRegex(promise, r"(red|network)")

    def test_no_screen_invents_a_word_the_product_does_not_use(self) -> None:
        # «Excluida» es de las dos listas que la 0011 retiró; «ZWSP» es una
        # sigla técnica en la pantalla de quien acaba de llegar.
        for key in ("fb.excluded", "empty.sample.text.spare", "state.skipping"):
            for value in self._value(key):
                with self.subTest(key=key, value=value):
                    self.assertNotIn("ZWSP", value)
                    self.assertNotIn("excluida", value.lower())
                    self.assertNotIn("excluded", value.lower())


if __name__ == "__main__":
    unittest.main()
