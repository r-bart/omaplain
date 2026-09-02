"""«Cero red en runtime», comprobado y no sólo afirmado.

El SPEC marcaba como hecho un test de red que no existía. Éste mira dos
cosas: que ningún módulo del helper importe nada que hable con la red, y
que el único socket que se crea sea de dominio Unix.
"""

from __future__ import annotations

import ast
import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[2]
HELPER = REPO / "helper" / "omaplain_lib"

NETWORK_MODULES = {
    "urllib.request", "urllib.error", "http", "http.client", "ftplib", "smtplib",
    "requests", "httpx", "aiohttp", "ssl", "socketserver", "asyncio", "xmlrpc",
}


class NoNetworkTests(unittest.TestCase):
    def modules(self) -> list[Path]:
        files = sorted(HELPER.glob("*.py")) + [REPO / "helper" / "omaplain"]
        self.assertGreater(len(files), 5)
        return files

    def test_no_helper_module_imports_a_network_library(self) -> None:
        for path in self.modules():
            tree = ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
            imported: set[str] = set()
            for node in ast.walk(tree):
                if isinstance(node, ast.Import):
                    imported.update(alias.name for alias in node.names)
                elif isinstance(node, ast.ImportFrom) and node.module:
                    imported.add(node.module)
            with self.subTest(module=path.name):
                self.assertEqual(sorted(imported & NETWORK_MODULES), [])

    def test_the_only_sockets_are_unix_domain(self) -> None:
        for path in self.modules():
            source = path.read_text(encoding="utf-8")
            with self.subTest(module=path.name):
                self.assertNotIn("AF_INET", source)
                self.assertNotIn("create_connection", source)
                self.assertNotIn("getaddrinfo", source)
                if "socket.socket(" in source:
                    self.assertEqual(source.count("socket.socket("), source.count("socket.AF_UNIX"))


if __name__ == "__main__":
    unittest.main()
