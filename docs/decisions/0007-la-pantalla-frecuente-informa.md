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

`TransformationIllustration` vuelve a la pantalla frecuente en un solo caso,
y conviene decir por qué no contradice lo anterior.

La regla es que la pantalla frecuente **informa**. Con el portapapeles vacío no
hay nada de lo que informar: no es una lista sin elementos ni un error, es lo
que ve alguien que acaba de llegar. Ahí enseñar deja de competir con el
contenido, porque no hay contenido con el que competir.

Así que ese estado —y sólo ese— lleva ilustración, una explicación de qué
pasará cuando copies algo, y una salida al recorrido de tres pasos para quien
todavía no sepa de qué va. El resto de la pantalla frecuente sigue sin enseñar
nada.

## Consecuencias

- `StatusHeader` deja de llevar el titular y la ilustración en la vista
  principal. Conserva el estado del servicio, que sí es información.
- `TransformationIllustration` sale de la cabecera diaria. Se queda en
  bienvenida y tour, y vuelve a la pantalla frecuente sólo en el estado vacío,
  por lo dicho arriba.
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
