# 0002 — Enviar el pegado con el dispatcher Lua de Hyprland

- Estado: aceptada
- Fecha: 31 de agosto de 2026

## Contexto

Hyprland 0.56 migró sus dispatchers al API Lua. La sintaxis legacy `hyprctl dispatch sendshortcut ...` falla en el baseline. Además, una ventana distinta podría ganar el foco mientras se limpia el clipboard.

## Decisión

`pasteClean` captura primero la dirección hexadecimal de la ventana y después invoca:

```text
hyprctl eval hl.dispatch(hl.dsp.send_shortcut(... window = "address:0x..."))
```

El helper espera 120 ms para que se liberen los modificadores físicos del atajo global y selecciona `Shift+Insert` para ventanas con tag `terminal`; las demás reciben `Ctrl+V`.

Los únicos valores interpolados son el address validado con una expresión hexadecimal y literales de teclas elegidos por el programa. El contenido del portapapeles nunca forma parte del comando.

## Consecuencias

- El pegado llega al target original aunque cambie el foco.
- No se añade una dependencia de `wtype`.
- Una versión futura de Hyprland puede requerir adaptar esta frontera, cubierta por tests de integración.
