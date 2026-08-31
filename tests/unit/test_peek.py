"""El contrato de `peek`: puede enseñar, no puede dejar rastro.

La decisión 0005 movió la frontera de sitio. El contenido puede cruzar el
socket y llegar al panel; lo que no puede es quedar escrito en ninguna
parte. Estos tests vigilan las dos mitades de esa frase.
"""

from __future__ import annotations

import io
import json
import re
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path

from omaplain_lib.config import write_config
from omaplain_lib.daemon import OmaPlainDaemon

from test_daemon import FakeBackend

# Una marca que no aparece por casualidad en ninguna otra parte del repo.
MARK = "zqx-marca-de-fuga-7f3a1c"


class PeekTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.base = Path(self.temporary.name)
        self.config = self.base / "config.json"
        self.status = self.base / "status.json"
        write_config(self.config, {})
        self.daemon = OmaPlainDaemon(
            "/tmp/omaplain", str(self.config), str(self.status), str(self.base / "omaplain.sock")
        )
        self.backend = FakeBackend()
        self.daemon.backend = self.backend

    def tearDown(self) -> None:
        self.temporary.cleanup()

    # ---------------------------------------------------------------- enseña

    def test_peek_reports_the_before_and_the_after(self) -> None:
        self.backend.payload = b"https://ejemplo.com/a?utm_source=x&keep=1"
        answer = self.daemon.peek()
        self.assertEqual(answer["result"], "ok")
        self.assertTrue(answer["eligible"])
        self.assertEqual(answer["original"], "https://ejemplo.com/a?utm_source=x&keep=1")
        self.assertEqual(answer["cleaned"], "https://ejemplo.com/a?keep=1")
        self.assertIn("tracking", answer["applied"])
        self.assertTrue(answer["changed"])

    def test_peek_agrees_with_what_cleaning_would_actually_do(self) -> None:
        # Si `peek` y `cleanNow` divergen, el panel enseña una promesa que el
        # motor no cumple. Es el mismo riesgo que la demo del tour.
        self.backend.payload = b"uno\r\ndos\r\n"
        preview = self.daemon.peek()
        self.daemon.clean_now()
        self.assertEqual(self.backend.writes[-1].decode("utf-8"), preview["cleaned"])

    def test_peek_marks_a_clipboard_that_needs_no_change(self) -> None:
        self.backend.payload = b"nada que limpiar"
        answer = self.daemon.peek()
        self.assertTrue(answer["eligible"])
        self.assertFalse(answer["changed"])
        self.assertEqual(answer["original"], answer["cleaned"])

    def test_peek_truncates_instead_of_shipping_the_whole_payload(self) -> None:
        self.backend.payload = b"a" * (OmaPlainDaemon.PEEK_LIMIT * 3)
        answer = self.daemon.peek()
        self.assertTrue(answer["truncated"])
        self.assertEqual(len(answer["original"]), OmaPlainDaemon.PEEK_LIMIT)
        self.assertEqual(answer["bytes"], OmaPlainDaemon.PEEK_LIMIT * 3)

    # -------------------------------------------------------------- se niega

    def test_peek_never_returns_sensitive_content(self) -> None:
        # La negativa vive en el helper. Si viviera en la interfaz seria un
        # ajuste, y un ajuste que destapa un secreto marcado es un revelador
        # de contraseñas con pasos extra.
        self.backend.types = ["x-kde-passwordManagerHint"]
        self.backend.payload = MARK.encode("utf-8")
        answer = self.daemon.peek()
        self.assertFalse(answer["eligible"])
        self.assertEqual(answer["reason"], "sensitive")
        self.assertNotIn("original", answer)
        self.assertNotIn("cleaned", answer)
        self.assertNotIn(MARK, json.dumps(answer, ensure_ascii=False))

    def test_peek_returns_no_content_for_images_files_or_structured(self) -> None:
        for types, reason in (
            (["image/png"], "image"),
            (["text/uri-list"], "files"),
        ):
            with self.subTest(types=types):
                self.backend.types = types
                self.backend.payload = MARK.encode("utf-8")
                answer = self.daemon.peek()
                self.assertFalse(answer["eligible"])
                self.assertEqual(answer["reason"], reason)
                self.assertNotIn(MARK, json.dumps(answer, ensure_ascii=False))

    # ----------------------------------------------------------- no persiste

    def test_peek_leaves_no_trace_of_the_content_anywhere(self) -> None:
        """El corazón de la 0005: mirar no puede dejar rastro."""
        self.backend.payload = MARK.encode("utf-8")
        out, err = io.StringIO(), io.StringIO()
        with redirect_stdout(out), redirect_stderr(err):
            answer = self.daemon.peek()
        self.assertIn(MARK, answer["original"])   # sí llegó al panel

        self.assertNotIn(MARK, out.getvalue(), "la marca se escapó por stdout")
        self.assertNotIn(MARK, err.getvalue(), "la marca se escapó por stderr")
        self.assertNotIn(MARK, json.dumps(self.daemon.status.snapshot(), ensure_ascii=False))
        for path in sorted(self.base.rglob("*")):
            if path.is_file():
                with self.subTest(file=path.name):
                    self.assertNotIn(MARK, path.read_text(encoding="utf-8", errors="replace"))

    def test_peek_does_not_count_as_an_operation(self) -> None:
        # `_record` es lo unico de la clase que escribe en disco. Mirar no es
        # una operacion y no debe mover los contadores.
        before = json.dumps(self.daemon.status.snapshot(), sort_keys=True)
        self.daemon.peek()
        self.assertEqual(json.dumps(self.daemon.status.snapshot(), sort_keys=True), before)

    def test_peek_never_writes_to_the_clipboard(self) -> None:
        self.daemon.peek()
        self.assertEqual(self.backend.writes, [])

    def test_peek_does_not_consume_a_pending_skip(self) -> None:
        # Mirar antes de copiar no puede gastarle al usuario la omision que
        # habia armado para la copia siguiente.
        self.daemon.skip_next()
        self.daemon.peek()
        self.assertTrue(self.daemon._skip_active(), "peek se comió el skipNext")

    def test_peek_does_not_advance_the_generation(self) -> None:
        before = self.daemon.generation
        self.daemon.peek()
        self.assertEqual(self.daemon.generation, before)

    def test_peek_is_reachable_as_a_command(self) -> None:
        self.assertEqual(self.daemon.command("peek")["result"], "ok")

    def test_peek_is_not_exposed_on_the_command_line(self) -> None:
        # `peek` responde contenido, y `control` lo imprimiria por stdout:
        # justo uno de los sitios que la auditoria reformulada por 0005 tiene
        # que barrer, ademas del historial y el scrollback de quien lo llame.
        # El panel lo alcanza por el socket; nada mas lo necesita.
        from omaplain_lib import cli

        source = Path(cli.__file__).read_text(encoding="utf-8")
        choices = re.search(r'control\.add_argument\("name", choices=\((?P<list>[^)]*)\)', source)
        self.assertIsNotNone(choices, "cambio la forma de declarar los comandos de control")
        self.assertNotIn("peek", choices.group("list"))


if __name__ == "__main__":
    unittest.main()
