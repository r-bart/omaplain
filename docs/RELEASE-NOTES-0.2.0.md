# OmaPlain 0.2.0

Segunda entrega local. La `0.1.0` limpiaba bien y no se dejaba mirar: enseñaba
una ilustración donde tenía que enseñar tu portapapeles, y sus nueve controles
estaban invisibles por un `import` que faltaba. Esta versión rehace el panel.

## Lo importante

- **Ves lo que tienes copiado y cómo quedaría**, cubierto por un vaho que
  levantas con el ojo o limpias con el dedo.
- **Decides qué aplicaciones no se destapan y cuáles no se leen siquiera.**
- **Está en inglés y en español**, con selector propio y `auto` desde el locale.
- **Con el portapapeles vacío enseña de qué va esto** con tres ejemplos reales
  en vez de dejar un hueco.
- **Puedes apagar el movimiento** desde los ajustes.
- Los nueve controles de la `0.1.0` ya se ven.

## Privacidad

El contenido del portapapeles puede llegar al panel, y no puede quedar escrito
en ninguna parte: ni estado, ni configuración, ni log, ni notificación, ni
traza, ni truncado. Mirar es inerte: no avanza la generación, no consume la
omisión, no reescribe el portapapeles y no toca el disco.

Comprobado en esta entrega con una muestra marcada perseguida por la respuesta
del socket, los ficheros de runtime, `status.json`, el journal del shell y la
configuración: aparece sólo donde tiene que aparecer.

## Limitaciones que debes conocer

- **La identificación del origen en Wayland es best effort.** Las listas de
  privacidad bloquean cuando OmaPlain reconoce la ventana de origen. Es un buen
  filtro; no es una barrera de seguridad. Lo que la aplicación marca como
  sensible sí está cubierto sin depender de ninguna atribución.
- **El historial nativo de Omarchy puede conservar el original** además de la
  versión limpia cuando una regla cambia caracteres. El panel lo explica.
- **Los secretos que una aplicación publique como texto normal** no se pueden
  detectar de forma fiable: añade esa aplicación a la lista de no leer.
- **Compartir pantalla.** El panel enseña tu portapapeles en cuanto lo abres, y
  aunque llega cubierto, el ojo lo destapa. Si estás compartiendo pantalla o
  grabando, ten en cuenta que ese contenido queda a la vista de quien mira.

## Verificación

La suite de `tests/run.sh` entera —256 tests al cerrar la versión—, el validador oficial de plugins, un
benchmark y un soak acelerado de 28.800 eventos. Consulta
[TEST-REPORT-0.2.0.md](notes/TEST-REPORT-0.2.0.md) para el detalle, incluido lo que **no** se ha
podido comprobar.
