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

    def test_peek_reports_a_rewrite_even_when_the_text_is_identical(self) -> None:
        # Retirar formato enriquecido no cambia un carácter: lo que desaparece
        # es la versión con formato. Si `changed` mirase sólo al texto, el
        # panel diría «ya está limpio» de algo que sí se va a reescribir.
        self.backend.types = ["text/html", "text/plain"]
        self.backend.payload = b"Resumen ejecutivo"
        answer = self.daemon.peek()
        self.assertTrue(answer["changed"], "peek no ve la retirada de formato")
        self.assertIn("rich_text", answer["applied"])
        self.assertEqual(answer["original"], answer["cleaned"])
        # Y el cambio que sí se puede enseñar son los tipos.
        self.assertEqual(answer["typesAfter"], ["text/plain"])

    def test_peek_and_clean_now_agree_about_whether_anything_happens(self) -> None:
        for types, payload in (
            (["text/html", "text/plain"], b"Resumen ejecutivo"),
            (["text/plain"], b"https://ejemplo.com/a?utm_source=x"),
            (["text/plain"], b"nada que hacer"),
        ):
            with self.subTest(types=types):
                self.setUp()
                self.backend.types = types
                self.backend.payload = payload
                preview = self.daemon.peek()
                result = self.daemon.clean_now()
                self.assertEqual(
                    preview["changed"], result["result"] == "cleaned",
                    "el panel promete algo distinto de lo que hace el motor",
                )

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

    def test_peek_calls_an_empty_clipboard_empty(self) -> None:
        self.backend.types = []
        answer = self.daemon.peek()
        self.assertEqual(answer["result"], "ok")
        self.assertEqual(answer["reason"], "empty")
        self.assertFalse(answer["eligible"])

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

    def test_peek_is_reachable_but_never_advertised(self) -> None:
        """El panel necesita transporte; nadie más necesita encontrarlo.

        El panel sólo habla con el helper leyendo la tubería de un proceso
        que lanza, así que `peek` tiene que existir en la CLI. Lo que no
        puede es anunciarse: quien lo teclee por curiosidad se lleva el
        contenido del portapapeles al scrollback y al historial. El repo ya
        resuelve esto con `emit-event`, oculto con `argparse.SUPPRESS`.
        """
        from omaplain_lib import cli

        parser = cli._parser()
        actions = [a for a in parser._actions if hasattr(a, "choices") and a.choices]
        subcommands = {}
        for action in actions:
            if isinstance(action.choices, dict):
                subcommands = action.choices
                break
        self.assertIn("peek", subcommands, "el panel se quedó sin transporte")

        helptext = parser.format_help()
        self.assertNotIn("peek", helptext, "peek aparece en el --help")
        # `help=argparse.SUPPRESS` no oculta un subcomando: argparse imprime
        # literalmente "==SUPPRESS==". Lo que oculta es no declarar `help`,
        # y hace falta un `metavar` propio o la lista entre llaves lo delata.
        self.assertNotIn("SUPPRESS", helptext)
        self.assertNotIn("emit-event", helptext, "la fontanería interna se anuncia")

        # Y sigue fuera de la lista que un humano navega en `control`.
        source = Path(cli.__file__).read_text(encoding="utf-8")
        choices = re.search(r'control\.add_argument\("name", choices=\((?P<list>[^)]*)\)', source)
        self.assertIsNotNone(choices, "cambió la forma de declarar los comandos de control")
        self.assertNotIn("peek", choices.group("list"))


if __name__ == "__main__":
    unittest.main()
