# Plan de cierre de la `0.2.0`

- Estado: **borrador, pendiente de aprobación**
- Fecha: 31 de agosto de 2026
- Sustituye en detalle a las fases `D2`, `F` y `G` de
  [`PLAN-0.2.0.md`](./PLAN-0.2.0.md), que se quedan como índice.

## Qué significa «acabado» aquí

Dejar la `0.2.0` lista para **una prueba final tuya**, que es el paso previo a
publicar. Lo que este plan ejecuta termina justo antes de fusionar: la fusión a
`main` y la etiqueta son la puerta que se cruza **después** de que esa prueba
pase, no parte del trabajo.

Fuera de alcance, igual que en el plan madre: publicar en el catálogo y la fase
6 de `PLAN.md` (filter API upstream).

## De dónde partimos

Seis fases de nueve terminadas. `develop` va 28 commits por delante de `main`,
con 114 tests, benchmark, soak y validador en verde. Quedan tres fases: la
privacidad por aplicación, las microinteracciones y el cierre.

## Las dos decisiones que había que tomar antes

Las dos se preguntaron y se respondieron el 31 de agosto. Van aquí porque
condicionan código y copy, y porque conviene que quede escrito quién decidió.

### 1. Hasta dónde llega la promesa de «app bloqueada»

Wayland no dice quién copió. El demonio lo deduce de la ventana enfocada en el
instante del evento, y el propio código ya lo rotula: *«Wayland cannot guarantee
the source, so this remains best effort and is never a safety gate»*
(`daemon.py`). Hoy eso sólo decide si algo se limpia —fallar es inofensivo—;
una lista de bloqueo convierte esa suposición en una promesa de privacidad.

**Elegido: best-effort, dicho claro.** Bloquea cuando reconoce la app, y la
interfaz no promete más que eso. Es lo que el mecanismo puede cumplir.

**Descartado:** *a prueba de fallos* —no enseñar nada cuando no se puede
atribuir— porque convierte un fallo raro de `hyprctl` en una pantalla rota en el
uso diario. Y *sin lista de bloqueo*, que resuelve el problema renunciando a lo
que pediste.

### 2. Quién conduce el movimiento reducido

Cinco componentes aceptan `motionEnabled` y **nadie lo conduce**. El carrusel
del estado vacío cicla sin fin y sin forma de pararlo, que es exactamente lo que
la WCAG 2.2.2 no permite.

**Elegido: un ajuste «Reducir movimiento».** Es el mecanismo de parada que pide
la norma, y sirve a quien se marea con el movimiento, no sólo a esa tarjeta.

Esto **enmienda la `F.1`**, que decía «propiedad que los componentes aceptan y
las probes conducen, no un ajuste de usuario». El motivo del original era no
inventar preferencias; el motivo para cambiarlo es que sin un mando accesible no
hay forma de parar una animación indefinida, y Omarchy no expone hoy ninguna
preferencia de sistema de la que colgarse (comprobado en `Commons/`).

---

## Ficheros

| Fichero | Acción | Para qué |
|---|---|---|
| `docs/decisions/0009-privacidad-por-aplicacion.md` | Crear | Las cuatro listas, la frontera de atribución y el alcance de la promesa |
| `helper/omaplain_lib/config.py` | Modificar | `alwaysCovered` y `blockedApps` en `DEFAULTS` y `_LIST_KEYS` |
| `helper/omaplain_lib/daemon.py` | Modificar | Recordar la clase de origen; bloquear antes de leer; marcar `cover` |
| `Service.qml` | Modificar | Los dos ajustes nuevos en la lista blanca de `updateSetting`; `reduceMotion` |
| `Panel.qml` | Modificar | Sección «Privacidad»; `motionEnabled` a los cinco componentes; `F.3` y `F.4` |
| `components/Strings.js` | Modificar | Copy nuevo en inglés y español |
| `components/StatusHeader.qml` | Modificar | Estado «omitir una copia» (`F.4`) |
| `components/ClipboardRow.qml` | Modificar | Confirmación visual de la limpieza (`F.3`); honrar `cover` |
| `tests/unit/test_privacy_lists.py` | Crear | La app bloqueada y el ojo que no persiste |
| `tests/unit/test_ui_contract.py` | Modificar | Guardas de la sección nueva y del movimiento reducido |
| `CHANGELOG.md` | Modificar | Cerrar «Sin publicar» en una `0.2.0` |
| `docs/RELEASE-NOTES-0.2.0.md` | Crear | Notas, con la advertencia de pantalla compartida |
| `docs/COMPATIBILITY.md`, `docs/TEST-REPORT.md` | Modificar | Matriz y evidencia repetidas sobre el estado final |

---

## Fase 1 — `D2`, privacidad por aplicación

La única de las tres que toca el helper, y la que mueve la frontera de la
`0005`. Va primero porque `F` y `G` se apoyan en una interfaz ya estable.

### `D2.1` — Decisión `0009`

Antes de escribir código, como manda el proceso del repo. Contenido mínimo:

- Las cuatro listas y por qué son cuatro y no dos: dos deciden **si se limpia**
  (`sourceExclusions`, `targetExclusions`) y dos deciden **si se lee y se
  enseña** (`alwaysCovered`, `blockedApps`). Mezclarlas haría que apagar una
  limpieza escondiera contenido, o al revés.
- La frontera de atribución, con la cita del `daemon.py` y el alcance elegido.
- Que la negativa vive en el helper y nunca en la UI: en la UI, una negativa es
  un ajuste, y un ajuste que puede destapar un secreto marcado es un revelador
  de contraseñas con pasos extra.
- Que el ojo levanta el vaho **una vez**: la copia siguiente vuelve a taparlo.

### `D2.2` — El demonio recuerda de dónde vino la copia

`_handle` ya toma la instantánea del origen en cada evento
(`source = self.backend.active_window()`). Falta guardarla, porque cuando el
panel pregunta el origen ya no es el de la copia: es el propio panel.

```python
# daemon.py — junto al resto del estado en memoria
self.last_source: str = ""      # clase de la ventana, nunca contenido
```

Se escribe en `automatic_event` y se lee en `peek`. Es metadato: la `0007`
prohíbe recordar el texto, no de dónde vino. No se persiste, no entra en
`status.json` y muere con el proceso.

**Caso límite:** antes del primer evento, y cuando `active_window()` devuelve
`None`, la clase es desconocida. Con el alcance elegido, desconocido **no** es
bloqueado.

### `D2.3` — `peek` devuelve `blocked` sin contenido

En `peek()`, antes de cualquier lectura:

```python
if self._source_blocked(self.last_source):
    return {"eligible": False, "reason": "blocked", "types": []}
```

Sin `original`, sin `cleaned`, sin `applied` y sin tipos MIME: de una app
bloqueada no se enseña ni de qué está hecho el contenido, que es más de lo que
se calla hoy con un bypass normal.

### `D2.4` — `peek` marca `cover: true`

Cuando el origen está en `alwaysCovered`, la respuesta lleva el contenido —hace
falta para enseñar el antes y el después— pero con la marca. El panel arranca
con las dos filas cubiertas y el ojo las levanta.

### `D2.5` — La ruta automática también salta las bloqueadas

En `_inspect_and_transform`, junto a `_source_excluded` y **antes** de
`self.backend.read(...)`: si no se lee, no se limpia. Motivo distinto del de
`sourceExclusions`, así que motivo distinto en el bypass: `source_blocked`.

### `D2.6` — Sección «Privacidad» en ajustes

Separada de las exclusiones de limpieza, con su propio encabezado y su propio
estado vacío, reutilizando `ExcludedAppRow` y `EmptyState`. El copy dice lo que
hace cada lista y **dice también lo que no puede garantizar**.

### `D2.7` — Tests

- Una muestra marcada copiada desde una app bloqueada no aparece en la respuesta
  de `peek`, ni truncada ni en los tipos.
- `alwaysCovered` no se puede convertir en revelado permanente: tras una copia
  nueva, el panel vuelve a cubrir.
- `validate_config` acepta las listas nuevas y descarta entradas inválidas igual
  que las dos que ya existen.
- Config vieja leída por helper nuevo y al revés: sin avisos ni pérdidas.

---

## Fase 2 — `F`, microinteracciones

### `F.1` — Un ajuste conduce el movimiento

`reduceMotion` en `config.py`, en la lista blanca de `updateSetting` y en la
sección de ajustes. `Panel.qml` lo baja a los cinco componentes que ya lo
aceptan: la ilustración, el tour, la bienvenida, la cubierta de vaho y el
carrusel. Con él puesto, el carrusel se queda en el primer ejemplo ya peinado.

### `F.2` — Enmendar la `0004`

Registrar que la puerta queda abierta, con qué mando y por qué dejó de ser
«sólo para pruebas».

### `F.3` — Confirmación visual de la limpieza

Tras una limpieza manual correcta, la fila «después» se asienta y enseña su
sello ~1,5 s. Sólo `opacity` y `scale`, por debajo de 220 ms, con su vía de
movimiento reducido. Es la nº 1 de `UX-OPPORTUNITIES`.

### `F.4` — «Omitir una copia», visible

Con `skipNext` activo, el encabezado lo dice con una hoja apartada y la frase
«La próxima copia pasará intacta». **Sin cuenta atrás**: el estado expira por
evento o por tiempo, y un reloj añade presión sin ayudar a decidir.

### `F.5` — Los cuatro de prioridad media, con criterio

Dos son incondicionales y entran: el bloque desplegable que explica **por qué
puede aparecer el original en el historial**, y el feedback que persiste
mientras el foco siga en la zona de resultado en vez de irse a los 2,5 s.

Los otros dos son condicionales en su propio texto y se resuelven **después** de
que `D2.6` haya crecido la página de ajustes: si la página pasa de un largo
razonable, entra la divulgación «Limpieza avanzada»; los iconos de aplicación
siguen fuera hasta que exista una fuente coherente, que no la hay.

### `F.6` — Queda cubierta por `F.1`

El mando de parada es el ajuste. Se cierra al cerrar `F.1`.

---

## Fase 3 — `G`, cierre

- `G.1` Matriz de compatibilidad y soak repetidos sobre el estado final.
- `G.2` Auditoría de privacidad con el criterio de la `B.3`: una muestra marcada
  atraviesa `peek` y se persigue por stdout, stderr, `status.json` y todos los
  ficheros de runtime. Ahora con dos rutas más que auditar: la bloqueada y la
  cubierta.
- `G.3` Validador oficial de plugins.
- `G.4` CHANGELOG: cerrar «Sin publicar» en una `0.2.0`. Hoy tiene dos entradas
  y por debajo hay 28 commits de trabajo real; hay que escribirlo entero.
- `G.6` Notas de release, con la advertencia de pantalla compartida.
- `G.5` **Fusionar y etiquetar: no.** Es la puerta que se cruza después de tu
  prueba final, y la cruzas tú.

---

## Dependencias

```yaml
dependencies:
  D2.1: []
  D2.2: [D2.1]
  D2.3: [D2.2]
  D2.4: [D2.2]
  D2.5: [D2.2]
  D2.6: [D2.3, D2.4]
  D2.7: [D2.3, D2.4, D2.5]
  F.1:  []
  F.2:  [F.1]
  F.3:  [F.1]
  F.4:  [F.1]
  F.5:  [D2.6]
  G.1:  [D2.7, F.3, F.4, F.5]
  G.2:  [D2.7]
  G.3:  [G.1]
  G.4:  [G.1, G.2, G.3]
  G.6:  [G.4]
```

`F.1` no depende de `D2`, así que puede ir en paralelo si conviene; `F.5` sí,
porque su decisión depende de cuánto haya crecido la página de ajustes.

---

## Riesgos

| Riesgo | Qué pasa si sale mal | Mitigación |
|---|---|---|
| **Atribución equivocada** | Una copia de una app bloqueada se lee y se enseña | Alcance elegido y dicho en el copy; nunca se vende como barrera |
| **`peek` lee antes de comprobar** | El bloqueo no bloquea nada | La comprobación va en la primera línea, y el test usa una muestra marcada |
| **El ojo se vuelve permanente** | Una app «siempre cubierta» deja de estarlo | El panel reinicia `showBefore`/`showAfter` con cada generación; test propio |
| **La página de ajustes se hace larga** | Los ajustes de limpieza se pierden bajo la privacidad | `F.5` decide la divulgación **con la página ya crecida**, no antes |
| **Config nueva con helper viejo** | Avisos o pérdida de ajustes | `validate_config` ignora claves desconocidas a propósito; test de ida y vuelta |
| **Texto con formato nunca visto** | Un estado se publica sin haberse mirado | Ver abajo: entra en la prueba final con el apaño de fixture |

### El estado que nunca se ha visto

`wl-copy` acepta un solo `--type`, así que un portapapeles que ofrezca
`text/html` y `text/plain` a la vez no se puede montar desde una shell. Está
cubierto por fixtures y por el motor, pero **el panel real nunca lo ha pintado
con contenido de verdad**. En `G.1` se monta con una copia real desde Chromium,
que es exactamente el caso, y se mira.

---

## Pruebas

- **Unitarias:** listas nuevas en `config`, bloqueo en `peek`, marca `cover`,
  bypass automático, ida y vuelta de configuración.
- **Contrato de UI:** la sección «Privacidad» existe y está separada; el ajuste
  de movimiento llega a los cinco componentes; el copy nuevo está en las dos
  tablas del catálogo.
- **Privacidad:** la muestra marcada perseguida por todas las salidas.
- **En el panel real:** los diez estados, más bloqueada, más cubierta, en los
  dos idiomas, con y sin movimiento.

---

## Criterios de terminado

### Fase 1 — `D2`

- [ ] `docs/decisions/0009-*.md` existe y dice qué **no** garantiza la lista.
- [ ] Una muestra marcada copiada desde una app bloqueada: `peek` responde
      `blocked` y su respuesta no contiene ni contenido ni tipos.
- [ ] Con la app en `alwaysCovered`, el panel abre con las dos filas cubiertas;
      tras levantar el ojo y copiar otra vez, vuelven a estar cubiertas.
- [ ] `tests/run.sh` en verde.

### Fase 2 — `F`

- [ ] Con «Reducir movimiento» puesto, el carrusel no cicla y la ilustración se
      pinta en su estado final: verificado en el panel real, no sólo por test.
- [ ] La confirmación de limpieza dura menos de 220 ms y sólo mueve `opacity` y
      `scale`.
- [ ] Con `skipNext` activo, el encabezado lo enseña y no hay ninguna cuenta
      atrás en el código.

### Fase 3 — `G`

- [ ] Matriz de compatibilidad repetida, incluido `text/html` + `text/plain`
      desde Chromium, **visto en el panel**.
- [ ] Auditoría de privacidad: la muestra marcada no aparece en stdout, stderr,
      `status.json` ni ningún fichero de runtime.
- [ ] `omarchy plugin validate .` en verde.
- [ ] `CHANGELOG.md` sin sección «Sin publicar».
- [ ] `docs/RELEASE-NOTES-0.2.0.md` con la advertencia de pantalla compartida.

### Global

- [ ] `tests/run.sh` completo en verde (unitarias, benchmark, soak, validador).
- [ ] Sin `TODO`, `FIXME` ni `HACK` en el código nuevo.
- [ ] El journal del shell, limpio tras reiniciar y abrir el panel.
- [ ] `develop` empujado; `main` **sin tocar**.

---

## La prueba final

Lo que queda para ti cuando esto termine. Se hace sobre `develop`, con el plugin
instalado como si acabara de instalarse:

1. **Primera vez.** Bienvenida, tour de tres pasos, ajustes con su salida
   visible, y aterrizar en la pantalla principal.
2. **Los estados de todos los días.** Portapapeles vacío, ya limpio, con algo
   que limpiar, con formato, sensible, archivo, imagen, demasiado grande.
3. **Privacidad.** Una app en cada lista nueva, comprobando que la bloqueada no
   enseña nada y que la cubierta se vuelve a cubrir.
4. **Los dos idiomas y dos temas**, uno claro y uno oscuro.
5. **Reducir movimiento**, puesto y quitado.

Si algo falla, se corrige y se repite el punto que falló. Cuando pase entera,
`G.5`: fusionar a `main` y etiquetar.
