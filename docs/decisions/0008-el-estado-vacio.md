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

**Carrusel.** Una cosa copiable cada vez, en una tarjeta centrada: qué es, cómo
llega, y lo que sobra encogiéndose hasta desaparecer en su sitio. Al terminar,
pasa a la siguiente.

| Valor | Elegido |
|---|---|
| Permanencia por elemento | 2600 ms |
| Transición | 620 ms |
| Curva | `cubic-bezier(0.32, 0.72, 0, 1)` |
| Altura de la tarjeta | fija, dimensionada para el ejemplo más largo |
| Cuerpo | una sola línea, sin ajuste de línea |

La altura fija y la línea única no son detalles de estilo: con altura variable,
cada elemento del ciclo redimensionaría el panel entero cada 2,6 segundos.

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
  queda en el primer ejemplo con lo que sobra ya retirado.
- Los ejemplos salen del motor, como los del tour, y un test los comprueba
  contra `transform()` para que la pantalla no prometa una limpieza que ya no
  ocurra.
