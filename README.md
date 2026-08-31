# OmaPlain

OmaPlain limpia texto del portapapeles en Omarchy: retira formato enriquecido, parámetros de seguimiento de URLs completas, finales de línea incompatibles y un conjunto conservador de caracteres invisibles. Archivos, imágenes, secretos marcados y formatos estructurales se dejan intactos.

La versión actual es `0.2.0`. Funciona enteramente en local, no tiene telemetría, no abre conexiones de red y no mantiene un historial propio.

## Funciones

- Limpieza automática de copias elegibles.
- Acción manual **Limpiar portapapeles ahora**.
- `pasteClean` para limpiar y pegar en la ventana capturada.
- Pausa y **Omitir la próxima copia** durante 60 segundos.
- Reglas independientes para formato, tracking, invisibles, finales de línea, comillas, viñetas, Unicode NFC y espacios finales.
- Exclusiones exactas por clase de aplicación, tanto de origen como de destino.
- Panel nativo de Omarchy Shell, operable con teclado y sin previsualizar contenido.
- Bienvenida de primera ejecución y tour de tres pasos, ambos revisables desde el panel.
- Bypass fail-open: ante una duda o error, conserva el portapapeles original.

OmaPlain no reemplaza el historial de Omarchy, no sincroniza dispositivos y no procesa la selección primaria de Wayland.

## Requisitos

- Omarchy con `omarchy-shell`.
- `wl-copy` y `wl-paste` de wl-clipboard.
- `hyprctl`.
- Python 3, solo biblioteca estándar.
- `setpriv` de util-linux.

El plugin comprueba estas dependencias al arrancar, pero nunca instala paquetes ni ejecuta `sudo`.

## Instalar

Mientras el plugin no esté publicado en el catálogo, se instala desde un clon local:

```sh
git clone https://github.com/r-bart/omaplain.git
omarchy plugin add ./omaplain --enable --yes
```

Abrir el panel:

```sh
omarchy-shell shell summon io.github.r-bart.omaplain '{}'
```

Al desarrollar, después de tocar cualquier `.qml` hay que reiniciar el shell:

```sh
omarchy restart shell
```

`omarchy-shell shell rescanPlugins` no basta. Vuelve a leer el registro de
plugins, pero Qt conserva el QML ya compilado para esa URL, así que el panel
sigue mostrando la versión anterior sin dar ningún error.

Comprobar el servicio:

```sh
omarchy-shell omaplain ping
omarchy-shell omaplain status
```

Desactivar, reactivar o retirar:

```sh
omarchy plugin disable io.github.r-bart.omaplain
omarchy plugin enable io.github.r-bart.omaplain
omarchy plugin remove io.github.r-bart.omaplain --yes
```

La desinstalación no borra el historial nativo ni instala/desinstala paquetes.

## Acciones IPC

```sh
omarchy-shell omaplain cleanNow
omarchy-shell omaplain pasteClean
omarchy-shell omaplain skipNext
omarchy-shell omaplain setAutomatic false
omarchy-shell omaplain setAutomatic true
omarchy-shell omaplain reload
```

Las acciones son asíncronas: la invocación devuelve `accepted` y el resultado sanitizado aparece en el panel y en `status`. Ninguna respuesta contiene texto copiado.

Un atajo global opcional puede invocar `omarchy-shell omaplain pasteClean`. OmaPlain no modifica la configuración de Hyprland y evita apropiarse de los atajos nativos `Super+V` y `Super+Ctrl+V`.

## Comportamiento seguro

El flujo es deliberadamente conservador:

```text
evento Wayland
  → clasificar estado y MIME
  → bypass si es sensible, imagen, archivo o estructura
  → leer como máximo 1 MiB de text/plain
  → transformar y validar invariantes
  → comprobar que el portapapeles no ha cambiado
  → como máximo una reescritura text/plain UTF-8
```

El daemon serializa eventos, usa generaciones monotónicas, compara antes de escribir y reconoce su propia reescritura mediante un hash efímero en memoria. Quickshell solo supervisa el proceso y nunca recibe el contenido.

Los ficheros de sesión viven en `$XDG_RUNTIME_DIR/omaplain/`: el directorio usa permisos `0700`, y configuración, estado y socket usan `0600`. El texto copiado no se persiste en ellos.

## Limitaciones conocidas

- Cuando una transformación cambia caracteres, el historial nativo puede conservar tanto el original como el resultado limpio. Desactiva tracking/invisibles o usa `pasteClean` si prefieres una acción explícita.
- Una contraseña copiada sin `CLIPBOARD_STATE=sensitive` ni un MIME de password manager es indistinguible de texto normal. Excluye la aplicación si no marca sus secretos.
- La atribución de aplicación de origen es best effort en Wayland. MIME y sensibilidad, no la clase, son las barreras de seguridad.
- LibreOffice anuncia formatos estructurales incluso junto a texto normal; `0.1.0` hace bypass conservador.
- Firefox no estaba instalado en el host de validación; su contrato `text/plain` + `text/html` está cubierto por fixture y por la copia real equivalente de Chromium.
- El soporte inicial es para el seat predeterminado.

Consulta la [matriz de compatibilidad](docs/COMPATIBILITY.md) y el [informe de pruebas](docs/TEST-REPORT.md) para el detalle.

## Privacidad

OmaPlain no realiza peticiones de red, no tiene analytics y no guarda contenido. El gestor de portapapeles incluido en Omarchy puede conservar texto en su historial, igual que antes de instalar este plugin. Esa persistencia pertenece a Omarchy.

Para reportar una vulnerabilidad, sigue [SECURITY.md](SECURITY.md) y no incluyas contenido real del portapapeles en el informe.

## Desarrollo y pruebas

```sh
tests/run.sh
```

La suite ejecuta tests unitarios y de propiedades, benchmark, soak acelerado de 28.800 eventos y el validador oficial. Las pruebas Wayland que modifican el portapapeles se documentan en [docs/TEST-REPORT.md](docs/TEST-REPORT.md).

Arquitectura y decisiones están desarrolladas en [SPEC.md](SPEC.md), [PLAN.md](PLAN.md) y [docs/decisions](docs/decisions).

## Licencia

Código bajo [GPL-3.0-or-later](LICENSE). Las tablas de reglas creadas para el proyecto se ofrecen bajo CC0-1.0; consulta [ATTRIBUTIONS.md](ATTRIBUTIONS.md).
