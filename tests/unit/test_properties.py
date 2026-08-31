from __future__ import annotations

import random
import string
import unittest

from omaplain_lib.config import DEFAULTS
from omaplain_lib.transform import clean_tracking_url, transform


class PropertyTests(unittest.TestCase):
    def setUp(self) -> None:
        self.config = dict(DEFAULTS)
        self.random = random.Random(0x0A5A57E)

    def test_default_transform_is_idempotent_for_diverse_unicode(self) -> None:
        alphabet = (
            string.ascii_letters
            + string.digits
            + " \t\n"
            + "👨‍👩‍👧‍👦🧑🏽‍💻 می‌روم العربية עברית हिन्दी ไทย 漢字 ∑≈≠"
            + "\u00ad\u200b\u2060\ufeff"
        )
        for _ in range(1_000):
            source = "".join(self.random.choice(alphabet) for _ in range(self.random.randrange(1, 256)))
            first = transform(source.encode("utf-8"), "text/plain;charset=utf-8", self.config)
            second = transform(first.output, "text/plain;charset=utf-8", self.config)
            self.assertEqual(second.output, first.output)

    def test_signed_url_fuzz_never_changes_bytes(self) -> None:
        signed_keys = ("Signature", "sig", "token", "X-Amz-Signature", "access_token", "hmac")
        for _ in range(500):
            key = self.random.choice(signed_keys)
            value = "".join(self.random.choice(string.ascii_letters + string.digits) for _ in range(24))
            source = f"https://example.com/a%2Fb?{key}={value}&utm_source=test#frag"
            self.assertEqual(clean_tracking_url(source), source)

    def test_tracking_cleanup_preserves_host_path_fragment_and_functional_order(self) -> None:
        for index in range(500):
            source = (
                f"https://Example.com/a%2Fb/{index}?a=1&utm_campaign=x&a=2&"
                f"keep={index}%2Fz#fragment-{index}"
            )
            expected = f"https://Example.com/a%2Fb/{index}?a=1&a=2&keep={index}%2Fz#fragment-{index}"
            self.assertEqual(clean_tracking_url(source), expected)


if __name__ == "__main__":
    unittest.main()
