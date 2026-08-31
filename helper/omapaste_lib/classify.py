"""Conservative clipboard MIME classification."""

from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable


_DATA_PATH = Path(__file__).resolve().parents[2] / "data" / "structural-mime-types.json"

_PLAIN_PREFERENCE = (
    "text/plain;charset=utf-8",
    "text/plain;charset=utf8",
    "text/plain",
    "utf8_string",
    "text",
    "string",
    "compound_text",
)
_RICH_TYPES = {
    "text/html",
    "text/rtf",
    "application/rtf",
    "application/x-rtf",
    "application/x-qt-richtext",
}
_SENSITIVE_TYPES = {
    "x-kde-passwordmanagerhint",
    "application/x-kde-passwordmanagerhint",
}


@dataclass(frozen=True, slots=True)
class Classification:
    eligible: bool
    reason: str
    plain_mime: str | None = None
    rich: bool = False


def _load_structural_rules() -> tuple[set[str], tuple[str, ...]]:
    try:
        raw = json.loads(_DATA_PATH.read_text(encoding="utf-8"))
        exact = {str(value).lower() for value in raw.get("exact", [])}
        prefixes = tuple(str(value).lower() for value in raw.get("prefixes", []))
    except (OSError, ValueError, TypeError):
        exact = set()
        prefixes = ()
    exact.update({
        "text/uri-list",
        "x-special/gnome-copied-files",
        "application/x-kde-cutselection",
        "application/vnd.portal.filetransfer",
    })
    return exact, prefixes


_STRUCTURAL_EXACT, _STRUCTURAL_PREFIXES = _load_structural_rules()


def _base_mime(mime: str) -> str:
    return mime.split(";", 1)[0].strip().lower()


def _is_plain(mime: str) -> bool:
    lowered = mime.strip().lower().replace(" ", "")
    return _base_mime(lowered) == "text/plain" or lowered in {
        "utf8_string", "text", "string", "compound_text"
    }


def _choose_plain(types: list[str]) -> str | None:
    candidates = [mime for mime in types if _is_plain(mime)]
    if not candidates:
        return None
    normalized = {mime.strip().lower().replace(" ", ""): mime for mime in candidates}
    for preferred in _PLAIN_PREFERENCE:
        if preferred in normalized:
            return normalized[preferred]
    return candidates[0]


def classify(mime_types: Iterable[str], clipboard_state: str = "data") -> Classification:
    types = [str(mime).strip() for mime in mime_types if str(mime).strip()]
    lowered = [mime.lower() for mime in types]
    bases = [_base_mime(mime) for mime in types]
    state = str(clipboard_state or "data").lower()

    if state == "sensitive" or any(base in _SENSITIVE_TYPES for base in bases):
        return Classification(False, "sensitive")
    if state in {"nil", "clear"} or not types:
        return Classification(False, "empty")
    if any(base.startswith("image/") or base == "application/x-qt-image" for base in bases):
        return Classification(False, "image")
    if any(
        base in _STRUCTURAL_EXACT
        or any(base.startswith(prefix) for prefix in _STRUCTURAL_PREFIXES)
        for base in bases
    ):
        if "text/uri-list" in bases or "x-special/gnome-copied-files" in bases:
            return Classification(False, "files")
        return Classification(False, "structured")

    plain = _choose_plain(types)
    rich = any(base in _RICH_TYPES for base in bases)
    if plain is None:
        return Classification(False, "html_without_plain" if rich else "no_plain_text")
    return Classification(True, "text", plain_mime=plain, rich=rich)


def safe_type_metadata(mime_types: Iterable[str]) -> dict[str, object]:
    """Return content-free type metadata suitable for diagnostics."""

    types = [str(value) for value in mime_types]
    return {
        "typeCount": len(types),
        "hasPlain": any(_is_plain(value) for value in types),
        "hasRich": any(_base_mime(value) in _RICH_TYPES for value in types),
        "hasImage": any(_base_mime(value).startswith("image/") for value in types),
        "mimeTypes": types,
    }

