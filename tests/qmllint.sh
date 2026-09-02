#!/usr/bin/env bash
# El test de humo del QML: cada fichero se carga y sus tipos resuelven.
#
# Los componentes importan `qs.Commons` y `qs.Ui`, que Quickshell resuelve
# desde la raíz del shell y `qmllint` no conoce. Se le enseña con un
# directorio temporal en el que `qs` es un enlace al shell instalado, y a
# partir de ahí sí analiza de verdad. Sólo cuentan las categorías que
# significan «esto no arranca»: sintaxis, un tipo que no existe, un import
# que falla. Las demás —acceso sin cualificar, miembros que el linter no ve
# en un singleton dinámico— son ruido conocido y se enseñan, no se cuentan.
#
# Sin Omarchy o sin `qmllint` se dice y se sigue: es lo que pasa en la CI.
set -euo pipefail

OMAPLAIN_REPO_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$OMAPLAIN_REPO_DIR"

shell_dir="${OMARCHY_PATH:-/usr/share/omarchy}/shell"
lint=$(command -v qmllint || true)
[ -x "$lint" ] || lint=/usr/lib/qt6/bin/qmllint

if [ ! -d "$shell_dir/Commons" ] || [ ! -x "$lint" ]; then
  echo "qmllint: sin Omarchy o sin qmllint a mano; se omite el humo del QML." >&2
  exit 0
fi

imports=$(mktemp -d)
trap 'rm -rf "$imports"' EXIT
ln -s "$shell_dir" "$imports/qs"

output=$("$lint" -I "$imports" -I . -I components ./*.qml components/*.qml 2>&1 || true)
fatal=$(printf '%s\n' "$output" | grep -E '^Error:|\[(unresolved-type|import|missing-type|syntax|inheritance-cycle)\]' || true)

if [ -n "$fatal" ]; then
  echo "qmllint: el QML no carga entero:" >&2
  printf '%s\n' "$fatal" >&2
  exit 1
fi

count=$(printf '%s\n' "$output" | grep -c '^Warning:' || true)
echo "qmllint: $(ls ./*.qml components/*.qml | wc -l) ficheros cargan; $count avisos de estilo que no cuentan."
