#!/usr/bin/env python3
"""Soak acelerado de OmaPlain: ocho horas de eventos, y luego el socket.

Dos fases. La primera mete 28 800 eventos —uno por segundo virtual durante
ocho horas— por el mismo camino que sigue un evento real menos el socket,
con un portapapeles que cambia cada minuto y que unas veces trae algo que
limpiar y otras no: así las reglas actúan de verdad en vez de dar
«unchanged» 28 799 veces seguidas. La segunda arranca el demonio entero
sobre un socket temporal y le habla como lo hacen `emit-event` y el panel,
para que los hilos, la cola de peticiones y el bucle de `accept` también
envejezcan un poco.
"""

from __future__ import annotations

import json
import tempfile
import threading
import time
import tracemalloc
from pathlib import Path
from unittest.mock import patch

from omaplain_lib.clipboard import WindowTarget
from omaplain_lib.config import write_config
from omaplain_lib.daemon import OmaPlainDaemon, socket_request


EVENTS_PER_SECOND = 1
VIRTUAL_SECONDS = 8 * 60 * 60
EVENT_COUNT = VIRTUAL_SECONDS * EVENTS_PER_SECOND
# Una copia nueva cada minuto virtual, rotando por estas cinco. Las tres
# primeras se reescriben; las otras dos no.
COPY_EVERY = 60
COPIES: tuple[tuple[list[str], bytes], ...] = (
    (["text/plain"], b"https://example.com/soak?utm_source=test&keep=1"),
    (["text/plain"], "uno\r\ndos​tres\r\n".encode("utf-8")),
    (["text/html", "text/plain;charset=utf-8"], b"Con formato pero limpio"),
    (["text/plain;charset=utf-8"], "ya limpio: café, 👋, العربية".encode("utf-8")),
    (["image/png"], b"\x89PNG..."),
)
DIRTY_COPIES = 3

SOCKET_EVENTS = 300
SOCKET_PEEKS = 60


class SoakBackend:
    def __init__(self) -> None:
        self.types: list[str] = []
        self.payload = b""
        self.writes = 0

    def copy(self, types: list[str], payload: bytes) -> None:
        self.types = list(types)
        self.payload = payload

    def list_types(self) -> list[str]:
        return list(self.types)

    def read(self, mime: str, maximum: int) -> bytes:
        return self.payload

    def unchanged(self, mime: str, maximum: int, expected: bytes, expected_types: list[str]) -> bool:
        return expected == self.payload and expected_types == self.types

    def write(self, payload: bytes) -> None:
        self.writes += 1
        self.payload = payload
        self.types = ["text/plain;charset=utf-8"]

    def active_window(self) -> WindowTarget | None:
        return None


def event_phase(daemon: OmaPlainDaemon, backend: SoakBackend) -> dict[str, object]:
    started = time.perf_counter()
    copies = 0
    for index in range(EVENT_COUNT):
        if index % COPY_EVERY == 0:
            types, payload = COPIES[copies % len(COPIES)]
            backend.copy(types, payload)
            copies += 1
        generation = daemon._next_generation()
        daemon.automatic_event("data", generation)
    expected_writes = sum(1 for n in range(copies) if n % len(COPIES) < DIRTY_COPIES)
    if backend.writes != expected_writes:
        raise SystemExit(f"expected {expected_writes} rewrites, got {backend.writes}")
    return {"eventCount": EVENT_COUNT, "copies": copies, "writes": backend.writes,
            "wallSeconds": round(time.perf_counter() - started, 3)}


def socket_phase(daemon: OmaPlainDaemon, backend: SoakBackend) -> dict[str, object]:
    def run() -> None:
        with patch("omaplain_lib.daemon.signal.signal"), patch.object(daemon, "_start_watcher", lambda: None):
            daemon.run()

    thread = threading.Thread(target=run, name="soak-daemon", daemon=True)
    thread.start()
    deadline = time.monotonic() + 5
    while time.monotonic() < deadline:
        if socket_request(str(daemon.socket_path), {"kind": "command", "name": "ping"}).get("result") == "ok":
            break
        time.sleep(0.01)
    else:
        raise SystemExit("the daemon never listened")

    started = time.perf_counter()
    failures = 0
    for index in range(SOCKET_EVENTS):
        types, payload = COPIES[index % len(COPIES)]
        backend.copy(types, payload)
        answer = socket_request(str(daemon.socket_path), {"kind": "event", "state": "data"}, timeout=5)
        if answer.get("result") == "error":
            failures += 1
        if index % (SOCKET_EVENTS // SOCKET_PEEKS) == 0:
            peek = socket_request(str(daemon.socket_path), {"kind": "command", "name": "peek"}, timeout=5)
            if peek.get("result") != "ok":
                failures += 1
    elapsed = time.perf_counter() - started
    daemon.stop_event.set()
    thread.join(timeout=5)
    if failures:
        raise SystemExit(f"{failures} socket requests failed")
    if daemon.workers:
        raise SystemExit(f"worker set did not drain: {len(daemon.workers)}")
    if daemon.socket_path.exists():
        raise SystemExit("the socket was not removed on stop")
    return {"events": SOCKET_EVENTS, "peeks": SOCKET_PEEKS, "wallSeconds": round(elapsed, 3)}


def main() -> None:
    with tempfile.TemporaryDirectory() as temporary:
        base = Path(temporary)
        config = base / "config.json"
        write_config(config, {})
        daemon = OmaPlainDaemon(
            __file__, str(config), str(base / "status.json"), str(base / "run" / "omaplain.sock")
        )
        backend = SoakBackend()
        daemon.backend = backend

        tracemalloc.start()
        events = event_phase(daemon, backend)
        sockets = socket_phase(daemon, backend)
        current, peak = tracemalloc.get_traced_memory()
        tracemalloc.stop()

        if peak > 30 * 1024 * 1024:
            raise SystemExit(f"Python allocation peak exceeded 30 MiB: {peak}")

        print(json.dumps({
            "virtualHours": 8,
            "events": events,
            "socket": sockets,
            "currentAllocatedBytes": current,
            "peakAllocatedBytes": peak,
            "session": daemon.status.snapshot()["session"],
        }, separators=(",", ":")))


if __name__ == "__main__":
    main()
