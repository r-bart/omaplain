# 0006 — Orden del onboarding

- Estado: aceptada
- Fecha: 31 de agosto de 2026
- Matiza: [`0004`](./0004-transformation-experience.md)
- Depende de: [`0005`](./0005-previsualizacion-del-portapapeles.md)

## Contexto

La `0005` cambia dónde termina el onboarding, porque cambia qué es la pantalla
principal. Antes era un formulario de ajustes; ahora es el portapapeles del
usuario con su veredicto delante.

Eso reabre una pregunta que la `0004` había cerrado con «la primera apertura es
educativa; las siguientes aterrizan directamente en la acción principal». Con
una pantalla principal que ya explica el producto por sí sola, ¿sigue teniendo
sentido llevar al usuario por los ajustes primero?

Había tres posturas sobre la mesa:

- Terminar en la pantalla principal y dejar Opciones como paso opcional.
- Pasar por Ajustes como paso obligatorio, para que configure antes de usar.
- Enseñar Ajustes con una salida clara y visible.

## Decisión

El recorrido es: **bienvenida → tour de tres pasos → Ajustes, con un «Saltar»
visible → pantalla principal**.

- Ajustes se **enseña**, no se **impone**. El usuario ve qué puede tocar sin
  quedar atrapado ahí.
- El control de salida es un botón visible y rotulado, no un aspa pequeña ni
  un gesto. Saltar es una respuesta legítima, no un escape.
- Salte o configure, el recorrido termina siempre en la pantalla principal con
  su portapapeles real delante.
- Los defaults siguen siendo seguros por sí solos. Pasar por Ajustes es para
  que sepan que existen, no porque haga falta tocar nada.

## Consecuencias

- `onboardingVersion` sube a `2`. Quien venía de la `0.1.0` ve una vez qué ha
  cambiado, porque la pantalla principal es otra cosa.
- La `0004` se matiza, no se revoca: la primera apertura sigue siendo
  educativa, y ahora el paso de ajustes forma parte de esa educación en lugar
  de ser un desvío.
- «Revisar bienvenida» y «Repetir mini tour» siguen viviendo en Ajustes y
  siguen siendo independientes entre sí.

## Descartado

- **Ajustes obligatorio sin salida.** Retrasa el primer momento útil y obliga a
  decidir sobre opciones que aún no se entienden, porque todavía no se ha visto
  el producto funcionando.
- **Saltarse Ajustes por completo.** Los cuatro interruptores opcionales llegan
  apagados; si nadie los ve nunca, es como si no existieran.
