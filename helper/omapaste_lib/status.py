"""Content-free runtime status."""

from __future__ import annotations

import copy
import threading
from datetime import datetime, timezone
from pathlib import Path

from .config import write_json_secure


class StatusStore:
    def __init__(self, path: str | Path, automatic: bool = True):
        self.path = Path(path)
        self.lock = threading.Lock()
        self.value: dict[str, object] = {
            "version": 1,
            "watcher": "starting",
            "automatic": automatic,
            "skipNext": False,
            "lastResult": "none",
            "lastReason": "none",
            "lastAt": "",
            "lastBytes": 0,
            "configWarnings": [],
            "session": {"cleaned": 0, "unchanged": 0, "bypassed": 0, "errors": 0},
        }
        self.write()

    def write(self) -> None:
        with self.lock:
            snapshot = copy.deepcopy(self.value)
        write_json_secure(self.path, snapshot)

    def update(self, **values: object) -> None:
        with self.lock:
            self.value.update(values)
        self.write()

    def record(self, result: str, reason: str, byte_count: int = 0) -> None:
        counter = {
            "cleaned": "cleaned",
            "unchanged": "unchanged",
            "bypassed": "bypassed",
            "error": "errors",
        }.get(result, "errors")
        with self.lock:
            session = self.value["session"]
            assert isinstance(session, dict)
            session[counter] = int(session.get(counter, 0)) + 1
            self.value.update({
                "lastResult": result,
                "lastReason": reason,
                "lastAt": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
                "lastBytes": max(0, int(byte_count)),
            })
        self.write()

    def snapshot(self) -> dict[str, object]:
        with self.lock:
            return copy.deepcopy(self.value)

