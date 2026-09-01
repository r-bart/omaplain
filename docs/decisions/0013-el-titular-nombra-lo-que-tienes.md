# 0013 — El titular nombra lo que tienes

- Fecha: 1 de septiembre de 2026
- Estado: aceptada
- Decidido con: `/prototype` sobre el estado de bypass de imagen, 1 de septiembre
- Relacionada con: [`0007`](./0007-la-pantalla-frecuente-informa.md), cuya enmienda
  metió el dibujo en estas pantallas

## Contexto

Con una imagen en el portapapeles, el panel enseñaba esto:

> **An image is left alone**
> OmaPlain does not even read it. Screenshots reach their destination byte for byte.
> *(ilustración)*  ·  `image/png`  ·  **See how it works**

Y la pregunta que lo abrió todo fue: **«si éste es el estado vacío esperando a
que el usuario tenga algo en el portapapeles, ¿por qué vemos esto?»**

No era el estado vacío. El portapapeles tenía una imagen —la captura que se
acababa de hacer—, y el panel decía la verdad. Lo que fallaba es que no se
notaba que hablaba de **lo que tú tienes copiado**.

De los cinco elementos de esa pantalla, cuatro hablaban del producto y uno
solo —el chip del tipo MIME, pequeño y abajo— hablaba de ti. Y encima el
titular estaba en pasiva y sin sujeto concreto: «An image is left alone» habla
de una imagen en abstracto, no de la tuya. Leído entero, el conjunto se parece
más a un cartel explicativo que a un veredicto sobre tu portapapeles.

## Decisión

**El titular nombra lo que tienes. La frase dice qué le hacemos.**

| | Antes | Ahora |
|---|---|---|
| Imagen | An image is left alone | **An image on your clipboard** |
| Archivos | Files, untouched | **Files on your clipboard** |
| Estructura | Structured format, untouched | **Structured data on your clipboard** |
| Secreto | Marked as sensitive | **A secret on your clipboard** |
| Grande | Too big to read | **More than 1 MB on your clipboard** |

Los cinco acaban igual, y no es repetición: **nunca se ven dos a la vez**. Lo
que se percibe es una forma constante — abras cuando abras el panel, la primera
línea contesta siempre a la misma pregunta.

### Tres elecciones de palabra dentro de la regla

**«No lo leemos», no «no lo procesamos».** La petición original decía procesar.
Leer es lo que el helper cumple de verdad —de una imagen ni abre el
contenido— y es una promesa más fuerte. Rebajarla sonaría a decisión de
producto en vez de a garantía.

**«Structured data», no «structured format».** «Formato estructurado» es jerga
nuestra. Lo que el usuario tiene son datos con estructura.

**«A secret», no «marked as sensitive».** Lo segundo describe el mecanismo; lo
primero describe la cosa. El mecanismo —que lo marcó su gestor de
contraseñas— sigue en la frase de abajo, que es su sitio.

## Lo que no cambia

**La maquetación.** El prototipo puso a competir tres direcciones —la actual,
una que convertía el portapapeles en una ficha, y una que quitaba la
ilustración— y ganó la actual. El problema era de palabras, no de estructura,
y la enmienda de la `0007` que metió el dibujo se mantiene entera.

**Los cuatro bypass raros** (`blocked`, `unreadable`, `richOnly`, `noText`).
Sus titulares ya nombran la causa en vez de la pasiva, así que la regla nueva
ya se cumple ahí.

## Descartado

- **La ficha del portapapeles** (una tarjeta con el tipo como sujeto, al estilo
  de las filas de los demás estados). Coherente, pero la ficha no contiene nada
  real: de una imagen no hay nada que enseñar, así que sería una ficha de
  metadatos ocupando el sitio de una de contenido.
- **Quitar la ilustración** y dejar sólo el veredicto con una marca. Es la
  `0007` en su redacción original y la más corta de las tres, pero deja vacía
  la mitad que en los demás estados ocupa la previsualización — que es
  exactamente la queja que hizo añadir el dibujo.

## Consecuencias

- Cinco pares de cadenas cambian en los dos idiomas. `detail.sensitive` se
  queda como estaba: ya decía lo que hay que decir.
- `detail.large` pierde el «Over 1 MB», que ahora vive en el titular. Repetirlo
  sería decir el mismo dato dos veces en tres líneas.
- El titular de `large` menciona el límite por defecto de `maxBytes`. Un test lo
  ata a `DEFAULTS`, así que el día que ese número cambie, la cadena lo sabrá.
