#!/usr/bin/env python3
"""Micro-benchmark determinista del transformador de OmaPlain.

Mide texto en el que las reglas actúan —finales de línea de Windows y un
invisible cada pocas líneas, que es lo que trae una copia desde un
navegador o un documento—, y aparte una URL con seguimiento, que es el
único caso en que la limpieza de enlaces trabaja. Un texto donde ninguna
regla actuara sólo mediría descodificar y volver a codificar.
"""

from __future__ import annotations

import json
import statistics
import time
from pathlib import Path

from omaplain_lib.config import DEFAULTS
from omaplain_lib.transform import transform


def dirty_prose(size: int) -> bytes:
    unit = "OmaPlain benchmark: prosa con finales de Windows​ y un invisible.\r\n".encode("utf-8")
    return (unit * ((size // len(unit)) + 1))[:size]


def tracked_url() -> bytes:
    return (
        b"https://example.com/articles/2026/benchmark?id=42&utm_source=news&utm_medium=mail"
        b"&utm_campaign=q3&fbclid=abc123&ref=keep#section-3"
    )


def measure(label: str, payload: bytes, iterations: int) -> dict[str, float | int | str]:
    samples: list[float] = []
    applied: tuple[str, ...] = ()
    for _ in range(iterations):
        started = time.perf_counter_ns()
        result = transform(payload, "text/plain;charset=utf-8", DEFAULTS)
        samples.append((time.perf_counter_ns() - started) / 1_000_000)
        applied = result.transformations
    if not applied:
        raise SystemExit(f"{label}: ninguna regla actuó, el benchmark no mide nada")
    ordered = sorted(samples)
    p95_index = min(len(ordered) - 1, int(len(ordered) * 0.95))
    return {
        "case": label,
        "bytes": len(payload),
        "iterations": iterations,
        "applied": ",".join(applied),
        "p50Ms": round(statistics.median(samples), 3),
        "p95Ms": round(ordered[p95_index], 3),
    }


def main() -> None:
    results = [
        measure("url", tracked_url(), 2000),
        measure("prose", dirty_prose(10 * 1024), 500),
        measure("prose", dirty_prose(100 * 1024), 200),
        measure("prose", dirty_prose(1024 * 1024), 20),
    ]
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
