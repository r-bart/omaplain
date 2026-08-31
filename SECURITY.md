# Seguridad

## Versiones soportadas

La rama `0.1.x` recibe correcciones de seguridad durante su validación comunitaria.

## Reportar un problema

No abras un informe que contenga contraseñas, tokens, URLs privadas, títulos de ventana ni texto real del portapapeles. Usa un payload sintético mínimo y describe:

- versión de OmaPlain y Omarchy;
- MIME types observados, sin contenido;
- aplicación y versión;
- resultado esperado y observado;
- si el contenido estaba marcado como sensible.

Hasta que exista un repositorio remoto con canal privado, conserva el informe localmente y contacta al mantenedor por un canal privado acordado. No hay una dirección de seguridad publicada todavía.

## Garantías y frontera

OmaPlain no tiene red, telemetría ni persistencia propia de contenido. Hace bypass de secretos cuando Wayland o el MIME los marca. Una aplicación que publique una contraseña como texto normal sin ninguna señal no puede distinguirse de otro texto; debe excluirse por clase de aplicación.

## Qué se muestra en pantalla

Desde [`0005`](./docs/decisions/0005-previsualizacion-del-portapapeles.md) el
panel muestra el contenido del portapapeles y cómo quedaría. El contenido viaja
por el socket local `0600` de `$XDG_RUNTIME_DIR`, vive en memoria mientras el
panel está abierto y no se escribe en ningún sitio: ni estado, ni configuración,
ni log, ni notificación, ni traza de error.

Tres límites, por orden de importancia:

- **Lo marcado como sensible no se muestra nunca.** La negativa está en el
  helper, no en la interfaz: `peek` sobre ese contenido devuelve el motivo y los
  tipos MIME, jamás el texto, aunque el panel lo pida. No hay ajuste que lo
  cambie.
- **El contenido llega cubierto.** El panel es una superficie layer-shell y se
  abre encima de lo que estés compartiendo o grabando. Descubrirlo es un acto
  explícito y por elemento, y cambiar de portapapeles vuelve a cubrir.
- **Compartir pantalla es el riesgo nuevo.** Si descubres el contenido durante
  una llamada o una grabación, lo estás enseñando. La cubierta por defecto
  reduce el accidente; no puede impedir la decisión.

Un secreto que su aplicación publique como texto normal, sin ninguna marca, es
indistinguible de cualquier otro texto y puede acabar visible en el panel.
Excluye esa aplicación por clase.

