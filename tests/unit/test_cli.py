"""La frontera que el panel usa de verdad: los subcomandos del helper.

`Service.qml` no llama a `daemon.py` ni a `transform.py`: lanza
`helper/omaplain` con un subcomando y lee su salida. Ese contrato —códigos
de salida, forma del JSON, y que ninguna respuesta lleve contenido— no
tenía ni un test, y es lo único que el panel ve.

La segunda mitad del fichero lo prueba de extremo a extremo: el ejecutable
de verdad, en un proceso aparte, contra un demonio escuchando en un socket
temporal. Es la misma secuencia que hace el shell al arrancar el plugin.
"""

from __future__ import annotations

import io
import json
import os
import subprocess
import sys
import tempfile
import threading
import time
import unittest
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path
from unittest.mock import patch

from omaplain_lib import __version__
from omaplain_lib.cli import main
from omaplain_lib.clipboard import ClipboardError, WindowTarget

sys.path.insert(0, str(Path(__file__).resolve().parent))
from test_daemon import FakeBackend  # noqa: E402
from test_daemon_runtime import RunningDaemon  # noqa: E402


REPO = Path(__file__).resolve().parents[2]
EXECUTABLE = REPO / "helper" / "omaplain"
# Una marca que no sale por casualidad en ninguna otra parte.
MARK = "zqx-marca-de-cli-4b8e2d"


def run_cli(*argv: str, stdin: bytes = b"") -> tuple[int, str, bytes]:
    """Llama a `main()` en este proceso y devuelve código, stdout y stderr."""
    out, err = io.BytesIO(), io.StringIO()
    text_out = io.TextIOWrapper(out, encoding="utf-8", write_through=True)
    stream = io.BytesIO(stdin)
    stream_wrapper = io.TextIOWrapper(stream, encoding="utf-8")
    with patch.object(sys, "stdin", stream_wrapper), redirect_stdout(text_out), redirect_stderr(err):
        code = main(list(argv))
    text_out.flush()
    return code, out.getvalue().decode("utf-8"), err.getvalue().encode("utf-8")


class ParserTests(unittest.TestCase):
    def test_a_missing_command_is_refused(self) -> None:
        with self.assertRaises(SystemExit), redirect_stderr(io.StringIO()):
            main([])

    def test_the_version_matches_the_manifest(self) -> None:
        manifest = json.loads((REPO / "manifest.json").read_text(encoding="utf-8"))
        self.assertEqual(__version__, manifest["version"])
        with self.assertRaises(SystemExit) as exit_code, redirect_stdout(io.StringIO()):
            main(["--version"])
        self.assertEqual(exit_code.exception.code, 0)

    def test_control_only_accepts_the_names_the_daemon_knows(self) -> None:
        with self.assertRaises(SystemExit), redirect_stderr(io.StringIO()):
            main(["control", "--socket", "/x", "explode"])

    def test_the_internal_plumbing_stays_out_of_the_help(self) -> None:
        # `peek` responde con contenido del portapapeles: no se anuncia
        # para que nadie lo teclee por curiosidad y acabe en su historial.
        out = io.StringIO()
        with self.assertRaises(SystemExit), redirect_stdout(out):
            main(["--help"])
        helped = out.getvalue()
        self.assertIn("check-dependencies", helped)
        self.assertNotIn("peek", helped)
        self.assertNotIn("emit-event", helped)


class DependencyTests(unittest.TestCase):
    def test_everything_present_is_a_zero(self) -> None:
        with patch("omaplain_lib.cli.shutil.which", return_value="/usr/bin/x"):
            code, out, _ = run_cli("check-dependencies")
        self.assertEqual(code, 0)
        answer = json.loads(out)
        self.assertEqual(answer, {"ok": True, "missing": [], "version": __version__})

    def test_what_is_missing_is_named_and_the_code_is_one(self) -> None:
        def which(name: str) -> str | None:
            return None if name in {"setpriv", "hyprctl"} else "/usr/bin/" + name
        with patch("omaplain_lib.cli.shutil.which", side_effect=which):
            code, out, _ = run_cli("check-dependencies")
        self.assertEqual(code, 1)
        self.assertEqual(json.loads(out)["missing"], ["hyprctl", "setpriv"])


class InspectTests(unittest.TestCase):
    def test_inspect_reports_types_and_never_content(self) -> None:
        backend = FakeBackend()
        backend.types = ["text/html", "text/plain"]
        backend.payload = MARK.encode("utf-8")
        with patch("omaplain_lib.cli.ClipboardBackend", return_value=backend):
            code, out, _ = run_cli("inspect")
        self.assertEqual(code, 0)
        answer = json.loads(out)
        self.assertEqual(answer["result"], "eligible")
        self.assertEqual(answer["reason"], "text")
        self.assertTrue(answer["hasRich"])
        self.assertNotIn(MARK, out)

    def test_an_unreadable_clipboard_is_reported_as_empty(self) -> None:
        backend = FakeBackend()
        backend.list_types = lambda: (_ for _ in ()).throw(ClipboardError("x"))  # type: ignore[method-assign]
        with patch("omaplain_lib.cli.ClipboardBackend", return_value=backend):
            code, out, _ = run_cli("inspect")
        self.assertEqual(code, 0)
        self.assertEqual(json.loads(out), {"result": "bypassed", "reason": "empty", "typeCount": 0})

    def test_a_bypass_is_named_by_its_reason(self) -> None:
        backend = FakeBackend()
        backend.types = ["image/png"]
        with patch("omaplain_lib.cli.ClipboardBackend", return_value=backend):
            code, out, _ = run_cli("inspect")
        self.assertEqual((code, json.loads(out)["reason"]), (0, "image"))


class WindowTests(unittest.TestCase):
    def test_the_active_window_answers_without_its_title(self) -> None:
        backend = FakeBackend()
        backend.target = WindowTarget("0xabc", "foot", "footclient", True)
        with patch("omaplain_lib.cli.ClipboardBackend", return_value=backend):
            code, out, _ = run_cli("active-window")
        self.assertEqual(code, 0)
        answer = json.loads(out)
        self.assertEqual(set(answer), {"result", "address", "appClass", "initialClass", "terminal"})
        self.assertEqual(answer["appClass"], "foot")

    def test_no_active_window_is_a_one(self) -> None:
        backend = FakeBackend()
        backend.target = None
        with patch("omaplain_lib.cli.ClipboardBackend", return_value=backend):
            code, out, _ = run_cli("active-window")
        self.assertEqual((code, json.loads(out)), (1, {"result": "unavailable"}))

    def test_open_windows_answers_only_classes(self) -> None:
        backend = FakeBackend()
        backend.open_windows = lambda: ["foot", "org.mozilla.firefox"]  # type: ignore[method-assign]
        with patch("omaplain_lib.cli.ClipboardBackend", return_value=backend):
            code, out, _ = run_cli("open-windows")
        self.assertEqual(code, 0)
        self.assertEqual(json.loads(out), {"result": "ok", "classes": ["foot", "org.mozilla.firefox"]})


class TransformCommandTests(unittest.TestCase):
    """Los tres códigos de salida que documenta el SPEC: 0, 10 y 20."""

    def test_a_rewrite_exits_zero_and_prints_the_clean_text(self) -> None:
        code, out, _ = run_cli("transform", stdin=b"https://example.com/?utm_source=x&a=1")
        self.assertEqual(code, 0)
        self.assertEqual(out, "https://example.com/?a=1")

    def test_nothing_to_do_exits_ten_with_the_text_intact(self) -> None:
        code, out, _ = run_cli("transform", stdin=b"ya limpio")
        self.assertEqual((code, out), (10, "ya limpio"))

    def test_a_bypass_exits_twenty_and_names_the_reason_on_stderr(self) -> None:
        code, out, err = run_cli("transform", stdin=b"a\x00b")
        self.assertEqual((code, out), (20, ""))
        self.assertEqual(err.strip(), b"nul")

    def test_too_large_is_a_bypass_that_never_reads_the_rest(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            config = Path(temporary) / "config.json"
            config.write_text(json.dumps({"maxBytes": 1024}), encoding="utf-8")
            code, out, _ = run_cli("transform", "--config", str(config), stdin=b"x" * 4096)
        self.assertEqual(code, 20)
        self.assertEqual(json.loads(out), {"result": "bypassed", "reason": "too_large"})

    def test_the_config_governs_which_rules_run(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            config = Path(temporary) / "config.json"
            config.write_text(json.dumps({"normalizeQuotes": True}), encoding="utf-8")
            code, out, _ = run_cli("transform", "--config", str(config), stdin="“hola”".encode("utf-8"))
        self.assertEqual((code, out), (0, '"hola"'))


class WriteConfigTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.path = Path(self.temporary.name) / "config.json"

    def test_a_valid_snapshot_is_written_private_and_complete(self) -> None:
        code, out, _ = run_cli(
            "write-config", "--path", str(self.path),
            "--json", json.dumps({"automatic": False, "blockedApps": ["foot"]}),
        )
        self.assertEqual((code, json.loads(out)), (0, {"result": "ok", "warnings": []}))
        self.assertEqual(self.path.stat().st_mode & 0o777, 0o600)
        written = json.loads(self.path.read_text(encoding="utf-8"))
        self.assertFalse(written["automatic"])
        self.assertEqual(written["blockedApps"], ["foot"])
        # Y el resto viene completo, no sólo lo que se pidió.
        self.assertIn("maxBytes", written)

    def test_a_bad_type_is_a_warning_and_the_default_survives(self) -> None:
        code, out, _ = run_cli(
            "write-config", "--path", str(self.path), "--json", json.dumps({"automatic": "sí"}),
        )
        self.assertEqual(code, 0)
        self.assertEqual(json.loads(out)["warnings"], ["automatic"])
        self.assertTrue(json.loads(self.path.read_text(encoding="utf-8"))["automatic"])

    def test_broken_json_is_refused_without_writing(self) -> None:
        code, out, _ = run_cli("write-config", "--path", str(self.path), "--json", "{no")
        self.assertEqual((code, json.loads(out)["reason"]), (1, "invalid_json"))
        self.assertFalse(self.path.exists())


class SocketCommandTests(unittest.TestCase):
    """Los subcomandos que hablan con el demonio, sin demonio delante."""

    def test_every_socket_command_survives_a_dead_daemon(self) -> None:
        missing = "/nonexistent/omaplain.sock"
        for argv, expected in (
            (["control", "--socket", missing, "status"], 1),
            (["peek", "--socket", missing], 1),
            (["emit-event", "--socket", missing], 0),
        ):
            with self.subTest(command=argv[0]):
                code, out, _ = run_cli(*argv)
                self.assertEqual(code, expected)
                if argv[0] != "emit-event":
                    self.assertEqual(json.loads(out)["reason"], "service_unavailable")

    def test_emit_event_forwards_the_clipboard_state_and_nothing_else(self) -> None:
        seen: list[dict] = []

        def fake(path: str, request: dict, timeout: float = 1.5) -> dict:
            seen.append(request)
            return {"result": "ok"}
        with patch("omaplain_lib.cli.socket_request", side_effect=fake), \
                patch.dict(os.environ, {"CLIPBOARD_STATE": "sensitive"}):
            code, _, _ = run_cli("emit-event", "--socket", "/x")
        self.assertEqual(code, 0)
        self.assertEqual(seen, [{"kind": "event", "state": "sensitive"}])

    def test_a_missing_clipboard_state_defaults_to_data(self) -> None:
        seen: list[dict] = []
        with patch("omaplain_lib.cli.socket_request", side_effect=lambda p, r, timeout=1.5: seen.append(r) or {}), \
                patch.dict(os.environ, {}, clear=True):
            run_cli("emit-event", "--socket", "/x")
        self.assertEqual(seen[0]["state"], "data")


class EndToEndTests(unittest.TestCase):
    """El ejecutable de verdad contra un demonio de verdad.

    Es la secuencia que hace el shell: comprobar dependencias, escribir la
    configuración, arrancar el demonio, avisarle de un evento y preguntarle
    por el portapapeles. Todo por procesos separados, como en producción.
    """

    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.base = Path(self.temporary.name)
        self.environment = dict(os.environ, PYTHONPATH=str(REPO / "helper"))

    def helper(self, *argv: str, state: str | None = None) -> subprocess.CompletedProcess[str]:
        environment = dict(self.environment)
        if state is not None:
            environment["CLIPBOARD_STATE"] = state
        return subprocess.run(
            [str(EXECUTABLE), *argv], capture_output=True, text=True,
            timeout=30, env=environment, check=False,
        )

    def test_the_executable_is_runnable_and_reports_its_version(self) -> None:
        self.assertTrue(os.access(EXECUTABLE, os.X_OK), "el helper perdió el bit de ejecución")
        result = self.helper("--version")
        self.assertEqual(result.returncode, 0)
        self.assertIn(__version__, result.stdout)

    def test_the_whole_startup_sequence_the_shell_performs(self) -> None:
        # 1. Dependencias. En un contenedor sin Wayland faltarán, y eso es
        #    una respuesta válida: lo que se comprueba es la forma.
        dependencies = json.loads(self.helper("check-dependencies").stdout)
        self.assertEqual(set(dependencies), {"ok", "missing", "version"})

        # 2. La configuración de sesión, escrita por el servicio.
        config = self.base / "config.json"
        written = self.helper(
            "write-config", "--path", str(config), "--json", json.dumps({"removeTracking": True}),
        )
        self.assertEqual(written.returncode, 0)
        self.assertEqual(config.stat().st_mode & 0o777, 0o600)

        # 3. El demonio, con un backend de mentira porque aquí no hay
        #    Wayland; el resto —socket, hilos, protocolo— es el de verdad.
        backend = FakeBackend()
        backend.payload = f"https://ejemplo.com/?utm_source={MARK}&keep=1".encode("utf-8")
        with RunningDaemon(self.base, backend) as running:
            socket_path = str(running.socket)

            # 4. El aviso de una copia, que es lo que lanza `wl-paste`.
            event = self.helper("emit-event", "--socket", socket_path, state="data")
            self.assertEqual(event.returncode, 0)
            deadline = time.monotonic() + 5
            while time.monotonic() < deadline and not backend.writes:
                time.sleep(0.02)
            self.assertEqual(backend.writes, [b"https://ejemplo.com/?keep=1"])

            # 5. El estado, que el panel lee una vez por segundo.
            status = json.loads(self.helper("control", "--socket", socket_path, "status").stdout)
            self.assertEqual(status["lastResult"], "cleaned")
            self.assertEqual(status["session"]["cleaned"], 1)

            # 6. Y el vistazo, la única respuesta con contenido dentro.
            peek = json.loads(self.helper("peek", "--socket", socket_path).stdout)
            self.assertEqual(peek["result"], "ok")
            self.assertEqual(peek["original"], "https://ejemplo.com/?keep=1")

            # 7. Una orden desconocida no la deja pasar ni el parser.
            self.assertNotEqual(self.helper("control", "--socket", socket_path, "explode").returncode, 0)

        # El socket se recoge al parar, y en el directorio no queda nada
        # con contenido dentro.
        self.assertFalse(running.socket.exists())
        for path in sorted(self.base.rglob("*")):
            if path.is_file():
                with self.subTest(file=path.name):
                    self.assertNotIn(MARK, path.read_text(encoding="utf-8", errors="replace"))

    def test_a_sensitive_copy_is_bypassed_end_to_end_without_being_read(self) -> None:
        backend = FakeBackend()
        backend.payload = MARK.encode("utf-8")
        with RunningDaemon(self.base, backend) as running:
            event = self.helper("emit-event", "--socket", str(running.socket), state="sensitive")
            self.assertEqual(event.returncode, 0)
            time.sleep(0.3)
            # Ni se listaron los tipos: la negativa llega antes de mirar.
            # Se comprueba aquí, antes de preguntar nada más, porque un
            # vistazo posterior sí lista —es otra pregunta.
            self.assertEqual(backend.list_calls, 0)
            status = json.loads(self.helper("control", "--socket", str(running.socket), "status").stdout)
        self.assertEqual(status["lastReason"], "sensitive")
        self.assertEqual(backend.writes, [])
        self.assertNotIn(MARK, json.dumps(status))

    def test_the_panel_cannot_peek_at_a_marked_secret_either(self) -> None:
        """`peek` no recibe `CLIPBOARD_STATE`, y aun así se planta.

        El panel pregunta siempre con estado `data`: no hay evento de
        Wayland detrás de su pregunta. Lo que le salva es que
        `wl-clipboard` sólo declara `sensitive` cuando la oferta trae el
        tipo del gestor de contraseñas, y ese tipo sí lo ve el listado.
        """
        backend = FakeBackend()
        backend.types = ["x-kde-passwordManagerHint", "text/plain"]
        backend.payload = MARK.encode("utf-8")
        with RunningDaemon(self.base, backend) as running:
            answer = json.loads(self.helper("peek", "--socket", str(running.socket)).stdout)
        self.assertEqual(answer["reason"], "sensitive")
        self.assertFalse(answer["eligible"])
        self.assertNotIn("original", answer)
        self.assertNotIn(MARK, json.dumps(answer))

    def test_two_helpers_talking_to_one_daemon_at_once(self) -> None:
        # El caso real: `wl-paste` avisa mientras el panel pregunta.
        backend = FakeBackend()
        with RunningDaemon(self.base, backend) as running:
            socket_path = str(running.socket)
            results: list[int] = []
            lock = threading.Lock()

            def call(*argv: str) -> None:
                code = self.helper(*argv).returncode
                with lock:
                    results.append(code)

            threads = [
                threading.Thread(target=call, args=("peek", "--socket", socket_path)),
                threading.Thread(target=call, args=("emit-event", "--socket", socket_path)),
                threading.Thread(target=call, args=("control", "--socket", socket_path, "status")),
                threading.Thread(target=call, args=("control", "--socket", socket_path, "ping")),
            ]
            for thread in threads:
                thread.start()
            for thread in threads:
                thread.join(timeout=30)
            self.assertEqual(results, [0, 0, 0, 0])
            self.assertTrue(running.drained(), "quedaron hilos sin recoger")


if __name__ == "__main__":
    unittest.main()
