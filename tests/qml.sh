#!/usr/bin/env bash
# Ejecuta el QML de verdad, dentro de un compositor de mentira.
#
# Los tipos de Quickshell viven enlazados dentro de su binario —su `qmldir`
# dice `linktarget quickshell-coreplugin`—, así que `qmltestrunner` no puede
# cargarlos, y `qs.Commons` importa Quickshell. La única forma de ejecutar
# nuestros componentes es `quickshell`, y `quickshell` necesita un
# compositor Wayland. Así que se levanta un Hyprland headless, se corre la
# raíz de prueba dentro, y se apaga.
#
# Sin Hyprland o sin quickshell se dice y se sigue, como el resto de pasos
# que dependen de Omarchy.
set -uo pipefail

OMAPLAIN_REPO_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$OMAPLAIN_REPO_DIR"

if ! command -v Hyprland > /dev/null 2>&1 || ! command -v quickshell > /dev/null 2>&1; then
  echo "qml.sh: sin Hyprland o sin quickshell; se omite la ejecución del QML." >&2
  exit 0
fi

# El compositor de prueba se anida dentro de la sesión que ya hay: usa el
# backend Wayland del padre. Sin sesión padre no arranca —su backend
# headless pide permisos de DRM que una CI no tiene—, así que ahí se omite,
# como el validador y `qmllint`.
if [ -z "${WAYLAND_DISPLAY:-}" ] || [ ! -e "${XDG_RUNTIME_DIR:-/nonexistent}/$WAYLAND_DISPLAY" ]; then
  echo "qml.sh: sin sesión Wayland en la que anidar; se omite la ejecución del QML." >&2
  exit 0
fi

# Quickshell resuelve `qs.X` contra el directorio de la raíz que se le pasa,
# no contra `QML_IMPORT_PATH`. Así que la raíz de prueba se monta con la
# forma que los componentes esperan: los módulos del shell colgando al lado,
# y `components` enlazado desde el repositorio.
shell_dir="${OMARCHY_PATH:-/usr/share/omarchy}/shell"
trabajo=$(mktemp -d)
raiz="$trabajo/root"
mkdir -p "$raiz"
for modulo in "$shell_dir"/*/; do
  ln -s "$modulo" "$raiz/$(basename "$modulo")"
done
ln -s "$OMAPLAIN_REPO_DIR/components" "$raiz/components"
sed 's|"\.\./\.\./components"|"components"|' "$OMAPLAIN_REPO_DIR/tests/qml/TestRoot.qml" > "$raiz/TestRoot.qml"

hyprland_pid=""
quickshell_pid=""
limpiar() {
  [ -n "$quickshell_pid" ] && kill "$quickshell_pid" 2> /dev/null
  [ -n "$hyprland_pid" ] && kill "$hyprland_pid" 2> /dev/null
  wait 2> /dev/null
  rm -rf "$trabajo"
}
trap limpiar EXIT

printf 'misc {\n  disable_hyprland_logo = true\n  disable_splash_rendering = true\n}\n' > "$trabajo/hypr.conf"

# El anidado no hereda la instancia del Hyprland real, para que `hyprctl` y
# la propia sesión de prueba no hablen con el de verdad.
antes=$(ls "$XDG_RUNTIME_DIR" | grep -cE '^wayland-[0-9]+$' || true)
env -u HYPRLAND_INSTANCE_SIGNATURE \
  Hyprland -c "$trabajo/hypr.conf" > "$trabajo/hypr.log" 2>&1 &
hyprland_pid=$!

for _ in $(seq 1 60); do
  sleep 0.25
  ahora=$(ls "$XDG_RUNTIME_DIR" | grep -cE '^wayland-[0-9]+$' || true)
  [ "$ahora" -gt "$antes" ] && break
done
if [ "$ahora" -le "$antes" ]; then
  echo "qml.sh: el compositor de prueba no llegó a arrancar." >&2
  tail -5 "$trabajo/hypr.log" >&2
  exit 1
fi

pantalla=$(ls "$XDG_RUNTIME_DIR" | grep -E '^wayland-[0-9]+$' | sort -V | tail -1)
firma=$(ls -t "$XDG_RUNTIME_DIR/hypr" | head -1)

salida="$trabajo/salida.log"

# El resultado se lee de la salida, no del código: Quickshell no atiende
# `Qt.exit` ni sale con `Quickshell.quit()`, y atar la suite a ese detalle
# de su API sería peor. La raíz imprime una línea `RESULTADO`, y ése es el
# contrato entre los dos ficheros.
HYPRLAND_INSTANCE_SIGNATURE="$firma" WAYLAND_DISPLAY="$pantalla" \
  quickshell -p "$raiz/TestRoot.qml" > "$salida" 2>&1 &
quickshell_pid=$!

for _ in $(seq 1 160); do
  sleep 0.25
  grep -q "RESULTADO" "$salida" 2> /dev/null && break
done

# Quickshell escribe sus propias líneas con nivel y con color, y el color
# se cuela **entre** `qml` y los dos puntos, así que hay que quitar los
# escapes antes de filtrar: sin eso el filtro no casaba nada y la suite
# pasaba en verde sin enseñar una sola comprobación.
sed 's/\x1b\[[0-9;]*m//g' "$salida" | sed -n 's/.*\bqml: \{0,1\}//p'

if ! grep -q "RESULTADO" "$salida" 2> /dev/null; then
  echo "qml.sh: la raíz de prueba no llegó a dar un resultado." >&2
  grep -iE "error|unresolvable" "$salida" | head -10 >&2
  exit 1
fi
if grep -q "FALLOS" "$salida"; then
  exit 1
fi
