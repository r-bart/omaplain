# Prueba de instalación limpia, 2 de septiembre de 2026

Desinstalar la copia de desarrollo e instalar el plugin como lo haría
cualquiera, con `omarchy plugin add`, sobre el escritorio real y en un
workspace vacío. Dos instalaciones: una desde GitHub, que es la vía del
README, y otra desde el repositorio local, para probar el código de hoy por
la misma tubería.

## Lo que encontró

### 1. Instalar desde GitHub da la `0.1.0`, y la `0.1.0` está rota

`omarchy plugin add` clona la rama por defecto del repositorio, que es `main`,
y `main` va **69 commits por detrás** de `develop`. La instalación aterriza
con `manifest.version` en `0.1.0`.

Arrancada, el diario del shell repite:

```text
WARN scene: …/components/SettingRow.qml[9:-1]: ReferenceError: Style is not defined
```

Es el fallo que el `CHANGELOG` de la `0.2.0` describe: los encabezados de
ajustes se pintan y debajo no hay ni un control. Se comprobó en pantalla.

**Consecuencia:** hasta que `develop` se fusione en `main`, quien siga el
README instala un producto que no se deja usar. Es la tarea `A.1` del plan, y
bloquea todo lo demás por una razón concreta y no sólo por orden.

### 2. El README decía que colocar el icono era cosa tuya

No lo es. `omarchy plugin enable` coloca el widget de barra de cualquier
plugin que lo declare: pregunta la sección de forma interactiva y, con
`--yes`, usa la de por defecto. La instalación de prueba dejó el icono en
`bar.center` sin que nadie lo pidiera. Corregido en el README.

## Lo que funcionó, en una instalación desde cero

| Comprobación | Resultado |
|---|---|
| `git clone` y `omarchy plugin validate` | correctos |
| `check-dependencies` | `ok`, sin nada que falte, versión `0.2.0` |
| Entrada `.desktop` | `desktop-file-validate` la acepta |
| Demonio y watcher | ambos vivos; `wl-paste --type text --watch` con `setpriv` |
| Ficheros de sesión | `0700` el directorio, `0600` config, estado y socket |
| Arranque del QML | sin un solo error en el diario |
| Primera ejecución | bienvenida, tour de tres pasos con su demostración, y los ajustes como último paso |
| Ajustes | todos los controles visibles, que es lo que la `0.1.0` no conseguía |
| Icono de la barra | colocado y funcional |
| Pantalla de cada día | «Already clean» sin botón muerto, con la línea de la omisión ([`0015`](../decisions/0015-la-pantalla-frecuente-no-ofrece-un-boton-muerto.md)) |

### La `0012`, en su escenario real

Una instalación limpia deja la entrada **sólo** en `bar.layout`, con
`plugins[]` ausente. Es exactamente el caso que la `0012` arregla, y aquí se
dio sin provocarlo.

Se apagó «Normalizar finales de línea» y se reinició el shell. El ajuste
sobrevivió en los tres sitios —`bar.layout`, el espejo de `plugins[]` y la
configuración de sesión que lee el helper— y el demonio lo obedeció: una
copia con `CRLF` quedó `unchanged`.

## Cómo se restauró

La copia de desarrollo se guardó entera antes de empezar, con su `stash`, y
se devolvió al terminar junto con `shell.json` byte a byte. La entrada del
lanzador se retiró porque no estaba antes. El portapapeles se guardó y se
devolvió.
