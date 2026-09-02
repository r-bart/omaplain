# 0015 — La pantalla frecuente no ofrece un botón muerto

- Fecha: 2 de septiembre de 2026
- Estado: aceptada
- Enmienda a: [`0007`](./0007-la-pantalla-frecuente-informa.md) y
  [`0013`](./0013-el-titular-nombra-lo-que-tienes.md)

## Contexto

La pantalla de todos los días tenía debajo de la previsualización una fila
con dos botones: **Apply to the clipboard**, el primario, y **Skip the next
copy**. Los dos siempre, en cualquier estado con texto.

Con el automático puesto —el modo por defecto— el demonio limpia cada copia
al copiarla. Cuando el panel se abre, el texto ya está limpio casi siempre, y
el veredicto es «Already clean». Y en «Already clean» el primario está
apagado, porque pulsarlo no haría nada.

Es decir: **en la configuración por defecto, la acción primaria de la
pantalla más vista estaba gris casi siempre.** Sólo cobraba vida con el
automático apagado, tras una omisión, o con una copia de una app con la regla
«no limpiar sus copias». Un botón primario permanentemente apagado es ruido y
además hace pensar que algo falla.

Un botón deshabilitado tiene sentido cuando la condición es temporal y quien
mira puede resolverla desde ahí. Aquí no había nada que hacer en esa pantalla
para encenderlo.

Y el segundo botón tenía otro problema: compartía fila con «Apply», que habla
de *esta* copia, pero él habla de *la siguiente*. Estaban juntos por ser «las
dos acciones manuales», no porque tuvieran que ver entre sí. Con el
automático apagado seguía vivo, aunque entonces no hay nada que omitir.

## Decisión

**Sólo se ofrece lo que se puede hacer, y cada cosa donde corresponde.**

1. **«Apply» sólo existe cuando hay algo que aplicar.** En «This can be
   cleaned» es el primario, a ancho completo. En «Already clean» no está: ni
   gris ni de ninguna otra forma.
2. **La omisión es una línea secundaria propia**, debajo, sin borde y
   alineada a la izquierda, con un rótulo que dice de qué habla: «Leave the
   next copy alone». Armada, cambia a «The next copy will be left alone» y
   pasa al color de acento. Sólo aparece con el automático puesto, que es
   cuando significa algo.
3. **«Already clean» con automático, la pantalla más vista, se queda sin
   ninguna acción de primer nivel.** El veredicto, la fila cubierta y,
   discreta, la línea de la omisión. Es lo que la `0007` ya defendía para
   esta pantalla: informa, no ofrece producto.

El foco de entrada sigue la misma regla: va al primario si existe, si no a la
línea de la omisión, y si tampoco, al engranaje, que siempre está.

## Lo que se descartó

- **Dejar «Apply» gris con un texto que explique por qué.** Explica un botón
  que no debería estar.
- **Hacer que «Apply» pegue limpio.** Cambia de significado según el estado,
  que es peor que no estar.
- **Quitar la omisión del panel** y dejarla sólo por IPC. Es la única forma
  de conseguir una copia sin limpiar sin ir a Ajustes, apagar el automático y
  volver a encenderlo; se queda, pero en su sitio.

## Consecuencias

- `test_ui_contract.py` fija las tres cosas: el primario atado a
  `peekChanges`, la omisión en su propia línea y sólo con automático, y el
  foco con a dónde ir.
- Las cadenas de la omisión dejan de decir «skip», que suena a saltarse el
  portapapeles, y dicen «leave alone», que es lo que pasa.
