#!/usr/bin/env python3
"""Mide dos contrastes del kit de Omarchy sobre todos los temas instalados.

Es la herramienta que sostiene los números de `UPSTREAM-2026-09-04.md`. No es
parte de OmaPlain: no la llama la suite, no la importa nadie, y sólo lee. Vive
aquí para que quien reciba el informe pueda repetir la medición en su máquina
en vez de creerse una tabla.

Lo que mide, y contra qué criterio:

1. `placeholderTextColor: Qt.darker(foreground, 1.6)`
   — `shell/Ui/TextField.qml`. Es texto, así que le aplica el 4,5:1 de la
   WCAG 2.1 SC 1.4.3 (AA).

2. El borde en reposo de un control, `Util.alpha(foreground, 0.4)` sobre el
   relleno `Util.alpha(foreground, 0.04)` — `normal-border-alpha` y
   `normal-fill-alpha` de `default/themed/shell.toml.tpl`. Es el contorno de
   un componente de interfaz, así que le aplica el 3:1 de la SC 1.4.11.

Uso:

    python3 docs/notes/contraste-del-kit.py
    python3 docs/notes/contraste-del-kit.py --csv

Los temas se leen de `/usr/share/omarchy/themes/*/colors.toml` y de
`~/.config/omarchy/themes/*/`. Un tema que trae su propio `shell.toml` manda
sobre la plantilla, y se lee de ahí.
"""

from __future__ import annotations

import argparse
import colorsys
import glob
import os
import re
import sys

# Los dos valores por defecto de `default/themed/shell.toml.tpl`. Un tema con
# `shell.toml` propio puede cambiarlos, y entonces se leen del tema.
NORMAL_BORDER_ALPHA = 0.4
NORMAL_FILL_ALPHA = 0.04

# El factor de `Qt.darker` en `Ui/TextField.qml`.
PLACEHOLDER_FACTOR = 1.6

AA_TEXTO = 4.5      # WCAG 2.1 SC 1.4.3
AA_CONTORNO = 3.0   # WCAG 2.1 SC 1.4.11


def a_rgb(h: str) -> tuple[float, float, float]:
    h = h.strip().lstrip("#")
    if len(h) == 8:  # AARRGGBB o RRGGBBAA: nos quedamos con los seis primeros
        h = h[:6]
    if len(h) != 6:
        raise ValueError(h)
    return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))


def a_hex(c: tuple[float, float, float]) -> str:
    return "#" + "".join("%02x" % round(max(0.0, min(1.0, x)) * 255) for x in c)


def _lineal(c: float) -> float:
    return c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4


def luminancia(c: tuple[float, float, float]) -> float:
    r, g, b = (_lineal(x) for x in c)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contraste(a, b) -> float:
    la, lb = luminancia(a), luminancia(b)
    return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)


def sobre(color, alfa: float, fondo):
    """Lo que se ve al pintar `color` con alfa sobre `fondo`, que es lo que
    hace `Util.alpha`: devuelve un ARGB y el compositor lo mezcla."""
    return tuple(color[i] * alfa + fondo[i] * (1 - alfa) for i in range(3))


def qt_darker(c, factor: float):
    """`Qt.darker`: divide el valor de HSV. Nótese que sólo mira al color que
    recibe — el fondo no entra en la cuenta, que es el fondo del asunto."""
    h, s, v = colorsys.rgb_to_hsv(*c)
    return colorsys.hsv_to_rgb(h, s, v / factor)


def claves(ruta: str) -> dict[str, str]:
    fuera: dict[str, str] = {}
    seccion = None
    with open(ruta, encoding="utf-8") as f:
        for linea in f:
            linea = linea.strip()
            if linea.startswith("#"):
                continue
            m = re.match(r"^\[([\w-]+)\]", linea)
            if m:
                seccion = m.group(1)
                continue
            # El valor va entre comillas o desnudo. Entre comillas se toma
            # entero —un color empieza por `#`, que fuera de las comillas
            # abre un comentario—; desnudo se corta en el primer `#`.
            m = re.match(r'^([\w-]+)\s*=\s*(?:"([^"]*)"|([^#\n]*))', linea)
            if m:
                valor = m.group(2) if m.group(2) is not None else (m.group(3) or "")
                clave = f"{seccion}.{m.group(1)}" if seccion else m.group(1)
                fuera[clave] = valor.strip()
    return fuera


def temas() -> list[tuple[str, dict[str, str]]]:
    rutas = sorted(
        glob.glob("/usr/share/omarchy/themes/*")
        + glob.glob(os.path.expanduser("~/.config/omarchy/themes/*"))
    )
    fuera = []
    for d in rutas:
        nombre = os.path.basename(d)
        propio, colores = os.path.join(d, "shell.toml"), os.path.join(d, "colors.toml")
        if os.path.isfile(propio):
            k = claves(propio)
            k.setdefault("foreground", k.get("popups.text", ""))
            k.setdefault("background", k.get("popups.background", ""))
            fuera.append((nombre, k))
        elif os.path.isfile(colores):
            fuera.append((nombre, claves(colores)))
    return fuera


def medir(k: dict[str, str]):
    fg, bg = a_rgb(k["foreground"]), a_rgb(k["background"])
    nb = float(k.get("controls.normal-border-alpha", NORMAL_BORDER_ALPHA))
    nf = float(k.get("controls.normal-fill-alpha", NORMAL_FILL_ALPHA))

    pista = qt_darker(fg, PLACEHOLDER_FACTOR)
    relleno = sobre(fg, nf, bg)
    borde = sobre(fg, nb, relleno)
    return {
        "modo": k.get("mode", "?"),
        "placeholder": contraste(pista, bg),
        "placeholder_color": a_hex(pista),
        "borde": contraste(borde, relleno),
        "borde_color": a_hex(borde),
    }


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("--csv", action="store_true", help="salida para pegar en una hoja")
    args = p.parse_args()

    filas = []
    for nombre, k in temas():
        if not k.get("foreground") or not k.get("background"):
            continue
        try:
            filas.append((nombre, medir(k)))
        except ValueError:
            continue

    if not filas:
        print("no se encontró ningún tema de Omarchy en esta máquina", file=sys.stderr)
        return 1

    if args.csv:
        print("tema,modo,placeholder,borde-en-reposo")
        for n, m in filas:
            print("%s,%s,%.2f,%.2f" % (n, m["modo"], m["placeholder"], m["borde"]))
        return 0

    print("%-22s %-6s %-22s %-22s" % ("tema", "modo", "placeholder (≥ 4,5)", "borde reposo (≥ 3)"))
    print("-" * 74)
    malos_p = malos_b = 0
    for n, m in filas:
        p_ok = m["placeholder"] >= AA_TEXTO
        b_ok = m["borde"] >= AA_CONTORNO
        malos_p += not p_ok
        malos_b += not b_ok
        print("%-22s %-6s %-22s %-22s" % (
            n, m["modo"],
            "%s %.2f:1" % ("  " if p_ok else "←", m["placeholder"]),
            "%s %.2f:1" % ("  " if b_ok else "←", m["borde"]),
        ))
    print("-" * 74)
    print("placeholder por debajo de %.1f:1 en %d de %d temas" % (AA_TEXTO, malos_p, len(filas)))
    print("borde en reposo por debajo de %.0f:1 en %d de %d temas" % (AA_CONTORNO, malos_b, len(filas)))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
