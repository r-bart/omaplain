# Seguridad

## Versiones soportadas

La rama `0.2.x` recibe correcciones de seguridad. La `0.1.x` ya no.

## Reportar un problema

No abras un informe que contenga contraseñas, tokens, URLs privadas, títulos de ventana ni texto real del portapapeles. Usa un payload sintético mínimo y describe:

- versión de OmaPlain y Omarchy;
- MIME types observados, sin contenido;
- aplicación y versión;
- resultado esperado y observado;
- si el contenido estaba marcado como sensible.

El repositorio vive en <https://github.com/r-bart/omaplain>. Para un problema de seguridad usa el informe privado de vulnerabilidades de GitHub sobre ese repositorio, no un issue público. Si esa vía no está disponible, abre un issue que diga sólo que hay un problema de seguridad y por dónde contactarte, sin ningún detalle, y el mantenedor te responderá por un canal privado.

## Garantías y frontera

OmaPlain no tiene red, telemetría ni persistencia propia de contenido. Hace bypass de secretos cuando Wayland o el MIME los marca. Una aplicación que publique una contraseña como texto normal sin ninguna señal no puede distinguirse de otro texto; debe excluirse por clase de aplicación.

Una precisión sobre «sin lectura». El watcher es `wl-paste --type text --watch`, y `wl-paste` entuba el contenido de cada copia de texto —también la marcada como sensible— al proceso efímero que avisa al demonio. Ese proceso no lee su entrada: sólo transmite `CLIPBOARD_STATE`. El demonio, que es quien clasifica, no llega a pedir el contenido de una copia sensible. Los bytes pasan por una tubería del núcleo entre `wl-paste` y un proceso que los descarta, y por ningún otro sitio.

## Qué se muestra en pantalla

Desde [`0005`](./docs/decisions/0005-previsualizacion-del-portapapeles.md) el
panel muestra el contenido del portapapeles y cómo quedaría. El contenido viaja
por el socket local `0600` de `$XDG_RUNTIME_DIR`, vive en memoria mientras el
panel está abierto, se olvida al cerrarlo y no se escribe en ningún sitio: ni
estado, ni configuración, ni log, ni notificación, ni traza de error.

Tres límites, por orden de importancia:

- **Lo marcado como sensible no se muestra nunca.** La negativa está en el
  helper, no en la interfaz: `peek` sobre ese contenido devuelve el motivo y los
  tipos MIME, jamás el texto, aunque el panel lo pida. No hay ajuste que lo
  cambie.
- **El contenido llega cubierto.** El panel es una superficie layer-shell y se
  abre encima de lo que estés compartiendo o grabando. Descubrirlo es un acto
  explícito y por elemento, y cambiar de portapapeles vuelve a cubrir. Mientras
  está cubierto, el texto tampoco está en el árbol de accesibilidad.
- **Compartir pantalla es el riesgo nuevo.** Si descubres el contenido durante
  una llamada o una grabación, lo estás enseñando. La cubierta por defecto
  reduce el accidente; no puede impedir la decisión.

Un secreto que su aplicación publique como texto normal, sin ninguna marca, es
indistinguible de cualquier otro texto y puede acabar visible en el panel.
Excluye esa aplicación por clase.
