"""Configuration loading and validation.

Configuration never contains clipboard data.  The canonical copy lives in
Omarchy's shell.json; the helper consumes a validated runtime snapshot.
"""

from __future__ import annotations

import json
import os
import tempfile
from pathlib import Path
from typing import Any


DEFAULTS: dict[str, Any] = {
    "automatic": True,
    "stripFormatting": True,
    "removeTracking": True,
    "removeInvisible": True,
    "normalizeLineEndings": True,
    "normalizeQuotes": False,
    "normalizeLists": False,
    "normalizeUnicodeNfc": False,
    "trimTrailingWhitespace": False,
    "sourceExclusions": [],
    "targetExclusions": [],
    # 0009: quién llega cubierto y quién no se lee siquiera.
    "alwaysCovered": [],
    "blockedApps": [],
    "maxBytes": 1_048_576,
}

_BOOL_KEYS = {
    "automatic",
    "stripFormatting",
    "removeTracking",
    "removeInvisible",
    "normalizeLineEndings",
    "normalizeQuotes",
    "normalizeLists",
    "normalizeUnicodeNfc",
    "trimTrailingWhitespace",
}
_LIST_KEYS = {"sourceExclusions", "targetExclusions", "alwaysCovered", "blockedApps"}


def _valid_app_class(value: object) -> bool:
    return (
        isinstance(value, str)
        and bool(value)
        and "\n" not in value
        and "\r" not in value
        and len(value.encode("utf-8")) <= 256
    )


def validate_config(raw: object) -> tuple[dict[str, Any], list[str]]:
    """Return a complete safe configuration and warning keys.

    Unknown keys are intentionally ignored so a newer snapshot can be read by
    an older helper after a downgrade.
    """

    result = dict(DEFAULTS)
    for key in _LIST_KEYS:
        result[key] = []
    warnings: list[str] = []

    if not isinstance(raw, dict):
        return result, ["config"]

    for key in _BOOL_KEYS:
        if key not in raw:
            continue
        if type(raw[key]) is bool:
            result[key] = raw[key]
        else:
            warnings.append(key)

    for key in _LIST_KEYS:
        if key not in raw:
            continue
        value = raw[key]
        if not isinstance(value, list) or not all(_valid_app_class(v) for v in value):
            warnings.append(key)
            continue
        result[key] = list(dict.fromkeys(value))

    if "maxBytes" in raw:
        value = raw["maxBytes"]
        if type(value) is int and 1_024 <= value <= 16 * 1_048_576:
            result["maxBytes"] = value
        else:
            warnings.append("maxBytes")

    return result, sorted(warnings)


def load_config(path: str | os.PathLike[str]) -> tuple[dict[str, Any], list[str]]:
    try:
        with Path(path).open("r", encoding="utf-8") as stream:
            raw = json.load(stream)
    except (OSError, UnicodeError, json.JSONDecodeError):
        return validate_config(None)
    return validate_config(raw)


def write_json_secure(path: str | os.PathLike[str], value: object) -> None:
    """Atomically write JSON with a private parent directory and file mode."""

    target = Path(path)
    target.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    os.chmod(target.parent, 0o700)
    fd, temporary = tempfile.mkstemp(prefix=f".{target.name}.", dir=target.parent)
    try:
        os.fchmod(fd, 0o600)
        with os.fdopen(fd, "w", encoding="utf-8") as stream:
            json.dump(value, stream, ensure_ascii=False, separators=(",", ":"))
            stream.write("\n")
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, target)
    except BaseException:
        try:
            os.unlink(temporary)
        except FileNotFoundError:
            pass
        raise


def write_config(path: str | os.PathLike[str], raw: object) -> list[str]:
    validated, warnings = validate_config(raw)
    write_json_secure(path, validated)
    return warnings

