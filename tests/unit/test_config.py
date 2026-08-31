from __future__ import annotations

import json
import os
import tempfile
import unittest
from pathlib import Path

from omapaste_lib.config import DEFAULTS, load_config, validate_config, write_config


class ConfigTests(unittest.TestCase):
    def test_partial_config_gets_defaults(self) -> None:
        config, warnings = validate_config({"automatic": False})
        self.assertFalse(config["automatic"])
        self.assertTrue(config["stripFormatting"])
        self.assertEqual(warnings, [])

    def test_invalid_values_fail_to_defaults(self) -> None:
        config, warnings = validate_config({
            "automatic": "yes",
            "maxBytes": True,
            "sourceExclusions": ["ok", "bad\nclass"],
        })
        self.assertEqual(config["automatic"], DEFAULTS["automatic"])
        self.assertEqual(config["maxBytes"], DEFAULTS["maxBytes"])
        self.assertEqual(config["sourceExclusions"], [])
        self.assertEqual(warnings, ["automatic", "maxBytes", "sourceExclusions"])

    def test_exclusions_are_exact_and_deduplicated(self) -> None:
        config, _ = validate_config({"targetExclusions": ["foot", "foot", "Foot"]})
        self.assertEqual(config["targetExclusions"], ["foot", "Foot"])

    def test_secure_atomic_write(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "private" / "config.json"
            warnings = write_config(path, {"automatic": False})
            self.assertEqual(warnings, [])
            self.assertEqual(os.stat(path).st_mode & 0o777, 0o600)
            self.assertEqual(os.stat(path.parent).st_mode & 0o777, 0o700)
            config, read_warnings = load_config(path)
            self.assertFalse(config["automatic"])
            self.assertEqual(read_warnings, [])

    def test_corrupt_file_returns_safe_defaults(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "config.json"
            path.write_text("{", encoding="utf-8")
            config, warnings = load_config(path)
            self.assertEqual(config["automatic"], DEFAULTS["automatic"])
            self.assertEqual(warnings, ["config"])


if __name__ == "__main__":
    unittest.main()

