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


if __name__ == "__main__":
    unittest.main()
