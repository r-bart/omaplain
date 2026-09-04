# Matriz de compatibilidad

Matriz observada sobre el baseline descrito en [BASELINE.md](./notes/BASELINE.md). Los MIME se registran como metadatos; ningún contenido real se guarda en estos documentos.

| Origen | Evidencia | MIME relevantes | Decisión v0.1 |
|---|---|---|---|
| Chromium 151 | Copia real de fixture HTML | `text/plain`, `text/html`, `chromium/x-source-url`, token interno | Elegible; usar plain y retirar rich |
| Foot 1.27 | Selección real de scrollback | `text/plain;charset=utf-8` y aliases | Elegible |
| Nautilus 50 | Copia real de dos archivos | `x-special/gnome-copied-files`, `text/uri-list`, portal transfer | Bypass `files` |
| LibreOffice Writer 26.2 | Copia real de documento HTML | plain UTF-8/UTF-16, RTF, HTML y varios `application/x-openoffice-*` | Bypass conservador `structured` |
| Gestor de contraseñas | Fixture estándar `wl-copy --sensitive` | `x-kde-passwordManagerHint` | Bypass antes de leer |
| Captura/imagen | Payload PNG controlado | `image/png` | Sin intervención del watcher textual |
| Clipboard vacío | Estado `nil`/`clear` | Sin tipos | Bypass `empty` |

## Revisión para la 0.2.0

La matriz de arriba sigue vigente: las reglas de clasificación no cambiaron en
esta versión —lo único que cambió en esa capa es que un `wl-paste --list-types`
que sale con error se toma como portapapeles vacío y no como fallo—, y el soak
de 28.800 eventos y el benchmark se repitieron sobre el estado final sin
desviaciones.

Dos precisiones de plataforma, comprobadas el 2 de septiembre:

- **Una copia de archivos sí llega; una imagen pura necesitaba un segundo
  vigilante.** Medido el 2 de septiembre: una copia de Nautilus ofrece
  `text/uri-list` junto a `text/plain`, así que `wl-paste --type text --watch`
  la ve y el demonio la clasifica como `files`. Una captura de pantalla ofrece
  sólo `image/png`, y con un único vigilante de texto no generaba ningún
  evento. Desde la `0016` hay un segundo `wl-paste --watch` sin tipo que avisa
  de esas copias y nunca de las que traen texto.
- **`Shift+Insert` pega el portapapeles en los terminales de Omarchy** porque
  sus configuraciones de alacritty, ghostty, kitty y foot lo mapean así. Con
  los valores de fábrica de esos cuatro terminales pegaría la selección
  primaria, que OmaPlain no toca.

Lo que la `0.2.0` añade por encima de ella son dos negativas nuevas, y ésas no
dependen del MIME sino de la aplicación de origen:

| Caso | Evidencia | Decisión |
|---|---|---|
| Copia desde una app en `blockedApps` | Copia real desde `foot` con el terminal en la lista | `source_blocked`, sin contenido ni tipos |
| Copia desde una app en `alwaysCovered` | Copia real desde `foot` con el terminal en la lista | Llega marcada; el vaho no se levanta |
| Portapapeles con `text/html` + `text/plain` | Selección real de una ventana GTK4 que ofrece los dos tipos | Elegible y `rich`; con automático limpia (`rich_text`), con el automático apagado **el panel lo pinta** |

Ese último dejó de estar pendiente: cómo se monta la oferta doble sin
navegador está en [TEST-REPORT-0.2.0.md](notes/TEST-REPORT-0.2.0.md).

## Revisión para la 1.0

Esta matriz tiene dos mitades, y sólo una se puede repetir sin una persona
delante copiando desde cada aplicación.

**Las ofertas** —qué tipos anuncia cada aplicación— se recogieron copiando de
verdad. Repetirlas pide sesión gráfica y manos. Lo que sí se comprobó el 4 de
septiembre de 2026 es que **las cuatro aplicaciones siguen en las versiones que
esta matriz cita**, así que las ofertas de arriba no se han quedado atrás:

| | En la matriz | Instalado hoy |
|---|---|---|
| Chromium | 151 | `151.0.7922.173-1` |
| Foot | 1.27 | `1.27.0-2` |
| Nautilus | 50 | `50.2.2-1` |
| LibreOffice Writer | 26.2 | `26.2.5-3` (`libreoffice-fresh`) |
| `wl-clipboard` | — | `1:2.3.0-1` |

**Las decisiones** —qué hace OmaPlain con cada oferta— sí se repiten, y ahora
en cada pasada de la suite. `tests/unit/test_compatibility_matrix.py` lee los
bloques de tipos de este documento, los pasa por el clasificador y comprueba
que sale lo que la tabla dice. Las siete filas salen como están escritas.

Es lo que faltaba: un documento que enumera decisiones y no las comprueba
envejece igual que envejeció el README, y aquí el coste de envejecer es que la
matriz llame «bypass» a algo que dejó de serlo.

## MIME observados

### Chromium

```text
text/plain
text/plain;charset=utf-8
UTF8_STRING
chromium/x-internal-source-rfh-token
TEXT
chromium/x-source-url
STRING
text/html
```

### Foot

```text
text/plain;charset=utf-8
text/plain
TEXT
STRING
UTF8_STRING
```

### Nautilus

```text
x-special/gnome-copied-files
text/plain;charset=utf-8
text/uri-list
application/vnd.portal.filetransfer
application/vnd.portal.files
```

### LibreOffice Writer

```text
application/x-openoffice-embed-source-xml
text/rtf
text/richtext
text/html
text/markdown
text/plain;charset=utf-16
application/x-openoffice-link
application/x-openoffice-objectdescriptor-xml
text/plain;charset=utf-8
application/x-libreoffice-internal-id-*
```

## Cobertura reproducible sin aplicaciones opcionales

Firefox y un gestor de contraseñas gráfico no están instalados en el host de desarrollo. La compatibilidad de Firefox queda cubierta por el mismo contrato observable `text/plain` + `text/html` usado por Chromium y por fixtures sintéticos del clasificador. El caso de password manager usa la marca interoperable que `wl-clipboard` documenta y que también consume el historial nativo de Omarchy.

La ausencia de una app opcional no relaja la clasificación: cualquier MIME estructural o sensible conocido sigue provocando bypass.
