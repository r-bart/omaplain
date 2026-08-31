from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import Mock, patch

from omaplain_lib.clipboard import WindowTarget
from omaplain_lib.config import write_config
from omaplain_lib.daemon import OmaPlainDaemon


class FakeBackend:
    def __init__(self) -> None:
        self.types = ["text/plain"]
        self.payload = b"https://example.com/?utm_source=test&a=1"
        self.writes: list[bytes] = []
        self.list_calls = 0
        self.current = True
        self.target = WindowTarget("0x123", "foot", "foot", True)
        self.paste_targets: list[WindowTarget] = []

    def list_types(self) -> list[str]:
        self.list_calls += 1
        return list(self.types)

    def read(self, mime: str, maximum: int) -> bytes:
        if len(self.payload) > maximum:
            raise AssertionError("fixture exceeds maximum")
        return self.payload

    def unchanged(self, mime: str, maximum: int, expected: bytes, expected_types: list[str]) -> bool:
        return self.current and expected == self.payload and expected_types == self.types

    def write(self, payload: bytes) -> None:
        self.writes.append(payload)
        self.payload = payload
        self.types = ["text/plain;charset=utf-8"]

    def wait_for_text(self, expected: bytes, maximum_wait: float = 0.25) -> bool:
        return self.payload == expected

    def active_window(self) -> WindowTarget | None:
        return self.target

    def send_paste(self, target: WindowTarget, release_delay: float = 0.12) -> None:
        self.paste_targets.append(target)


class DaemonTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        base = Path(self.temporary.name)
        self.config = base / "config.json"
        write_config(self.config, {})
        self.daemon = OmaPlainDaemon(
            "/tmp/omaplain", str(self.config), str(base / "status.json"), str(base / "omaplain.sock")
        )
        self.backend = FakeBackend()
        self.daemon.backend = self.backend

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def test_clean_now_rewrites_tracking_url(self) -> None:
        result = self.daemon.clean_now()
        self.assertEqual(result["result"], "cleaned")
        self.assertEqual(self.backend.writes, [b"https://example.com/?a=1"])

    def test_rich_text_rewrites_even_when_plain_text_is_identical(self) -> None:
        self.backend.types = ["text/plain", "text/html"]
        self.backend.payload = b"hello"
        result = self.daemon.clean_now()
        self.assertEqual(result["result"], "cleaned")
        self.assertEqual(result["reason"], "rich_text")

    def test_an_empty_clipboard_is_a_state_and_not_an_error(self) -> None:
        # `wl-paste --list-types` sale con error cuando no hay nada copiado.
        # Tratarlo como fallo convertia el portapapeles vacio —el que tienes
        # al arrancar la sesion— en una incidencia contada.
        self.backend.types = []
        generation = self.daemon._next_generation()
        result = self.daemon.automatic_event("data", generation)
        self.assertEqual(result["result"], "bypassed")
        self.assertEqual(result["reason"], "empty")
        self.assertEqual(self.backend.writes, [])

    def test_sensitive_event_never_lists_or_reads_types(self) -> None:
        generation = self.daemon._next_generation()
        result = self.daemon.automatic_event("sensitive", generation)
        self.assertEqual(result["reason"], "sensitive")
        self.assertEqual(self.backend.list_calls, 0)
        self.assertEqual(self.backend.writes, [])

    def test_skip_next_is_not_consumed_by_ineligible_content(self) -> None:
        self.daemon.skip_next()
        self.backend.types = ["image/png"]
        generation = self.daemon._next_generation()
        self.daemon.automatic_event("data", generation)
        self.assertTrue(self.daemon.status.snapshot()["skipNext"])

        self.backend.types = ["text/plain"]
        generation = self.daemon._next_generation()
        result = self.daemon.automatic_event("data", generation)
        self.assertEqual(result["reason"], "skip_next")
        self.assertFalse(self.daemon.status.snapshot()["skipNext"])

    def test_compare_before_write_rejects_stale_clipboard(self) -> None:
        self.backend.current = False
        result = self.daemon.clean_now()
        self.assertEqual(result["reason"], "clipboard_changed")
        self.assertEqual(self.backend.writes, [])

    def test_own_rewrite_is_consumed_once(self) -> None:
        first = self.daemon.clean_now()
        self.assertEqual(first["result"], "cleaned")
        generation = self.daemon._next_generation()
        second = self.daemon.automatic_event("data", generation)
        self.assertEqual(second["result"], "self")
        self.assertEqual(len(self.backend.writes), 1)

    def test_paste_clean_captures_target_and_sends_terminal_paste(self) -> None:
        result = self.daemon.paste_clean()
        self.assertTrue(result["pasted"])
        self.assertEqual(self.backend.paste_targets, [self.backend.target])

    def test_target_exclusion_pastes_original_without_rewrite(self) -> None:
        write_config(self.config, {"targetExclusions": ["foot"]})
        self.daemon.reload_config()
        result = self.daemon.paste_clean()
        self.assertEqual(result["reason"], "target_excluded")
        self.assertTrue(result["pasted"])
        self.assertEqual(self.backend.writes, [])

    def test_source_exclusion_blocks_only_automatic_cleaning(self) -> None:
        write_config(self.config, {"sourceExclusions": ["foot"]})
        self.daemon.reload_config()
        generation = self.daemon._next_generation()
        result = self.daemon.automatic_event("data", generation, self.backend.target)
        self.assertEqual(result["reason"], "source_excluded")
        self.assertEqual(self.backend.writes, [])

        manual = self.daemon.clean_now()
        self.assertEqual(manual["result"], "cleaned")

    def test_skip_next_expires_after_sixty_seconds(self) -> None:
        with patch("omaplain_lib.daemon.time.monotonic", return_value=100.0):
            self.daemon.skip_next()
        with patch("omaplain_lib.daemon.time.monotonic", return_value=160.01):
            status = self.daemon.command("status")
        self.assertFalse(status["skipNext"])

    def test_status_never_contains_clipboard_content(self) -> None:
        original = self.backend.payload.decode()
        self.daemon.clean_now()
        raw = Path(self.daemon.status_path).read_text(encoding="utf-8")
        self.assertNotIn(original, raw)
        parsed = json.loads(raw)
        self.assertIn(parsed["lastResult"], {"cleaned", "unchanged", "bypassed", "error"})

    def test_one_thousand_events_produce_at_most_one_write(self) -> None:
        for _ in range(1_000):
            generation = self.daemon._next_generation()
            self.daemon.automatic_event("data", generation)
        self.assertLessEqual(len(self.backend.writes), 1)

    def test_watcher_dies_if_daemon_is_killed(self) -> None:
        process = Mock()
        with patch("omaplain_lib.daemon.subprocess.Popen", return_value=process) as popen:
            self.daemon._start_watcher()
        command = popen.call_args.args[0]
        self.assertEqual(command[:5], ["setpriv", "--pdeathsig", "TERM", "--", "wl-paste"])
        self.assertIs(self.daemon.watcher, process)


if __name__ == "__main__":
    unittest.main()
