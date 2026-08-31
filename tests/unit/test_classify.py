from __future__ import annotations

import unittest

from omaplain_lib.classify import classify


class ClassifyTests(unittest.TestCase):
    def test_plain_text_is_eligible(self) -> None:
        result = classify(["text/plain;charset=utf-8"])
        self.assertTrue(result.eligible)
        self.assertEqual(result.plain_mime, "text/plain;charset=utf-8")

    def test_rich_text_uses_plain_representation(self) -> None:
        result = classify(["text/html", "text/plain"])
        self.assertTrue(result.eligible)
        self.assertTrue(result.rich)
        self.assertEqual(result.plain_mime, "text/plain")

    def test_html_without_plain_is_bypassed(self) -> None:
        result = classify(["text/html"])
        self.assertFalse(result.eligible)
        self.assertEqual(result.reason, "html_without_plain")

    def test_sensitive_state_wins_without_types(self) -> None:
        result = classify([], "sensitive")
        self.assertFalse(result.eligible)
        self.assertEqual(result.reason, "sensitive")

    def test_password_hint_is_bypassed(self) -> None:
        result = classify(["text/plain", "x-kde-passwordManagerHint"])
        self.assertFalse(result.eligible)
        self.assertEqual(result.reason, "sensitive")

    def test_images_win_over_plain_fallback(self) -> None:
        result = classify(["image/png", "text/plain"])
        self.assertFalse(result.eligible)
        self.assertEqual(result.reason, "image")

    def test_file_copy_is_bypassed(self) -> None:
        result = classify(["text/plain", "text/uri-list", "x-special/gnome-copied-files"])
        self.assertFalse(result.eligible)
        self.assertEqual(result.reason, "files")

    def test_libreoffice_structural_payload_is_bypassed(self) -> None:
        result = classify(["text/plain", "application/x-openoffice-embed-source-xml"])
        self.assertFalse(result.eligible)
        self.assertEqual(result.reason, "structured")

    def test_unknown_companion_mime_does_not_override_plain(self) -> None:
        result = classify(["text/plain", "application/x-example-metadata"])
        self.assertTrue(result.eligible)


if __name__ == "__main__":
    unittest.main()

