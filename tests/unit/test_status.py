"""`status.json`: lo que se escribe, cuándo y en qué orden."""

from __future__ import annotations

import json
import tempfile
import threading
import unittest
from pathlib import Path

from omaplain_lib.status import StatusStore


class StatusStoreTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.path = Path(self.temporary.name) / "status.json"
        self.store = StatusStore(self.path)

    def on_disk(self) -> dict:
        return json.loads(self.path.read_text(encoding="utf-8"))

    def test_the_file_is_private_and_starts_with_the_full_shape(self) -> None:
        self.assertEqual(self.path.stat().st_mode & 0o777, 0o600)
        self.assertEqual(
            set(self.on_disk()),
            {"version", "watcher", "automatic", "lastResult", "lastReason",
             "lastAt", "lastEventAt", "eventSeq", "lastBytes", "configWarnings", "session"},
        )

    def test_an_event_mark_is_memory_only_until_the_next_write(self) -> None:
        self.store.mark_event()
        self.assertEqual(self.on_disk()["lastEventAt"], "")
        self.store.record("unchanged", "already_clean", 3)
        self.assertNotEqual(self.on_disk()["lastEventAt"], "")
        self.store.mark_event(write=True)
        self.assertEqual(self.on_disk()["lastEventAt"], self.store.snapshot()["lastEventAt"])

    def test_record_counts_and_unknown_results_count_as_errors(self) -> None:
        self.store.record("cleaned", "tracking", 10)
        self.store.record("nonsense", "x")
        session = self.on_disk()["session"]
        self.assertEqual((session["cleaned"], session["errors"]), (1, 1))
        self.assertEqual(self.on_disk()["lastBytes"], 0)

    def test_concurrent_writers_leave_the_newest_value_on_disk(self) -> None:
        # Muchos hilos actualizando el mismo campo: al final el disco tiene
        # que decir lo último que se dijo, no lo último que llegó a escribir.
        barrier = threading.Barrier(8)
        final = threading.Event()

        def worker(n: int) -> None:
            barrier.wait()
            for i in range(30):
                self.store.update(lastReason=f"w{n}-{i}")
            final.set()

        threads = [threading.Thread(target=worker, args=(n,)) for n in range(8)]
        for thread in threads:
            thread.start()
        for thread in threads:
            thread.join()
        self.store.update(lastReason="final")
        self.assertEqual(self.on_disk()["lastReason"], "final")
        self.assertEqual(self.store.snapshot()["lastReason"], "final")

    def test_an_update_that_changes_nothing_does_not_touch_the_disk(self) -> None:
        # El supervisor dice «running» dos veces por segundo; sin esto eran
        # dos `fsync` por segundo para dejar el fichero igual.
        self.store.update(watcher="running")
        before = self.path.stat().st_mtime_ns
        self.store.update(watcher="running")
        self.assertEqual(self.path.stat().st_mtime_ns, before)
        self.store.update(watcher="degraded")
        self.assertNotEqual(self.path.stat().st_mtime_ns, before)

    def test_snapshot_is_a_copy(self) -> None:
        snapshot = self.store.snapshot()
        snapshot["session"]["cleaned"] = 99
        self.assertEqual(self.store.snapshot()["session"]["cleaned"], 0)


if __name__ == "__main__":
    unittest.main()
