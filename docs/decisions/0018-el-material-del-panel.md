# 0018 — El material del panel: cristal, halo y grano

- Fecha: 3 de septiembre de 2026
- Estado: aceptada
- Fija el material que estrena el porte del paquete de diseño, y enmienda el
  guarda `test_only_the_bypass_states_get_the_drawing`

## Contexto

El paquete de diseño llega con una receta de superficie —«el cristal»— que usan
todos los activos nuevos: un relleno degradado, un borde tenue, una sombra
proyectada, un filo claro de 1 px arriba y un brillo interior que muere a media
altura. Y con dos piezas más que hoy no existen: un halo radial de acento
detrás de cada ilustración, y un grano de tres capas que dice que el control
**no lee** la tarjeta que pasa.

Tres de sus indicaciones no se pueden seguir tal cual, y una cuarta afecta a un
test. Van juntas porque las cuatro son el mismo material, y decidirlas por
separado a mitad de una implementación es cómo se acaba con cuatro superficies
que se parecen y no coinciden.

## Decisión

### 1. El cristal es un componente, no una receta que se repite

`GlassSurface.qml`, sobre `BorderSurface`, con las tres variantes del paquete
—atenuada, pequeña y hundida— como una propiedad. Diecisiete superficies
copiando cinco declaraciones a mano es cómo se desincronizan.

**Ninguna altura del cristal es una constante.** El paquete escribe la
geometría en píxeles y avisa, en su propia sección de la lista de ajustes, de
que «si cambias alturas de fila o de tarjeta, recalcula esto». No se puede
recalcular a mano lo que el usuario cambia en tiempo de ejecución:
`Style.font.family` y sus tamaños salen de `OMARCHY_MENU_FONT`, y
`Style.space()` multiplica por una escala de espaciado que también es suya.
Cada número del paquete se traduce a un mínimo contra el contenido, como ya
hace `ClipboardRow` desde la `0.2.0`. **Se porta el criterio, no el número.**

### 2. El relleno va en gradiente vertical; a 150° sólo el halo

`Rectangle.gradient` de Qt Quick sólo hace vertical y horizontal. Un ángulo
arbitrario pide `QtQuick.Shapes` con un `LinearGradient`, es decir **un `Shape`
por superficie**, y en la cinta del control hay cuatro moviéndose a la vez.

Diez puntos de alfa repartidos en diagonal no se pagan con eso. El relleno del
cristal va vertical.

`QtQuick.Shapes` entra igualmente, y sólo para el halo, donde el paquete es
explícito: *«nunca un halo plano: al 10-18 % sobre un fondo tan oscuro no llega
a brillar y sí llega a ensuciar — se lee como un disco gris detrás del
dibujo»*. Un disco gris detrás del dibujo es exactamente lo que hay hoy en
`CopySpecimen` y en `TransformationIllustration`. Ahí el radial no es un
refinamiento: es la diferencia entre un halo y una mancha.

`QtQuick.Shapes` y `QtQuick.Effects` los usa ya el shell de Omarchy, así que
caben en «los módulos ya incluidos por Omarchy» del SPEC §13 sin ampliar esa
lista ni añadir una dependencia.

### 3. El ruido se pinta una vez y no se repinta nunca

El paquete pide una textura PNG de ruido gris de 120 × 120 en repetición. No
existe, y este repositorio no versiona un solo binario fuera de
`docs/images/`.

Se pinta con un `Canvas` que llama a `requestPaint` **al crearse y nunca más**.
Cumple lo que el paquete pedía de verdad —que la textura no se recalcule por
cuadro; lo único que se anima es su desplazamiento y su opacidad— sin meter un
binario en el árbol.

Los valores del ruido salen de los **mismos hashes deterministas** que la
balística de los añicos, no de `Math.random()`. Se ve irregular, y dos
ejecuciones dan la misma imagen: una captura de un test puede compararse
consigo misma.

### 4. El modo `screen` de las tres capas no se puede, y se acepta la desviación

Las tres capas del grano se apilan en el prototipo en modo `screen`. Qt Quick
no tiene modos de fusión sin `ShaderEffect`, y el propio paquete descarta el
`ShaderEffect` en la línea siguiente.

Sobre un fondo tan oscuro la mezcla normal se le acerca mucho, porque `screen`
apenas se separa de la mezcla normal cuando el fondo es casi negro. **Se acepta
la desviación**, se anota en el comentario del componente para que quien la vea
sepa que es deliberada, y si al mirarla no convence, la salida es un
`ShaderEffect` de cuatro líneas y no rehacer la pantalla.

### 5. La ilustración del bypass es una variante propia: `unread`

`test_only_the_bypass_states_get_the_drawing` exige hoy `variant: "protect"` en
los dos estados de bypass de `Panel.qml`. Cuando se escribió, `protect` era una
tarjeta con tres filas y un sello, que servía igual para el paso 1 del tour y
para «esto no lo hemos tocado».

Ya no. `protect` pasa a ser la cinta en marcha, y una cinta ciclando en el panel
frecuente es justo lo que la [`0007`](./0007-la-pantalla-frecuente-informa.md)
no quiere: esa pantalla informa, no actúa.

**El bypass estrena `unread`**: una sola tarjeta con el dibujo de lo que hay en
el portapapeles y el grano quieto encima. El nombre sale del argumento del
propio paquete —el grano dice que el control *no la lee*—, y aquí es literal:
el helper miró el tipo de la oferta y se plantó.

El guarda pasa a exigir `variant: "unread"` **y `motionEnabled: false`**. La
segunda mitad es la que de verdad protege la `0007`, y hoy no estaba escrita en
ninguna parte.

## Lo que se descartó

- **Repetir la receta del cristal en cada superficie**, sin componente. Es lo
  que hay hoy con `Border.controlSpec` copiado diecisiete veces, y ya se nota:
  dos ejemplares del carrusel llevan radios distintos sin que nada lo pida.
- **El relleno a 150° con un `Shape` por superficie.** Se midió que un `Shape`
  con `LinearGradient` dibuja bien y a plena tasa; lo que no se sostiene es
  pagarlo cuatro veces en una cinta en movimiento para un cambio de ángulo que
  nadie va a nombrar.
- **Versionar el PNG de ruido.** Un binario de 120 × 120 en el árbol es un
  binario que nadie sabe regenerar dentro de un año.
- **`Math.random()` para el grano.** Más corto, y deja de ser reproducible justo
  donde el resto del paquete se ha molestado en serlo.
- **Reutilizar `protect` en el bypass con la cinta parada.** Deja un motor de
  cuatro tarjetas y un arco montado en la pantalla más vista para enseñar una
  sola tarjeta quieta, y ata la pantalla frecuente a los cambios del tour.

## Consecuencias

- Tres componentes nuevos: `GlassSurface.qml`, `Halo.qml` y `Grain.qml`.
- `CopySpecimen` y `TransformationIllustration` dejan de dibujar su halo con un
  `Rectangle` circular y pasan por `Halo`.
- El SPEC §13 no cambia: no entra ninguna dependencia nueva.
- `test_only_the_bypass_states_get_the_drawing` exige la variante nueva y el
  movimiento apagado.
