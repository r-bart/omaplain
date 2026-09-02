"""La frontera con Wayland y Hyprland, sin Wayland ni Hyprland.

`clipboard.py` no tenía ni un test: todo lo que hace es lanzar procesos, y
eso se prueba sustituyendo el proceso. Para la lectura con plazo se usa un
proceso de verdad —`python3` haciendo de `wl-paste`— porque el plazo es
justo lo que un doble no ejercita.
"""

from __future__ import annotations

import json
import subprocess
import sys
import unittest
from unittest.mock import patch

from omaplain_lib.clipboard import ClipboardBackend, ClipboardError, ClipboardTooLarge, WindowTarget


class Completed:
    def __init__(self, returncode: int = 0, stdout: bytes = b"") -> None:
        self.returncode = returncode
        self.stdout = stdout


def fake_wl_paste(script: str):
    """Sustituye `wl-paste` por un `python3 -c` que hace lo que diga `script`."""

    real_popen = subprocess.Popen

    def popen(argv, **kwargs):
        assert argv[0] == "wl-paste", argv
        return real_popen([sys.executable, "-c", script], **kwargs)
    return patch("omaplain_lib.clipboard.subprocess.Popen", side_effect=popen)


class ListTypesTests(unittest.TestCase):
    def test_a_clean_exit_lists_one_type_per_line(self) -> None:
        with patch("omaplain_lib.clipboard.subprocess.run", return_value=Completed(0, b"text/plain\n text/html \n\n")):
            self.assertEqual(ClipboardBackend().list_types(), ["text/plain", "text/html"])

    def test_a_failed_exit_is_an_empty_clipboard(self) -> None:
        # `wl-paste --list-types` sale con error cuando no hay nada copiado.
        with patch("omaplain_lib.clipboard.subprocess.run", return_value=Completed(1, b"")):
            self.assertEqual(ClipboardBackend().list_types(), [])

    def test_a_missing_binary_or_a_timeout_is_a_real_failure(self) -> None:
        for error in (OSError("no such file"), subprocess.TimeoutExpired("wl-paste", 1.0)):
            with self.subTest(error=type(error).__name__):
                with patch("omaplain_lib.clipboard.subprocess.run", side_effect=error):
                    with self.assertRaises(ClipboardError):
                        ClipboardBackend().list_types()


class ReadTests(unittest.TestCase):
    def test_reads_what_the_source_serves(self) -> None:
        with fake_wl_paste("import sys; sys.stdout.buffer.write(b'hola'); sys.stdout.flush()"):
            self.assertEqual(ClipboardBackend().read("text/plain", 1024), b"hola")

    def test_stops_reading_past_the_maximum(self) -> None:
        with fake_wl_paste("import sys; sys.stdout.buffer.write(b'x' * 100000); sys.stdout.flush()"):
            with self.assertRaises(ClipboardTooLarge):
                ClipboardBackend().read("text/plain", 10)

    def test_a_source_that_never_finishes_hits_the_deadline(self) -> None:
        # La aplicación de origen escribe la mitad y se queda colgada. Sin
        # plazo esto bloqueaba el demonio para siempre con el cerrojo cogido.
        script = "import sys, time; sys.stdout.buffer.write(b'medio'); sys.stdout.flush(); time.sleep(30)"
        with fake_wl_paste(script):
            backend = ClipboardBackend(read_timeout=0.3)
            with self.assertRaisesRegex(ClipboardError, "timeout"):
                backend.read("text/plain", 1024)

    def test_a_failed_exit_after_output_is_a_read_failure(self) -> None:
        with fake_wl_paste("import sys; sys.stdout.buffer.write(b'x'); sys.stdout.flush(); sys.exit(1)"):
            with self.assertRaisesRegex(ClipboardError, "read_failed"):
                ClipboardBackend().read("text/plain", 1024)

    def test_a_missing_binary_is_reported_as_such(self) -> None:
        with patch("omaplain_lib.clipboard.subprocess.Popen", side_effect=OSError("no wl-paste")):
            with self.assertRaisesRegex(ClipboardError, "wl_paste_unavailable"):
                ClipboardBackend().read("text/plain", 1024)


class CompareAndWriteTests(unittest.TestCase):
    def test_unchanged_requires_the_same_types_and_the_same_bytes(self) -> None:
        backend = ClipboardBackend()
        with patch.object(backend, "list_types", return_value=["text/plain"]), \
                patch.object(backend, "read", return_value=b"abc"):
            self.assertTrue(backend.unchanged("text/plain", 100, b"abc", ["text/plain"]))
            self.assertFalse(backend.unchanged("text/plain", 100, b"abd", ["text/plain"]))
            self.assertFalse(backend.unchanged("text/plain", 100, b"abc", ["text/plain", "text/html"]))
        with patch.object(backend, "list_types", side_effect=ClipboardError("x")):
            self.assertFalse(backend.unchanged("text/plain", 100, b"abc", ["text/plain"]))

    def test_write_uses_a_single_utf8_plain_type(self) -> None:
        with patch("omaplain_lib.clipboard.subprocess.run", return_value=Completed(0)) as run:
            ClipboardBackend().write(b"hola")
        argv = run.call_args.args[0]
        self.assertEqual(argv, ["wl-copy", "--type", "text/plain;charset=utf-8"])
        self.assertEqual(run.call_args.kwargs["input"], b"hola")

    def test_write_failures_are_one_error(self) -> None:
        for outcome in (Completed(1), OSError("x"), subprocess.TimeoutExpired("wl-copy", 1.0)):
            with self.subTest(outcome=type(outcome).__name__):
                kwargs = {"side_effect": outcome} if isinstance(outcome, Exception) else {"return_value": outcome}
                with patch("omaplain_lib.clipboard.subprocess.run", **kwargs):
                    with self.assertRaisesRegex(ClipboardError, "write_failed"):
                        ClipboardBackend().write(b"x")

    def test_wait_for_text_returns_when_the_hash_matches(self) -> None:
        backend = ClipboardBackend()
        with patch.object(backend, "list_types", return_value=["text/plain;charset=utf-8"]), \
                patch.object(backend, "read", return_value=b"listo"):
            self.assertTrue(backend.wait_for_text(b"listo", maximum_wait=0.2))
            self.assertFalse(backend.wait_for_text(b"otro", maximum_wait=0.05))


class HyprlandTests(unittest.TestCase):
    def test_active_window_keeps_only_class_address_and_terminal_tag(self) -> None:
        payload = json.dumps({
            "address": "0x55d0c0ffee",
            "class": "foot",
            "initialClass": "footclient",
            "title": "secreto.txt — editor",
            "tags": ["terminal*", "otra"],
        }).encode("utf-8")
        with patch("omaplain_lib.clipboard.subprocess.run", return_value=Completed(0, payload)):
            target = ClipboardBackend().active_window()
        self.assertEqual(target, WindowTarget("0x55d0c0ffee", "foot", "footclient", True))
        self.assertFalse(hasattr(target, "title"))

    def test_active_window_rejects_anything_that_is_not_a_window(self) -> None:
        for raw in (b"{}", b'{"address": "not-hex"}', b"Invalid", b"[]"):
            with self.subTest(raw=raw):
                with patch("omaplain_lib.clipboard.subprocess.run", return_value=Completed(0, raw)):
                    self.assertIsNone(ClipboardBackend().active_window())

    def test_open_windows_lists_classes_sorted_and_without_titles(self) -> None:
        clients = [
            {"class": "org.mozilla.firefox", "title": "documento privado"},
            {"class": "foot", "title": "x"},
            {"class": "foot"},
            {"class": ""},
            {"class": "con\nsalto"},
            "no es un objeto",
        ]
        with patch("omaplain_lib.clipboard.subprocess.run", return_value=Completed(0, json.dumps(clients).encode())):
            classes = ClipboardBackend().open_windows()
        self.assertEqual(classes, ["foot", "org.mozilla.firefox"])

    def test_paste_sends_shift_insert_to_terminals_and_ctrl_v_elsewhere(self) -> None:
        cases = {
            WindowTarget("0xabc", "foot", "foot", True): ('mods = "SHIFT"', 'key = "INSERT"'),
            WindowTarget("0xabc", "firefox", "firefox", False): ('mods = "CTRL"', 'key = "V"'),
        }
        for target, expected in cases.items():
            with self.subTest(terminal=target.terminal):
                with patch("omaplain_lib.clipboard.subprocess.run", return_value=Completed(0, b"ok")) as run, \
                        patch("omaplain_lib.clipboard.time.sleep"):
                    ClipboardBackend().send_paste(target)
                argv = run.call_args.args[0]
                self.assertEqual(argv[:2], ["hyprctl", "eval"])
                for fragment in expected:
                    self.assertIn(fragment, argv[2])
                self.assertIn('window = "address:0xabc"', argv[2])

    def test_paste_refuses_an_address_that_could_carry_code(self) -> None:
        with patch("omaplain_lib.clipboard.subprocess.run") as run:
            with self.assertRaisesRegex(ClipboardError, "invalid_target"):
                ClipboardBackend().send_paste(WindowTarget('0x1" }) os.exit(', "x", "x", False))
        run.assert_not_called()

    def test_paste_failures_are_reported(self) -> None:
        for outcome in (Completed(1, b"ok"), Completed(0, b"error"), OSError("x")):
            with self.subTest(outcome=type(outcome).__name__):
                kwargs = {"side_effect": outcome} if isinstance(outcome, Exception) else {"return_value": outcome}
                with patch("omaplain_lib.clipboard.subprocess.run", **kwargs), \
                        patch("omaplain_lib.clipboard.time.sleep"):
                    with self.assertRaisesRegex(ClipboardError, "paste_failed"):
                        ClipboardBackend().send_paste(WindowTarget("0xabc", "x", "x", False))


if __name__ == "__main__":
    unittest.main()
