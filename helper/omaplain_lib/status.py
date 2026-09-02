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
            # Y un contador, para que dos eventos en el mismo microsegundo
            # o un reloj que salte no se confundan con «nada nuevo».
            "eventSeq": 0,
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
        evento— y no cuesta un `fsync` propio. Con el automático apagado
        el evento no se apunta, y entonces se pide escribir aquí. El evento
        propio de una reescritura no se marca en absoluto.
        """
        with self.lock:
            self.value["lastEventAt"] = self._now()
            self.value["eventSeq"] = int(self.value.get("eventSeq", 0)) + 1
        if write:
            self.write()

    def update(self, **values: object) -> None:
        """Cambia campos y escribe, sólo si algo cambió de verdad.

        El supervisor del watcher llama a `update(watcher="running")` cada
        medio segundo mientras todo va bien. Escribir y hacer `fsync` dos
        veces por segundo para dejar el fichero igual es gasto sin nada a
        cambio; y `mark_event` ya se encarga de sus propias escrituras.
        """
        with self.lock:
            changed = any(self.value.get(key) != value for key, value in values.items())
            self.value.update(values)
        if changed:
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

