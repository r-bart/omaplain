#!/usr/bin/env python3
"""Deterministic micro-benchmark for OmaPlain's pure transformation path."""

from __future__ import annotations

import json
import statistics
import time
from pathlib import Path

from omaplain_lib.config import DEFAULTS
from omaplain_lib.transform import transform


def measure(size: int, iterations: int) -> dict[str, float | int]:
    unit = b"OmaPlain benchmark with plain deterministic text.\n"
    payload = (unit * ((size // len(unit)) + 1))[:size]
    samples: list[float] = []
    for _ in range(iterations):
        started = time.perf_counter_ns()
        transform(payload, "text/plain;charset=utf-8", DEFAULTS)
        samples.append((time.perf_counter_ns() - started) / 1_000_000)
    ordered = sorted(samples)
    p95_index = min(len(ordered) - 1, int(len(ordered) * 0.95))
    return {
        "bytes": size,
        "iterations": iterations,
        "p50Ms": round(statistics.median(samples), 3),
        "p95Ms": round(ordered[p95_index], 3),
    }


def main() -> None:
    results = [measure(10 * 1024, 500), measure(100 * 1024, 200), measure(1024 * 1024, 20)]
    status = Path("/proc/self/status").read_text(encoding="utf-8")
    high_water = next(
        int(line.split()[1]) for line in status.splitlines() if line.startswith("VmHWM:")
    )
    print(json.dumps({
        "results": results,
        "maxRssKiB": high_water,
    }, separators=(",", ":")))


if __name__ == "__main__":
    main()
