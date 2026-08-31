#!/usr/bin/env bash
set -euo pipefail

OMAPLAIN_REPO_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$OMAPLAIN_REPO_DIR"

export PYTHONPATH="$OMAPLAIN_REPO_DIR/helper"
python3 -m unittest discover -s tests/unit -q
tests/benchmark.py
tests/soak.py
omarchy plugin validate .
