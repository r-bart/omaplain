"""El demonio corriendo de verdad: socket, hilos, generaciones y supervisor.

`test_daemon.py` llama a los métodos uno a uno. Aquí se arranca `run()`
sobre un socket temporal y se habla con él como lo hacen `emit-event`,
`peek` y `control`, que es la única forma de probar lo que pasa entre
hilos: una limpieza que otra adelanta, un `tick` que nadie llama, una
petición malformada que no debe tumbar nada.
"""

from __future__ import annotations

import json
import socket
import tempfile
import threading
import time
import unittest
from pathlib import Path
from unittest.mock import patch

from omaplain_lib.clipboard import ClipboardError, WindowTarget
from omaplain_lib.config import write_config
from omaplain_lib.daemon import RESPONSE_LIMIT, OmaPlainDaemon, socket_request

from test_daemon import FakeBackend


class GatedBackend(FakeBackend):
    """Un backend cuya lectura se puede retener desde el test."""

    def __init__(self) -> None:
        super().__init__()
        self.gate = threading.Event()
        self.gate.set()
        self.reading = threading.Event()

    def read(self, mime: str, maximum: int) -> bytes:
        self.reading.set()
        self.gate.wait(timeout=5)
        return super().read(mime, maximum)


class RunningDaemon:
    """Arranca `run()` en un hilo y lo para al salir del `with`."""

    def __init__(self, base: Path, backend: FakeBackend, config: dict | None = None):
        self.config = base / "config.json"
        write_config(self.config, config or {})
        self.socket = base / "run" / "omaplain.sock"
        self.daemon = OmaPlainDaemon(
            "/tmp/omaplain", str(self.config), str(base / "run" / "status.json"), str(self.socket)
        )
        self.daemon.backend = backend
        self.thread = threading.Thread(target=self._run, name="daemon-under-test", daemon=True)
        self.exit_code: int | None = None

    def _run(self) -> None:
        # `signal.signal` sólo vale en el hilo principal, y aquí el demonio
        # corre en uno secundario. El watcher tampoco: no hay Wayland.
        with patch("omaplain_lib.daemon.signal.signal"), \
                patch.object(self.daemon, "_start_watcher", lambda: None):
            self.exit_code = self.daemon.run()

    def __enter__(self) -> "RunningDaemon":
        self.thread.start()
        deadline = time.monotonic() + 5
        while time.monotonic() < deadline:
            if self.socket.exists() and self.request({"kind": "command", "name": "ping"}).get("result") == "ok":
                return self
            time.sleep(0.01)
        raise AssertionError("el demonio no llegó a escuchar")

    def __exit__(self, *_: object) -> None:
        self.daemon.stop_event.set()
        self.thread.join(timeout=5)

    def request(self, request: dict, timeout: float = 5.0) -> dict:
        return socket_request(str(self.socket), request, timeout=timeout)

    def drained(self, timeout: float = 2.0) -> bool:
        """Los hilos de petición se recogen justo después de contestar.

        El cliente ve el cierre de la conexión un instante antes de que el
        hilo se quite de `workers`, así que se espera un poco en vez de
        mirar una sola vez.
        """
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            if not self.daemon.workers:
                return True
            time.sleep(0.01)
        return not self.daemon.workers

    def raw(self, payload: bytes, timeout: float = 5.0) -> bytes:
        client = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        client.settimeout(timeout)
        try:
            client.connect(str(self.socket))
            client.sendall(payload)
            client.shutdown(socket.SHUT_WR)
            chunks = b""
            while True:
                part = client.recv(4096)
                if not part:
                    return chunks
                chunks += part
        finally:
            client.close()


class SocketTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.base = Path(self.temporary.name)
        self.backend = GatedBackend()

    def test_ping_status_and_peek_answer_over_the_socket(self) -> None:
        with RunningDaemon(self.base, self.backend) as running:
            self.assertEqual(running.request({"kind": "command", "name": "ping"}), {"result": "ok"})
            status = running.request({"kind": "command", "name": "status"})
            self.assertEqual(status["version"], 1)
            self.assertIn("session", status)
            peek = running.request({"kind": "command", "name": "peek"})
            self.assertTrue(peek["eligible"])
            self.assertEqual(peek["cleaned"], "https://example.com/?a=1")

    def test_the_socket_and_its_directory_are_private(self) -> None:
        with RunningDaemon(self.base, self.backend) as running:
            self.assertEqual(running.socket.parent.stat().st_mode & 0o777, 0o700)
            self.assertEqual(running.socket.stat().st_mode & 0o777, 0o600)
        self.assertFalse(running.socket.exists(), "el socket no se recogió al parar")
        self.assertEqual(running.exit_code, 0)
        self.assertEqual(running.daemon.status.snapshot()["watcher"], "stopped")

    def test_an_event_cleans_and_a_self_event_is_swallowed(self) -> None:
        with RunningDaemon(self.base, self.backend) as running:
            first = running.request({"kind": "event", "state": "data"})
            self.assertEqual(first["result"], "cleaned")
            self.assertEqual(self.backend.writes, [b"https://example.com/?a=1"])
            second = running.request({"kind": "event", "state": "data"})
            self.assertEqual(second["result"], "self")
            session = running.request({"kind": "command", "name": "status"})["session"]
            self.assertEqual(session["cleaned"], 1)

    def test_malformed_requests_answer_and_never_kill_the_loop(self) -> None:
        with RunningDaemon(self.base, self.backend) as running:
            cases = {
                b"[1, 2, 3]\n": "bad_request",
                b'{"kind": "nothing"}\n': "bad_request",
                b'{"kind": "command", "name": "explode"}\n': "unknown_command",
                b"\n": None,
                b"{" + b"x" * 9000 + b"}\n": "request_too_large",
            }
            for payload, reason in cases.items():
                with self.subTest(payload=payload[:20]):
                    answer = running.raw(payload)
                    if reason is None:
                        # JSON inválido: se cierra sin respuesta, y ya está.
                        self.assertEqual(answer, b"")
                    else:
                        self.assertEqual(json.loads(answer)["reason"], reason)
            # Y el demonio sigue vivo y entero.
            self.assertEqual(running.request({"kind": "command", "name": "ping"}), {"result": "ok"})
            self.assertTrue(running.drained(), "quedaron hilos sin recoger")

    def test_a_newer_event_supersedes_the_one_still_reading(self) -> None:
        # El evento 1 se queda leyendo; mientras, llega el 2 y avanza la
        # generación. Al soltar la lectura, el 1 ya no es el actual y no
        # escribe; el 2 hace la limpieza. Es el camino `superseded`, que
        # sin dos hilos no se puede recorrer.
        self.backend.gate.clear()
        with RunningDaemon(self.base, self.backend) as running:
            answers: dict[str, dict] = {}

            def fire(name: str) -> None:
                answers[name] = running.request({"kind": "event", "state": "data"}, timeout=10)

            first = threading.Thread(target=fire, args=("first",))
            first.start()
            self.assertTrue(self.backend.reading.wait(timeout=5), "el primer evento no llegó a leer")
            second = threading.Thread(target=fire, args=("second",))
            second.start()
            deadline = time.monotonic() + 5
            while running.daemon.generation < 2 and time.monotonic() < deadline:
                time.sleep(0.005)
            self.assertGreaterEqual(running.daemon.generation, 2)
            self.backend.gate.set()
            first.join(timeout=10)
            second.join(timeout=10)

        self.assertEqual(answers["first"]["reason"], "superseded")
        self.assertEqual(answers["second"]["result"], "cleaned")
        self.assertEqual(len(self.backend.writes), 1)

    def test_the_idle_loop_ticks_without_any_client(self) -> None:
        # La caducidad de `skipNext` depende de que alguien despierte al
        # demonio con el escritorio quieto. Es el bucle de `accept`, cada
        # medio segundo de silencio.
        with RunningDaemon(self.base, self.backend) as running:
            with patch.object(running.daemon, "tick", wraps=running.daemon.tick) as tick:
                deadline = time.monotonic() + 3
                while not tick.called and time.monotonic() < deadline:
                    time.sleep(0.05)
                self.assertTrue(tick.called, "el bucle no llamó a tick en tres segundos")

    def test_a_paused_event_still_leaves_its_mark_for_the_panel(self) -> None:
        with RunningDaemon(self.base, self.backend, {"automatic": False}) as running:
            before = running.request({"kind": "command", "name": "status"})
            self.assertEqual(before["lastEventAt"], "")
            answer = running.request({"kind": "event", "state": "data"})
            self.assertEqual(answer["result"], "paused")
            after = running.request({"kind": "command", "name": "status"})
            self.assertNotEqual(after["lastEventAt"], "")
            # Y en disco, que es lo que el panel lee.
            on_disk = json.loads(running.daemon.status_path.read_text(encoding="utf-8"))
            self.assertEqual(on_disk["lastEventAt"], after["lastEventAt"])

    def test_peek_responses_with_emoji_fit_the_client_limit(self) -> None:
        # Con `ensure_ascii` cada emoji ocupaba doce bytes y un portapapeles
        # de cuatro mil superaba el tope de respuesta del cliente.
        self.backend.payload = ("😀" * OmaPlainDaemon.PEEK_LIMIT).encode("utf-8")
        with RunningDaemon(self.base, self.backend) as running:
            answer = running.request({"kind": "command", "name": "peek"})
        self.assertEqual(answer["result"], "ok", answer)
        self.assertEqual(len(answer["original"]), OmaPlainDaemon.PEEK_LIMIT)
        self.assertLess(len(json.dumps(answer, ensure_ascii=False).encode("utf-8")), RESPONSE_LIMIT)


class FakeWatcher:
    def __init__(self, alive: bool) -> None:
        self.alive = alive

    def poll(self) -> int | None:
        return None if self.alive else 1


class FakeStopEvent:
    """Un `stop_event` que cuenta las esperas y se rinde tras `budget`."""

    def __init__(self, budget: int) -> None:
        self.budget = budget
        self.waits: list[float] = []
        self.stopped = False

    def wait(self, timeout: float) -> bool:
        self.waits.append(timeout)
        if len(self.waits) >= self.budget:
            self.stopped = True
        return self.stopped

    def is_set(self) -> bool:
        return self.stopped

    def set(self) -> None:
        self.stopped = True


class WatcherSupervisionTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        base = Path(self.temporary.name)
        config = base / "config.json"
        write_config(config, {})
        self.daemon = OmaPlainDaemon(
            "/tmp/omaplain", str(config), str(base / "status.json"), str(base / "omaplain.sock")
        )
        self.daemon.backend = FakeBackend()
        self.spawned: list[FakeWatcher] = []

    def _start_with(self, outcomes: list[bool]) -> None:
        def start() -> None:
            alive = outcomes.pop(0) if outcomes else True
            watcher = FakeWatcher(alive)
            self.spawned.append(watcher)
            self.daemon.watcher = watcher
        self.daemon._start_watcher = start  # type: ignore[method-assign]

    def test_repeated_failures_climb_the_backoff_and_degrade(self) -> None:
        self.daemon.watcher = FakeWatcher(alive=False)
        self._start_with([False, False, False, False, False, False])
        stop = FakeStopEvent(budget=6)
        self.daemon.stop_event = stop  # type: ignore[assignment]
        with patch("omaplain_lib.daemon.time.monotonic", side_effect=[float(n) for n in range(100)]):
            self.daemon._supervise_watcher()
        self.assertEqual(stop.waits, [1, 2, 5, 10, 30, 30])
        self.assertEqual(self.daemon.status.snapshot()["watcher"], "degraded")

    def test_a_long_healthy_run_resets_the_backoff(self) -> None:
        # Muere una vez (1 s), corre sano más de un minuto, y vuelve a
        # morir: el siguiente reintento espera 1 s otra vez, no 2 s.
        self.daemon.watcher = FakeWatcher(alive=False)
        self._start_with([True, True])
        stop = FakeStopEvent(budget=99)
        self.daemon.stop_event = stop  # type: ignore[assignment]
        original_wait = stop.wait

        def wait(timeout: float) -> bool:
            original_wait(timeout)
            healthy_waits = stop.waits.count(0.5)
            # Tras dos vueltas sanas —la segunda ya más de un minuto
            # después de la primera— el watcher muere.
            if timeout == 0.5 and healthy_waits == 2:
                self.spawned[0].alive = False
            # Y en cuanto se ha visto el reintento siguiente, se para.
            if len(stop.waits) >= 4:
                stop.stopped = True
            return stop.stopped

        stop.wait = wait  # type: ignore[method-assign]
        # Reloj: muerto en 0 s; sano en 1 s; sano en 70 s; muerto en 71 s.
        clock = iter([0.0, 1.0, 70.0, 71.0])
        with patch("omaplain_lib.daemon.time.monotonic", side_effect=lambda: next(clock, 99.0)):
            self.daemon._supervise_watcher()
        self.assertEqual(stop.waits, [1, 0.5, 0.5, 1])


class LoopGuardAndPasteTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        base = Path(self.temporary.name)
        self.config = base / "config.json"
        write_config(self.config, {})
        self.daemon = OmaPlainDaemon(
            "/tmp/omaplain", str(self.config), str(base / "status.json"), str(base / "omaplain.sock")
        )
        self.backend = FakeBackend()
        self.daemon.backend = self.backend

    def _event(self) -> dict:
        return self.daemon.automatic_event("data", self.daemon._next_generation())

    def test_the_loop_guard_expires_after_five_seconds(self) -> None:
        with patch("omaplain_lib.daemon.time.monotonic", return_value=100.0):
            self.assertEqual(self.daemon.clean_now()["result"], "cleaned")
        with patch("omaplain_lib.daemon.time.monotonic", return_value=105.1):
            answer = self._event()
        # Ya no es «self»: es una copia igual, y como ya está limpia, queda.
        self.assertEqual(answer["result"], "unchanged")

    def test_a_different_payload_leaves_the_guard_armed(self) -> None:
        self.assertEqual(self.daemon.clean_now()["result"], "cleaned")
        armed = self.daemon.loop_guard
        self.backend.payload = b"otra cosa"
        self.backend.types = ["text/plain"]
        self.assertEqual(self._event()["result"], "unchanged")
        self.assertEqual(self.daemon.loop_guard, armed)

    def test_a_failed_write_disarms_the_guard(self) -> None:
        def broken(payload: bytes) -> None:
            raise ClipboardError("write_failed")
        self.backend.write = broken  # type: ignore[method-assign]
        answer = self.daemon.clean_now()
        self.assertEqual(answer, {"result": "error", "reason": "write_failed", "bytes": len(self.backend.payload)})
        self.assertIsNone(self.daemon.loop_guard)
        self.assertEqual(self.daemon.status.snapshot()["session"]["errors"], 1)

    def test_a_self_event_does_not_consume_a_pending_skip(self) -> None:
        self.assertEqual(self.daemon.clean_now()["result"], "cleaned")
        self.daemon.skip_next()
        self.assertEqual(self._event()["result"], "self")
        self.assertTrue(self.daemon.status.snapshot()["skipNext"])

    def test_manual_cleaning_and_oversize_copies_leave_the_skip_alone(self) -> None:
        self.daemon.skip_next()
        self.assertEqual(self.daemon.clean_now()["result"], "cleaned")
        self.assertTrue(self.daemon.status.snapshot()["skipNext"])

        self.backend.payload = b"x" * 2048
        self.daemon.config["maxBytes"] = 1024

        def too_big(mime: str, maximum: int) -> bytes:
            from omaplain_lib.clipboard import ClipboardTooLarge
            raise ClipboardTooLarge("too_large")
        self.backend.read = too_big  # type: ignore[method-assign]
        self.assertEqual(self._event()["reason"], "too_large")
        self.assertTrue(self.daemon.status.snapshot()["skipNext"])

    def test_paste_without_a_target_is_an_error_that_counts(self) -> None:
        self.backend.target = None
        answer = self.daemon.paste_clean()
        self.assertEqual(answer["reason"], "no_target")
        self.assertFalse(answer["pasted"])
        self.assertEqual(self.daemon.status.snapshot()["session"]["errors"], 1)

    def test_a_failed_paste_is_recorded_after_the_clean(self) -> None:
        def broken(target: WindowTarget, release_delay: float = 0.12) -> None:
            raise ClipboardError("paste_failed")
        self.backend.send_paste = broken  # type: ignore[method-assign]
        answer = self.daemon.paste_clean()
        self.assertEqual(answer["reason"], "paste_failed")
        self.assertFalse(answer["pasted"])
        session = self.daemon.status.snapshot()["session"]
        self.assertEqual((session["cleaned"], session["errors"]), (1, 1))

    def test_paste_waits_for_the_clean_text_before_sending_keys(self) -> None:
        seen: list[bytes] = []

        def wait_for_text(expected: bytes, maximum_wait: float = 0.25) -> bool:
            seen.append(expected)
            return True
        self.backend.wait_for_text = wait_for_text  # type: ignore[method-assign]
        self.assertTrue(self.daemon.paste_clean()["pasted"])
        self.assertEqual(seen, [b"https://example.com/?a=1"])

    def test_target_exclusion_matches_the_initial_class_and_counts(self) -> None:
        self.backend.target = WindowTarget("0xabc", "renamed", "foot", True)
        write_config(self.config, {"targetExclusions": ["foot"]})
        self.daemon.reload_config()
        answer = self.daemon.paste_clean()
        self.assertEqual(answer["reason"], "target_excluded")
        self.assertTrue(answer["pasted"])
        self.assertEqual(self.backend.writes, [])
        self.assertEqual(self.daemon.status.snapshot()["session"]["bypassed"], 1)

    def test_reload_surfaces_config_warnings_in_the_status(self) -> None:
        self.config.write_text(json.dumps({"automatic": "yes", "maxBytes": 7}), encoding="utf-8")
        warnings = self.daemon.reload_config()
        self.assertEqual(warnings, ["automatic", "maxBytes"])
        snapshot = self.daemon.status.snapshot()
        self.assertEqual(snapshot["configWarnings"], ["automatic", "maxBytes"])
        self.assertTrue(snapshot["automatic"])

    def test_the_last_source_follows_the_newest_generation(self) -> None:
        # Dos eventos que se ejecutan en orden inverso: el más nuevo manda.
        older = self.daemon._next_generation()
        newer = self.daemon._next_generation()
        self.daemon.automatic_event("data", newer, WindowTarget("0x2", "nueva", "nueva", False))
        self.daemon.automatic_event("data", older, WindowTarget("0x1", "vieja", "vieja", False))
        self.assertEqual(self.daemon.last_source, ("nueva", "nueva"))

    def test_an_encoding_only_rewrite_is_named_as_such(self) -> None:
        self.backend.payload = "﻿hola".encode("utf-8")
        answer = self.daemon.peek()
        self.assertTrue(answer["changed"])
        self.assertEqual(answer["applied"], ["encoding"])
        self.assertEqual(self.daemon.clean_now()["reason"], "encoding")


if __name__ == "__main__":
    unittest.main()
