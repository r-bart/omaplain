"""La sección «Aplicaciones» y las dos trampas que aparecieron con ella.

Ver [`0011`] —una sola sección, un solo formulario— y [`0012`] —dónde vive la
configuración cuando el icono está en la barra, y por qué el anillo de foco lo
dibujamos nosotros—.
"""

from __future__ import annotations

import json
import pathlib
import re
import subprocess
import sys
import unittest

REPO = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "helper"))

from omaplain_lib.clipboard import ClipboardBackend  # noqa: E402


def _lee(*partes: str) -> str:
    return (REPO.joinpath(*partes)).read_text(encoding="utf-8")


class UnSoloFormularioTests(unittest.TestCase):
    """La `0011`: el formulario estaba escrito dos veces."""

    def setUp(self) -> None:
        self.panel = _lee("Panel.qml")

    def test_solo_queda_un_campo_de_clase(self) -> None:
        # Había dos, con el mismo placeholder y dos rótulos que se
        # diferenciaban en una palabra.
        self.assertEqual(self.panel.count("TextField {"), 1)
        self.assertEqual(self.panel.count('placeholderText:'), 1)

    def test_la_pista_de_mayusculas_acompana_al_campo_que_existe(self) -> None:
        # Sólo estaba bajo uno de los dos campos.
        self.assertIn('Strings.t("apps.class.hint", root.lang)', self.panel)
        catalogo = _lee("components", "Strings.js")
        self.assertIn("Capital letters matter.", catalogo)
        self.assertIn("Las mayúsculas cuentan.", catalogo)

    def test_enter_y_el_selector_hacen_lo_mismo_y_no_eligen_lista(self) -> None:
        # `onAccepted` confirmaba una de dos listas sin decir cuál, con dos
        # botones idénticos al lado. Ahora sólo hay una acción.
        self.assertIn("onAccepted: root.addApp(classField.text)", self.panel)
        cuerpo = self.panel.split("function addApp(", 1)[1].split("\n  }", 1)[0]
        for lista in ("alwaysCovered", "blockedApps", "sourceExclusions", "targetExclusions"):
            with self.subTest(lista=lista):
                self.assertNotIn(lista, cuerpo)
        self.assertIn("pendingApp = name", cuerpo)

    def test_los_botones_de_app_detectada_ya_no_existen(self) -> None:
        # Uno rellenaba el campo y el otro añadía a `source` sin preguntar.
        for resto in ("usePrivacyDetected", "excludeDetected", "currentAppClass"):
            with self.subTest(resto=resto):
                self.assertNotIn(resto, self.panel)
                self.assertNotIn(resto, _lee("Service.qml"))

    def test_las_cuatro_reglas_siguen_siendo_cuatro(self) -> None:
        # Lo que la `0009` protege: cuatro decisiones independientes. La `0011`
        # funde el formulario, no las listas.
        reglas = _lee("components", "AppRules.qml")
        for clave, kind in (
            ("rules.covered", "covered"),
            ("rules.blocked", "blocked"),
            ("rules.source", "source"),
            ("rules.target", "target"),
        ):
            with self.subTest(regla=kind):
                self.assertIn(f'Strings.t("{clave}", root.lang)', reglas)
                self.assertIn(f'root.ruleToggled("{kind}"', reglas)
        # Y las dos familias de la 0009 se ven separadas.
        self.assertIn('Strings.t("rules.reading", root.lang)', reglas)
        self.assertIn('Strings.t("rules.cleaning", root.lang)', reglas)

    def test_una_app_sin_reglas_dice_que_no_esta_guardada(self) -> None:
        # No hay dónde guardarla: las cuatro listas son el almacén.
        reglas = _lee("components", "AppRules.qml")
        self.assertIn(
            "readonly property bool pending: !covered && !blocked && !source && !target",
            reglas,
        )
        self.assertIn('Strings.t("apps.pending", root.lang)', reglas)
        self.assertIn("visible: root.pending", reglas)

    def test_la_lista_va_ordenada_y_debajo_del_formulario(self) -> None:
        # Ordenada: si el orden saliera de las listas, marcar una regla movería
        # la tarjeta bajo el dedo. Debajo: la lista crece y el formulario no
        # debe moverse al añadir.
        cuerpo = self.panel.split("function ruledApps()", 1)[1].split("\n  }", 1)[0]
        self.assertIn("names.sort(", cuerpo)
        self.assertLess(self.panel.index("id: classField"), self.panel.index("id: appsList"))

    def test_quitar_se_lleva_las_cuatro_reglas(self) -> None:
        cuerpo = self.panel.split("function removeApp(", 1)[1].split("\n  }", 1)[0]
        self.assertIn('["covered", "blocked", "source", "target"]', cuerpo)
        self.assertIn("removeExclusion", cuerpo)


class SelectorDeVentanasTests(unittest.TestCase):
    """La fuente de las clases: ventanas abiertas, nunca títulos."""

    def test_el_titulo_de_la_ventana_no_sale_del_helper(self) -> None:
        # Nombra el documento abierto, y eso es contenido (`0005`).
        cuerpo = _lee("helper", "omaplain_lib", "clipboard.py")
        funcion = cuerpo.split("def open_windows(", 1)[1].split("\n    def ", 1)[0]
        self.assertNotIn('"title"', funcion)
        self.assertNotIn("'title'", funcion)
        cli = _lee("helper", "omaplain_lib", "cli.py")
        salida = cli.split("def _open_windows(", 1)[1].split("\n\n\n", 1)[0]
        self.assertNotIn("title", salida)

    def test_devuelve_clases_sin_repetir_y_ordenadas(self) -> None:
        backend = ClipboardBackend()
        backend._capture = lambda argv, **kw: json.dumps([  # type: ignore[method-assign]
            {"class": "foot", "title": "un documento privado"},
            {"class": "firefox", "title": "otra cosa"},
            {"class": "foot", "title": "y otra"},
            {"class": "Alacritty", "title": ""},
        ]).encode()
        self.assertEqual(backend.open_windows(), ["Alacritty", "firefox", "foot"])

    def test_una_clase_rota_no_tumba_la_lista(self) -> None:
        backend = ClipboardBackend()
        backend._capture = lambda argv, **kw: json.dumps([  # type: ignore[method-assign]
            {"class": ""},
            {"class": "x" * 300},
            {"class": "con\nsalto"},
            "no soy un objeto",
            {"class": "foot"},
        ]).encode()
        self.assertEqual(backend.open_windows(), ["foot"])

    def test_sin_hyprland_devuelve_lista_vacia_y_no_revienta(self) -> None:
        backend = ClipboardBackend()

        def falla(argv, **kw):
            raise RuntimeError("no debería propagarse")

        backend._capture = lambda argv, **kw: b"esto no es json"  # type: ignore[method-assign]
        self.assertEqual(backend.open_windows(), [])

    def test_el_cli_expone_el_subcomando(self) -> None:
        salida = subprocess.run(
            [str(REPO / "helper" / "omaplain"), "--help"],
            capture_output=True, text=True,
        )
        self.assertIn("open-windows", salida.stdout)
        # Y responde de verdad, con la forma que el panel espera.
        vivo = subprocess.run(
            [str(REPO / "helper" / "omaplain"), "open-windows"],
            capture_output=True, text=True,
        )
        self.assertEqual(vivo.returncode, 0)
        datos = json.loads(vivo.stdout)
        self.assertEqual(datos["result"], "ok")
        self.assertIsInstance(datos["classes"], list)
        self.assertEqual(set(datos) , {"result", "classes"})

    def test_el_panel_pide_la_lista_al_abrir_y_al_entrar_en_ajustes(self) -> None:
        # Ofrece lo que hay abierto *ahora*, no lo que había al abrir el panel.
        panel = _lee("Panel.qml")
        self.assertEqual(panel.count("service.captureOpenWindows()"), 2)
        cuerpo = panel.split("function togglePage()", 1)[1].split("\n  }", 1)[0]
        self.assertIn("captureOpenWindows", cuerpo)

    def test_no_se_ofrecen_las_aplicaciones_instaladas(self) -> None:
        # 23 de 93 entradas `.desktop` declaran `StartupWMClass`: tres de cada
        # cuatro darían una regla que nunca dispara.
        for archivo in ("Panel.qml", "Service.qml"):
            with self.subTest(archivo=archivo):
                self.assertNotIn("DesktopEntries", _lee(archivo))


class DondeVivenLosAjustesTests(unittest.TestCase):
    """La `0012`: con el icono en la barra, nada se guardaba."""

    def test_se_lee_donde_el_shell_escribe(self) -> None:
        # `updateEntryInline` busca primero en bar.layout y, si lo encuentra,
        # no toca `plugins[]`. Leer sólo `plugins[]` guardaba en un sitio y
        # leía de otro.
        service = _lee("Service.qml")
        cuerpo = service.split("function entryFor()", 1)[1].split("\n  }", 1)[0]
        # La barra primero, `plugins[]` después: el mismo orden que el shell.
        self.assertIn("barLayoutEntry() || pluginsEntry()", cuerpo)
        barra = service.split("function barLayoutEntry()", 1)[1].split("\n  }", 1)[0]
        self.assertIn('["left", "center", "right"]', barra)
        plugins = service.split("function pluginsEntry()", 1)[1].split("\n  }", 1)[0]
        self.assertIn("shellConfig.plugins", plugins)

    def test_entry_settings_no_vuelve_a_mirar_solo_los_plugins(self) -> None:
        service = _lee("Service.qml")
        cuerpo = service.split("function entrySettings()", 1)[1].split("\n  }", 1)[0]
        self.assertIn("entryFor()", cuerpo)
        self.assertNotIn("shellConfig.plugins", cuerpo)

    def test_el_shell_sigue_buscando_en_la_barra_primero(self) -> None:
        # El día que el kit cambie de orden, este test lo cuenta antes que el
        # usuario: nuestra lectura está copiada de aquí.
        kit = pathlib.Path("/usr/share/omarchy/shell/shell.qml")
        if not kit.exists():
            self.skipTest("el shell de Omarchy no está instalado")
        cuerpo = kit.read_text(encoding="utf-8").split("function updateEntryInline(", 1)[1]
        cuerpo = cuerpo.split("\n  }", 1)[0]
        self.assertIn("foundInLayout", cuerpo)
        self.assertLess(cuerpo.index("bar.layout"), cuerpo.index("copy.plugins.length"))


class AnilloDeFocoTests(unittest.TestCase):
    """La `0012`: el borde de foco del kit es más tenue que el de reposo."""

    RUTAS = ("PanelButton.qml", "SettingRow.qml", "PrimaryButton.qml")

    def test_todo_control_del_panel_dibuja_su_propio_anillo(self) -> None:
        for nombre in self.RUTAS:
            source = _lee("components", nombre)
            with self.subTest(control=nombre):
                anillo = [
                    b for b in re.findall(r"Rectangle \{[^}]*\}", source, re.DOTALL)
                    if "border.width" in b and "activeFocus" in b
                ]
                self.assertTrue(anillo, f"{nombre} no dibuja anillo de foco")

    def test_el_anillo_es_neutro_y_no_de_marca(self) -> None:
        # En este panel el acento ya significa «elegido»: lo lleva el idioma
        # activo. Un anillo de marca competiría con él.
        for nombre in ("PanelButton.qml", "SettingRow.qml"):
            source = _lee("components", nombre)
            anillo = next(
                b for b in re.findall(r"Rectangle \{[^}]*\}", source, re.DOTALL)
                if "border.width" in b and "activeFocus" in b
            )
            with self.subTest(control=nombre):
                self.assertIn("Util.alpha(Color.popups.text, 0.68)", anillo)
                self.assertNotIn("Color.accent", anillo)

    def test_el_anillo_llega_al_minimo_de_la_sc_1411(self) -> None:
        # 0,68 del color de texto sobre el fondo de la tarjeta y sobre el
        # relleno de foco. Los dos por encima de 3:1.
        def lineal(canal: float) -> float:
            canal /= 255
            return canal / 12.92 if canal <= 0.04045 else ((canal + 0.055) / 1.055) ** 2.4

        def luminancia(rgb: tuple[int, int, int]) -> float:
            r, g, b = (lineal(v) for v in rgb)
            return 0.2126 * r + 0.7152 * g + 0.0722 * b

        def contraste(a, b) -> float:
            la, lb = luminancia(a), luminancia(b)
            return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)

        texto = (216, 203, 180)      # Color.popups.text, medido en el panel
        fondo = (12, 22, 38)         # el fondo de la tarjeta
        relleno = (28, 36, 49)       # el relleno que pinta el foco del kit
        anillo = tuple(round(0.68 * t + 0.32 * f) for t, f in zip(texto, relleno))
        self.assertGreaterEqual(contraste(anillo, fondo), 3.0)
        self.assertGreaterEqual(contraste(anillo, relleno), 3.0)

    def test_el_kit_sigue_apagando_el_foco(self) -> None:
        # Si algún día el tema deja de hacerlo, este anillo sobra y hay que
        # revisar la 0012 en vez de arrastrarlo.
        estilo = pathlib.Path("/usr/share/omarchy/shell/Commons/Style.qml")
        if not estilo.exists():
            self.skipTest("el shell de Omarchy no está instalado")
        source = estilo.read_text(encoding="utf-8")
        self.assertIn('styleAlpha("normal-border-alpha", 0.4)', source)
        self.assertIn('styleAlpha("hover-cursor-border-alpha", 0.25)', source)
        self.assertIn('styleAlpha("focus-border-alpha", hoverBorderAlpha)', source)


if __name__ == "__main__":
    unittest.main()


class AvisosDelFormularioTests(unittest.TestCase):
    """Lo que la revisión posterior encontró en el mensaje del campo."""

    def setUp(self) -> None:
        self.panel = _lee("Panel.qml")

    def test_solo_alerta_lo_que_es_una_alerta(self) -> None:
        # «Ya tiene su tarjeta abajo» es la pista del campo con otro texto: no
        # interrumpe a nadie. Sólo la clase inválida es una alerta.
        bloque = self.panel.split("id: appsMessage", 1)[1].split("\n              }", 1)[0]
        self.assertIn("root.appsUrgent && root.appsError !== \"\"", bloque)
        self.assertIn("Accessible.AlertMessage", bloque)

    def test_el_aviso_de_duplicada_no_se_queda_puesto(self) -> None:
        # Sólo lo borraban otra pulsación, una tecla en el campo o quitar la
        # aplicación; mientras tanto tapaba la pista de las mayúsculas.
        cuerpo = self.panel.split("function toggleRule(", 1)[1].split("\n  }", 1)[0]
        self.assertIn("if (!appsUrgent) appsError = \"\"", cuerpo)

    def test_la_lista_recien_crecida_se_enseña_por_arriba(self) -> None:
        # `reveal` alinea por abajo lo que no cabe, que para una lista que
        # acaba de crecer deja al usuario en la última tarjeta.
        cuerpo = self.panel.split("function addApp(", 1)[1].split("\n  }", 1)[0]
        self.assertIn("revealTop(appsList)", cuerpo)
        self.assertNotIn("reveal(appsList)", cuerpo.replace("revealTop(appsList)", ""))
        alinea = self.panel.split("function revealTop(", 1)[1].split("\n  }", 1)[0]
        self.assertIn("scroll.contentY = Math.max(0,", alinea)


class RedDeSeguridadDeLosAjustesTests(unittest.TestCase):
    """`plugins[]` no puede quedarse congelado mientras el icono esté puesto.

    Si se queda, quitar el icono de la barra devuelve el idioma, el movimiento
    y las cuatro listas de la `0009` a lo que hubiera semanas atrás.
    """

    def setUp(self) -> None:
        self.service = _lee("Service.qml")
        self.cuerpo = self.service.split("function mirrorToPluginsEntry(", 1)[1].split("\n  }", 1)[0]

    def test_se_copia_al_escribir_en_la_barra(self) -> None:
        escritura = self.service.split("function updateSetting(", 1)[1].split("\n  }", 1)[0]
        self.assertIn("shell.updateEntryInline(pluginId, next)", escritura)
        self.assertIn("mirrorToPluginsEntry(next)", escritura)
        # Después de la escritura del kit, o copiaría el valor viejo.
        self.assertLess(
            escritura.index("updateEntryInline"),
            escritura.index("mirrorToPluginsEntry"),
        )

    def test_solo_cuando_la_entrada_vive_en_la_barra(self) -> None:
        # Sin icono puesto, `updateEntryInline` ya escribe en `plugins[]`.
        self.assertIn("if (!barLayoutEntry()) return", self.cuerpo)

    def test_no_escribe_si_no_hay_nada_que_cambiar(self) -> None:
        # `mutateShellConfig` persiste siempre, sin comprobar si algo cambió.
        self.assertIn("if (!pendiente) return", self.cuerpo)
        self.assertIn("JSON.stringify(actual[key]) !== JSON.stringify(next[key])", self.cuerpo)

    def test_va_por_la_via_que_el_shell_expone(self) -> None:
        # Nada de escribir `shell.json` por detrás.
        self.assertIn('typeof shell.mutateShellConfig !== "function"', self.cuerpo)
        self.assertIn("shell.mutateShellConfig(function(config)", self.cuerpo)
        for prohibido in ("FileView", "setText", "userConfigPath", "shell.json"):
            with self.subTest(prohibido=prohibido):
                self.assertNotIn(prohibido, self.cuerpo)

    def test_solo_toca_nuestra_entrada(self) -> None:
        self.assertEqual(self.cuerpo.count("=== pluginId"), 1)
        self.assertIn("var copia = { id: pluginId }", self.cuerpo)
        # Y no arrastra el `id` de `next` encima del suyo.
        self.assertIn('if (clave !== "id") copia[clave] = next[clave]', self.cuerpo)

    def test_el_shell_sigue_ofreciendo_mutate(self) -> None:
        kit = pathlib.Path("/usr/share/omarchy/shell/shell.qml")
        if not kit.exists():
            self.skipTest("el shell de Omarchy no está instalado")
        source = kit.read_text(encoding="utf-8")
        self.assertIn("function mutateShellConfig(mutator)", source)
        cuerpo = source.split("function mutateShellConfig(mutator)", 1)[1].split("\n  }", 1)[0]
        self.assertIn("persistShellConfig(copy)", cuerpo)


class ElFocoLlegaATodasPartesTests(unittest.TestCase):
    """La `0012` se quedó a medias: cuatro componentes seguían sin anillo.

    El test que ya existía miraba los ficheros con `activeFocusOnTab` escrito
    dentro, y esos cuatro lo heredaban sin escribirlo. Pasaba en verde con el
    fallo delante — y el fallo era que en el recorrido no se veía dónde estabas,
    hasta el punto de que se pulsaba «Atrás» creyendo pulsar el botón final.
    """

    # Los dos únicos que pueden tocar el kit: son los que ponen el anillo.
    ENVOLTORIOS = {"PanelButton.qml", "SettingRow.qml"}

    def test_ningun_componente_usa_el_boton_del_kit_a_pelo(self) -> None:
        for ruta in sorted((REPO / "components").glob("*.qml")):
            if ruta.name in self.ENVOLTORIOS:
                continue
            source = ruta.read_text(encoding="utf-8")
            sin_comentarios = "\n".join(
                l for l in source.splitlines() if not l.strip().startswith("//")
            )
            with self.subTest(componente=ruta.name):
                self.assertIsNone(
                    re.search(r"^\s*Button \{", sin_comentarios, re.MULTILINE),
                    f"{ruta.name} usa el Button del kit: se queda sin anillo de foco",
                )
                self.assertIsNone(
                    re.search(r"^\s*Toggle \{", sin_comentarios, re.MULTILINE),
                    f"{ruta.name} usa el Toggle del kit: se queda sin anillo de foco",
                )

    def test_el_panel_tampoco(self) -> None:
        panel = "\n".join(
            l for l in _lee("Panel.qml").splitlines() if not l.strip().startswith("//")
        )
        self.assertIsNone(re.search(r"^\s*Button \{", panel, re.MULTILINE))
        self.assertIsNone(re.search(r"^\s*Toggle \{", panel, re.MULTILINE))

    def test_el_anillo_sobrevive_a_un_boton_sin_borde(self) -> None:
        # «Saltar el recorrido» y el ojo van sin borde a propósito. Si el
        # anillo colgara de `bordered`, esos dos volverían a quedarse mudos.
        envoltorio = _lee("components", "PanelButton.qml")
        anillo = next(
            b for b in re.findall(r"Rectangle \{[^}]*\}", envoltorio, re.DOTALL)
            if "border.width" in b
        )
        self.assertIn("visible: root.focusable && root.activeFocus", anillo)
        self.assertNotIn("bordered", anillo)


class ElBotonFinalDiceADondeVaTests(unittest.TestCase):
    """«Ver los ajustes» no siempre llevaba a los ajustes."""

    def test_el_boton_nombra_un_destino_solo_si_el_recorrido_continua(self) -> None:
        tour = _lee("components", "TourPage.qml")
        self.assertIn("property bool endsInSettings: true", tour)
        boton = tour.split("id: nextButton", 1)[1].split("onClicked:", 1)[0]
        self.assertIn('root.endsInSettings ? Strings.t("tour.finish"', boton)
        self.assertIn('Strings.t("tour.done"', boton)

    def test_cuando_termina_el_boton_termina(self) -> None:
        # Al final de un recorrido de tres pasos se espera «Finalizar», no un
        # botón de navegación: nombrar el destino fue el primer arreglo y
        # seguía siendo el gesto equivocado.
        catalogo = _lee("components", "Strings.js")
        self.assertIn('"tour.done": "Finish"', catalogo)
        self.assertIn('"tour.done": "Finalizar"', catalogo)
        for destino in ("Back to the panel", "Volver al panel"):
            with self.subTest(destino=destino):
                self.assertNotIn(destino, catalogo)

    def test_el_panel_dice_la_verdad_sobre_donde_acaba(self) -> None:
        panel = _lee("Panel.qml")
        bloque = panel.split("step: root.tourStep", 1)[1].split("onBackRequested", 1)[0]
        self.assertIn('root.learningOrigin === "first-run" || root.panelPage === "settings"', bloque)

    def test_el_recorrido_de_la_primera_vez_sigue_acabando_en_ajustes(self) -> None:
        # Lo que la `0006` pide: la primera vez aterriza en los ajustes.
        cuerpo = _lee("Panel.qml").split("function advanceTour()", 1)[1].split("\n  }", 1)[0]
        self.assertIn('if (learningOrigin === "first-run") showOnboardingSettings()', cuerpo)

    def test_las_dos_etiquetas_existen_en_los_dos_idiomas(self) -> None:
        catalogo = _lee("components", "Strings.js")
        for clave in ('"tour.finish"', '"tour.done"'):
            with self.subTest(clave=clave):
                self.assertEqual(catalogo.count(clave), 2)


class LosBotonesNoRepitenSuRotuloTests(unittest.TestCase):
    """Flechas y marcas de visto que no decían nada que el rótulo no dijera.

    «← Volver», «→ Siguiente», «✓ Finalizar», «→ Ver cómo funciona»: el glifo
    repetía la palabra. Se quedan los dos que **identifican** en vez de
    decorar — el engranaje de los ajustes y el de «limpiar ahora» —, que no
    tienen palabra que repetir.
    """

    DECORATIVOS = ("→", "←", "✓")

    def test_ningun_boton_decora_su_rotulo_con_una_flecha(self) -> None:
        rutas = [REPO / "Panel.qml"] + sorted((REPO / "components").glob("*.qml"))
        for ruta in rutas:
            source = ruta.read_text(encoding="utf-8")
            iconos = re.findall(r"^\s*iconText:.*$", source, re.MULTILINE)
            for linea in iconos:
                for glifo in self.DECORATIVOS:
                    with self.subTest(fichero=ruta.name, glifo=glifo):
                        self.assertNotIn(glifo, linea, f"{ruta.name}: {linea.strip()}")

    def test_tampoco_escondidos_dentro_de_una_cadena(self) -> None:
        # `nav.skip` llevaba el suyo en el texto porque `iconText` sólo pinta
        # a la izquierda: si vuelve, vuelve por ahí.
        catalogo = _lee("components", "Strings.js")
        for linea in catalogo.splitlines():
            if not re.match(r'\s*"[a-z]', linea):
                continue
            for glifo in self.DECORATIVOS:
                with self.subTest(glifo=glifo, linea=linea.strip()[:40]):
                    self.assertNotIn(glifo, linea)

    def test_los_que_identifican_se_quedan(self) -> None:
        panel = _lee("Panel.qml")
        self.assertIn('"󰅍"', panel)          # limpiar ahora
        self.assertIn('"󰢻"', panel)          # los ajustes


class ElTitularNombraLoQueTienesTests(unittest.TestCase):
    """La `0013`.

    La pantalla de un bypass se confundió con el estado vacío, y la pregunta
    que lo destapó fue literal: «si éste es el estado vacío esperando a que el
    usuario tenga algo, ¿por qué vemos esto?». El portapapeles tenía una
    imagen. Lo que fallaba es que el titular hablaba de una imagen en
    abstracto, en pasiva, en vez de la tuya.
    """

    ESTADOS = ("image", "files", "structured", "sensitive", "large")

    def setUp(self) -> None:
        self.catalogo = _lee("components", "Strings.js")

    def _valor(self, clave: str, idioma: str) -> str:
        # Dos bloques en el fichero: EN primero, ES después.
        partes = self.catalogo.split(f'"{clave}": "')
        self.assertEqual(len(partes), 3, f"{clave} no aparece dos veces")
        return partes[1 if idioma == "en" else 2].split('"', 1)[0]

    def test_los_cinco_titulares_nombran_lo_que_tienes(self) -> None:
        for estado in self.ESTADOS:
            with self.subTest(estado=estado, idioma="en"):
                self.assertTrue(
                    self._valor(f"verdict.{estado}", "en").endswith("on your clipboard"),
                    "el titular tiene que nombrar lo que hay en el portapapeles",
                )
            with self.subTest(estado=estado, idioma="es"):
                self.assertTrue(
                    self._valor(f"verdict.{estado}", "es").endswith("en tu portapapeles"),
                )

    def test_ningun_titular_vuelve_a_la_pasiva(self) -> None:
        # Las formas exactas que había: «is left alone», «untouched»,
        # «Marked as», «Too big». Cada una decía qué le pasa a la cosa y no
        # cuál es la cosa.
        pasivas = ("is left alone", "untouched", "Marked as", "Too big",
                   "no se toca", "intacto", "intactos", "Marcado como", "Demasiado grande")
        for estado in self.ESTADOS:
            for idioma in ("en", "es"):
                titular = self._valor(f"verdict.{estado}", idioma)
                for forma in pasivas:
                    with self.subTest(estado=estado, idioma=idioma, forma=forma):
                        self.assertNotIn(forma, titular)

    def test_la_frase_no_repite_el_dato_del_titular(self) -> None:
        # El titular de `large` ya dice 1 MB; la frase lo decía otra vez tres
        # líneas más abajo.
        self.assertNotIn("1 MB", self._valor("detail.large", "en"))
        self.assertNotIn("1 MB", self._valor("detail.large", "es"))

    def test_el_limite_del_titular_es_el_limite_de_verdad(self) -> None:
        # Si `maxBytes` cambia, la cadena miente. Que lo diga este test y no
        # el usuario.
        from omaplain_lib.config import DEFAULTS
        self.assertEqual(int(DEFAULTS["maxBytes"]), 1024 * 1024)
        self.assertIn("1 MB", self._valor("verdict.large", "en"))
        self.assertIn("1 MB", self._valor("verdict.large", "es"))

    def test_la_promesa_fuerte_no_se_rebaja(self) -> None:
        # «No lo leemos» es lo que el helper cumple; «no lo procesamos» sonaría
        # a decisión de producto en vez de a garantía.
        self.assertIn("does not read", self._valor("detail.image", "en"))
        self.assertIn("no lee", self._valor("detail.image", "es"))

    def test_el_secreto_dice_la_cosa_y_luego_el_mecanismo(self) -> None:
        self.assertIn("secret", self._valor("verdict.sensitive", "en"))
        self.assertIn("secreto", self._valor("verdict.sensitive", "es"))
        # Quién lo marcó sigue estando, abajo, que es su sitio.
        self.assertIn("password manager", self._valor("detail.sensitive", "en"))
        self.assertIn("gestor de contraseñas", self._valor("detail.sensitive", "es"))

    def test_la_decision_esta_escrita(self) -> None:
        doc = REPO / "docs" / "decisions" / "0013-el-titular-nombra-lo-que-tienes.md"
        self.assertTrue(doc.exists())
        texto = doc.read_text(encoding="utf-8")
        # Y con lo descartado, que es la parte que ahorra la discusión de dentro
        # de tres semanas.
        self.assertIn("## Descartado", texto)
        self.assertIn("ficha", texto)
