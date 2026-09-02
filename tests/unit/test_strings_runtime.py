"""El catálogo ejecutado, no leído.

`Strings.js` es JavaScript sin dependencias, así que se puede correr con
`node` tal cual —quitando la directiva `.pragma`, que es de Qt— y preguntar
a `t`, `f` y `fromLocale` lo que hacen, en vez de buscar en el fuente la
línea que se supone que lo hace. Sin `node` los tests se saltan diciéndolo.
"""

from __future__ import annotations

import json
import shutil
import subprocess
import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[2]
CATALOGUE = REPO / "components" / "Strings.js"

PROBE = r"""
const fs = require("fs");
const vm = require("vm");
const source = fs.readFileSync(process.argv[1], "utf8").replace(/^\.pragma library\s*$/m, "");
const context = {};
vm.createContext(context);
vm.runInContext(source, context);
const { t, f, fromLocale, keys, languages } = context;
const out = {
  known: t("nav.back", "en"),
  knownEs: t("nav.back", "es"),
  missingKey: t("no.such.key", "es"),
  onlyEnglish: (() => { context.ES.__probe = undefined; return t("nav.back", "es"); })(),
  ordered: f("rule.removed.a11y", "en", "A", "B"),
  dollar: f("row.show", "en", "$& $1 $` %2"),
  nested: f("rule.removed.a11y", "en", "%2", "second"),
  missingArg: f("rule.removed.a11y", "en", "only"),
  locales: ["es_ES.UTF-8", "es", "ES", "en_US", "ca_ES", "", null].map(fromLocale),
  languages: languages(),
  keyCount: keys().length,
};
process.stdout.write(JSON.stringify(out));
"""


@unittest.skipIf(shutil.which("node") is None, "node no está instalado")
class RuntimeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        result = subprocess.run(
            ["node", "-e", PROBE, str(CATALOGUE)],
            capture_output=True, text=True, timeout=30, check=True,
        )
        cls.out = json.loads(result.stdout)

    def test_lookup_falls_back_to_english_and_then_to_the_key(self) -> None:
        self.assertEqual(self.out["known"], "Back")
        self.assertEqual(self.out["knownEs"], "Volver")
        self.assertEqual(self.out["missingKey"], "no.such.key")

    def test_placeholders_are_filled_in_order(self) -> None:
        self.assertEqual(self.out["ordered"], "Removed: A, under the B setting")

    def test_arguments_are_inserted_verbatim(self) -> None:
        # Un argumento con `$&` o `%2` se pega tal cual: una clase de
        # ventana la pone la aplicación, no nosotros.
        self.assertEqual(self.out["dollar"], "Show $& $1 $` %2")
        self.assertEqual(self.out["nested"], "Removed: %2, under the second setting")

    def test_a_missing_argument_leaves_its_placeholder(self) -> None:
        self.assertEqual(self.out["missingArg"], "Removed: only, under the %2 setting")

    def test_the_locale_maps_to_one_of_the_two(self) -> None:
        self.assertEqual(self.out["locales"], ["es", "es", "es", "en", "en", "en", "en"])
        self.assertEqual(self.out["languages"], ["en", "es"])
        self.assertGreater(self.out["keyCount"], 100)


if __name__ == "__main__":
    unittest.main()
