#!/usr/bin/env bash
set -euo pipefail

OMAPLAIN_REPO_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$OMAPLAIN_REPO_DIR"

export PYTHONPATH="$OMAPLAIN_REPO_DIR/helper"

# Un `ResourceWarning` es un fallo: así es como se ven los directorios
# temporales que un test deja abiertos, y así es como se quedaron tres sin
# que nadie lo viera hasta la 0.2.0.
python3 -W error::ResourceWarning -m unittest discover -s tests/unit -q
tests/benchmark.py
tests/soak.py

# El validador de Omarchy y `qmllint` sólo existen con Omarchy instalado.
# Sin él se dice y se sigue: la CI es la misma suite y no tiene Omarchy.
if command -v omarchy > /dev/null 2>&1; then
  omarchy plugin validate .
else
  echo "omarchy no está instalado: se omite «omarchy plugin validate»." >&2
fi
