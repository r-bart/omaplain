"""La matriz de compatibilidad, comprobada contra el clasificador.

`docs/COMPATIBILITY.md` lleva desde la `0.1` las ofertas MIME reales de cuatro
aplicaciones y, al lado, la decisión que OmaPlain toma con cada una. Los tipos
se recogieron copiando de verdad desde cada aplicación; eso no se puede repetir
sin una sesión gráfica y una persona delante.

Lo que sí se puede repetir en cada suite es la otra mitad: que **el
clasificador siga decidiendo lo que el documento dice que decide**. Un
documento que enumera decisiones y no las comprueba envejece igual que
envejeció el README, y aquí el coste de que envejezca es que la matriz diga
«bypass» de algo que hace meses dejó de serlo.

Así que este fichero no inventa casos: lee los bloques del documento y los pasa
por `classify`. Si alguien cambia una regla y no la matriz, o la matriz y no la
regla, se entera aquí.
"""

from __future__ import annotations

import re
import sys
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "helper"))

from omaplain_lib.classify import classify  # noqa: E402

MATRIZ = REPO / "docs" / "COMPATIBILITY.md"

# Lo que el documento dice de cada aplicación, en su tabla de arriba. La clave
# es el encabezado del bloque de tipos, para que las dos mitades del documento
# —la tabla y los tipos observados— se comprueben la una contra la otra.
ESPERADO = {
    "Chromium": (True, "text"),
    "Foot": (True, "text"),
    "Nautilus": (False, "files"),
    "LibreOffice Writer": (False, "structured"),
}

# Los tres casos que no tienen bloque de tipos porque no hace falta: se
# describen con una condición, no con una oferta.
SIN_BLOQUE = {
    "gestor de contraseñas": ((["text/plain"], "sensitive"), (False, "sensitive")),
    "captura de pantalla": (((["image/png"]), "data"), (False, "image")),
    "portapapeles vacío": (([], "data"), (False, "empty")),
}


def _bloques() -> dict[str, list[str]]:
    doc = MATRIZ.read_text(encoding="utf-8")
    fuera = {}
    for nombre, cuerpo in re.findall(r"### (.+?)\n\n```text\n(.*?)```", doc, re.DOTALL):
        tipos = [l.strip() for l in cuerpo.splitlines() if l.strip()]
        # LibreOffice anuncia un id interno con un sufijo variable; el
        # documento lo escribe con comodín y aquí se le da uno cualquiera.
        fuera[nombre] = [t.replace("*", "1234") for t in tipos]
    return fuera


class LaMatrizSigueSiendoCiertaTests(unittest.TestCase):
    def setUp(self) -> None:
        self.bloques = _bloques()

    def test_el_documento_trae_los_cuatro_bloques(self) -> None:
        # Si alguien retira uno, los `subTest` de abajo se quedarían sin caso
        # y este fichero pasaría en verde comprobando nada.
        self.assertEqual(set(self.bloques), set(ESPERADO))
        for nombre, tipos in self.bloques.items():
            with self.subTest(app=nombre):
                self.assertGreater(len(tipos), 1, "un bloque con un solo tipo no es una oferta real")

    def test_cada_oferta_observada_decide_lo_que_la_matriz_dice(self) -> None:
        for nombre, (elegible, razon) in ESPERADO.items():
            with self.subTest(app=nombre):
                decision = classify(self.bloques[nombre])
                self.assertEqual(decision.eligible, elegible)
                self.assertEqual(decision.reason, razon)

    def test_los_tres_casos_sin_oferta_tambien(self) -> None:
        for nombre, ((tipos, estado), (elegible, razon)) in SIN_BLOQUE.items():
            with self.subTest(caso=nombre):
                decision = classify(tipos, estado)
                self.assertEqual(decision.eligible, elegible)
                self.assertEqual(decision.reason, razon)

    def test_la_razon_que_decide_esta_escrita_en_la_tabla(self) -> None:
        # La tabla de arriba del documento y los bloques de abajo son dos
        # mitades del mismo dato, y estaban sin atar: se podía corregir una y
        # dejar la otra diciendo lo contrario.
        doc = MATRIZ.read_text(encoding="utf-8")
        tabla = doc.split("## MIME observados", 1)[0]
        for nombre, (elegible, razon) in ESPERADO.items():
            with self.subTest(app=nombre):
                fila = next((l for l in tabla.splitlines() if l.startswith(f"| {nombre.split()[0]}")), None)
                self.assertIsNotNone(fila, f"{nombre} no tiene fila en la tabla")
                if not elegible:
                    self.assertIn(razon, fila,
                                  f"la fila de {nombre} no nombra el bypass que provoca")

    def test_la_matriz_no_promete_un_trabajo_ya_hecho(self) -> None:
        # Decía «antes de la 1.0.0 se repetirá la matriz». Se repitió lo que se
        # puede repetir sin una persona copiando desde cada aplicación, y el
        # documento cuenta ahora qué mitad es cuál. Que no vuelva a quedar una
        # promesa en futuro dentro de un documento publicado.
        doc = MATRIZ.read_text(encoding="utf-8")
        self.assertNotIn("Antes de la `1.0.0` se repetirá", doc)


if __name__ == "__main__":
    unittest.main()
