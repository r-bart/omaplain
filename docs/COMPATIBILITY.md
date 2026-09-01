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

La matriz de arriba sigue vigente: el motor de clasificación no cambió en esta
versión, y el soak de 28.800 eventos y el benchmark se repitieron sobre el
estado final sin desviaciones.

Lo que la `0.2.0` añade por encima de ella son dos negativas nuevas, y ésas no
dependen del MIME sino de la aplicación de origen:

| Caso | Evidencia | Decisión |
|---|---|---|
| Copia desde una app en `blockedApps` | Copia real desde `foot` con el terminal en la lista | `source_blocked`, sin contenido ni tipos |
| Copia desde una app en `alwaysCovered` | Copia real desde `foot` con el terminal en la lista | Llega marcada; el vaho no se levanta |
| Portapapeles con `text/html` + `text/plain` | Selección real de una ventana GTK4 que ofrece los dos tipos | Elegible y `rich`; con automático limpia (`rich_text`), con `skipNext` **el panel lo pinta** |

Ese último dejó de estar pendiente: cómo se monta la oferta doble sin
navegador está en [TEST-REPORT-0.2.0.md](notes/TEST-REPORT-0.2.0.md).

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

Antes de promover `0.1.0` a `1.0.0` se repetirá la matriz en más aplicaciones y versiones. La ausencia de una app opcional no relaja la clasificación: cualquier MIME estructural o sensible conocido sigue provocando bypass.

