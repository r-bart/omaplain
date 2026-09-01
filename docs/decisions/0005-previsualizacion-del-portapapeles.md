# 0005 — Mostrar el portapapeles en el panel

- Estado: aceptada
- Fecha: 31 de agosto de 2026
- Revierte: el «Evitar» de `notes/UX-OPPORTUNITIES.md` sobre previsualizar contenido
- Afecta: `PLAN.md` F1.11 y F4.5, la definición operativa de terminado, `SECURITY.md`

## Contexto

El panel de la `0.1.0` es un formulario de ajustes que *habla* de limpiar. La
acción primaria, «Limpiar portapapeles ahora», pide confianza sin enseñar nada:
no puedes saber qué va a cambiar hasta después de que haya cambiado.

El proyecto se prohibió expresamente enseñar el contenido. `notes/UX-OPPORTUNITIES.md`
lo listaba en «Evitar», `F1.11` obligaba a emitir «únicamente eventos JSON de
metadatos; ningún contenido», y la definición de terminado exigía que la
revisión de privacidad no encontrase contenido «en logs, estado, IPC o UI».

Esa prohibición se escribió para impedir **fuga y persistencia**, que es el
riesgo real de una utilidad de portapapeles. Pero al meter «IPC» y «UI» en la
misma frase que «logs» y «estado», acabó prohibiendo también la única forma de
demostrar el producto.

## Decisión

El panel muestra el contenido actual del portapapeles y cómo quedaría.

La frontera se redibuja donde estaba el riesgo de verdad:

- El contenido **puede** cruzar el IPC y llegar al panel. El socket es
  `0600` y vive en `$XDG_RUNTIME_DIR`.
- El contenido **no puede escribirse en ningún sitio**: ni `status.json`, ni
  configuración, ni log, ni `stdout`/`stderr`, ni notificación, ni traza de
  error. Ni siquiera truncado, ni siquiera hasheado.
- El contenido vive en memoria mientras el panel está abierto y muere con él.

Tres reglas de presentación, que no son estéticas sino parte de la decisión:

1. **Cubierto por defecto.** El panel es una superficie layer-shell que se abre
   encima de lo que el usuario esté compartiendo o grabando. Se descubre por
   acto explícito, nunca al abrir.
2. **Descubrir es por elemento, no un modo.** Cambiar de portapapeles vuelve a
   cubrir. Se puede ver el resultado sin destapar el original.
3. **Lo marcado como sensible no se muestra por ninguna vía.** La negativa vive
   en el helper: `peek` sobre contenido sensible devuelve motivo y tipos, nunca
   texto, aunque el panel lo pida. Si viviese en la UI, sería un ajuste; en el
   helper es un invariante.

## Consecuencias

- `F1.11` se reformula: el *canal de eventos* sigue siendo sólo metadatos; la
  respuesta a una petición explícita del panel puede llevar contenido.
- `F4.5` deja de auditar la UI y pasa a auditar dónde el contenido no debe
  quedar: logs, estado en disco, notificaciones y salidas estándar. Se vuelve
  más estricta, no menos: la prueba es una muestra con marca reconocible que
  atraviesa `peek` y luego se busca en cada uno de esos sitios.
- El criterio que bloquea una entrega, «se registra o persiste contenido del
  portapapeles», sigue intacto y es ahora el que carga con todo el peso.
- `SECURITY.md` gana un párrafo sobre pantalla compartida: es el riesgo nuevo
  que esta decisión introduce y hay que decirlo en voz alta.

## Descartado

- **Seguir sin previsualización.** Deja el producto pidiendo un acto de fe y
  hace que la acción primaria sea irreversible a ciegas.
- **Enseñar sólo el resultado, no el original.** Sin el antes no se entiende
  qué se retiró, que es justo lo que hay que demostrar.
- **Difuminar el texto en vez de cubrirlo.** Un desenfoque suficiente para no
  leerse es indistinguible de una cubierta, y uno insuficiente filtra. La
  cubierta opaca es más honesta.
- **Poner el revelado bajo un ajuste.** Un ajuste que puede destapar un secreto
  marcado es un revelador de contraseñas con pasos extra.
