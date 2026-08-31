#!/usr/bin/env python3
"""Accelerated eight-hour-equivalent event soak for OmaPlain."""

from __future__ import annotations

import json
import tempfile
import time
import tracemalloc
from pathlib import Path

from omaplain_lib.clipboard import WindowTarget
from omaplain_lib.config import write_config
from omaplain_lib.daemon import OmaPlainDaemon


EVENTS_PER_SECOND = 1
VIRTUAL_SECONDS = 8 * 60 * 60
EVENT_COUNT = VIRTUAL_SECONDS * EVENTS_PER_SECOND


class SoakBackend:
    def __init__(self) -> None:
        self.types = ["text/plain"]
        self.payload = b"https://example.com/soak?utm_source=test&keep=1"
        self.writes = 0

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


def main() -> None:
    with tempfile.TemporaryDirectory() as temporary:
        base = Path(temporary)
        config = base / "config.json"
        write_config(config, {})
        daemon = OmaPlainDaemon(
            __file__, str(config), str(base / "status.json"), str(base / "omaplain.sock")
        )
        backend = SoakBackend()
        daemon.backend = backend

        tracemalloc.start()
        started = time.perf_counter()
        for _ in range(EVENT_COUNT):
            generation = daemon._next_generation()
            daemon.automatic_event("data", generation)
        elapsed = time.perf_counter() - started
        current, peak = tracemalloc.get_traced_memory()
        tracemalloc.stop()

        status = daemon.status.snapshot()
        if backend.writes != 1:
            raise SystemExit(f"expected exactly one rewrite, got {backend.writes}")
        if daemon.workers:
            raise SystemExit(f"worker set did not drain: {len(daemon.workers)}")
        if peak > 30 * 1024 * 1024:
            raise SystemExit(f"Python allocation peak exceeded 30 MiB: {peak}")

        print(json.dumps({
            "virtualHours": 8,
            "eventCount": EVENT_COUNT,
            "wallSeconds": round(elapsed, 3),
            "writes": backend.writes,
            "currentAllocatedBytes": current,
            "peakAllocatedBytes": peak,
            "session": status["session"],
        }, separators=(",", ":")))


if __name__ == "__main__":
    main()
