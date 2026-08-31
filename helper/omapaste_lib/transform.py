"""Pure, deterministic text transformations."""

from __future__ import annotations

import codecs
import re
import unicodedata
from dataclasses import dataclass
from urllib.parse import unquote_plus, urlsplit


_INVISIBLE_TRANSLATION = {
    ord("\u00ad"): None,
    ord("\u200b"): None,
    ord("\u2060"): None,
    ord("\ufeff"): None,
}
_QUOTE_MAP = str.maketrans({
    "\u2018": "'", "\u2019": "'", "\u201a": "'", "\u201b": "'",
    "\u201c": '"', "\u201d": '"', "\u201e": '"', "\u201f": '"',
})
_BULLET_RE = re.compile(r"(?m)^([ \t]*)[•◦▪‣][ \t]+")
_TRAILING_RE = re.compile(r"[ \t]+(?=\n|$)")
_PERCENT_ERROR_RE = re.compile(r"%(?![0-9A-Fa-f]{2})")


@dataclass(frozen=True, slots=True)
class TransformResult:
    output: bytes
    changed: bool
    transformations: tuple[str, ...]


class TransformBypass(ValueError):
    def __init__(self, reason: str):
        super().__init__(reason)
        self.reason = reason


def decode_text(payload: bytes, mime: str) -> str:
    lowered = mime.lower().replace(" ", "")
    charset = ""
    if "charset=" in lowered:
        charset = lowered.split("charset=", 1)[1].split(";", 1)[0].strip('"')

    if payload.startswith(codecs.BOM_UTF8):
        codec = "utf-8-sig"
    elif payload.startswith(codecs.BOM_UTF16_LE) or payload.startswith(codecs.BOM_UTF16_BE):
        codec = "utf-16"
    elif charset:
        aliases = {
            "utf8": "utf-8",
            "utf-8": "utf-8",
            "utf16": "utf-16",
            "utf-16": "utf-16",
            "utf-16le": "utf-16-le",
            "utf-16be": "utf-16-be",
            "us-ascii": "ascii",
            "ascii": "ascii",
            "iso-8859-1": "iso-8859-1",
            "latin1": "iso-8859-1",
            "windows-1252": "cp1252",
        }
        codec = aliases.get(charset, "")
        if not codec:
            raise TransformBypass("unsupported_encoding")
    else:
        codec = "utf-8"

    try:
        text = payload.decode(codec, errors="strict")
    except (UnicodeDecodeError, LookupError):
        raise TransformBypass("invalid_text") from None
    if "\x00" in text:
        raise TransformBypass("nul")
    return text


def _remove_invisibles(text: str) -> str:
    # A leading byte-order mark has already been consumed by decode_text.
    # str.translate performs the conservative deletion in C without building
    # a Python list with one pointer per clipboard character.
    return text.translate(_INVISIBLE_TRANSLATION)


def _outer_whitespace(text: str) -> tuple[str, str, str]:
    start = 0
    end = len(text)
    while start < end and text[start].isspace():
        start += 1
    while end > start and text[end - 1].isspace():
        end -= 1
    return text[:start], text[start:end], text[end:]


def _valid_percent_encoding(value: str) -> bool:
    return _PERCENT_ERROR_RE.search(value) is None


def _query_key(part: str) -> str | None:
    raw = part.split("=", 1)[0]
    if not _valid_percent_encoding(raw):
        return None
    try:
        return unquote_plus(raw, encoding="utf-8", errors="strict").casefold()
    except UnicodeError:
        return None


def _is_tracking_key(key: str) -> bool:
    return key.startswith("utm_") or key in {
        "fbclid", "gclid", "dclid", "gbraid", "wbraid", "mc_cid", "mc_eid",
        "mkt_tok", "igshid", "msclkid", "twclid", "yclid", "vero_conv",
        "vero_id", "wickedid", "oly_anon_id", "oly_enc_id", "rb_clickid",
    }


def _is_signed_key(key: str) -> bool:
    return key.startswith("x-amz-") or key in {
        "signature", "sig", "expires", "token", "auth", "authorization", "key",
        "api_key", "apikey", "access_token", "jwt", "hmac", "hash",
    }


def clean_tracking_url(text: str) -> str:
    leading, core, trailing = _outer_whitespace(text)
    if not core or any(character.isspace() for character in core):
        return text
    try:
        parsed = urlsplit(core)
    except ValueError:
        return text
    if parsed.scheme.lower() not in {"http", "https"} or not parsed.netloc:
        return text
    if "?" not in core:
        return text

    before_fragment, separator, fragment = core.partition("#")
    prefix, question, query = before_fragment.partition("?")
    if not question:
        return text
    parts = query.split("&")
    keys = [_query_key(part) for part in parts]
    if any(key is None for key in keys):
        return text
    if any(_is_signed_key(key or "") for key in keys):
        return text

    remaining = [part for part, key in zip(parts, keys, strict=True) if not _is_tracking_key(key or "")]
    if len(remaining) == len(parts):
        return text
    rebuilt = prefix
    if remaining:
        rebuilt += "?" + "&".join(remaining)
    if separator:
        rebuilt += "#" + fragment

    try:
        verified = urlsplit(rebuilt)
    except ValueError:
        return text
    if verified.netloc != parsed.netloc or verified.path != parsed.path:
        return text
    return leading + rebuilt + trailing


def transform(payload: bytes, mime: str, config: dict[str, object]) -> TransformResult:
    text = decode_text(payload, mime)
    original = text
    applied: list[str] = []

    if config.get("normalizeLineEndings", True):
        next_text = text.replace("\r\n", "\n").replace("\r", "\n")
        if next_text != text:
            text = next_text
            applied.append("line_endings")

    if config.get("removeInvisible", True):
        next_text = _remove_invisibles(text)
        if next_text != text:
            text = next_text
            applied.append("invisible")

    if config.get("removeTracking", True):
        next_text = clean_tracking_url(text)
        if next_text != text:
            text = next_text
            applied.append("tracking")

    if config.get("normalizeQuotes", False):
        next_text = text.translate(_QUOTE_MAP)
        if next_text != text:
            text = next_text
            applied.append("quotes")

    if config.get("normalizeLists", False):
        next_text = _BULLET_RE.sub(r"\1- ", text)
        if next_text != text:
            text = next_text
            applied.append("lists")

    if config.get("normalizeUnicodeNfc", False):
        next_text = unicodedata.normalize("NFC", text)
        if next_text != text:
            text = next_text
            applied.append("unicode_nfc")

    if config.get("trimTrailingWhitespace", False):
        next_text = _TRAILING_RE.sub("", text)
        if next_text != text:
            text = next_text
            applied.append("trailing_whitespace")

    output = text.encode("utf-8")
    maximum = int(config.get("maxBytes", 1_048_576))
    if original and not text:
        raise TransformBypass("empty_output")
    if len(output) > maximum:
        raise TransformBypass("too_large")
    if len(output) > max(len(payload) + 4, int(len(payload) * 1.10)):
        raise TransformBypass("growth")
    return TransformResult(output, output != payload, tuple(applied))
