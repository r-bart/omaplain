"""Los bordes del transformador: URL raras, codificaciones y el tope."""

from __future__ import annotations

import codecs
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from omaplain_lib import transform as transform_module
from omaplain_lib.config import DEFAULTS
from omaplain_lib.transform import TransformBypass, clean_tracking_url, transform


class TrackingUrlEdgeTests(unittest.TestCase):
    def test_keys_are_matched_without_case_or_percent_encoding(self) -> None:
        self.assertEqual(clean_tracking_url("https://a.com/?UTM_Source=x&k=1"), "https://a.com/?k=1")
        self.assertEqual(clean_tracking_url("https://a.com/?utm%5Fsource=x&k=1"), "https://a.com/?k=1")
        self.assertEqual(clean_tracking_url("https://a.com/?FBCLID=abc"), "https://a.com/")

    def test_a_trailing_ampersand_does_not_leave_a_dangling_question_mark(self) -> None:
        self.assertEqual(clean_tracking_url("https://a.com/?fbclid=1&"), "https://a.com/")
        self.assertEqual(clean_tracking_url("https://a.com/?k=1&fbclid=1&"), "https://a.com/?k=1")

    def test_query_shapes_that_carry_no_tracking_are_untouched(self) -> None:
        for source in (
            "https://a.com/?",
            "https://a.com/?&",
            "https://a.com/?flag",
            "https://a.com/?a=1&b",
            "https://a.com/#frag?utm_source=x",
        ):
            with self.subTest(source=source):
                self.assertEqual(clean_tracking_url(source), source)

    def test_only_http_and_https_are_touched(self) -> None:
        self.assertEqual(clean_tracking_url("http://a.com/?utm_source=x"), "http://a.com/")
        for source in ("ftp://a.com/?utm_source=x", "mailto:x@a.com?utm_source=x", "a.com/?utm_source=x"):
            with self.subTest(source=source):
                self.assertEqual(clean_tracking_url(source), source)

    def test_userinfo_ports_and_idn_hosts_survive(self) -> None:
        source = "https://user:pw@münchen.example:8443/p?utm_source=x&k=1#f"
        self.assertEqual(clean_tracking_url(source), "https://user:pw@münchen.example:8443/p?k=1#f")

    def test_a_plus_in_a_key_still_matches(self) -> None:
        # `unquote_plus` convierte `+` en espacio: `utm+source` no es `utm_source`.
        self.assertEqual(clean_tracking_url("https://a.com/?utm+source=x"), "https://a.com/?utm+source=x")

    def test_signed_prefix_from_the_data_file_is_honoured(self) -> None:
        source = "https://a.com/?x-amz-credential=abc&utm_source=x"
        self.assertEqual(clean_tracking_url(source), source)

    def test_a_broken_data_file_falls_back_to_the_built_in_rules(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            broken = Path(temporary) / "tracking-parameters.json"
            broken.write_text(json.dumps({"prefixes": [], "exact": [], "signed": []}), encoding="utf-8")
            with patch.object(transform_module, "_TRACKING_DATA_PATH", broken):
                prefixes, exact, signed_prefixes, signed = transform_module._load_tracking_rules()
        self.assertEqual(prefixes, ("utm_",))
        self.assertIn("fbclid", exact)
        self.assertEqual(signed_prefixes, ("x-amz-",))
        self.assertIn("signature", signed)


class EncodingTests(unittest.TestCase):
    def setUp(self) -> None:
        self.config = dict(DEFAULTS)

    def test_a_bom_only_rewrite_is_named_encoding(self) -> None:
        result = transform(codecs.BOM_UTF8 + b"hola", "text/plain;charset=utf-8", self.config)
        self.assertEqual(result.output, b"hola")
        self.assertTrue(result.changed)
        self.assertEqual(result.transformations, ("encoding",))

    def test_utf16_is_rewritten_as_utf8_and_named_encoding(self) -> None:
        result = transform("hola".encode("utf-16"), "text/plain;charset=utf-16", self.config)
        self.assertEqual(result.output, b"hola")
        self.assertEqual(result.transformations, ("encoding",))

    def test_latin1_with_many_accents_is_not_mistaken_for_growth(self) -> None:
        payload = ("café ñandú " * 20).encode("latin-1")
        result = transform(payload, "text/plain;charset=iso-8859-1", self.config)
        self.assertEqual(result.output.decode("utf-8"), "café ñandú " * 20)
        self.assertEqual(result.transformations, ("encoding",))

    def test_quoted_and_aliased_charsets_are_understood(self) -> None:
        for mime in ('text/plain;charset="UTF-8"', "text/plain; charset=latin1", "text/plain;charset=windows-1252"):
            with self.subTest(mime=mime):
                self.assertEqual(transform(b"abc", mime, self.config).output, b"abc")

    def test_an_unknown_charset_is_a_bypass(self) -> None:
        with self.assertRaisesRegex(TransformBypass, "unsupported_encoding"):
            transform(b"abc", "text/plain;charset=koi8-r", self.config)

    def test_a_copy_made_only_of_invisibles_is_not_emptied(self) -> None:
        with self.assertRaisesRegex(TransformBypass, "empty_output"):
            transform("​⁠".encode("utf-8"), "text/plain", self.config)

    def test_the_growth_cap_still_stops_a_runaway_rule(self) -> None:
        # Una regla que hiciera crecer el texto más de un 10 % se para.
        self.config["normalizeLists"] = True
        with patch.object(transform_module, "_BULLET_RE") as bullets:
            bullets.sub = lambda replacement, text: text + "x" * 50
            with self.assertRaisesRegex(TransformBypass, "growth"):
                transform(b"hola", "text/plain", self.config)

    def test_nothing_to_do_is_unchanged_with_no_transformations(self) -> None:
        result = transform(b"ya limpio", "text/plain", self.config)
        self.assertFalse(result.changed)
        self.assertEqual(result.transformations, ())


if __name__ == "__main__":
    unittest.main()
