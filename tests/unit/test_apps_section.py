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
