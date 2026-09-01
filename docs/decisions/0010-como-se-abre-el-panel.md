# 0010 — Cómo se abre el panel

- Fecha: 1 de septiembre de 2026
- Estado: aceptada

## Contexto

Hasta la `0.2.0` el panel sólo se abría escribiendo un comando:

```sh
omarchy-shell shell summon io.github.r-bart.omaplain '{}'
```

Eso basta para desarrollar y no basta para nada más. Un plugin que se instala y
no se puede abrir no está instalado: está presente. El `manifest.json` declaraba
`service` y `panel`, y un `panel` sólo existe cuando alguien lo invoca, así que
no había ninguna superficie desde la que invocarlo.

## Decisión

**Dos entradas, ninguna obligatoria.**

### 1. Un widget de barra, que el usuario coloca

Se añade el `kind` `bar-widget` al manifiesto, con su punto de entrada. El clic
izquierdo hace `toggle` sobre el propio panel.

Declararlo lo hace **disponible**, no **colocado**. Omarchy ya decide eso en
`shell.json`, con `bar.layout.left`, `center` y `right`, donde el usuario pone
los ids que quiere ver; en un escritorio real ya conviven ahí ids de terceros.
De modo que «el icono es opcional» no necesita mecanismo propio: **ya lo es**, y
añadir un ajuste nuestro para encenderlo y apagarlo duplicaría el de la
plataforma y competiría con él.

### 2. Una entrada `.desktop`, para el lanzador

El «Apps menu» del menú de Omarchy enumera entradas `.desktop` a través de
`DesktopEntries`, así que una entrada estándar hace que OmaPlain se pueda abrir
escribiendo su nombre, como cualquier aplicación.

No se instala sola. El plugin vive en `~/.config/omarchy/plugins/`, que no está
en `XDG_DATA_DIRS`, así que copiarla es un paso del `README` y no un efecto
secundario de instalar el plugin. Un plugin de portapapeles que escribe en los
directorios de aplicaciones del usuario sin decirlo hace justo lo que este
proyecto promete no hacer.

## Descartado

**Un atajo global.** Es la vía más cómoda y la única que rompe una promesa ya
publicada: el `README` dice que OmaPlain **no modifica la configuración de
Hyprland** y que evita apropiarse de `Super+V` y `Super+Ctrl+V`, que son los
atajos nativos del portapapeles de Omarchy. Quien quiera uno lo añade a su
propia configuración, y el `README` sigue explicando cómo.

**Una entrada en el menú de Omarchy.** `MenuModel.js` es de primera parte y no
expone forma de que un plugin contribuya entradas. La vía `.desktop` llega al
mismo sitio sin tocar nada ajeno.

**Un ajuste «mostrar en la barra» dentro de nuestros ajustes.** Ver arriba: el
mando ya existe y es de la barra, no nuestro.

## Consecuencias

- El manifiesto pasa de dos `kinds` a tres. `omarchy plugin list` lo reflejará.
- El widget de barra **no lee el portapapeles ni recibe su contenido**: llama a
  `toggle` y nada más. La frontera de la `0005` no se mueve un milímetro.
- El clic derecho queda libre a propósito. `pasteClean` a un clic de distancia
  es tentador y es también la acción que escribe en el portapapeles; darle un
  gesto que se dispara sin querer merece su propia decisión.
