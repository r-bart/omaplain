# 0009 — Privacidad por aplicación: cuatro listas, no dos

- Estado: aceptada
- Fecha: 31 de agosto de 2026
- Decidido con: respuesta directa del 31 de agosto sobre el alcance de la promesa
- Depende de: [`0005`](./0005-previsualizacion-del-portapapeles.md), que fijó
  qué puede llegar al panel y qué no puede escribirse nunca

## Contexto

Hoy OmaPlain cubre lo que Wayland marca como sensible, y nada más. El usuario
sabe cosas que Wayland no sabe: qué aplicaciones suyas manejan material que no
quiere ver aparecer en un panel, aunque esas aplicaciones no marquen nada.

Ya existen dos listas por clase de aplicación, y la tentación era colgar de
ellas lo nuevo. No sirven: deciden **si algo se limpia**, no **si algo se lee**.

## Decisión

**Cuatro listas, en dos parejas que no se mezclan.**

| Lista | Qué decide | Dónde vive |
|---|---|---|
| `sourceExclusions` | Lo copiado ahí no se limpia | helper |
| `targetExclusions` | «Pegar limpio» no actúa ahí | helper |
| **`alwaysCovered`** | El vaho no se puede levantar | helper marca, panel obedece |
| **`blockedApps`** | Ni se lee ni se enseña | **helper**, nunca la interfaz |

Son cuatro y no dos porque las dos preguntas son independientes. Hay
aplicaciones cuyo texto no se debe tocar pero se puede mirar —un editor de
código donde la limpieza estorba— y aplicaciones cuyo texto da igual limpiar
pero no se debe enseñar. Fundirlas obligaría a aceptar la una para tener la
otra.

### La negativa vive en el helper

`blockedApps` se comprueba **antes de leer el portapapeles**, no antes de
pintarlo. En la interfaz, una negativa es un ajuste; y un ajuste que puede
destapar un secreto marcado es un revelador de contraseñas con pasos extra. La
respuesta de `peek` para una app bloqueada no lleva contenido, ni recortado ni
en forma de tipos MIME: de una app bloqueada no se enseña ni de qué está hecho
lo que hay dentro, que es más de lo que se calla con un bypass normal.

### `alwaysCovered` es «no se destapa», no «llega tapado»

Aquí hubo que corregir el rumbo a mitad de camino. La lista se pidió como «que
el contenido de estas apps llegue siempre empañado», y al ir a implementarla
resultó que **eso ya le pasa a todo el mundo**: las dos filas del panel nacen
cubiertas y sólo el ojo las levanta. Peor: el ojo, una vez levantado, se quedaba
levantado al cambiar de copia, de modo que revelar una vez enseñaba lo siguiente
sin que nadie lo pidiera. Eso era un fallo, y se arregla aparte: **cada
respuesta nueva vuelve a llegar cubierta**, venga de donde venga.

Arreglado eso, una lista que sólo prometiera «llega cubierto» no diría nada. Así
que dice otra cosa, que el defecto no da: **en estas aplicaciones el vaho no se
levanta**. Ves que hay algo, ves si se limpiaría, y no ves el texto.

Queda una escalera de tres peldaños, y cada uno se gana el suyo:

| | Se lee | Se puede ver |
|---|---|---|
| Normal | sí | sí, levantando el vaho |
| `alwaysCovered` | sí | **no** |
| `blockedApps` | **no** | no |

La negativa no depende de que el panel se acuerde de pedirla: la fila calcula lo
que concede (`revealed`) a partir de lo que le piden (`shown`) y de si está bajo
llave, así que ni el ojo ni el gesto de limpiar el vaho la levantan.

## Hasta dónde llega la promesa

Wayland no dice quién copió. El demonio lo deduce de la ventana enfocada en el
instante del evento, y el propio código ya lo rotula desde antes de esta
decisión:

```python
# Snapshot attribution before this event waits on the serialization lock.
# Wayland cannot guarantee the source, so this remains best effort and is
# never a safety gate.
```

Para `sourceExclusions` esa deducción sólo decide si algo se limpia, y fallar es
inofensivo. `blockedApps` la convierte en una promesa de privacidad, así que hay
que decir en voz alta qué promesa es.

**La lista bloquea cuando OmaPlain reconoce la ventana de origen.** No es una
barrera de seguridad, y la interfaz no la vende como tal: el copy de la sección
lo dice con esas palabras. Lo que Wayland marca como sensible sigue cubierto por
el bypass de siempre, que no depende de ninguna atribución.

Cuando el origen es desconocido —antes del primer evento, o si `hyprctl` falla—
**no se trata como bloqueado**.

## Descartadas

- **A prueba de fallos**: no enseñar nada cuando no se puede atribuir la copia.
  La promesa sería más fuerte, pero convierte un fallo raro de `hyprctl` en una
  pantalla rota en el uso diario, y esa pantalla se abre muchas veces al día
  para una lista que la mayoría de la gente dejará vacía.
- **No tener lista de bloqueo** y quedarse sólo con la de cubrir. Resuelve el
  problema de la promesa renunciando a la función.
- **Colgar lo nuevo de `sourceExclusions`**, con un modo. Dos preguntas
  distintas bajo un mismo ajuste: quien quiera una se lleva la otra.

## Consecuencias

- El demonio recuerda **la clase de la ventana de origen** del último evento.
  Es metadato, no contenido: la `0007` prohíbe recordar el texto, no de dónde
  vino. No se persiste, no entra en `status.json` y muere con el proceso.
- Se recuerda **antes** de mirar si la limpieza automática está activa, o con el
  automático apagado no habría a quién atribuir nada.
- La ruta automática salta las bloqueadas con su propio motivo,
  `source_blocked`, distinto de `source_excluded`: si no se lee, no se limpia.
- La sección «Privacidad» de los ajustes va separada de las exclusiones de
  limpieza, con su propio encabezado y su propio estado vacío.
- El panel reinicia el ojo con cada respuesta nueva del helper. Es el arreglo
  del fallo que se encontró escribiendo esto, y vale para todo el mundo, no
  sólo para las apps de la lista.
- La auditoría de privacidad de la `G.2` gana dos rutas que perseguir: la
  bloqueada y la cubierta.
