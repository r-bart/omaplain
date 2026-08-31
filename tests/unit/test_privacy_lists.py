"""Las dos listas de la `0009`: la que cubre y la que no deja leer.

`blockedApps` convierte una atribución best-effort en una promesa de
privacidad, así que la promesa hay que probarla en la única forma que
importa: una muestra marcada copiada desde una app bloqueada no puede
aparecer en la respuesta del panel, ni recortada, ni en forma de tipos, ni
por ninguna de las tres formas que tiene el helper de leer el portapapeles.
"""

from __future__ import annotations

import io
import json
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path

from omaplain_lib.clipboard import WindowTarget
from omaplain_lib.config import validate_config, write_config
from omaplain_lib.daemon import OmaPlainDaemon

from test_daemon import FakeBackend

MARK = "zqx-marca-bloqueada-4e91b2"
VAULT = WindowTarget("0x900", "org.keepassxc.KeePassXC", "keepassxc", False)
NOTES = WindowTarget("0x901", "com.ejemplo.Notas", "notas", False)


class PrivacyListTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.base = Path(self.temporary.name)
        self.config = self.base / "config.json"
        write_config(self.config, {
            "blockedApps": ["org.keepassxc.KeePassXC"],
            "alwaysCovered": ["com.ejemplo.Notas"],
        })
        self.daemon = OmaPlainDaemon(
            "/tmp/omaplain", str(self.config), str(self.base / "status.json"),
            str(self.base / "omaplain.sock"),
        )
        self.backend = FakeBackend()
        self.daemon.backend = self.backend

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def _copy_from(self, target: WindowTarget, payload: bytes) -> None:
        """Una copia hecha desde `target`, como la ve el demonio."""
        self.backend.payload = payload
        self.daemon.automatic_event("data", self.daemon._next_generation(), target)

    # ------------------------------------------------------------- bloqueada

    def test_a_blocked_app_never_reaches_the_panel(self) -> None:
        self.backend.payload = MARK.encode("utf-8")
        self.daemon.last_source = (VAULT.app_class, VAULT.initial_class)

        out, err = io.StringIO(), io.StringIO()
        with redirect_stdout(out), redirect_stderr(err):
            answer = self.daemon.peek()

        self.assertFalse(answer["eligible"])
        self.assertEqual(answer["reason"], "source_blocked")
        # Ni contenido, ni recorte, ni de qué está hecho: de una app bloqueada
        # no se enseña ni la lista de tipos.
        self.assertEqual(answer["types"], [])
        self.assertNotIn("original", answer)
        self.assertNotIn("cleaned", answer)
        self.assertNotIn(MARK, json.dumps(answer, ensure_ascii=False))

        self.assertNotIn(MARK, out.getvalue())
        self.assertNotIn(MARK, err.getvalue())
        self.assertNotIn(MARK, json.dumps(self.daemon.status.snapshot(), ensure_ascii=False))
        for path in sorted(self.base.rglob("*")):
            if path.is_file():
                with self.subTest(file=path.name):
                    self.assertNotIn(MARK, path.read_text(encoding="utf-8", errors="replace"))

    def test_a_blocked_app_is_not_even_inspected(self) -> None:
        # «Ni lee» es literal: no se le piden los tipos al portapapeles.
        self.daemon.last_source = (VAULT.app_class, VAULT.initial_class)
        before = self.backend.list_calls
        self.daemon.peek()
        self.assertEqual(self.backend.list_calls, before, "se inspeccionó una app bloqueada")

    def test_a_blocked_app_is_not_cleaned_automatically(self) -> None:
        self._copy_from(VAULT, MARK.encode("utf-8"))
        self.assertEqual(self.backend.writes, [], "se reescribió el portapapeles de una app bloqueada")

    def test_the_manual_action_does_not_open_the_door_either(self) -> None:
        # Una acción explícita no levanta la negativa: si la levantara, la
        # lista significaría «bloqueado hasta que alguien pulse un botón».
        self.daemon.last_source = (VAULT.app_class, VAULT.initial_class)
        self.backend.payload = MARK.encode("utf-8")
        answer = self.daemon.clean_now()
        self.assertEqual(answer["reason"], "source_blocked")
        self.assertEqual(self.backend.writes, [])

    def test_the_initial_class_counts_too(self) -> None:
        # Una app puede cambiarse la clase en caliente; `initialClass` no.
        self.daemon.last_source = ("otra.cosa", "keepassxc")
        write_config(self.config, {"blockedApps": ["keepassxc"]})
        self.daemon.config = validate_config(json.loads(self.config.read_text()))[0]
        self.assertFalse(self.daemon.peek()["eligible"])

    def test_an_unknown_source_is_not_a_blocked_source(self) -> None:
        # Decidido en la 0009 y dicho en el copy: la atribución es best
        # effort, y tratar lo desconocido como bloqueado rompería la pantalla
        # de todos los días cada vez que `hyprctl` tosa.
        self.daemon.last_source = ("", "")
        self.assertTrue(self.daemon.peek()["eligible"])

    # -------------------------------------------------------------- cubierta

    def test_a_covered_app_arrives_marked(self) -> None:
        self._copy_from(NOTES, b"https://ejemplo.com/a?utm_source=x&keep=1")
        answer = self.daemon.peek()
        self.assertTrue(answer["eligible"])
        self.assertTrue(answer["cover"], "la app de la lista no llegó marcada")
        # Cubrir no es bloquear: el contenido sí viaja, para poder enseñar el
        # antes y el después cuando el usuario levante el ojo.
        self.assertIn("original", answer)

    def test_the_mark_comes_back_with_the_next_copy(self) -> None:
        # El ojo levanta la fila que hay delante; no cambia la lista. Aunque
        # el panel hubiera destapado, la copia siguiente vuelve marcada.
        self._copy_from(NOTES, b"uno")
        self.assertTrue(self.daemon.peek()["cover"])
        self._copy_from(NOTES, b"dos")
        self.assertTrue(self.daemon.peek()["cover"], "la marca no volvió con la copia siguiente")

    def test_a_copy_from_elsewhere_is_not_covered(self) -> None:
        self._copy_from(NOTES, b"uno")
        self._copy_from(WindowTarget("0x902", "foot", "foot", True), b"dos")
        self.assertFalse(self.daemon.peek()["cover"], "se quedó cubierto lo que ya no venía de la lista")

    # ------------------------------------------------------------ el origen

    def test_the_source_is_remembered_even_with_automatic_off(self) -> None:
        # Con el automático apagado el evento sale antes de limpiar, pero la
        # atribución tiene que quedar igual o el panel no sabría de dónde
        # viene lo que tiene delante.
        write_config(self.config, {"automatic": False, "blockedApps": ["org.keepassxc.KeePassXC"]})
        self.daemon.config = validate_config(json.loads(self.config.read_text()))[0]
        self.daemon.automatic_event("data", self.daemon._next_generation(), VAULT)
        self.assertEqual(self.daemon.last_source, (VAULT.app_class, VAULT.initial_class))
        self.assertFalse(self.daemon.peek()["eligible"])

    def test_the_source_never_reaches_disk(self) -> None:
        # Es metadato, no contenido, pero tampoco tiene por qué persistirse.
        # Se prueba con una app que no está en ninguna lista: las que sí lo
        # están aparecen en `config.json` porque el usuario las escribió allí,
        # que es otra cosa que recordar de dónde vino una copia.
        stranger = WindowTarget("0x903", "com.ejemplo.SinLista", "sinlista", False)
        self._copy_from(stranger, b"uno")
        self.assertEqual(self.daemon.last_source, (stranger.app_class, stranger.initial_class))
        snapshot = json.dumps(self.daemon.status.snapshot(), ensure_ascii=False)
        self.assertNotIn(stranger.app_class, snapshot)
        for path in sorted(self.base.rglob("*")):
            if path.is_file():
                with self.subTest(file=path.name):
                    self.assertNotIn(stranger.app_class, path.read_text(encoding="utf-8", errors="replace"))


if __name__ == "__main__":
    unittest.main()
