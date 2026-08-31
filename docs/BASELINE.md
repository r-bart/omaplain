# Baseline técnico

Registrado el 31 de agosto de 2026 sobre la máquina de desarrollo de OmaPaste.

| Componente | Versión o valor |
|---|---|
| Omarchy | 4.0.1-1 |
| Quickshell | 0.3.1 |
| Hyprland | 0.56.2 |
| wl-clipboard | 2.3.0 |
| Python | 3.14.7 |
| util-linux `setpriv` | 2.42.2 |
| Sesión | Wayland, Hyprland, `wayland-1` |
| Clipboard nativo | Dos watchers: texto e imagen |

## Dependencias

`helper/omapaste check-dependencies` confirma la disponibilidad de:

- `wl-copy`
- `wl-paste`
- `hyprctl`
- `setpriv`
- `python3`

No existe ninguna dependencia de red, paquete Python externo, entorno virtual o proceso privilegiado.

## Límites confirmados

- `wl-copy` solo puede publicar un MIME type propio a la vez. Al publicar texto añade aliases de interoperabilidad, pero no puede conservar simultáneamente HTML o RTF.
- `wl-paste --watch` expone `CLIPBOARD_STATE`; el estado sensible se produce al detectar `x-kde-passwordManagerHint`.
- Omarchy mantiene su historial con watchers separados de texto e imagen y deduplica texto idéntico.
- Hyprland 0.56 usa dispatchers Lua. El envío estable es `hyprctl eval` con `hl.dsp.send_shortcut`, nunca la sintaxis legacy de `hyprctl dispatch sendshortcut`.

## Regla de desarrollo

Todo el código vive en este repositorio. Las lecturas de `/usr/share/omarchy/` se usan como referencia, pero ningún test o instalación modifica esa ruta.

