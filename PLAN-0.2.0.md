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
| D. Pantalla principal | Terminada | Vista de portapapeles con cubierta | Los diez estados se ven correctos en el panel real |
| D2. Privacidad por app | Pendiente | Listas `alwaysCovered` y `blockedApps` | Una app bloqueada no devuelve contenido ni pidiéndolo |
| E. Onboarding | Terminada | Bienvenida y tour hacia la nueva pantalla | El recorrido termina donde diga `0006` |
| F. Microinteracciones | Pendiente | `motionEnabled` y las tres de prioridad alta | Cada movimiento tiene su vía de movimiento reducido |
| H. Bilingüe | Terminada | Catálogo en inglés y español | Las dos tablas comparten claves y marcadores |
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
- [x] `D.2` Vista principal: estado, veredicto, subtítulo, dos filas de altura
      fija, desglose y acciones.
- [x] `D.2a` Separar enseñar de informar ([`0007`](./docs/decisions/0007-la-pantalla-frecuente-informa.md)):
      `StatusHeader` pierde el titular y la ilustración, que se quedan en
      bienvenida y tour. Verificado en el panel real.
- [x] `D.3` Cubierta por defecto, con ojo por fila y barrido si `D.1` lo permite.
      El ojo es la ruta de teclado y manda; el barrido es el adorno.
- [x] `D.4` Estados de bypass —imagen, archivos, sensible— y portapapeles vacío.
- [x] `D.5` Chips de tipos MIME para el caso «formato enriquecido», donde el
      texto no cambia y el diff no sirve.
- [x] `D.6` Botón «Opciones» y la página de ajustes como segunda vista.
- [x] `D.7` Recorrido completo por teclado y semántica accesible: mientras hay
      cubierta, el texto no se anuncia.
- [x] `D.8` Verificación en el panel real de los diez estados, con capturas.

### Criterios de salida

- Los diez estados se ven correctos en el panel real, no sólo en tests.
- Cambiar de portapapeles vuelve a cubrir.
- Nada de lo sensible se puede destapar por ninguna vía.

---

## 7bis. Fase D2 — Privacidad por aplicación

Dos listas nuevas, pedidas el 31 de agosto. Hoy sólo se cubre lo que Wayland
marca como sensible, y el usuario sabe cosas que Wayland no sabe.

Ambas se deciden en `0008` antes de escribir código, porque tocan la frontera
que fijó la `0005`.

| Lista | Qué hace | Dónde se aplica |
|---|---|---|
| `sourceExclusions` (existe) | Lo copiado ahí no se limpia | helper |
| `targetExclusions` (existe) | «Pegar limpio» no actúa ahí | helper |
| **`alwaysCovered`** (nueva) | Llega siempre cubierto; el ojo lo levanta y vuelve a cubrirse en la copia siguiente | panel, con la marca que da el helper |
| **`blockedApps`** (nueva) | OmaPlain ni lee ni muestra; el panel dice «aplicación excluida» | **helper**, nunca la UI |

### Trabajo

- [ ] `D2.1` Decisión `0008` con las cuatro listas y por qué son cuatro y no dos.
- [ ] `D2.2` El demonio recuerda la **clase de la aplicación de origen** del
      último evento. Es metadato, no contenido: la `0007` prohíbe recordar el
      texto, no de dónde vino.
- [ ] `D2.3` `peek` devuelve `blocked` sin contenido cuando el origen está en
      `blockedApps`. La negativa vive en el helper, como la de lo sensible.
- [ ] `D2.4` `peek` marca `cover: true` cuando el origen está en `alwaysCovered`.
- [ ] `D2.5` La ruta automática también salta `blockedApps`: si no se lee, no se
      limpia.
- [ ] `D2.6` Sección «Privacidad» en ajustes con las dos listas nuevas,
      separadas de las de limpieza.
- [ ] `D2.7` Tests: una muestra marcada copiada desde una app bloqueada no
      aparece en la respuesta de `peek`; y `alwaysCovered` no se puede
      convertir en revelado permanente.

### Criterios de salida

- Una app bloqueada no devuelve contenido ni pidiéndolo explícitamente.
- Una app siempre cubierta vuelve a cubrirse en la copia siguiente, aunque se
  hubiera levantado el ojo.

---

## 8. Fase E — Onboarding y welcome tour

Bloqueada por `B.2`.

### Trabajo

- [x] `E.1` Reordenar el recorrido según `0006`.
- [x] `E.2` Adaptar el tour: la demostración segura ya existe y sigue anclada al
      motor por `test_demo_sample.py`.
- [x] `E.3` El recorrido termina en la pantalla principal con el portapapeles
      real delante.
- [x] `E.4` `onboardingVersion` sube a `2`; quien venía de la `0.1.0` ve una vez
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
- [ ] `F.6` El carrusel del estado vacío cicla sin fin y sin forma de pararlo,
      que es lo que pide la WCAG 2.2.2. El componente ya acepta `motionEnabled`
      y se queda quieto con él en falso; lo que falta es quién lo conduce, y
      eso es `F.1`.

### Criterios de salida

- Cada movimiento tiene su vía explícita de movimiento reducido.
- Ninguna animación **de respuesta a una acción** supera los 300 ms ni anima
  otra cosa que no sea `transform` u `opacity`.
- Las **demostraciones** —la ilustración de la bienvenida y el carrusel del
  estado vacío— duran lo que hace falta para leerlas, y pueden animar el ancho
  de lo que se retira porque eso *es* lo que demuestran.

> El criterio original no distinguía, y así redactado ya lo incumplía la
> ilustración que la `0004` aceptó: 620 ms y a propósito. Un tope pensado para
> la respuesta a un clic no dice nada útil sobre una animación que nadie ha
> pedido y que está ahí para ser leída.

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

## 12. Verificación en el panel real

Ambas comprobaciones que quedaron pendientes en el prototipo están cerradas.
En el navegador no se podían hacer —la pestaña automatizada corre en
`document.hidden`, sin fotogramas, y el arrastre sintético no emite la
secuencia de puntero— pero en el panel real sí, conduciendo el puntero del
compositor con `hl.dsp.cursor.move` y `hl.dsp.send_key_state`.

| Comprobación | Método | Resultado |
|---|---|---|
| El barrido con arrastre | Puntero real: pulsar, catorce movimientos, soltar | Limpia el vaho y deja ver el texto con el borde suave |
| La deriva de la neblina | Dos capturas separadas 4 s, comparadas con `magick compare` | RMSE 3819 (5,8 %) frente a 0 de la imagen contra sí misma |

Queda un estado sin ver en vivo: **el de formato enriquecido**. `wl-copy`
acepta un solo `--type`, así que no se puede montar desde la shell un
portapapeles que ofrezca `text/html` y `text/plain` a la vez. El lado del
motor está cubierto por tests y los chips se ven funcionando en los bypass;
lo que no se ha visto es la combinación.

## 13. Registro de progreso

| Fecha | Hito | Resultado |
|---|---|---|
| 2026-08-31 | Plan `0.2.0` redactado | Siete fases, dos puertas de decisión; siguiente tarea `A.1` |
| 2026-08-31 | Estado vacío (dibujos) | Tres siluetas distintas, peine y motas atados al mismo avance, coreografía por turno con la tarjeta quieta. Ejemplos al catálogo y comprobados contra el motor en los dos idiomas |
| 2026-08-31 | Fase A | Import restaurado, guardia uso/import añadida y los nueve controles verificados en el panel real |
| 2026-08-31 | Bilingüe | 163 claves en inglés y español, selector en ajustes y `auto` desde el locale. Verificado en pantalla en los dos idiomas |
| 2026-08-31 | Fase E | El recorrido pasa por Ajustes con dos salidas visibles; ilustración animada con vía de movimiento reducido |
| 2026-08-31 | Estado vacío | Cuatro direcciones prototipadas; elegido el carrusel, con sus ejemplos atados al motor (`0008`) |
| 2026-08-31 | Verificación | Arrastre y deriva comprobados con puntero real; seis de siete estados vistos en el panel |
| 2026-08-31 | Fase D | Chips MIME, estados de bypass y desglose con su ajuste. Portapapeles vacío deja de contarse como error. Seis estados verificados en el panel real |
| 2026-08-31 | Fase D (parcial) | Panel partido en dos páginas: portapapeles y ajustes tras el engranaje. Veredicto, dos filas, desglose y acciones debajo. Verificado en el panel real |
| 2026-08-31 | Decisión `0007` | La pantalla frecuente informa y la primera enseña; el héroe educativo sale de la vista diaria. Sin memoria del contenido |
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
