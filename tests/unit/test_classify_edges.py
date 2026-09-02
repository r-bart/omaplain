"""Lo que el clasificador prefiere y lo que lee del fichero de datos."""

from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from omaplain_lib.classify import classify, safe_type_metadata


REPO = Path(__file__).resolve().parents[2]


class PreferenceTests(unittest.TestCase):
    def test_utf8_plain_is_preferred_over_legacy_x11_names(self) -> None:
        result = classify(["UTF8_STRING", "STRING", "text/plain", "text/plain;charset=utf-8", "TEXT"])
        self.assertEqual(result.plain_mime, "text/plain;charset=utf-8")

    def test_the_first_candidate_wins_when_nothing_is_preferred(self) -> None:
        result = classify(["text/plain;charset=iso-8859-1", "text/plain;charset=utf-16"])
        self.assertEqual(result.plain_mime, "text/plain;charset=iso-8859-1")

    def test_legacy_x11_names_alone_are_still_text(self) -> None:
        result = classify(["UTF8_STRING"])
        self.assertTrue(result.eligible)
        self.assertEqual(result.plain_mime, "UTF8_STRING")

    def test_the_original_spelling_of_the_type_is_returned(self) -> None:
        # Se pide a `wl-paste` con el nombre exacto que anunció.
        result = classify(["Text/Plain;Charset=UTF-8"])
        self.assertEqual(result.plain_mime, "Text/Plain;Charset=UTF-8")


class StateTests(unittest.TestCase):
    def test_nil_and_clear_are_empty_whatever_the_types_say(self) -> None:
        for state in ("nil", "clear", "NIL"):
            with self.subTest(state=state):
                result = classify(["text/plain"], state)
                self.assertEqual(result.reason, "empty")

    def test_a_qt_image_counts_as_an_image(self) -> None:
        self.assertEqual(classify(["application/x-qt-image", "text/plain"]).reason, "image")

    def test_the_data_file_prefixes_are_applied(self) -> None:
        data = json.loads((REPO / "data" / "structural-mime-types.json").read_text(encoding="utf-8"))
        for prefix in data["prefixes"]:
            with self.subTest(prefix=prefix):
                result = classify(["text/plain", prefix + "anything"])
                self.assertFalse(result.eligible)
                self.assertEqual(result.reason, "structured")

    def test_no_text_at_all_says_so(self) -> None:
        result = classify(["application/x-example"])
        self.assertEqual(result.reason, "no_plain_text")


class BrokenDataTests(unittest.TestCase):
    def test_an_unreadable_data_file_still_bypasses_files_and_folders(self) -> None:
        # Las reglas de archivo van en el código además de en el fichero:
        # un JSON corrupto no puede convertir una copia de archivos en
        # texto que se reescribe.
        from unittest.mock import patch
        from omaplain_lib import classify as classify_module
        with tempfile.TemporaryDirectory() as temporary:
            broken = Path(temporary) / "structural-mime-types.json"
            broken.write_text("{no es json", encoding="utf-8")
            with patch.object(classify_module, "_DATA_PATH", broken):
                exact, prefixes = classify_module._load_structural_rules()
        self.assertEqual(prefixes, ())
        for name in ("text/uri-list", "x-special/gnome-copied-files",
                     "application/x-kde-cutselection", "application/vnd.portal.filetransfer"):
            with self.subTest(mime=name):
                self.assertIn(name, exact)


class MetadataTests(unittest.TestCase):
    def test_safe_metadata_summarises_without_content(self) -> None:
        summary = safe_type_metadata(["text/html", "text/plain", "image/png"])
        self.assertEqual(summary["typeCount"], 3)
        self.assertTrue(summary["hasPlain"])
        self.assertTrue(summary["hasRich"])
        self.assertTrue(summary["hasImage"])
        self.assertEqual(set(summary), {"typeCount", "hasPlain", "hasRich", "hasImage", "mimeTypes"})


if __name__ == "__main__":
    unittest.main()
