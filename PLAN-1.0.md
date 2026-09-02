# Plan de la 1.0

- Escrito el 1 de septiembre de 2026, sobre `develop` en `8fca03b`; puesto al
  día el 2 de septiembre tras la revisión completa
- Estado del repositorio al escribirlo: **privado**, `main` 19 commits por
  detrás, un único tag `v0.1.0`, sin CI, README en español y desactualizado.
  Al ponerlo al día: CI en marcha, README en inglés y rehecho, la raíz
  ordenada; sigue privado, sigue sin `v0.2.0`
- Objetivo: consolidar, publicar una `1.0` y dejar OmaPlain instalable por
  cualquiera con `omarchy plugin add`

## Antes de nada: qué significa «ser plugin de Omarchy»

Esto hay que corregirlo antes de planificar sobre una idea equivocada. **No
existe un registro de plugins de terceros.** Lo comprobé en la instalación:
`omarchy plugin catalog` sólo recorre lo que ya está instalado en disco
—`$OMARCHY_PATH/shell/plugins` y `~/.config/omarchy/plugins`—, y no consulta
ningún índice remoto.

Hay dos caminos, y son muy distintos:

| | **Instalable** | **De primera parte** |
|---|---|---|
| Qué es | `omarchy plugin add https://github.com/r-bart/omaplain.git` | OmaPlain dentro del repo de Omarchy |
| Qué exige | Repo público que pase `omarchy plugin validate` | PR aceptado en `basecamp/omarchy` |
| El id | `io.github.r-bart.omaplain` | **Tendría que cambiar a `omarchy.*`** |
| Quién mantiene | Tú | Upstream, con tu ayuda |
| Descubrimiento | Discord, Discussions, el README | Viene instalado |

El validador **rechaza explícitamente** el namespace `omarchy.*` para terceros
(`plugin id '…' uses the reserved omarchy.* namespace`), así que el segundo
camino no es un ascenso del primero: es un cambio de identidad y de dueño.

**Este plan persigue el primero.** El segundo se plantea sólo si upstream lo
pide, y entonces será su propia decisión.

---

## Fase A — Consolidar el repositorio

### `A.1` La prueba final y la fusión a `main`

Bloquea todo lo demás, y la prueba de instalación del 2 de septiembre dice
por qué con un caso concreto: **`omarchy plugin add` clona `main`, y `main`
sirve hoy la `0.1.0`**, la versión cuyos nueve controles no se ven. Quien
siga el README instala un producto que no se deja usar. Está medido en
[`INSTALL-TEST-2026-09-02.md`](docs/notes/INSTALL-TEST-2026-09-02.md).

**Los criterios de cierre de la `0.2.0` ya están todos**: los siete que
faltaban se verificaron el 2 de septiembre sobre una instalación hecha desde
cero, y [`PLAN-CIERRE-0.2.0.md`](docs/notes/PLAN-CIERRE-0.2.0.md) no tiene
ninguna casilla vacía. Uno de ellos quedó sin efecto porque la
[`0016`](docs/decisions/0016-la-omision-de-una-copia-no-se-gana-su-sitio.md)
retiró la función que describía.

Así que sólo queda la parte que es tuya: **fusionar `develop` en `main`,
etiquetar `v0.2.0`** —que nunca se etiquetó— y sólo entonces empezar la 1.0.

### `A.2` Decidir qué es público y qué son notas de trabajo

La raíz llevaba `PLAN.md`, `PLAN-0.2.0.md`, `PLAN-CIERRE-0.2.0.md`,
`PLAN-1.0.md` y `SPEC.md`; `docs/` llevaba diez ficheros más. Para quien llegue
de fuera, eso era ruido delante de la puerta. **Hecho el 1 de septiembre**:

- **Se quedan a la vista**: `README.md`, `CHANGELOG.md`, `LICENSE`,
  `SECURITY.md`, `ATTRIBUTIONS.md`, `docs/decisions/`.
- **Bajan a `docs/notes/`**: los planes cumplidos, los informes de prueba, la
  `SPIKE`, la `BASELINE`, la `UI-REVIEW`, las `UX-OPPORTUNITIES`. Son historia
  útil y no material de entrada.
- **`SPEC.md`**: se mantiene como contrato vivo. El 2 de septiembre se revisó
  entero contra el código —árbol, manifiesto, configuración, IPC, invariantes,
  garantías, criterios de aceptación— y se le puso fecha de revisión. La regla
  a partir de aquí: cada cambio de comportamiento toca el SPEC en el mismo
  commit.

### `A.3` El idioma

El repositorio está en español y Omarchy y su comunidad, en inglés. El panel ya
es bilingüe; el repositorio no.

Recomendación, que necesita su decisión (`0014`):

- **En inglés** lo que lee quien llega: `README`, `CHANGELOG`, `SECURITY`,
  las notas de publicación y los mensajes de commit a partir de la 1.0.
- **En español** las decisiones de `docs/decisions/`. Su valor está en el
  matiz del argumento, traducirlas lo pierde, y son notas de diseño internas.
  El `README` puede decir en una línea que están en español y por qué.

Es la decisión más discutible del plan y por eso va con su documento. **Hecho**:
la [`0014`](docs/decisions/0014-el-idioma-del-repositorio.md) está escrita y
aceptada; README y `SECURITY` en inglés con test, decisiones y cuaderno en
español, y el `CHANGELOG` pasa al inglés con la 1.0.

### `A.4` Integración continua — **hecho**

`tests/run.sh` lo hace todo en un comando y, desde el 2 de septiembre, se
salta el validador de Omarchy cuando no está instalado y falla ante cualquier
`ResourceWarning`. La CI lo llama tal cual, así que no hay dos listas de pasos
que puedan desviarse.

`.github/workflows/tests.yml`, en **3.10 y 3.13**. Corre la suite entera
—unitarias, benchmark y soak— y comprueba el manifiesto y la entrada
`.desktop` con los mismos criterios que el validador aplica sin necesitar el
shell.

Comprobado que la suite pasa en un entorno pelado y que el helper degrada bien
sin Omarchy delante: `open-windows` devuelve lista vacía en vez de reventar, y
`check-dependencies` enumera lo que falta.

El validador completo y el humo del QML (`tests/qmllint.sh`) se quedan como
pasos locales, porque dependen de una instalación de Omarchy; `run.sh` los
salta cuando no está.

### `A.5` Higiene previa a hacerlo público — **en marcha**

- Rutas personales y datos: **comprobado hoy, no hay ninguna** (`grep` de
  `/home/rbart` y `rbart` en todo el árbol, sin resultados). Repetir justo
  antes de abrir el repositorio.
- Revisar que las capturas que se añadan al README no lleven contenido real
  de portapapeles.
- `.gitignore` ya cubre lo de Python; añadir lo de las capturas de trabajo.

---

### `A.6` Lo que apareció al instalarlo desde cero — **hecho**

Clonar el repositorio en limpio y validarlo destapó que **el helper decía
`0.1.0` durante toda la `0.2.0`**: `__version__` nunca se subió, y sale por
`check-dependencies` y por `--version`, que son justo las dos superficies que se
miran cuando algo ya ha ido mal. Corregido, y con un test que ata la versión del
helper a la del `manifest.json` y ésta al `CHANGELOG`.

La instalación en sí funciona: `plugin add` es clonar, validar y mover, y las
tres pasan sobre un clon limpio.

## Fase B — El README — **hecho, salvo una captura**

Rehecho en inglés el 1 de septiembre con la estructura de abajo, y repasado
afirmación por afirmación el 2 de septiembre: tres decían cosas que el código
no hacía —las marcas direccionales, que Quickshell no recibía el contenido,
qué hace «pegar limpio» en una ventana excluida— y las tres están corregidas.
`test_docs.py` ata al código lo que se puede atar. Las cuatro capturas están,
la del estado vacío desde el 2 de septiembre.

Tenía tres problemas, y el tercero era el grave.

1. **Está en español** (ver `A.3`).
2. **Cita la `0.2.0`** y habrá que moverlo con cada versión.
3. **Describe un producto que ya no existe.** Dice «exclusiones exactas por
   clase de aplicación, tanto de origen como de destino», que es el modelo de
   dos listas que la [`0011`](docs/decisions/0011-una-sola-seccion-de-aplicaciones.md)
   sustituyó hoy por una sección de aplicaciones con cuatro reglas cada una. Y
   no menciona el selector de ventanas abiertas, ni el icono de la barra, ni el
   lanzador.

### Estructura propuesta

1. **Una frase y una captura.** Qué hace y cómo se ve, antes de nada.
2. **Qué no hace** — arriba, no en «Limitaciones». Es la promesa: no toca
   imágenes, archivos ni secretos; no guarda historial; no abre red; no
   modifica la configuración de Hyprland; no se apropia de `Super+V`.
3. **Instalar**: `omarchy plugin add`, la entrada del lanzador, el icono de la
   barra.
4. **Las tres formas de abrirlo** ([`0010`](docs/decisions/0010-como-se-abre-el-panel.md)).
5. **Qué limpia**, con un ejemplo real de antes y después.
6. **Reglas por aplicación** ([`0011`](docs/decisions/0011-una-sola-seccion-de-aplicaciones.md)).
7. **Privacidad**, con el alcance exacto de la promesa
   ([`0009`](docs/decisions/0009-privacidad-por-aplicacion.md)): la atribución
   de origen es best-effort porque Wayland no dice quién copió.
8. **Requisitos** y versiones probadas.
9. **Desarrollo**: `tests/run.sh`, y que las decisiones se leen en `docs/decisions/`.
10. **Licencia**.

### Capturas

Hacen falta cuatro, y hay que producirlas con contenido de mentira: estado
vacío, algo que limpiar con las dos filas, la sección de aplicaciones, y un
bypass. Ninguna con portapapeles real.

---

## Fase C — La 1.0

### `C.1` Qué promete un 1.0 aquí

Que **la promesa es estable**: lo que OmaPlain no toca hoy no lo tocará mañana,
y la configuración de un usuario sobrevive a las actualizaciones. No promete
que no haya más funciones; promete que las que hay no cambian debajo.

### `C.2` Lo que hay que resolver antes

Las «limitaciones conocidas», clasificadas el 2 de septiembre:

| Limitación | Veredicto |
|---|---|
| El historial de Omarchy puede guardar las dos versiones | **Permanente** hasta que el core ofrezca una API de filtro; documentada en el README y explicada en el panel |
| Un secreto sin marca es texto normal | **Permanente**, de plataforma; la salida es la regla «no leer» por aplicación |
| La atribución de origen es best effort | **Permanente**, Wayland no dice quién copió; el panel lo dice en esas palabras |
| LibreOffice se evita por conservador | **Permanente** en la 1.0; revisar si alguien lo pide con un caso |
| La selección primaria no se procesa | **Permanente**: es otra cosa y tocarla sorprendería |
| Los dispositivos no se sincronizan | **Permanente**: no hay red y no la habrá |
| Sólo el seat por defecto | **Permanente** en la 1.0 |
| Una imagen o un archivo no genera evento | **Permanente**, es cómo funciona `wl-paste --type text`; documentada en README y COMPATIBILITY |
| `maxBytes` sin control en la interfaz | **Fijo y documentado** («1 MiB» en el README); se expone sólo si alguien lo pide |

Lo que sigue abierto:

- **El clic derecho del icono de la barra sigue libre** ([`0010`](docs/decisions/0010-como-se-abre-el-panel.md)).
  Decidir si `pasteClean` se le cuelga o se deja libre para siempre.
- **Dos defectos de plataforma anotados y no arreglados**: el borde en reposo
  a 2,79:1 y la fórmula del `placeholderTextColor` del kit
  ([`0012`](docs/decisions/0012-el-anillo-de-foco-y-donde-viven-los-ajustes.md)).
  Decidir si se reportan a Omarchy antes de la 1.0.

### `C.3` Compatibilidad

Omarchy va por **`4.0.0.alpha`**, y hoy mismo un cambio del kit nos costó un
fallo silencioso: `updateEntryInline` escribe en `bar.layout` y el panel leía
`plugins[]`, así que con el icono puesto no se guardaba ningún ajuste.

- Declarar en el README la versión de Omarchy contra la que se probó.
- Mantener y ampliar los tests que **vigilan el kit** —ya hay tres— porque son
  lo único que avisa antes que el usuario.
- Decidir la política: ¿la 1.0 se ata a Omarchy 4.x?

### `C.4` La publicación

`manifest.json` a `1.0.0`, `CHANGELOG` cerrado, `docs/RELEASE-NOTES-1.0.md`,
tag `v1.0.0` y release en GitHub. Y **hacer el repositorio público**, que es el
requisito que lo convierte en instalable.

---

## Fase D — Proponerlo

Sólo cuando la 1.0 esté publicada y el repositorio sea público.

1. **Que instale de verdad.** Probar `omarchy plugin add` desde cero en una
   sesión limpia, no sobre la copia de desarrollo. Es la única prueba que
   cuenta.
2. **Anunciarlo donde vive la comunidad**: el Discord de Omarchy y
   Discussions → Suggestions. Los issues de `basecamp/omarchy` son sólo para
   fallos verificados de Omarchy; un plugin de terceros no va ahí.
3. **Escuchar y esperar.** Si upstream se interesa por adoptarlo, entonces —y
   sólo entonces— se plantea el camino de primera parte, con su decisión: id
   nuevo, árbol movido y mantenimiento compartido.

---

## Orden y dependencias

```
A.1 prueba final + merge + tag v0.2.0
 └─> A.2 estructura   A.3 idioma (0014)   A.5 higiene
      └─> A.4 CI
           └─> B README (necesita A.3 y las capturas)
                └─> C.2 limitaciones  C.3 compatibilidad
                     └─> C.4 publicar 1.0 + repo público
                          └─> D proponerlo
```

`A.1` bloquea todo. `A.3` bloquea `B`. `C.4` bloquea `D`.

## Lo que dejó la revisión completa del 2 de septiembre

Una lectura de todo —helper, QML, docs, tests— contra el código instalado del
shell y el fuente de `wl-clipboard`. Lo que se arregló está en el `CHANGELOG`
bajo «Sin publicar». Lo que queda como deuda, nombrado:

- **El QML se ejecuta, pero sólo con Omarchy delante y sólo los
  componentes.** `tests/qml.sh` levanta un Hyprland anidado y corre los
  componentes dentro de un Quickshell de verdad: dieciocho comprobaciones en
  medio segundo, y probado que caza una regresión inyectada. `qmltestrunner`
  no vale —los tipos de Quickshell están enlazados dentro de su binario— y
  el backend headless de Hyprland pide permisos de DRM, así que en la CI se
  salta. **`Panel.qml` y `Service.qml` siguen sin ejecutarse en ninguna
  prueba**: necesitan el shell entero, con su `shell.json` y sus procesos.
  Ésa es la deuda que queda, y es la que esconde los fallos de ciclo de vida
  que la revisión del 2 de septiembre encontró leyendo.
- **Parte de la suite sigue leyendo el fuente en vez de ejecutarlo**
  (`test_ui_contract.py`, `test_apps_section.py`). Los bucles que pasaban en
  vacío ya afirman que hay algo que recorrer; el resto se irá sustituyendo
  cuando exista el runner de arriba.
- **`FogCover` usa `Canvas.FramebufferObject`**, destino heredado en Qt 6.
  Se deja porque el SPIKE midió el repintado con él; cambiarlo sin medir
  sería peor.
Saldado el mismo día: la captura del estado vacío está en el README, y la
`0014` está aceptada con `SECURITY.md` ya en inglés. Y los cambios de
comportamiento se comprobaron en la sesión real: refresco tras «Aplicar» y
tras una copia con el automático pausado, contenido olvidado al cerrar,
descubrir con el teclado. El arrastre sobre el vaho no se pudo simular sin un
inyector de ratón; queda por probar a mano.

## Criterios de terminado

- [ ] `main` tiene la 0.2.0 fusionada y etiquetada.
- [x] La raíz del repositorio se lee en diez segundos: sin planes cumplidos.
- [x] Decisión `0014` escrita y aceptada; README y SECURITY en inglés, con test.
- [x] CI en verde en cada push, con la versión mínima de Python declarada.
- [x] README rehecho, con las cuatro capturas, y **sin una sola afirmación que
      el código contradiga** — repasado el 2 de septiembre.
- [x] Cada «limitación conocida» está clasificada: arreglada o permanente.
- [ ] `manifest.json` en `1.0.0`, `CHANGELOG` cerrado, notas de publicación,
      tag `v1.0.0`.
- [ ] Repositorio público.
- [x] `omarchy plugin add` funciona desde una sesión limpia: probado el 2 de
      septiembre de punta a punta, incluida la primera ejecución y la
      persistencia de ajustes con la entrada sólo en `bar.layout`. Falta
      repetirlo contra `main` cuando lleve el código.
- [ ] Anunciado, con la versión de Omarchy contra la que se probó.

## Riesgos

**Omarchy es alpha.** Es el riesgo dominante. Una `1.0` sobre una plataforma
`4.0.0.alpha` promete estabilidad encima de algo que no la promete. Mitigación:
decir en el README contra qué versión se probó y mantener los tests que vigilan
el kit — hoy ya nos ahorraron un fallo que no daba ningún error.

**El README se vuelve a quedar atrás.** Ya ha pasado: describe el modelo de dos
listas que se sustituyó esta mañana. Mitigación: un test que compruebe las
afirmaciones comprobables del README contra el código, como los que ya vigilan
el catálogo de cadenas.

**Hacerlo público es irreversible.** El historial completo queda a la vista,
con dieciocho commits de un solo día y todos los planes. La higiene de `A.5` se
hace **antes** y no después.
