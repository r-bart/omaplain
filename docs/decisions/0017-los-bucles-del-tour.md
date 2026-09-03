# 0017 — Los bucles viven en el tour, y en ningún otro sitio

- Fecha: 3 de septiembre de 2026
- Estado: aceptada
- Enmienda a: [`0004`](./0004-transformation-experience.md), y al guarda
  `test_the_entrance_plays_once_and_never_loops` que la fijaba

## Contexto

`TransformationIllustration` se escribió con una regla dentro, y un test que la
sujeta desde entonces:

> un bucle ambiente en una ilustración de onboarding es decoración, y encima
> compite con el texto que la acompaña

El test la aplica por la letra: prohíbe `loops:`, `Animation.Infinite` y
`running: true` en ese fichero. Nada más. Un recorrido de entrada, y quieto.

El rediseño del panel llega con dos bucles justo ahí. Uno es la cinta del
control de seguridad del paso 1 —cuatro tarjetas cruzando un arco cada 15 600
ms—, y el otro es el recorrido de la lista de ajustes del paso 3, que sube 104
px y vuelve.

## El argumento

La regla del test es buena y el paquete de diseño no la refuta: la discute en
un caso concreto, y en ese caso tiene razón.

**La cinta es el argumento, no su decoración.** El paso 1 dice que las
imágenes, los archivos y los secretos no se tocan. Lo que había antes eran tres
tarjetas quietas con un rótulo cada una, y tres tarjetas quietas no dicen eso:
dicen «aquí hay tres cosas». Lo que lo afirma es verlas entrar en el control,
perder el dibujo bajo el grano y **salir enteras por el otro lado**. Una cinta
que se para después de un viaje deja cuatro tarjetas quietas en mitad del
recorrido, que es la pantalla que este rediseño existe para sustituir. El bucle
no acompaña al texto del paso: es lo que el texto afirma, ocurriendo.

**El recorrido de la lista se cumple entero con un viaje.** Su argumento es
«hay más ajustes debajo del velo». Eso se demuestra la primera vez que la
tarjeta sube y baja. A partir de la segunda no queda nada por demostrar, y lo
que se mueve en un sitio donde ya no hay nada que contar es exactamente la
decoración de la que hablaba el test.

Así que la diferencia no está entre «tour» y «panel»: está entre un movimiento
que **sostiene una afirmación mientras se lee** y uno que ya la ha entregado.

## Decisión

**Se permite ciclar sólo donde el ciclo es la afirmación.**

1. **La cinta del control (`protect`) cicla**, indefinidamente y despacio, los
   15 600 ms del paquete. Es el único bucle de `TransformationIllustration`.
2. **El recorrido de la lista (`control`) va y vuelve una vez** y se queda
   quieto en su primera parada. Los cuatro interruptores se encienden
   escalonados una sola vez, y el quinto no se mueve nunca.
3. **Las variantes `transform` y `unread` no ciclan.** La primera es un
   recorrido de entrada, como hasta hoy. La segunda vive en el panel frecuente
   y va siempre con `motionEnabled: false` desde `Panel.qml`, por la
   [`0007`](./0007-la-pantalla-frecuente-informa.md).
4. **Fuera del tour no hay bucles ambiente.** Ni en la fila del portapapeles,
   ni en el veredicto, ni en el carrusel del estado vacío —cuyo ciclo es de
   contenido y está resuelto en la [`0008`](./0008-el-estado-vacio.md)—, ni en
   la ilustración del bypass.

El guarda pasa de «nunca hay bucles» a «nunca hay bucles fuera de las variantes
del tour», que es lo que de verdad protegía. Y lo dice con su motivo escrito,
como el que sustituye.

### El sónar no cuenta, y conviene decir por qué

`StatusHeader` estrena tres anillos que salen y se pierden mientras el servicio
arranca. Es un bucle, y este documento no lo prohíbe.

No cuenta por dos razones, y hacen falta las dos. **Una: no es una
ilustración.** Es la insignia de estado, y el estado que representa es
literalmente una espera: mientras el bucle dura, hay algo ocurriendo que
todavía no ha terminado. Un indicador de progreso indeterminado cicla porque su
referente cicla. **Y dos: se acaba solo.** Vive los segundos que tarda el
demonio en atender, y en cuanto atiende desaparece. No hay pantalla en la que
un usuario se quede mirándolo.

El día que algo así se quede fijo en el panel frecuente, vuelve a ser
decoración y esta decisión no lo ampara.

## Lo que se descartó

- **Renunciar a los dos bucles.** Devuelve el paso 1 a las tres tarjetas
  quietas. Es respetar la letra del test rompiendo lo que el test protege, que
  es que el onboarding se entienda.
- **Aceptar los dos.** Gasta el permiso también en el sitio donde el test
  acierta, y sin ganar nada: nadie mira la lista de ajustes esperando el cuarto
  viaje.
- **Dejar el test como está y colarse por su literalidad**, conduciendo la
  cinta desde un `FrameAnimation` o un reloj externo sin escribir `loops:` en
  ninguna parte. Pasaría en verde y sería mentira. Un guarda que se rodea es
  peor que un guarda que se enmienda por escrito.

## Consecuencias

- `test_the_entrance_plays_once_and_never_loops` cambia de nombre y de forma:
  admite el ciclo dentro de las variantes del tour y sigue prohibiéndolo en el
  resto del fichero y en los componentes del panel frecuente.
- La cinta corre mientras el paso 1 está a la vista. `TourPage` ya monta y
  desmonta la ilustración por paso, así que no hay un bucle corriendo detrás de
  una pantalla que nadie ve.
- Con «Reducir movimiento» puesto, los dos siguen apagados: la cinta se pinta
  con las cuatro tarjetas repartidas en sus posiciones de reposo, y la lista en
  su primera parada. Ninguna de las dos pierde información al pararse.
