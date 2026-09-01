# Informe de validación de OmaPlain 0.1.0

Fecha: 31 de agosto de 2026. Entorno: el baseline de [BASELINE.md](BASELINE.md).

## Resultado

La release local `0.1.0` cumple la puerta técnica del plan. No se publicó código ni se modificó `/usr/share/omarchy/`.

La revisión de los dos catálogos actuales confirmó que `OmaPlain` y `io.github.r-bart.omaplain` están libres. El nombre provisional OmaPaste se descartó al aparecer un gestor de historial comunitario llamado Omapaste; la decisión está en [0003-product-name.md](../decisions/0003-product-name.md).

## Suite reproducible

Comando:

```sh
tests/run.sh
```

Resultado observado:

| Prueba | Resultado |
|---|---|
| Unitarias y propiedades | 45 tests, 0 fallos |
| Transformación 10 KiB | p50 0,015 ms; p95 0,015 ms |
| Transformación 100 KiB | p50 0,126 ms; p95 0,130 ms |
| Transformación 1 MiB | p50 1,804 ms; p95 1,931 ms |
| Memoria máxima del benchmark | 22.564 KiB |
| Soak acelerado | 28.800 eventos; 1 escritura; 0 errores |
| Pico de asignaciones en soak | 464.690 bytes |
| Validador oficial | correcto |

El soak representa ocho horas a un evento por segundo y fuerza 28.800 escrituras atómicas de estado. Finalizó en 5,828 s de pared; produjo una limpieza inicial, 27.798 resultados sin cambio y un self-event no contabilizado.

## Integración Wayland real

| Caso | Evidencia observada |
|---|---|
| Chromium rich text | `text/plain` + `text/html`; termina como plain elegible |
| URL con UTM | Se retiró tracking y se conservaron host, ruta y parámetro funcional |
| Foot | Texto elegible; pegado dirigido con `Shift+Insert` verificado por proceso receptor |
| Nautilus | URI, operación de archivos y MIME portal preservados |
| LibreOffice Writer | MIME estructurales provocan bypass conservador |
| PNG | MIME y SHA-256 de control sin cambios; el watcher textual no intervino |
| Secreto marcado | Bypass antes de listar o leer; ausente del historial nativo |
| 21 copias rápidas | Ganó la última y ninguna anterior la sobrescribió |
| `skipNext` | Omitió una copia elegible y `cleanNow` pudo limpiarla después |
| Pausa/reanudación | Persistió en `shell.json`; pausado conservó UTM y reanudado lo limpió |
| 1 MiB | Procesado como `unchanged`; 1 MiB + 1 byte hizo bypass `too_large` |
| Clipboard vacío | Bypass `empty`, sin error ni escritura |

Los MIME completos están en [COMPATIBILITY.md](../COMPATIBILITY.md).

## Ciclo de vida

- `omarchy plugin disable` detuvo daemon y watcher; `enable` inició exactamente uno de cada.
- Dos hot reloads consecutivos conservaron un daemon y un watcher.
- `omarchy restart shell` recuperó IPC y watcher.
- `SIGTERM` al watcher provocó restart interno con backoff.
- `SIGKILL` al daemon terminó también el watcher por `PDEATHSIG`; Quickshell inició un único reemplazo.
- La regresión que dejaba watchers huérfanos durante hot reload fue detectada durante QA, corregida y cubierta por test unitario.

## Privacidad y seguridad

- Runtime: directorio `0700`; configuración, estado y socket `0600`.
- `ss -tunap` no mostró sockets TCP o UDP del helper. Solo existe el socket Unix privado de IPC.
- La suite y el transformador funcionan dentro de `bwrap --unshare-net`.
- Un canary sensible no apareció en estado, logs de Quickshell ni archivos del plugin.
- Una búsqueda estática confirmó que no existen clientes HTTP, DNS, `shell=True`, `os.system`, `sh -c` ni interpolación de contenido.
- El address enviado a Hyprland se valida como hexadecimal y teclas/modificadores son literales internos.
- Estado, IPC, panel y notificaciones contienen solo contadores, motivos y tamaños.

## Interfaz

- Panel inspeccionado visualmente a 2560×1440 con tema oscuro.
- Encabezado y acciones primarias permanecen fijos; los ajustes tienen scroll independiente.
- Escape cierra la capa y Tab produce foco visible.
- Controles interactivos de al menos 44 px, campo de 16 px, labels accesibles y errores inline.
- No hay preview, paleta propia ni animaciones del plugin; usa tokens y controles de Omarchy Shell.
- El layout limita ancho y alto al monitor, por lo que conserva scroll en paneles pequeños y escalados altos.

## Limitaciones aceptadas

- Posible duplicado original/limpio en el historial standalone.
- Secretos sin marca requieren exclusión.
- Origen best effort en Wayland.
- Firefox y password manager gráfico no estaban instalados; se usaron fixtures de protocolo. Deben repetirse como copia real antes de promover a `1.0.0`.
- Una sesión de ocho horas de pared queda sustituida en esta release local por un soak determinista equivalente en volumen; el uso real prolongado sigue siendo criterio previo a `1.0.0`.

## Fallo escapado en la `0.1.0` — controles invisibles

`components/SettingRow.qml` usaba `Style.space()` sin importar `qs.Commons`.
`Style` no existía, su `implicitHeight` colapsaba a cero y **ninguno de los
nueve controles del panel se renderizaba**. El fallo estaba desde el primer
commit y sobrevivió a la revisión de interfaz, a la suite, al soak y a la
release.

La suite no podía verlo. `test_controls_scale_the_minimum_hit_height` lee el
texto del QML y comprueba que nadie escriba un `44` a pelo; `Style.space(44)`
lo cumple perfectamente. Lo que faltaba no era la expresión, era el import.

Dos cambios a raíz de esto:

- `test_every_qml_using_a_commons_singleton_imports_it` comprueba la pareja
  uso/import en todos los `.qml`, y nombra el fichero y el singleton al fallar.
- Toda pantalla nueva se verifica en el panel real con `omarchy restart shell`,
  no sólo con tests de contrato. Un test que lee cadenas no ve un import que
  falta; sólo se ve abriendo el panel.

