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
        # Un cerrojo aparte para el disco. La instantánea se tomaba bajo
        # `lock` y se escribía fuera de él, así que dos hilos podían
        # escribir sus instantáneas en orden inverso y dejar en disco la
        # vieja hasta la siguiente actualización.
        self.write_lock = threading.Lock()
        self.value: dict[str, object] = {
            "version": 1,
            "watcher": "starting",
            "automatic": automatic,
            "skipNext": False,
            "lastResult": "none",
            "lastReason": "none",
            "lastAt": "",
            # El último evento del portapapeles, se procesara o no. Es lo
            # que el panel abierto vigila para saber que lo que enseña ya
            # no es lo que hay.
            "lastEventAt": "",
            "lastBytes": 0,
            "configWarnings": [],
            "session": {"cleaned": 0, "unchanged": 0, "bypassed": 0, "errors": 0},
        }
        self.write()

    @staticmethod
    def _now() -> str:
        return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")

    def write(self) -> None:
        with self.write_lock:
            with self.lock:
                snapshot = copy.deepcopy(self.value)
            write_json_secure(self.path, snapshot)

    def mark_event(self, write: bool = False) -> None:
        """Deja constancia de un evento, en memoria; a disco si se pide.

        La marca viaja con la siguiente escritura —el `record` del mismo
        evento, casi siempre— y no cuesta un `fsync` propio. Sólo cuando
        el evento no se va a apuntar, con el automático apagado, se
        escribe aquí: es el único caso en que nadie más lo haría.
        """
        with self.lock:
            self.value["lastEventAt"] = self._now()
        if write:
            self.write()

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
                "lastAt": self._now(),
                "lastBytes": max(0, int(byte_count)),
            })
        self.write()

    def snapshot(self) -> dict[str, object]:
        with self.lock:
            return copy.deepcopy(self.value)

