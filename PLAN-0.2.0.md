# OmaPlain — Plan de ejecución `0.2.0`

Plan operativo para convertir el panel de OmaPlain de un formulario de ajustes
en un producto que enseña su propio trabajo, y para saldar la deuda que dejó la
`0.1.0`.

| Campo | Valor |
|---|---|
| Estado | En curso — fases A, B y C terminadas |
| Creado | 31 de agosto de 2026 |
| Versión objetivo | `0.2.0` |
| Plan anterior | [`PLAN.md`](./PLAN.md) — fases 0–5 terminadas |
| Prototipo de referencia | Artefacto «Rediseño de OmaPlain», validado con los diez estados reales del motor |
| Entorno base | Omarchy 4.0.1, Quickshell 0.3.1, Hyprland 0.56.2, Qt 6.11.2 |

## 1. Cómo se usa este plan

Rigen las mismas reglas que `PLAN.md`: `SPEC.md` es la fuente de verdad, una
tarea sólo se cierra con evidencia reproducible, y un hallazgo que cambie el
producto se documenta en `docs/decisions/` **antes** de seguir.

Dos añadidos propios de esta versión:

- Toda pantalla nueva se comprueba **en el panel real**, no sólo con tests de
  contrato. La `0.1.0` demostró que un test que lee el texto del QML no ve un
  import que falta.
- Recargar QML exige `omarchy restart shell`. `rescanPlugins` no basta: Qt
  cachea el QML compilado por URL.

## 2. Resultado esperado

- La pantalla principal muestra qué hay en el portapapeles y cómo quedaría.
- El contenido se cubre por defecto y se descubre por elemento.
- Lo que el sistema marca como sensible no se muestra por ninguna vía.
- Los ajustes viven en una segunda página, tras un botón «Opciones».
- El contenido del portapapeles puede cruzar el IPC y llegar al panel, pero
  **no puede escribirse en ningún sitio**.
- Todos los controles del panel se renderizan. Hoy no lo hace ninguno.

No forman parte de `0.2.0`: historial propio, widget permanente de barra, la
filter API upstream (fase 6 de `PLAN.md`, aplazada a propósito).

## 3. Resumen de fases

| Fase | Estado | Entregable principal | Puerta de salida |
|---|---|---|---|
| A. Desatascar | Terminada | Panel con sus controles visibles | Los nueve toggles se renderizan en el panel real |
| B. Decisiones | Terminada | `0005` y `0006` aceptadas | El criterio de auditoría de contenido es verificable de nuevo |
| C. Contrato `peek` | Terminada | El helper expone contenido sin persistirlo | Una muestra marcada no aparece en logs, estado ni notificaciones |
| D. Pantalla principal | Pendiente | Vista de portapapeles con cubierta | Los diez estados se ven correctos en el panel real |
| E. Onboarding | Pendiente | Bienvenida y tour hacia la nueva pantalla | El recorrido termina donde diga `0006` |
| F. Microinteracciones | Pendiente | `motionEnabled` y las tres de prioridad alta | Cada movimiento tiene su vía de movimiento reducido |
| G. Cierre `0.2.0` | Pendiente | Release local validada | `develop` fusionado y CHANGELOG sin sección pendiente |

---

## 4. Fase A — Desatascar

Lo más barato y lo más urgente. La página que la fase E quiere promover a paso
de onboarding hoy no pinta ni un control.

### Trabajo

- [x] `A.1` Añadir `import qs.Commons` a `components/SettingRow.qml`.
- [x] `A.2` Añadir un test de contrato general: todo `.qml` que use `Style`,
      `Color`, `Util` o `Border` debe importar `qs.Commons`. Un import que falta
      no lo detecta un test que sólo busca cadenas.
- [x] `A.3` Verificar en el panel real, tras `omarchy restart shell`, que los
      nueve controles se renderizan y responden.
- [x] `A.4` Documentar en `README.md` que recargar QML exige reiniciar el shell.
- [x] `A.5` Registrar en `docs/TEST-REPORT.md` que la `0.1.0` se publicó con
      todos los toggles invisibles, y por qué la suite no lo detectó.

### Criterios de salida

- El panel real muestra Modo, Limpieza y Opcionales con sus controles.
- El test nuevo falla si se quita el import de cualquier componente.

---

## 5. Fase B — Decisiones de producto

Sin esto no se puede escribir código: la pantalla principal contradice un
invariante documentado del proyecto.

### Trabajo

- [x] `B.1` Escribir `docs/decisions/0005-previsualizacion-del-portapapeles.md`.
      Revierte el «Evitar: mostrar una previsualización del contenido real del
      portapapeles» de `UX-OPPORTUNITIES.md` y fija la distinción que salva el
      invariante: **el contenido puede llegar al panel; no puede persistirse**.
- [x] `B.2` Escribir `docs/decisions/0006-orden-del-onboarding.md`. **Puerta de
      decisión, ver abajo.**
- [x] `B.3` Reformular `F4.5` y la «Definición operativa de terminado» de
      `PLAN.md`: la auditoría deja de buscar contenido en la UI y pasa a
      buscarlo en logs, estado en disco, notificaciones y `stdout`/`stderr`.
- [x] `B.4` Actualizar `UX-OPPORTUNITIES.md` retirando el «Evitar» revertido y
      anotando la regla que lo sustituye.
- [x] `B.5` Actualizar `SECURITY.md` con el nuevo modelo: qué se muestra, qué no
      se muestra nunca, y qué ve alguien que esté compartiendo pantalla.

### Puerta de decisión — orden del onboarding

Las dos opciones llevan a trabajo distinto en la fase E:

**Resuelta el 31 de agosto de 2026** en
[`0006`](./docs/decisions/0006-orden-del-onboarding.md): bienvenida → tour →
**Ajustes con un «Saltar» visible** → pantalla principal. Ajustes se enseña,
no se impone, y el recorrido termina siempre con el portapapeles real delante.

### Criterios de salida

- `0005` y `0006` en estado «aceptada».
- Ningún documento del repo sigue prohibiendo lo que la `0.2.0` va a hacer.

---

## 6. Fase C — Contrato `peek`

Hoy `F1.11` obliga a emitir «únicamente eventos JSON de metadatos; ningún
contenido». El panel necesita el contenido. Este es el cambio de arquitectura
de la versión y el que más cuidado exige.

### Trabajo

- [x] `C.1` Añadir el comando `peek` al helper: devuelve clasificación, original,
      resultado y reglas aplicadas para el portapapeles actual.
- [x] `C.2` Garantizar que `peek` no escribe: ni `status.json`, ni log, ni
      notificación, ni traza. Es una lectura y una respuesta, nada más.
- [x] `C.3` Truncar por el límite de 1 MiB y marcar la respuesta como truncada,
      en vez de devolver un megabyte al panel.
- [x] `C.4` Lo clasificado como `sensitive` devuelve motivo y tipos, **nunca
      contenido**, aunque el panel lo pida explícitamente. La negativa vive en
      el helper, no en la UI.
- [x] `C.5` Bloquear `peek` cuando el clasificador dé `image`, `files` o
      `structured`: no hay texto que enseñar.
- [x] `C.6` Tests: una muestra con marca reconocible atraviesa `peek` y después
      se barren `status.json`, el runtime, `stdout`, `stderr` y las
      notificaciones buscándola. Debe no aparecer en ninguno.
- [x] `C.7` Test de que `peek` sobre contenido sensible nunca devuelve el texto.
- [x] `C.8` **No** exponer `peek` en la CLI. `control` imprime por `stdout`, que
      es uno de los sitios que la auditoría de `F4.5` tiene que barrer, y además
      quedaría en el historial y el scrollback de quien lo llame. El panel lo
      alcanza por el socket; nada más lo necesita. Fijado con un test.

### Criterios de salida

- La muestra marcada no aparece en ningún fichero ni salida.
- `peek` sobre sensible, imagen y archivos no devuelve contenido.
- La suite sigue en verde y el soak no crece.

---

## 7. Fase D — Pantalla principal

Traducir el prototipo a QML. Los diez estados y su copia ya están validados
contra el motor real.

### Trabajo

- [x] `D.1` **Spike terminado.** `destination-out` funciona en `Canvas`, y
      repintar la neblina entera cuesta **1,5 ms por fotograma** — un 4,5 % del
      presupuesto a 30 fps. No hacen falta `ShaderEffect` ni cubierta de
      reserva. Medido en `docs/SPIKE.md`.
- [ ] `D.2` Vista principal: estado, veredicto, subtítulo, dos filas de altura
      fija, desglose y acciones.
- [ ] `D.3` Cubierta por defecto, con ojo por fila y barrido si `D.1` lo permite.
      El ojo es la ruta de teclado y manda; el barrido es el adorno.
- [ ] `D.4` Estados de bypass —imagen, archivos, sensible— y portapapeles vacío.
- [ ] `D.5` Chips de tipos MIME para el caso «formato enriquecido», donde el
      texto no cambia y el diff no sirve.
- [ ] `D.6` Botón «Opciones» y la página de ajustes como segunda vista.
- [ ] `D.7` Recorrido completo por teclado y semántica accesible: mientras hay
      cubierta, el texto no se anuncia.
- [ ] `D.8` Verificación en el panel real de los diez estados, con capturas.

### Criterios de salida

- Los diez estados se ven correctos en el panel real, no sólo en tests.
- Cambiar de portapapeles vuelve a cubrir.
- Nada de lo sensible se puede destapar por ninguna vía.

---

## 8. Fase E — Onboarding y welcome tour

Bloqueada por `B.2`.

### Trabajo

- [ ] `E.1` Reordenar el recorrido según `0006`.
- [ ] `E.2` Adaptar el tour: la demostración segura ya existe y sigue anclada al
      motor por `test_demo_sample.py`.
- [ ] `E.3` El recorrido termina en la pantalla principal con el portapapeles
      real delante.
- [ ] `E.4` `onboardingVersion` sube a `2`; quien venía de la `0.1.0` ve una vez
      qué ha cambiado.

---

## 9. Fase F — Microinteracciones

### Trabajo

- [ ] `F.1` Traer el patrón `motionEnabled` de OmaPilot: propiedad que los
      componentes aceptan y las probes conducen, no un ajuste de usuario. Esto
      abre la puerta que `0004` dejó cerrada.
- [ ] `F.2` Enmendar `0004` registrando que la puerta queda abierta y por qué.
- [ ] `F.3` Confirmación visual de la transformación (prioridad alta nº1).
- [ ] `F.4` Estado «omitir una copia» en el héroe (nº2).
- [ ] `F.5` Los cuatro puntos de prioridad media de `UX-OPPORTUNITIES.md`.

### Criterios de salida

- Cada movimiento tiene su vía explícita de movimiento reducido.
- Ninguna animación supera los 300 ms ni anima otra cosa que no sea
  `transform` u `opacity`.

---

## 10. Fase G — Cierre `0.2.0`

- [ ] `G.1` Repetir matriz de compatibilidad y soak.
- [ ] `G.2` Auditoría de privacidad con el criterio nuevo de `B.3`.
- [ ] `G.3` Validador oficial de plugins.
- [ ] `G.4` CHANGELOG: cerrar la sección «Sin publicar» en una `0.2.0`.
- [ ] `G.5` Fusionar `develop` en `main` y etiquetar.
- [ ] `G.6` Notas de release, incluida la advertencia de pantalla compartida.

---

## 11. Fuera de alcance

- **Fase 6 de `PLAN.md`** (filter API upstream). Tu propio plan la aplazó para
  no depender de una versión no publicada, y además es una propuesta a otro
  proyecto. Fuera de la `0.2.0` salvo que lo pidas.
- **Publicación remota** del repositorio o del plugin en el catálogo.

## 12. Lo que no puedo verificar yo

Dos comprobaciones del prototipo necesitan tu ratón, y ninguna es un fallo de
código:

- **La deriva de la neblina.** La pestaña automatizada corre en
  `document.hidden`, y medí 0 fotogramas en 1,5 s: `requestAnimationFrame` está
  suspendido ahí.
- **El barrido con arrastre.** Un clic simple sí borra —comprobado—, pero el
  arrastre sintético no emite la secuencia de puntero.

## 13. Registro de progreso

| Fecha | Hito | Resultado |
|---|---|---|
| 2026-08-31 | Plan `0.2.0` redactado | Siete fases, dos puertas de decisión; siguiente tarea `A.1` |
| 2026-08-31 | Fase A | Import restaurado, guardia uso/import añadida y los nueve controles verificados en el panel real |
| 2026-08-31 | Spike `D.1` | `destination-out` soportado y 1,5 ms por fotograma; la cubierta va con `Canvas` |
| 2026-08-31 | Fase C | `peek` inerte: no escribe, no consume la omisión, no avanza la generación y no llega a la CLI. 13 tests nuevos |
| 2026-08-31 | Fase B | `0005` y `0006` aceptadas; `F1.11`, `F4.5`, criterios de terminado, UX-OPPORTUNITIES y SECURITY reformulados |

## 14. Definición operativa de terminado

`0.2.0` está terminada cuando:

- Los nueve controles del panel se renderizan y responden.
- La pantalla principal muestra los diez estados correctamente en el panel real.
- Una muestra marcada atraviesa `peek` y no aparece en logs, estado en disco,
  notificaciones ni salidas estándar.
- Nada marcado como sensible se puede mostrar por ninguna vía, ni pidiéndolo.
- Cada animación tiene su vía de movimiento reducido.
- `develop` está fusionado en `main` y el CHANGELOG no tiene sección pendiente.
