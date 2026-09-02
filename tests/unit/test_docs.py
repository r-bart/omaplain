"""La documentación, que en un proyecto abierto es la puerta de entrada.

Nada de esto comprueba prosa: comprueba lo que se puede romper sin darse
cuenta —un enlace que apunta a donde ya no hay nada, una versión que se separa
de otra, un plan cumplido que se queda estorbando en la raíz—.
"""

from __future__ import annotations

import pathlib
import re
import unittest

REPO = pathlib.Path(__file__).resolve().parents[2]


def _markdown() -> list[pathlib.Path]:
    return sorted(p for p in REPO.rglob("*.md") if ".git" not in p.parts)


class EnlacesTests(unittest.TestCase):
    def test_ningun_enlace_interno_apunta_al_vacio(self) -> None:
        # Mover nueve documentos a `docs/notes/` rompió dieciséis enlaces de
        # golpe, y ninguno dio error hasta que alguien los pinchó.
        rotos = []
        for ruta in _markdown():
            texto = ruta.read_text(encoding="utf-8")
            for destino in re.findall(r"\]\(([^)#][^)]*)\)", texto):
                if destino.startswith(("http://", "https://", "mailto:")):
                    continue
                objetivo = ruta.parent / destino.split("#", 1)[0]
                if not objetivo.exists():
                    rotos.append(f"{ruta.relative_to(REPO)} -> {destino}")
        self.assertEqual(rotos, [], "enlaces rotos:\n  " + "\n  ".join(rotos))

    def test_cada_decision_esta_numerada_sin_huecos_ni_repetidas(self) -> None:
        numeros = sorted(
            int(p.name[:4])
            for p in (REPO / "docs" / "decisions").glob("[0-9][0-9][0-9][0-9]-*.md")
        )
        self.assertEqual(numeros, list(range(1, len(numeros) + 1)))


class LaRaizSeLeeDeUnVistazoTests(unittest.TestCase):
    """Lo que ve quien llega al repositorio, y sólo eso."""

    ESPERADOS = {
        "README.md", "CHANGELOG.md", "SECURITY.md",
        "ATTRIBUTIONS.md", "SPEC.md",
        # No es material de entrada para una persona: son las reglas del
        # repositorio para un agente, y la herramienta las lee de la raíz
        # y de ningún otro sitio. Se queda por eso y no por costumbre.
        "CLAUDE.md",
    }

    def test_solo_el_plan_en_curso_vive_en_la_raiz(self) -> None:
        # Un plan cumplido es historia y git ya la guarda; en la raíz sólo
        # estorba. El que está en curso sí se queda, para que se encuentre.
        raiz = {p.name for p in REPO.glob("*.md")}
        planes = {n for n in raiz if n.startswith("PLAN")}
        self.assertLessEqual(
            len(planes), 1,
            f"más de un plan en la raíz: {sorted(planes)}. Los cumplidos van a docs/notes/",
        )
        self.assertEqual(
            raiz - planes, self.ESPERADOS,
            "la raíz tiene documentos que no son de entrada",
        )

    def test_la_licencia_esta_donde_github_la_busca(self) -> None:
        self.assertTrue((REPO / "LICENSE").is_file())

    def test_las_notas_de_trabajo_estan_recogidas(self) -> None:
        notas = {p.name for p in (REPO / "docs" / "notes").glob("*.md")}
        for nombre in ("PLAN.md", "PLAN-0.2.0.md", "BASELINE.md", "SPIKE.md",
                       "TEST-REPORT.md", "UI-REVIEW.md", "UX-OPPORTUNITIES.md"):
            with self.subTest(nota=nombre):
                self.assertIn(nombre, notas)


class ElReadmeNoMienteTests(unittest.TestCase):
    """Las afirmaciones comprobables del README, atadas al código.

    Esta mañana el README describía el modelo de dos listas por aplicación que
    la `0011` había sustituido el día anterior. Nadie lo vio porque nada lo
    comprobaba: la prosa no se ejecuta.
    """

    def setUp(self) -> None:
        self.readme = (REPO / "README.md").read_text(encoding="utf-8")
        import sys
        sys.path.insert(0, str(REPO / "helper"))
        from omaplain_lib.config import DEFAULTS
        self.defaults = DEFAULTS

    def test_las_cuatro_reglas_de_serie_son_las_que_vienen_puestas(self) -> None:
        tabla = self.readme.split("Four rules are on out of the box", 1)[1]
        tabla = tabla.split("Four more are available", 1)[0]
        de_serie = ("stripFormatting", "removeTracking", "removeInvisible",
                    "normalizeLineEndings")
        for clave in de_serie:
            with self.subTest(regla=clave):
                self.assertTrue(self.defaults[clave], f"{clave} ya no viene puesta")
        # Y las cuatro filas están: una por regla.
        self.assertEqual(tabla.count("\n|"), len(de_serie) + 2)  # cabecera y separador

    def test_las_cuatro_opcionales_siguen_apagadas(self) -> None:
        for clave in ("normalizeQuotes", "normalizeLists", "normalizeUnicodeNfc",
                      "trimTrailingWhitespace"):
            with self.subTest(regla=clave):
                self.assertFalse(self.defaults[clave], f"{clave} ya no es opcional")
        self.assertIn("off by default", self.readme)

    def test_las_cuatro_reglas_por_aplicacion_estan_las_cuatro(self) -> None:
        # El fallo de esta mañana, en forma de test.
        for rotulo in ("Never uncover", "Never read",
                       "Don't clean its copies", "Don't paste clean here"):
            with self.subTest(regla=rotulo):
                self.assertIn(rotulo, self.readme)
        catalogo = (REPO / "components" / "Strings.js").read_text(encoding="utf-8")
        for rotulo in ("Never uncover", "Never read",
                       "Don't clean its copies", "Don't paste clean here"):
            with self.subTest(regla=rotulo, sitio="panel"):
                self.assertIn(f'"{rotulo}"', catalogo)

    def test_el_limite_de_tamano_es_el_de_verdad(self) -> None:
        self.assertEqual(self.defaults["maxBytes"], 1024 * 1024)
        self.assertIn("1 MiB", self.readme)

    def test_las_acciones_que_documenta_existen(self) -> None:
        cli = (REPO / "helper" / "omaplain_lib" / "cli.py").read_text(encoding="utf-8")
        acciones = re.findall(r"omarchy-shell omaplain (\w+)", self.readme)
        self.assertTrue(acciones)
        for accion in set(acciones):
            if accion in {"status", "setAutomatic"}:
                continue  # los sirve el servicio QML, no el CLI del helper
            with self.subTest(accion=accion):
                self.assertIn(f'"{accion}"', cli, f"{accion} no existe en el helper")

    def test_las_tres_formas_de_abrirlo_estan_declaradas(self) -> None:
        import json
        manifiesto = json.loads((REPO / "manifest.json").read_text(encoding="utf-8"))
        self.assertIn("bar-widget", manifiesto["kinds"])
        self.assertIn("panel", manifiesto["kinds"])
        self.assertTrue((REPO / "io.github.r-bart.omaplain.desktop").is_file())
        self.assertIn(manifiesto["id"], self.readme)

    def test_no_promete_un_atajo_global(self) -> None:
        # La promesa que la `0010` protege. Se comprueba sobre el texto sin
        # saltos de línea, o el README no puede envolver donde le conviene.
        plano = " ".join(self.readme.split())
        self.assertIn("never claims a global shortcut", plano)
        self.assertIn("will not add it for you", plano)

    def test_las_capturas_existen_y_llevan_texto_alternativo(self) -> None:
        # Un plugin con interfaz sin una sola captura no se puede evaluar. Y
        # una captura sin `alt` no la lee quien no ve.
        imagenes = re.findall(r"!\[([^\]]*)\]\(([^)]+)\)", self.readme)
        self.assertGreaterEqual(len(imagenes), 3, "faltan capturas")
        for alt, ruta in imagenes:
            with self.subTest(imagen=ruta):
                self.assertTrue((REPO / ruta).is_file(), f"{ruta} no existe")
                self.assertGreater(len(alt.split()), 5, "el alt no describe nada")

    def test_se_puede_instalar_antes_de_leerselo_entero(self) -> None:
        # La estructura: quien viene a instalarlo no debería recorrer la mitad
        # del documento. Install va en los tres primeros títulos.
        titulos = re.findall(r"^## (.+)$", self.readme, re.MULTILINE)
        self.assertIn("Install", titulos)
        self.assertLessEqual(titulos.index("Install"), 2)

    def test_la_promesa_se_lee_antes_que_nada(self) -> None:
        # Comprimida en la entrada, y desarrollada más abajo con su captura.
        entrada = self.readme.split("## Install", 1)[0]
        plano = " ".join(entrada.split())
        for promesa in ("never touches images", "keeps no history",
                        "no network requests", "never claims a global shortcut"):
            with self.subTest(promesa=promesa):
                self.assertIn(promesa, plano)
        self.assertIn("## What it never does", self.readme)

    def test_esta_en_ingles(self) -> None:
        # Decisión `0014`: lo que lee quien llega, en inglés. El README y
        # SECURITY; el CHANGELOG a partir de la 1.0.
        castellano = (" el ", " la ", " los ", " las ", " que ", " para ", " con ")
        for nombre in ("README.md", "SECURITY.md"):
            cuerpo = (REPO / nombre).read_text(encoding="utf-8").lower()
            # Los nombres de fichero en español —las decisiones— no cuentan.
            cuerpo = re.sub(r"\([^)]*\)", "", cuerpo)
            encontradas = [p for p in castellano if p in cuerpo]
            with self.subTest(documento=nombre):
                self.assertEqual(encontradas, [], f"quedan trozos en español: {encontradas}")


if __name__ == "__main__":
    unittest.main()
