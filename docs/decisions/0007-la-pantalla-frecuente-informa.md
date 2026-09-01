# 0007 — La pantalla frecuente informa; la primera enseña

- Estado: aceptada
- Fecha: 31 de agosto de 2026
- Cumple: [`0004`](./0004-transformation-experience.md), que lo dijo y no se implementó
- Depende de: [`0005`](./0005-previsualizacion-del-portapapeles.md)

## Contexto

La `0004` ya lo había decidido: *«La primera apertura es educativa; las
siguientes aterrizan directamente en la acción principal»*. La implementación no
lo cumplió. El héroe educativo se quedó fijo en la vista principal, y el panel
de todos los días nunca dejó de hacer onboarding.

El síntoma es literal:

```
StatusHeader.qml:83   text: "Texto limpio,\nsin sorpresas."
WelcomePage.qml:68    text: "Texto limpio,\nsin sorpresas."
```

El mismo titular en las dos pantallas. Más la ilustración de transformación,
que ocupa el tercio superior de un panel pequeño para explicar en abstracto algo
que el usuario ya vio en el tour.

## Decisión

Las dos superficies se separan por lo que hacen, no por cuándo aparecen.

**La primera experiencia enseña.** «Texto limpio, sin sorpresas», la ilustración
de transformación y la explicación del modelo viven en la bienvenida y el tour,
que es donde tienen trabajo. La demo del ejemplo real sigue en el paso 2.

**La pantalla frecuente informa.** Enseña *tu* portapapeles, el veredicto sobre
él y la acción que corresponde. Ni titular educativo ni ilustración: el producto
se explica solo enseñando lo que va a hacer con tu contenido, que es mejor
profesor que un dibujo.

### Qué enseña cuando ya está limpio

Con la limpieza automática puesta —el default— el demonio ya ha limpiado el
portapapeles antes de que el panel abra. Esa es la situación normal, no una
excepción.

**La pantalla informa del estado actual y no recuerda nada.** No se guarda en
memoria el antes y el después de la última limpieza, ni siquiera con caducidad.
El contenido sigue siendo tan transitorio como lo era en la `0.1.0`, y la `0005`
no amplía su vida útil ni un segundo.

Así que hay dos formas normales de la pantalla:

- **Ya está limpio.** Una sola fila con lo que hay ahora. No es una pantalla
  vacía: es la buena noticia de que el producto está funcionando.
- **Esto se puede limpiar.** Dos filas, antes y después, con su desglose y sus
  acciones. Aparece cuando de verdad queda algo pendiente: modo manual, omisión
  activa, aplicación excluida o automático apagado.

## La excepción: el portapapeles vacío

La pantalla frecuente vuelve a enseñar en un solo caso, y conviene decir por
qué no contradice lo anterior.

La regla es que la pantalla frecuente **informa**. Con el portapapeles vacío no
hay nada de lo que informar: no es una lista sin elementos ni un error, es lo
que ve alguien que acaba de llegar. Ahí enseñar deja de competir con el
contenido, porque no hay contenido con el que competir.

Así que ese estado —y sólo ese— lleva material didáctico: la
[`0008`](./0008-el-estado-vacio.md) decidió cuál. El resto de la pantalla
frecuente sigue sin enseñar nada.

## Consecuencias

- `StatusHeader` deja de llevar el titular y la ilustración en la vista
  principal. Conserva el estado del servicio, que sí es información.
- `TransformationIllustration` sale de la pantalla frecuente por completo y se
  queda en bienvenida y tour.
- El caso «ya está limpio» deja de ser un hueco a rellenar y pasa a ser un
  estado de primera clase con su propia copia.
- La superficie de privacidad **no crece** respecto a la `0.1.0`: el contenido
  se lee cuando el panel pregunta y muere con la respuesta.

## Descartado

- **Recordar en memoria la última limpieza**, con caducidad corta, para poder
  enseñar siempre un antes y un después. Es lo que más lucía, y por eso mismo
  conviene decir que no: alarga la vida del contenido en memoria a cambio de
  una pantalla más vistosa, y este producto se vende sobre la contención.
- **Recordar sólo qué reglas actuaron**, sin texto. Sin riesgo, pero cuenta una
  historia sobre el pasado en una pantalla cuyo trabajo es el presente.
- **Dejar el héroe donde estaba.** Es la opción de no hacer nada, y equivale a
  seguir incumpliendo la `0004`.

## Enmienda — 1 de septiembre de 2026

**Los estados de bypass llevan dibujo.** La regla de arriba —«ni titular
educativo ni ilustración»— se mantiene en todas las pantallas que enseñan el
portapapeles, y se levanta en las que no pueden enseñarlo.

El motivo de la decisión original es que *el producto se explica solo enseñando
lo que va a hacer con tu contenido, que es mejor profesor que un dibujo*. Ese
motivo no llega a un bypass: de una imagen no se lee ni un byte, y de una
aplicación bloqueada no se enseña ni la lista de tipos. Ahí no hay contenido que
haga de profesor, así que la mitad de la pantalla que en los demás estados ocupa
la previsualización se quedaba en blanco, con el veredicto flotando encima y
debajo una frase que decía que no había nada que hacer.

No era una hipótesis: la pantalla del estado «imagen» se confundió con la del
estado vacío, y quien la confundió había escrito las dos.

### Qué entra, y qué no

- **Entra** el dibujo de la variante «protege», que es el de *Imágenes /
  Archivos / Secretos* con su marca de visto. Dibuja exactamente lo que ese
  veredicto afirma.
- **Entra** la salida al tour. La última línea era «no hay ninguna acción que
  ofrecer aquí»: cierto sobre el portapapeles, callejón sin salida sobre la
  pantalla. Quien no entiende por qué su imagen no se toca ahora tiene dónde
  averiguarlo.
- **Sale** esa nota genérica cuando aparece esa salida, porque decir «no hay
  ninguna acción que ofrecer» justo encima de un botón que ofrece una es
  falso. Las notas que sí informan —«ya está limpio», la de aplicación
  bloqueada y la de contenido sensible— se quedan.
- **No entra** ningún titular educativo, ni la ilustración de transformación,
  ni el carrusel de ejemplos. El carrusel enseña una limpieza, y ponerlo en una
  pantalla cuyo veredicto es «esto no se toca» contradiría el veredicto.

### Qué no cambia

El dibujo va **quieto**. Esta pantalla se abre muchas veces al día y una
animación de entrada en cada apertura es lo que no se le hace a un gesto
frecuente, así que se pinta en su estado final sin recorrido, con
independencia del ajuste de movimiento.

Las pantallas que sí enseñan el portapapeles —«ya está limpio» y «esto se puede
limpiar»— siguen sin dibujo, exactamente como decidió la `0007`.
