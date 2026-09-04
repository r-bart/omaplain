# 0021 — El clic derecho de la barra queda libre, y para siempre

- Fecha: 4 de septiembre de 2026
- Estado: aceptada el 4 de septiembre de 2026
- Cierra el pendiente que dejó abierto la
  [`0010`](./0010-como-se-abre-el-panel.md) y el `C.2` de
  [`PLAN-1.0.md`](../../PLAN-1.0.md)

## Contexto

La [`0010`](./0010-como-se-abre-el-panel.md) puso el icono en la barra y le dio
al clic izquierdo el `toggle` del panel. Del derecho dijo esto y no más:

> El clic derecho queda libre a propósito. `pasteClean` a un clic de distancia
> es tentador y es también la acción que escribe en el portapapeles; darle un
> gesto que se dispara sin querer merece su propia decisión.

Ésta es esa decisión, y llega porque una `1.0` promete que lo que hay no cambia
debajo ([`PLAN-1.0.md`](../../PLAN-1.0.md), `C.1`). Un gesto que hoy no hace
nada y mañana escribe en el portapapeles es exactamente el tipo de cambio que
esa promesa existe para impedir; y al revés, un gesto que la `1.0` estrena ya no
se puede retirar sin romperla. Se decide ahora o se hereda sin decidir.

## Qué hace hoy la barra con el clic derecho

Los cinco widgets del shell que lo usan, leídos en la instalación
(`/usr/share/omarchy/shell/`):

| Widget | Clic derecho | ¿Se deshace? |
|---|---|---|
| `menu` | Abre un terminal | Se cierra |
| `clock` | Cambia el formato de la hora | Se vuelve a cambiar |
| `weather` | Lanza una notificación con el parte | Se va sola |
| `media` | Abre el desplegable del reproductor | Se cierra |
| `ActiveWindow` | **Cierra la ventana enfocada** | **No** |

Cuatro de los cinco comparten una regla que nadie escribió y que se lee sola:
el derecho es **una segunda acción barata y reversible**. Ninguna toca datos
del usuario, y de las cuatro se sale mirando a otro lado.

La quinta es la excepción, y conviene mirarla despacio porque es el caso que
nos ocupa con otro nombre. En `ActiveWindow`, un clic derecho —o uno medio, que
hace lo mismo— cierra la ventana que tienes delante, sin confirmar, desde una
tira de la barra que está a unos píxeles del reloj. Es un fallo del ratón entre
perder un rato de trabajo y no perderlo. No es una convención que seguir: es la
demostración de qué pasa cuando un gesto que se dispara sin querer lleva colgada
una acción que no se deshace.

## Decisión

**El clic derecho del icono no hace nada, y así se queda.**

No es «todavía no lo hemos decidido». Es lo decidido, y con motivo:

**`pasteClean` es la acción menos reversible que tiene OmaPlain.** Reescribe el
portapapeles del usuario, y al reescribirlo **el original deja de existir** —no
hay historial propio del que recuperarlo, por decisión de producto: OmaPlain no
persiste el contenido en ningún sitio. Quien copia una URL con sus parámetros
de seguimiento, roza el icono de la barra y pega, ya no tiene la URL original.
Ni un aviso, ni una vuelta atrás, y probablemente ni la sospecha de que ha
pasado algo: la acción no abre ninguna ventana.

**El gesto se dispara solo más de lo que parece.** Un clic derecho fallado en
una tira de iconos de 26 px de alto, un dos dedos del panel táctil, la tecla de
menú contextual del teclado, y en un ratón para zurdos sin configurar es el
botón principal. Ninguno de esos casos avisa antes.

**Y no hace falta.** La acción ya tiene tres vías, todas con la mano puesta
encima: el botón del panel, `omarchy-shell omaplain pasteClean` desde el
terminal, y el modo automático, que es la respuesta de verdad a «quiero pegar
limpio sin pensarlo» y no le pide al usuario ni un clic. Colgarla del derecho
no resuelve un problema, añade una cuarta puerta a una habitación que ya tiene
tres, y le quita el pomo.

**La opción sin coste tampoco vale.** Se pensó en colgarle algo inofensivo
—pausar el automático, abrir los ajustes— para no «desperdiciar» el gesto. Un
gesto invisible no se desperdicia: no hay nada en la interfaz que prometa que
ahí hay algo, así que nadie lo echa de menos. Lo que sí cuesta es lo contrario:
un usuario que aprende que el derecho pausa el automático es un usuario al que
un roce le apaga la vigilancia sin decírselo, y OmaPlain apagado se parece
mucho a OmaPlain funcionando.

## Lo que se descartó

- **Colgarle `pasteClean`.** Todo lo de arriba. Es la opción cómoda y la única
  que convierte un roce en una escritura irreversible del portapapeles ajeno.
- **Un menú contextual.** Es la respuesta correcta en otra aplicación: un menú
  se lee antes de elegir, así que ningún roce ejecuta nada. Aquí cuesta un
  componente, sus cadenas en dos idiomas, su orden de foco, su cierre al perder
  el foco y sus pruebas — y todo eso para llegar a las mismas acciones que
  están a un clic izquierdo de distancia, en un panel que ya existe y que ya se
  abre desde ese mismo icono. Si algún día hay una acción que **no** quepa en
  el panel, se reabre esta decisión; hoy no la hay.
- **Dejarlo escrito como «pendiente».** Es lo que había, y es lo que una `1.0`
  no puede llevar dentro: cualquier cosa que se le cuelgue después es un cambio
  de comportamiento en un gesto que el usuario ya habrá aprendido que está
  muerto.

## Consecuencias

- `BarWidget.qml` mantiene su guarda —`if (mouseButton === Qt.RightButton)
  return`— y el comentario pasa de «merece su propia decisión» a apuntar aquí.
- El README ya lo dice en esas palabras: *«Right click deliberately does
  nothing»*. Deja de ser una descripción del estado actual y pasa a ser parte
  de la promesa de la `1.0`.
- `tests/unit/test_launch_surfaces.py` lo sujeta: el widget rechaza el botón
  derecho, y ni `pasteClean` ni ninguna otra acción de escritura aparece en el
  fichero. Un test que sólo mirase el `return` pasaría en verde con un
  `pasteClean` escrito dos líneas más arriba.
- La frontera de la [`0005`](./0005-previsualizacion-del-portapapeles.md) no se
  mueve: el widget de barra sigue sin leer el portapapeles y sin recibir su
  contenido.
