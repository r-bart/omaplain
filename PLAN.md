# OmaPaste — Plan de ejecución

Plan operativo para convertir la [especificación de producto y técnica](./SPEC.md) en un plugin instalable, seguro y publicable para Omarchy.

| Campo | Valor |
|---|---|
| Estado | Listo para ejecutar |
| Actualizado | 31 de agosto de 2026 |
| Versión objetivo inicial | `0.1.0` |
| Entorno base | Omarchy 4.0.1, Quickshell 0.3.1, Hyprland 0.56.2, wl-clipboard 2.3.0 |
| Fase actual | Fase 0 — Spike técnico |
| Próxima tarea | `F0.1` — Preparar el banco de pruebas y registrar el baseline |

## 1. Cómo se usa este plan

- `SPEC.md` es la fuente de verdad sobre comportamiento, seguridad e interfaz.
- Este documento controla el orden de implementación, los entregables y las puertas de decisión.
- Una tarea solo se marca terminada cuando existe evidencia reproducible: test, medición, documento o artefacto funcional.
- Al cerrar cada fase se actualizan el estado, los resultados y cualquier desviación respecto al spec.
- Los hallazgos que cambien el producto se documentan como una decisión en `docs/decisions/` antes de continuar.

Estados posibles: `pendiente`, `en curso`, `bloqueada` y `terminada`.

## 2. Resultado esperado

La entrega `0.1.0` debe incluir:

- Un helper local que limpia únicamente texto elegible y falla dejando intacto el original.
- Limpieza automática, `cleanNow`, `pasteClean`, pausa y `skipNext`.
- Integración con Omarchy Shell mediante servicio, panel e IPC.
- Exclusiones exactas por clase de aplicación.
- Cero red, telemetría o persistencia propia del contenido copiado.
- Tests unitarios, de integración Wayland, seguridad, rendimiento y accesibilidad.
- Instalación y desinstalación sin privilegios, hooks ni cambios en `/usr/share/omarchy/`.
- Documentación honesta sobre secretos no marcados y posibles duplicados del historial.

No forman parte de `0.1.0`: historial propio, sincronización, widget permanente de barra, perfiles complejos, scripts de usuario o limpieza de HTML que no ofrezca texto plano.

## 3. Resumen de fases

| Fase | Estado | Entregable principal | Puerta de salida |
|---|---|---|---|
| 0. Spike técnico | **Siguiente** | Matriz de compatibilidad y decisión sobre el modo automático | No hay pérdida de datos, loops ni sobrescrituras tardías |
| 1. Motor seguro | Pendiente | Helper y librería probados sin UI | Clasificación, transformaciones e invariantes pasan tests |
| 2. Integración Omarchy | Pendiente | Servicio, IPC y acciones globales | Ciclo de vida estable y configuración canónica |
| 3. Panel y experiencia | Pendiente | Panel accesible y completo | Todos los estados y flujos funcionan con teclado |
| 4. Endurecimiento | Pendiente | Matriz real, auditoría y soak test | Criterios de seguridad, rendimiento y fiabilidad cumplidos |
| 5. Publicación `0.1.0` | Pendiente | Plugin validado y documentación final | Instalación limpia y checklist de release completo |
| 6. Integración core | Opcional | Propuesta de filter API para Omarchy | Historial con una sola versión del texto |

## 4. Fase 0 — Spike técnico

Objetivo: responder primero si un watcher standalone puede limpiar el portapapeles automáticamente sin degradar la experiencia nativa de Omarchy.

### Trabajo

- [ ] `F0.1` Crear un banco de pruebas aislado y registrar versiones, ejecutables disponibles, variables Wayland y estado del plugin nativo de portapapeles.
- [ ] `F0.2` Implementar un prototipo CLI mínimo con `wl-paste --watch`, inspección previa de MIME, reescritura de texto plano y loop guard efímero.
- [ ] `F0.3` Registrar los MIME reales producidos por Firefox, Chromium, terminal, gestor de archivos, captura de pantalla, gestor de contraseñas y LibreOffice.
- [ ] `F0.4` Medir el orden de eventos respecto a `omarchy.clipboard`, incluidos texto sin cambios, URL transformada y caracteres invisibles.
- [ ] `F0.5` Probar copias consecutivas a menos de 100 ms y confirmar compare-before-write: la copia más reciente siempre gana.
- [ ] `F0.6` Confirmar bypass sin lectura o reescritura para secretos marcados, imágenes, archivos, cortes y MIME estructurales.
- [ ] `F0.7` Validar el envío de pegado con `hyprctl dispatch sendshortcut` en ventanas normales y terminales, conservando el destino inicial.
- [ ] `F0.8` Medir latencia, consumo idle, reinicios y número de eventos/escrituras por copia.
- [ ] `F0.9` Documentar resultados en `docs/SPIKE.md` y la matriz en `docs/COMPATIBILITY.md`.
- [ ] `F0.10` Registrar la decisión en `docs/decisions/0001-automatic-mode.md`.

### Puerta de decisión

Se elegirá una de estas salidas, usando los resultados y no una preferencia previa:

| Resultado | Decisión |
|---|---|
| Automático estable, sin daño y con duplicados asumibles | Continuar con modo automático en `0.1.0` |
| Automático seguro pero degrada demasiado el historial | Publicar primero `cleanNow` y `pasteClean`; mantener automático experimental |
| Existen carreras o pérdida de semántica que no se pueden cerrar | Detener el watcher standalone y priorizar una filter API en Omarchy |

### Criterios de salida

- Cero loops en al menos 1.000 eventos sintéticos.
- Cero sobrescrituras de una copia más reciente.
- Imágenes, archivos y secretos marcados conservan owner y MIME originales.
- El resultado explica el comportamiento observable del historial nativo.
- Existe una recomendación go/no-go reproducible para el modo automático.

## 5. Fase 1 — Motor seguro

Objetivo: convertir el aprendizaje del spike en un núcleo determinista, testeable y sin dependencia de QML.

### Trabajo

- [ ] `F1.1` Crear la estructura definitiva del repositorio, el CLI `helper/omapaste` y los módulos de librería.
- [ ] `F1.2` Definir comandos internos para `watch`, `inspect`, `clean-now`, `paste-clean`, `status` y `check-dependencies`.
- [ ] `F1.3` Implementar clasificación data-driven antes de leer el payload completo.
- [ ] `F1.4` Añadir decodificación estricta, límites de 1 MiB, detección de NUL y fail-open.
- [ ] `F1.5` Implementar retirada de rich text usando `text/plain` como fuente canónica.
- [ ] `F1.6` Implementar normalización CRLF/CR a LF sin alterar el salto final.
- [ ] `F1.7` Implementar la lista conservadora de invisibles, preservando ZWJ, ZWNJ, bidi, selectores de variación y marcas de combinación.
- [ ] `F1.8` Implementar limpieza de URLs completas con protección estricta de URLs firmadas o autenticadas.
- [ ] `F1.9` Implementar normalizadores opcionales, apagados por defecto y aislados entre sí.
- [ ] `F1.10` Añadir loop guard, serialización, generaciones monotónicas, cancelación y compare-before-write.
- [ ] `F1.11` Emitir únicamente eventos JSON de metadatos; ningún contenido, URL, título o hash persistente.
- [ ] `F1.12` Cubrir classifier, transforms, configuración, concurrencia e invariantes con tests unitarios.

### Criterios de salida

- Toda entrada obtiene uno de cuatro resultados: `cleaned`, `unchanged`, `bypassed` o `error`.
- Un error en cualquier etapa conserva el portapapeles original.
- Cada evento provoca cero o una reescritura.
- El corpus Unicode obligatorio pasa byte a byte donde debe preservarse.
- Los tests no necesitan red ni un entorno virtual.

## 6. Fase 2 — Integración con Omarchy

Objetivo: convertir el helper en un servicio de Omarchy Shell estable, configurable y accionable.

### Trabajo

- [ ] `F2.1` Crear y validar `manifest.json` con ID no reservado y entry points de servicio y panel.
- [ ] `F2.2` Implementar `Service.qml` como supervisor; QML no procesa contenido del portapapeles.
- [ ] `F2.3` Materializar configuración y estado en `$XDG_RUNTIME_DIR/omapaste/` con directorio `0700` y ficheros `0600`.
- [ ] `F2.4` Leer y actualizar preferencias mediante la entrada inline de `shell.shellConfig.plugins`.
- [ ] `F2.5` Supervisar el helper con `PDEATHSIG`, backoff y detección de watcher degradado.
- [ ] `F2.6` Exponer IPC para `ping`, `status`, `cleanNow`, `pasteClean`, `skipNext`, `setAutomatic` y `reload`.
- [ ] `F2.7` Implementar pausa y `skipNext` con caducidad de 60 segundos y consumo solo por evento elegible.
- [ ] `F2.8` Implementar exclusiones exactas de origen y destino usando clases de Hyprland.
- [ ] `F2.9` Completar `pasteClean` con snapshot del destino, timeout y atajo apropiado para terminal.
- [ ] `F2.10` Verificar hot reload, enable/disable y reinicio del shell sin watchers duplicados ni hijos huérfanos.

### Criterios de salida

- Todos los IPC devuelven respuestas estructuradas y nunca contenido.
- Configuración corrupta o incompleta vuelve a defaults seguros y genera un warning sanitizado.
- La caída del watcher no impide las acciones one-shot.
- No se modifica `clipboard-history.json`, `/usr/share/omarchy/` ni la configuración activa sin autorización de prueba.

## 7. Fase 3 — Panel y experiencia

Objetivo: ofrecer control y diagnóstico sin convertir OmaPaste en una aplicación que requiera atención constante.

### Trabajo

- [ ] `F3.1` Construir el panel de una columna con encabezado de estado y una única acción primaria.
- [ ] `F3.2` Añadir pausa, limpieza automática y switches independientes de transformación.
- [ ] `F3.3` Añadir “Omitir próxima copia” y sus estados de activación/caducidad.
- [ ] `F3.4` Construir la gestión de exclusiones: aplicación actual, clase manual, validación y eliminación.
- [ ] `F3.5` Representar `listo`, `pausado`, `procesando`, `bypass`, `error` y `helper caído` sin mostrar contenido.
- [ ] `F3.6` Implementar feedback temporal para acciones manuales y rate limit para errores repetidos.
- [ ] `F3.7` Completar navegación por teclado, foco visible, semántica accesible y hit targets mínimos de 44 × 44 px.
- [ ] `F3.8` Verificar temas claro/oscuro, escalas 1×/1.5×/2×, panel pequeño y reduced motion.
- [ ] `F3.9` Usar exclusivamente tokens y componentes compatibles con Omarchy Shell; no introducir una paleta propia.

### Criterios de salida

- El panel se puede operar por completo sin ratón.
- Cada estado tiene texto y semántica; ninguno depende solo del color.
- Ninguna vista, tooltip, accesibility label o notificación contiene el texto copiado.
- Cerrar el panel devuelve el foco correctamente.

## 8. Fase 4 — Endurecimiento y validación

Objetivo: demostrar que el plugin soporta aplicaciones reales y sesiones prolongadas sin comprometer datos.

### Trabajo

- [ ] `F4.1` Completar fixtures de navegadores, terminales, ofimática, gestores de archivos y gestores de contraseñas.
- [ ] `F4.2` Ejecutar el corpus Unicode multilingüe, emoji, código, tabs y whitespace intencional.
- [ ] `F4.3` Ampliar las pruebas de URLs firmadas, encoding, parámetros repetidos y fragmentos.
- [ ] `F4.4` Verificar cero sockets y DNS durante watcher y acciones manuales.
- [ ] `F4.5` Auditar stdout, stderr, runtime state, health state, IPC, notificaciones y QML en busca de contenido.
- [ ] `F4.6` Medir p50/p95, RSS, CPU idle, límite de 250 ms y comportamiento con 1 MiB.
- [ ] `F4.7` Ejecutar pruebas de caída, reinicio, clipboard vacío, owner desaparecido y cierre del shell.
- [ ] `F4.8` Ejecutar un soak test de ocho horas sin loops, procesos huérfanos ni crecimiento no acotado.
- [ ] `F4.9` Revisar dependencias, licencias, datos vendorizados y superficie de subprocesses.
- [ ] `F4.10` Repetir la matriz de compatibilidad y registrar limitaciones restantes.

### Criterios de salida

- Se cumplen los objetivos de rendimiento del spec o se documenta y aprueba una corrección medible.
- No hay contenido del clipboard en ninguna ruta de observabilidad propia.
- La suite reproduce las carreras críticas y pasa de forma estable.
- Las limitaciones conocidas tienen workaround y microcopy pública.

## 9. Fase 5 — Publicación `0.1.0`

Objetivo: producir una entrega comunitaria instalable, reversible y comprensible.

### Trabajo

- [ ] `F5.1` Finalizar `README.md`, arquitectura, privacidad, troubleshooting y matriz de compatibilidad.
- [ ] `F5.2` Añadir `LICENSE`, `CHANGELOG.md` y atribuciones/licencias de reglas de tracking.
- [ ] `F5.3` Comprobar en ese momento que `omapaste.cleaner` no colisiona con el catálogo comunitario.
- [ ] `F5.4` Ejecutar el validador oficial de plugins y resolver todos los errores.
- [ ] `F5.5` Probar instalación, enable, disable, upgrade y desinstalación desde un estado limpio.
- [ ] `F5.6` Confirmar que el plugin no instala paquetes, no usa `sudo`, no ejecuta hooks y no modifica archivos del sistema.
- [ ] `F5.7` Preparar notas de release `0.1.0` con la limitación del historial y de secretos no marcados.
- [ ] `F5.8` Crear el tag de release únicamente después de una revisión final.

### Puerta de publicación

Publicar requiere que todos los criterios de aceptación de `SPEC.md` estén marcados y respaldados por resultados. Crear un repositorio remoto, subir código, abrir una PR al catálogo o publicar una release necesita autorización explícita; preparar todos esos artefactos localmente no.

## 10. Fase 6 — Integración core opcional

Esta fase no bloquea `0.1.0`. Se activa si el spike o el uso real demuestran que los dos watchers generan duplicados o carreras inevitables.

- [ ] `F6.1` Especificar un contrato mínimo de filter API para `omarchy.clipboard`.
- [ ] `F6.2` Prototipar el flujo con timeout, códigos de salida y fail-open.
- [ ] `F6.3` Añadir detección de capacidad en OmaPaste y desactivar automáticamente el watcher propio cuando exista la API.
- [ ] `F6.4` Probar que solo una versión llega al historial y que Omarchy conserva ownership del evento.
- [ ] `F6.5` Preparar propuesta upstream separada, sin hacer que el plugin dependa de una versión no publicada.

## 11. Estrategia de pruebas continua

Cada cambio debe pasar la capa más barata aplicable antes de entrar en una prueba real:

1. Tests unitarios puros del módulo afectado.
2. Tests de proceso con payloads y MIME sintéticos.
3. Integración dentro de una sesión Wayland.
4. Matriz con aplicaciones reales.
5. Soak y auditoría antes de release.

Casos que bloquean inmediatamente una entrega:

- Un secreto marcado llega al transformador.
- Una imagen, archivo o corte pierde MIME u ownership.
- Una copia antigua sobrescribe una más reciente.
- Existe más de una reescritura por evento o aparece un loop.
- Se registra o persiste contenido del portapapeles.
- Una URL firmada cambia.
- Emoji, escritura RTL o ZWJ/ZWNJ se alteran con defaults.

## 12. Reglas para la ejecución autónoma

Durante la implementación se puede avanzar sin pedir decisiones menores siguiendo estos defaults:

- Seguridad y preservación semántica ganan a una limpieza más agresiva.
- Ante MIME desconocido o error, bypass y fail-open.
- Python estándar para el helper; QML solo para ciclo de vida e interfaz.
- Sin nuevas dependencias runtime mientras una herramienta incluida en Omarchy resuelva el caso.
- Sin cambios en el historial nativo ni en `/usr/share/omarchy/`.
- Sin publicar, abrir PRs o modificar la configuración activa del usuario sin autorización explícita.

Se detiene la ejecución y se solicita una decisión solo si un hallazgo obliga a cambiar la promesa del producto, requiere privilegios, implica pérdida de datos o hace inviable el modo automático.

## 13. Registro de progreso

| Fecha | Hito | Resultado |
|---|---|---|
| 2026-08-31 | Plan inicial | Fases, puertas de decisión y criterios definidos; siguiente tarea `F0.1` |

## 14. Definición operativa de terminado

`0.1.0` está terminado cuando:

- Las fases 0–5 y los criterios de aceptación del spec están cerrados.
- La matriz real funciona en Firefox, Chromium, terminal, gestor de archivos, gestor de contraseñas y LibreOffice.
- Una sesión de ocho horas no produce loops ni procesos huérfanos.
- Una revisión de privacidad no encuentra contenido en logs, estado, IPC o UI.
- Instalar, activar, desactivar y desinstalar deja el sistema en un estado conocido.
- Las limitaciones del historial y de secretos no marcados están visibles en la documentación.

La etiqueta `1.0.0` queda reservada hasta que el modo automático tenga suficiente uso real y la convivencia con el historial cuente con una solución estable.
