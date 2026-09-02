# 0016 — La omisión de una copia no se gana su sitio

- Fecha: 2 de septiembre de 2026
- Estado: aceptada
- Deja sin efecto el punto 2 de la [`0015`](./0015-la-pantalla-frecuente-no-ofrece-un-boton-muerto.md)

## Contexto

«Omitir la próxima copia» estaba desde la `0.1.0`: armaba una excepción de un
solo uso al modo automático, y la siguiente copia elegible pasaba sin limpiar.
Caducaba a los sesenta segundos.

La [`0015`](./0015-la-pantalla-frecuente-no-ofrece-un-boton-muerto.md) la sacó
de la fila de acciones y la puso en una línea propia, porque hablaba de la
copia *siguiente* y compartía sitio con un botón que hablaba de *ésta*. Ahí
quedó a la vista lo que el cambio de sitio no arreglaba:

> **✓ The next copy will be left alone**
> The next copy will be left alone

La misma frase dos veces, el botón y su mensaje de resultado. Una acción cuyo
único resultado observable es repetirse a sí misma.

## El argumento

Tres cosas, y la tercera es la que decide.

**Uno: pide adivinar el futuro.** Hay que armarla *antes* de copiar, y acordarse
de que se armó. Si el minuto pasa, la copia se limpia igual y no queda rastro de
por qué. Si la copia siguiente es una imagen o un secreto, la omisión no se
consume y sigue ahí, esperando a una copia que ya no recuerdas haber protegido.

**Dos: la alternativa es de la misma longitud y no caduca.** Apagar «Limpiar
automáticamente» en Ajustes es un interruptor, funciona para el tiempo que haga
falta, y se ve. La omisión ahorraba dos clics a cambio de un estado invisible con
un reloj dentro.

**Tres: es la única acción de la pantalla más vista.** Con el automático puesto
—el modo por defecto— el texto llega ya limpio, y en «Already clean» no hay nada
que aplicar. La `0015` dejó esa pantalla sin acción primaria; la línea de la
omisión era lo único que quedaba, así que la pantalla que la `0007` quiere
informativa terminaba ofreciendo la acción más marginal del producto como si
fuera la principal.

## Decisión

**Se retira entera: panel, IPC, helper y demonio.**

No se queda «sólo por IPC». Una acción que no se gana su sitio en la interfaz
tampoco se lo gana en el código: dejarla ahí es mantener un camino que nadie
recorre y que hay que seguir probando.

Quien quiera una copia sin limpiar apaga el automático en Ajustes, la copia, y
lo vuelve a encender. Es explícito, no caduca, y se ve mientras dura.

## Lo que se lleva por delante

| Se va | Por qué existía |
|---|---|
| `skipNext` en el panel, el IPC y el CLI | la acción |
| `skip_next`, `_skip_active`, `_consume_skip` | armar, consultar y consumir |
| `tick()` del demonio y su llamada en el bucle de `accept` | **sólo existía** para caducar la omisión con el escritorio quieto |
| `skipNext` en `status.json` | el estado que el panel leía |
| `skipping` en la cabecera de estado | la insignia |
| Siete cadenas por idioma | los rótulos y los mensajes |

Que `tick()` desaparezca es la señal de que la decisión es correcta: el demonio
tenía un temporizador cuya única razón de ser era una función que ahora no
está. Con ella se va también la rama del bucle que lo llamaba.

## Lo que se descartó

- **Dejarla sólo por IPC, para quien quiera un atajo.** Es la forma educada de
  no decidir. Nadie ha pedido ese atajo, y mantenerlo cuesta código, tests y una
  línea en el README.
- **Convertirla en «pausar cinco minutos».** Cambia el reloj de sitio, no quita
  el reloj. El interruptor de Ajustes ya hace eso sin caducidad.
- **Dejar el botón y quitar sólo su mensaje repetido.** Arregla el síntoma que
  se veía en pantalla y deja la acción, que es lo que no se sostiene.

## Consecuencias

- La pantalla de cada día con el automático puesto y el portapapeles limpio se
  queda **sin ninguna acción**. Es exactamente lo que la
  [`0007`](./0007-la-pantalla-frecuente-informa.md) defiende: informa, no ofrece
  producto.
- La cabecera de estado pierde un estado de siete: ya no hay «omitiendo».
- El tour deja de nombrarla. Su tercer paso ahora dice que puedes limpiar a
  mano, apagar el automático o darle reglas a una aplicación.
- `status.json` cambia de forma. No es un formato persistente entre sesiones,
  así que no hay migración que hacer.
