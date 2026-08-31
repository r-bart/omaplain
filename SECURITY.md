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
