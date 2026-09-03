"""El icono del lanzador, repintado con los colores del tema.

El lanzador dibuja un fichero tal cual: `shell/plugins/menu/Menu.qml` lo pone
en un `Image` sin teñir nada. Así que teñirlo es escribir otro fichero, y eso
lo hace este hook — el gancho `theme-set` que Omarchy ya llama.

Lo que estos tests sujetan no es el color, que lo pone el tema: es **hasta
dónde llega el hook**. Escribe en su propio directorio y cambia una línea de
una entrada `.desktop` que el usuario copió a mano. Nada más, y nada cuando
no hay lanzador instalado.
"""

from __future__ import annotations

import os
import re
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[2]
HOOK = REPO / "launcher" / "omaplain-launcher-icon"
ICONO = REPO / "io.github.r-bart.omaplain.svg"
DESKTOP = REPO / "io.github.r-bart.omaplain.desktop"

# Los tres colores de marca del SVG versionado. El hook los sustituye por los
# del tema, así que si alguien repinta el fichero y no toca el hook, el icono
# se queda a medias: mitad tema, mitad marca.
FONDO = "#F6F2EA"
TINTA = "#1B201E"
PUNTO = "#3E8E79"


class HookTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.tmp, True)
        self.bin = self.tmp / "bin"
        self.datos = self.tmp / "data"
        (self.datos / "applications").mkdir(parents=True)
        self.bin.mkdir()
        self.entrada = self.datos / "applications" / DESKTOP.name
        self.entrada.write_text(DESKTOP.read_text(encoding="utf-8"), encoding="utf-8")
        self.tema = {"foreground": "#d8cbb4", "background": "#0c1626", "accent": "#d9a862"}
        self._escribir_tema()

    def _escribir_tema(self) -> None:
        ruta = self.bin / "omarchy-theme-color"
        casos = "\n".join(f'  {k}) echo "{v}" ;;' for k, v in self.tema.items())
        ruta.write_text(f'#!/usr/bin/env bash\ncase "$1" in\n{casos}\nesac\n',
                        encoding="utf-8")
        ruta.chmod(0o755)

    def _correr(self, con_tema: bool = True) -> subprocess.CompletedProcess:
        camino = f"{self.bin}:/usr/bin:/bin" if con_tema else "/usr/bin:/bin"
        return subprocess.run(
            ["bash", str(HOOK)], capture_output=True, text=True,
            env={**os.environ, "PATH": camino, "XDG_DATA_HOME": str(self.datos),
                 "HOME": str(self.tmp)})

    def _icono_puesto(self) -> str:
        for linea in self.entrada.read_text(encoding="utf-8").splitlines():
            if linea.startswith("Icon="):
                return linea[len("Icon="):]
        return ""

    def _generados(self) -> list[Path]:
        carpeta = self.datos / "omaplain" / "icons"
        return sorted(carpeta.glob("omaplain-*.svg")) if carpeta.exists() else []

    def _inventario(self) -> set[str]:
        return {str(p.relative_to(self.tmp)) for p in self.tmp.rglob("*")}

    def test_the_hook_is_shipped_runnable(self) -> None:
        self.assertTrue(HOOK.exists())
        self.assertTrue(os.access(HOOK, os.X_OK), "el hook tiene que llegar ejecutable")

    def test_the_three_brand_colours_are_the_ones_the_icon_has(self) -> None:
        """Que el hook y el icono no se separen.

        El hook sustituye tres cadenas literales. Repintar el SVG sin tocarlas
        deja un icono a medias —una parte del tema y otra de la marca— y nada
        falla: el hook sigue saliendo con cero.
        """
        svg = ICONO.read_text(encoding="utf-8")
        hook = HOOK.read_text(encoding="utf-8")
        for color in (FONDO, TINTA, PUNTO):
            with self.subTest(color=color):
                self.assertEqual(svg.count(color), 1, "el icono ya no lo usa una vez")
                self.assertIn(f"s/{color}/", hook, "el hook ya no lo sustituye")

    def test_it_repaints_the_icon_and_points_the_entry_at_it(self) -> None:
        self._correr()
        generados = self._generados()
        self.assertEqual(len(generados), 1)
        self.assertEqual(self._icono_puesto(), str(generados[0]))

        pintado = generados[0].read_text(encoding="utf-8")
        for color in self.tema.values():
            with self.subTest(color=color):
                self.assertIn(color, pintado)
        for color in (FONDO, TINTA, PUNTO):
            with self.subTest(marca=color):
                self.assertNotIn(color, pintado)

    def test_the_geometry_survives_the_repaint(self) -> None:
        # Sólo cambian tres colores. El trazo es el mismo que compara
        # `test_launch_surfaces.BrandTests`, y tiene que seguir siéndolo.
        self._correr()
        def trazo(texto: str) -> str:
            m = re.search(r'<path d="([^"]+)"', texto)
            assert m
            return m.group(1)
        self.assertEqual(trazo(self._generados()[0].read_text(encoding="utf-8")),
                         trazo(ICONO.read_text(encoding="utf-8")))

    def test_the_second_run_writes_nothing(self) -> None:
        # El hook corre en cada cambio de tema y volver a un tema ya visto es
        # lo más normal del mundo. Reescribir la entrada cada vez es tocar un
        # fichero del usuario para dejarlo igual.
        self._correr()
        antes = self.entrada.stat().st_mtime_ns
        self._correr()
        self.assertEqual(self.entrada.stat().st_mtime_ns, antes)

    def test_a_new_theme_replaces_the_file_instead_of_piling_up(self) -> None:
        self._correr()
        viejo = self._generados()[0]
        self.tema["accent"] = "#db684c"
        self._escribir_tema()
        self._correr()
        generados = self._generados()
        self.assertEqual(len(generados), 1, "se acumulan iconos de temas pasados")
        self.assertNotEqual(generados[0], viejo)
        self.assertEqual(self._icono_puesto(), str(generados[0]))

    def test_without_a_launcher_entry_it_does_nothing(self) -> None:
        # Instalar la entrada es una decisión del usuario ([`0010`]). Sin
        # ella el hook no tiene nada que repintar, y no la crea.
        self.entrada.unlink()
        antes = self._inventario()
        resultado = self._correr()
        self.assertEqual(resultado.returncode, 0, resultado.stderr)
        self.assertEqual(self._inventario(), antes)

    def test_without_the_theme_resolver_it_does_nothing(self) -> None:
        antes = self._inventario()
        resultado = self._correr(con_tema=False)
        self.assertEqual(resultado.returncode, 0, resultado.stderr)
        self.assertEqual(self._inventario(), antes)

    def test_a_colour_that_is_not_a_colour_stops_it(self) -> None:
        # Ante la duda, no se toca nada: la misma regla que el bypass.
        self.tema["accent"] = "rgb(217, 168, 98)"
        self._escribir_tema()
        antes = self._inventario()
        resultado = self._correr()
        self.assertEqual(resultado.returncode, 0, resultado.stderr)
        self.assertEqual(self._inventario(), antes)

    def test_it_writes_only_in_its_own_corner(self) -> None:
        """Escribe en `<datos>/omaplain/icons` y en su propia entrada.

        Un plugin de portapapeles que reparte ficheros por los directorios de
        aplicaciones del usuario está haciendo justo lo que este proyecto
        promete no hacer. Así que lo que toca se cuenta.
        """
        antes = self._inventario()
        self._correr()
        nuevos = self._inventario() - antes
        # `update-desktop-database` reindexa el directorio y deja ahí su
        # `mimeinfo.cache`. No es nuestro, es el índice de ese directorio, y
        # lo escribe igual cualquier instalación de una entrada `.desktop`.
        permitido = ("data/omaplain", "data/applications/mimeinfo.cache")
        for ruta in nuevos:
            with self.subTest(ruta=ruta):
                self.assertTrue(ruta.startswith(permitido), ruta)


if __name__ == "__main__":
    unittest.main()
