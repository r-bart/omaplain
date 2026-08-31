# 0008 — El estado vacío enseña qué se copia

- Estado: aceptada
- Fecha: 31 de agosto de 2026
- Decidido en: prototipo «Estado vacío de OmaPlain», cuatro direcciones
- Depende de: [`0007`](./0007-la-pantalla-frecuente-informa.md), que ya admitió
  la excepción de enseñar cuando no hay nada que informar

## Contexto

Con el portapapeles vacío la pantalla no tiene nada que reportar. La primera
versión puso una hoja en blanco y una frase; correcta, olvidable. Un estado
vacío es la pantalla de alguien que acaba de llegar, así que puede hacer más
trabajo que ocupar el hueco.

Se prototiparon cuatro direcciones sobre el panel real, con los mismos tokens y
la misma tipografía, y con ejemplos sacados del motor: los `utm_` que se van, el
carácter invisible que no se ve, el `text/html` que desaparece.

## Decisión

**Carrusel.** Una cosa copiable cada vez, en una tarjeta: su pieza gráfica, qué
es, cómo llega, y lo que sobra encogiéndose hasta desaparecer. Al terminar, pasa
a la siguiente.

Cada ejemplo trae su propio dibujo, en el lenguaje de hojas de la bienvenida, y
los tres tienen silueta distinta para que se vea que son tres cosas distintas y
no el mismo icono con otro pie: una barra de dirección sobre su página, con la
cola de seguimiento en acento; una hoja de párrafo con el invisible dibujado
como lo que es, una caja vacía sin glifo dentro; y dos copias superpuestas de
las que se retira la de arriba, la que lleva el formato. Dibujo y texto
comparten el mismo avance, así que pierden lo que sobra **en un solo gesto** en
vez de contar dos historias a destiempo.

### La coreografía

Un turno completo es una sola secuencia, no cuatro efectos sueltos:

| Fase | Duración | Curva | Qué ocurre |
|---|---|---|---|
| Llegada | 300 ms | `cubic-bezier(0.32, 0.72, 0, 1)` | dibujo y frase entran desde abajo; la frase 70 ms detrás |
| Espera | 80 ms | — | primero se ve qué hay, y sólo entonces qué sobra |
| Peinado | 620 ms | `InOutCubic` | una banda cruza el dibujo, lo que sobra se encoge, tres motas se apagan |
| Lectura | 1340 ms | — | la copia limpia se queda quieta |
| Salida | 190 ms | `InCubic` | sube y se apaga: ya está leída |

Tres reglas dentro de eso, cada una por un motivo concreto:

- **La tarjeta no se mueve; se mueve su contenido.** Es el escenario. Haciéndola
  entrar y salir entera, el borde parpadeaba tres veces cada ocho segundos justo
  al lado de un botón que sí es pulsable.
- **La marca de posición del ejemplo en curso es además su reloj**: se llena
  mientras dura el turno, así que el relevo se ve venir en vez de sorprender a
  media lectura.
- **Altura fija y una sola línea de cuerpo.** No son detalles de estilo: con
  altura variable, cada elemento del ciclo redimensionaría el panel entero cada
  2,6 segundos.

## Por qué ésta

Cuenta la promesa entera de una sentada. Ves qué copiaste, ves qué sobra, y ves
cómo desaparece — que es exactamente lo que el producto hace y lo que la
pantalla no podía demostrar sin contenido real.

## Descartadas

- **Reposo**, la hoja en blanco que había. No miente ni molesta, pero tampoco
  enseña nada, y es justo el hueco que la pantalla tenía que llenar.
- **Cinta**: las copias desfilan por un peine fijo y pierden el rosa al cruzarlo.
  La metáfora es la más literal de las cuatro, y el movimiento continuo es lo
  que la hunde: un panel de uso diario con algo moviéndose sin parar cansa, y
  compite con el texto de al lado. Además cada pastilla se lee a medias.
- **Pila**: las copias se acumulan una sobre otra, cada una ya limpia. Se lee
  bien, pero cuenta una historia sobre acumulación —un historial— que es
  precisamente lo que OmaPlain no hace y lo que la privacidad promete no hacer.

## Consecuencias

- La variante `waiting` de la ilustración se retira: no llegó a usarse en
  ninguna pantalla salvo ésta, y el carrusel la sustituye.
- El ciclo se detiene con el panel cerrado y bajo movimiento reducido, donde se
  queda en el primer ejemplo con lo que sobra ya retirado, sin marcas de
  posición y sin reservarles sitio.
- Los ejemplos salen del catálogo y se comprueban contra el motor, como los
  del tour, para que la pantalla no prometa una limpieza que ya no ocurra. Se
  comprueban **una vez por idioma**: escritos en el QML se quedaron en español,
  y la guardia que caza prosa fuera del catálogo usa el acento como señal, que
  `El pan de masa madre` no lleva.
- El ejemplo con formato dice qué se retira en palabras —«en negrita y con
  color»— en vez de en tipos MIME. El desglose ya enseña `text/html` a quien
  quiera el detalle; una pantalla de bienvenida no es el sitio.
