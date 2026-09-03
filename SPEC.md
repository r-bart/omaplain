# OmaPlain

Especificación de producto y técnica para un limpiador de portapapeles nativo de Omarchy, inspirado funcionalmente en Pure Paste.

| Campo | Valor |
|---|---|
| Estado | Implementada — `0.2.x`; el documento se revisó contra el código el 2 de septiembre de 2026 |
| Versión del documento | 0.2 |
| Fecha | 31 de agosto de 2026, revisado el 2 de septiembre de 2026 |
| Nombre de producto | OmaPlain |
| ID provisional del plugin | `io.github.r-bart.omaplain` |
| Repositorio propuesto | `omarchy-omaplain` |
| Superficies | Servicio de Omarchy Shell + panel bajo demanda |
| Baseline auditada | Omarchy 4.0.1, Quickshell 0.3.1, Hyprland 0.56.2, wl-clipboard 2.3.0 |

## 1. Decisión de producto

OmaPlain convierte el portapapeles en texto limpio de forma automática o bajo demanda. Elimina formato enriquecido, puede retirar parámetros de seguimiento de URLs y limpia un conjunto conservador de caracteres invisibles no semánticos. Debe preservar sin tocar archivos, imágenes, secretos y estructuras de aplicación que no puedan reducirse a texto con seguridad.

La utilidad tendrá interfaz, pero no necesita ocupar la barra de forma permanente. El producto se divide en:

- Un servicio sin interfaz que observa y transforma el portapapeles.
- Un panel compacto para estado, acciones rápidas, preferencias y exclusiones.
- Un target IPC para atajos y automatizaciones.
- Un helper separado de Quickshell que procesa datos no confiables y mantiene el watcher de Wayland.

El nombre **OmaPlain** comunica el encaje con Omarchy sin reutilizar la marca Pure Paste. Es un producto independiente, desarrollado mediante una especificación clean-room basada en comportamiento observable y documentación pública.

## 2. Resumen ejecutivo

### Promesa

> Copia texto de cualquier sitio y pégalo limpio, sin llevarte fuentes, colores, enlaces de seguimiento ni basura invisible.

### Propuesta de valor

- Hace que el pegado limpio sea el comportamiento habitual, no un atajo distinto que haya que recordar en cada aplicación.
- Funciona localmente y sin red.
- Se integra con Wayland, Hyprland y el portapapeles ya incluido en Omarchy.
- Prefiere no modificar antes que arriesgarse a romper una imagen, un archivo, una fórmula, un corte o un secreto.
- Explica cuándo se ha saltado una limpieza sin mostrar el contenido copiado.

### Criterio de éxito

Después de la configuración inicial, el usuario no debería pensar en OmaPlain. El 99 % de las copias elegibles deben limpiarse sin error, sin latencia perceptible y sin alterar contenido semántico.

## 3. Problema

Copiar desde navegadores, documentos, correo o chats suele arrastrar HTML, tipografías, colores, tamaños y enlaces enriquecidos. El destino puede pegar ese estilo en lugar de adoptar el suyo. Además, algunos textos contienen parámetros de seguimiento, separadores extraños, guiones blandos o caracteres invisibles que estropean búsquedas, código y documentos.

Las alternativas actuales tienen fricción:

- Los atajos de “pegar sin formato” cambian entre aplicaciones.
- Algunas aplicaciones no implementan esa acción.
- Remapear un atajo no limpia URLs ni caracteres invisibles.
- Los scripts simples suelen romper archivos, imágenes, contraseñas, emoji o escritura bidireccional.
- Un segundo gestor de historial duplicaría una función que Omarchy ya resuelve.

## 4. Objetivos y no objetivos

### Objetivos

1. Quitar formato enriquecido de texto copiado y ofrecer `text/plain` UTF-8.
2. Limpiar URLs de seguimiento sin romper parámetros funcionales o URLs firmadas.
3. Retirar un conjunto estrecho y auditable de caracteres invisibles no semánticos.
4. Preservar imágenes, archivos, secretos, cortes y payloads estructurados.
5. Permitir exclusiones por aplicación de origen y, en el pegado manual, por aplicación de destino.
6. Ofrecer modo automático, limpieza inmediata y pegar limpio.
7. Mantener toda la operación local, sin telemetría y sin persistir el contenido.
8. Integrarse con el historial existente de Omarchy sin reemplazarlo.
9. Fallar de forma abierta: ante una duda o error, dejar el portapapeles original intacto.

### No objetivos para v1

- Ser un gestor o buscador de historial.
- Sincronizar el portapapeles entre equipos.
- Conservar parcialmente negrita, cursiva, tablas o enlaces enriquecidos.
- Restaurar el formato original después de reescribir el portapapeles.
- Transformar imágenes, archivos, HTML sin representación `text/plain` o la selección primaria de Wayland.
- Ejecutar JavaScript o scripts arbitrarios definidos por el usuario.
- Corregir gramática, traducir o resumir texto.
- Detectar todos los supuestos “watermarks de IA”. La interfaz no debe prometerlo.
- Modificar automáticamente la configuración de Hyprland durante la instalación.

## 5. Usuarios y trabajos principales

### Usuario general

Quiere copiar desde una web y pegar en correo, notas o chat sin que cambie la tipografía ni aparezcan colores extraños.

### Persona técnica

Quiere pegar en una terminal, editor o issue tracker sin caracteres invisibles, CRLF inesperados ni enlaces con `utm_*`.

### Usuario cuidadoso con la privacidad

Quiere compartir URLs limpias y necesita garantías claras de que el contenido nunca sale del equipo ni aparece en logs de OmaPlain.

### Usuario de ofimática

Necesita que tablas, fórmulas y operaciones de cortar sigan funcionando. Debe poder excluir LibreOffice u otra aplicación en un paso.

## 6. Principios de comportamiento

1. **La semántica gana al aspecto.** Es aceptable perder estilo cuando se pide texto limpio; no es aceptable perder contenido significativo.
2. **La duda provoca bypass.** Un MIME desconocido, texto inválido o una operación sensible no se “arregla” por intuición.
3. **El contenido sólo vive en el panel, cubierto y mientras está abierto.** Desde la [`0005`](docs/decisions/0005-previsualizacion-del-portapapeles.md) el panel enseña el antes y el después, tapados hasta que alguien pide verlos; nunca lo marcado como sensible, y nunca en estado, logs ni notificaciones.
4. **Una reescritura como máximo.** Cada cambio del portapapeles genera cero o una reescritura y nunca un bucle.
5. **Configuración mínima con salida rápida.** Los valores recomendados funcionan sin crear un perfil complejo.
6. **Complementar Omarchy.** El historial sigue perteneciendo a `omarchy.clipboard`.

## 7. Modos y acciones

### 7.1 Limpieza automática

Cuando aparece una nueva selección estándar de portapapeles:

1. Clasificar el contenido y sus MIME types.
2. Comprobar sensibilidad, tamaño, aplicación de origen y exclusiones.
3. Leer la representación `text/plain` solo si es elegible.
4. Ejecutar la tubería de transformaciones.
5. Reescribir como `text/plain;charset=utf-8` si había formato rico o cambió el texto.
6. Registrar únicamente metadatos de resultado en memoria.

La limpieza automática se activa en la configuración inicial. Para preservar una copia concreta se apaga el automático en Ajustes; la excepción de un solo uso se retiró en la [`0016`](docs/decisions/0016-la-omision-de-una-copia-no-se-gana-su-sitio.md).

### 7.2 Limpiar el portapapeles ahora

Acción principal del panel. Limpia el contenido actual, pero no pega ni cambia el foco. Si no es elegible, muestra el motivo: “Es una imagen”, “Contenido sensible”, “Supera 1 MB” o “No hay texto compatible”.

### 7.3 Pegar limpio

Acción pensada para un atajo global y no para el panel:

1. Capturar la ventana activa como destino.
2. Aplicar las exclusiones de destino: en una ventana excluida no se limpia, pero sí se pega lo que haya ([`0009`](docs/decisions/0009-privacidad-por-aplicacion.md)).
3. Limpiar el portapapeles actual si es elegible.
4. Esperar hasta confirmar que el nuevo owner ofrece el hash esperado, con límite de 250 ms.
5. Enviar `Ctrl+V` a una ventana normal o `Shift+Insert` a una ventana etiquetada como terminal. Los terminales que Omarchy configura pegan el portapapeles con `Shift+Insert`; con los valores de fábrica de foot, alacritty, kitty o ghostty pegaría la selección primaria.
6. Si la limpieza falla o hay bypass, pegar el contenido original sin leerlo cuando sea sensible.

El envío se realiza con `hyprctl eval` y el dispatcher Lua `hl.dsp.send_shortcut` ([`0002`](docs/decisions/0002-hyprland-input.md)); en la expresión sólo entran literales y una dirección hexadecimal validada, nunca contenido. El target de ventana se conserva antes de iniciar la operación para no pegar en otra ventana si cambia el foco.

Atajo sugerido, solo como documentación y después de comprobar conflictos locales:

```lua
o.bind("SUPER + ALT + V", "Paste clean", "omarchy-shell omaplain pasteClean")
```

OmaPlain no se adueñará de `Super+V`, que Omarchy ya usa como pegado universal, ni de `Super+Ctrl+V`, reservado al gestor de portapapeles.

### 7.4 Pausa

El interruptor superior permite pausar y reanudar la limpieza automática. La limpieza manual y `pasteClean` siguen disponibles durante la pausa. v1 no necesita temporizadores de cinco o treinta minutos; se pueden añadir cuando exista evidencia de uso.

## 8. Clasificación del portapapeles

La clasificación se hace antes de leer el payload completo.

| Condición | Resultado | Motivo |
|---|---|---|
| `CLIPBOARD_STATE=sensitive` | Bypass | No leer, guardar ni reescribir secretos |
| MIME `x-kde-passwordManagerHint` | Bypass | Convención usada por gestores de contraseñas |
| Cualquier `image/*` | Bypass | Preservar imágenes y sus metadatos |
| `text/uri-list` o MIME de copia/corte de archivos | Bypass | No convertir archivos en rutas de texto |
| Corte, fórmula, tabla o payload estructural conocido | Bypass | Preservar semántica de la aplicación |
| `text/plain` + `text/html`, RTF o rich text | Elegible | Usar el texto plano y retirar los demás sabores |
| Solo `text/plain` compatible | Elegible | Aplicar normalizadores habilitados |
| Solo HTML, sin representación de texto plano | Bypass en v1 | No inferir texto mediante un parser HTML |
| MIME desconocido junto a texto | Decisión por denylist conservadora | Los formatos estructurales conocidos ganan |
| Más de 1 MiB de texto | Bypass | Evitar bloquear el shell o copiar documentos enormes |
| UTF-8/UTF-16 no decodificable sin pérdidas | Bypass | No sustituir bytes inválidos por `�` |

La lista de MIME estructurales será data-driven y tendrá pruebas por aplicación. Debe incluir como mínimo:

- `x-special/gnome-copied-files`
- `application/x-kde-cutselection`
- formatos conocidos de fórmulas, celdas y tablas de LibreOffice/OnlyOffice
- formatos de dibujo o nodos que también anuncien una representación textual

La selección primaria (`wl-paste --primary`) queda siempre fuera de alcance.

## 9. Aplicaciones y exclusiones

### Origen en modo automático

OmaPlain toma un snapshot de `hyprctl activewindow -j` cuando recibe el evento y usa `class` como identificador estable. `initialClass` sirve como fallback. El título de ventana no se guarda ni se usa para reglas.

Wayland no garantiza que la ventana enfocada sea quien originó una copia programática. Por eso:

- La atribución se marca internamente como `known` o `best_effort`.
- Una exclusión solo se aplica cuando la clase coincide.
- La seguridad no depende de identificar el origen; depende de MIME y sensibilidad.
- La interfaz dice “Aplicación detectada” y no “Aplicación garantizada”.

### Destino en `pasteClean`

El destino sí es la ventana activa capturada al ejecutar el atajo. Las exclusiones de destino se aplican antes de leer o reescribir el contenido.

### Edición de reglas por aplicación

Una sola sección ([`0011`](docs/decisions/0011-una-sola-seccion-de-aplicaciones.md)) con las cuatro listas de la [`0009`](docs/decisions/0009-privacidad-por-aplicacion.md):

- Un selector con las clases de las ventanas abiertas ahora mismo: la clase que da Hyprland es la que compara el demonio. No se ofrece un catálogo de aplicaciones instaladas porque tres de cada cuatro no declaran su clase.
- Campo para teclear una clase a mano.
- Cada aplicación es una tarjeta con la clase exacta, cuatro interruptores independientes y un botón «Quitar».
- Comparación exacta por defecto; glob o regex quedan fuera de v1.
- Validación al perder foco o al pulsar Añadir, no en cada tecla.
- Una clase vacía, con saltos de línea o de más de 256 bytes se rechaza con mensaje inline.

No se precargará una lista enorme de exclusiones. La denylist de MIME debe resolver los casos peligrosos; las exclusiones son una salida para incompatibilidades concretas.

## 10. Tubería de transformación

El orden es fijo para que el resultado sea reproducible:

```text
clasificar MIME
  → decodificar sin pérdidas
  → normalizar fin de línea
  → retirar invisibles no semánticos
  → limpiar URL si todo el contenido es una URL
  → normalizadores opcionales de escritura
  → validar invariantes
  → reescribir como text/plain
```

### 10.1 Retirar formato

- Activado por defecto.
- Si existe `text/plain`, esa es la fuente canónica.
- La presencia de HTML/RTF hace necesaria la reescritura aunque el texto no cambie.
- La salida ofrece un único MIME `text/plain;charset=utf-8`.
- v1 no ofrece “conservar enlaces”, porque `wl-copy` 2.3.0 no puede publicar varios MIME types a la vez y mantener rich text introduce resultados inconsistentes entre aplicaciones.

### 10.2 Fin de línea

- Activado por defecto.
- Convierte CRLF y CR aislado en LF.
- No añade ni quita un salto final.
- No une líneas de PDF ni colapsa párrafos.

### 10.3 Caracteres invisibles

- Activado por defecto con un conjunto conservador.
- Puede retirar `U+00AD SOFT HYPHEN`, `U+200B ZERO WIDTH SPACE`, `U+2060 WORD JOINER` y `U+FEFF` cuando no es el BOM inicial.
- Conserva siempre `U+200C ZERO WIDTH NON-JOINER`, `U+200D ZERO WIDTH JOINER`, selectores de variación, marcas de combinación y controles necesarios para emoji o idiomas.
- Los controles bidireccionales no se retiran por defecto. Una futura opción de seguridad deberá advertir que puede romper árabe, hebreo o persa.
- La interfaz usa “Retirar invisibles no semánticos”, no “Eliminar watermarks de IA”.

### 10.4 URLs sin seguimiento

- Activado por defecto.
- Solo actúa en v1 cuando el contenido completo, después de ignorar whitespace exterior para el parseo, es una URL absoluta `http` o `https`.
- Conserva el whitespace exterior original.
- Retira claves conocidas, sin distinguir mayúsculas: `utm_*`, `fbclid`, `gclid`, `dclid`, `gbraid`, `wbraid`, `mc_cid`, `mc_eid`, `mkt_tok` y otras reglas auditadas.
- Preserva esquema, host, puerto, ruta, fragmento, orden relativo y valores de los parámetros restantes.
- No modifica URLs con parámetros de firma o autorización conocidos, por ejemplo `X-Amz-*`, `Signature`, `Expires`, `token`, `auth`, `key` o equivalentes configurados.
- Si el parseo y la serialización cambian host o ruta, se aborta la transformación.
- Reglas especiales para redes sociales se añaden solo con fixtures de antes/después y prueba de que el enlace sigue siendo funcional.
- No se descarga ninguna lista ni se hace una petición a la URL.

La lista de reglas se versiona dentro del repositorio con fuente, licencia, fecha de actualización y tests. No se actualizará silenciosamente en runtime.

### 10.5 Normalizadores opcionales

Apagados por defecto porque pueden cambiar texto intencionado:

- Comillas tipográficas a comillas rectas.
- Viñetas al inicio de línea a `- `.
- Normalización Unicode NFC.
- Retirada de espacios al final de línea.

No habrá un interruptor genérico “Arreglar espacios”. Cada cambio semántico debe ser explícito y testeable.

### 10.6 Invariantes finales

Antes de reescribir:

- La salida debe ser UTF-8 válido.
- Una entrada no vacía no puede quedar vacía salvo que una acción manual futura lo permita explícitamente.
- El tamaño no puede crecer más de un 10 % —con cuatro bytes de margen para textos cortos— sobre el original ya en UTF-8, ni superar 1 MiB. Se mide sobre el original recodificado para que un texto en Latin-1 no cuente su paso a UTF-8 como crecimiento.
- Si los bytes cambian sin que ninguna regla haya actuado —un BOM consumido, un texto que no venía en UTF-8— la reescritura se nombra `encoding`.
- Debe conservar NUL = 0; cualquier NUL produce bypass.
- Debe completar antes del timeout.
- Si la salida es idéntica y no había rich text, no se reescribe.

## 11. Compatibilidad con el historial de Omarchy

### Estado actual auditado

`omarchy.clipboard` mantiene su propio historial en `~/.local/state/omarchy/clipboard-history.json`. Dos watchers de `wl-paste` capturan texto e imágenes, ignoran `CLIPBOARD_STATE=sensitive` y `x-kde-passwordManagerHint`, y deduplican entradas de texto idénticas.

Consecuencias:

- Retirar solo formato no crea normalmente un duplicado: el historial ve el mismo texto antes y después y lo deduplica.
- Limpiar una URL o invisibles sí puede dejar dos entradas distintas: original y limpia.
- El orden de ejecución entre watchers no está garantizado.

### Regla de seguridad para el plugin

OmaPlain **no modificará directamente** `clipboard-history.json`. Reescribir un archivo propiedad de otro plugin introduciría carreras y podría perder entradas.

### MVP sin cambios en Omarchy core

- El modo automático funciona y muestra una advertencia no bloqueante si hay transformaciones que cambian caracteres.
- El panel explica: “El historial puede conservar también la versión original cuando cambia el texto”.
- El usuario puede dejar activa solo la retirada de formato para una integración sin duplicados semánticos.
- `pasteClean` sigue siendo la opción más predecible cuando se quiere conservar el original en historial.

### Integración completa propuesta

Para una v1 sin duplicados debe proponerse a Omarchy un punto de extensión estrecho en `omarchy.clipboard`:

```text
evento Wayland
  → clasificador sensible/archivo/imagen de Omarchy
  → filtro de texto OmaPlain
  → una sola escritura de historial
  → una sola reescritura del clipboard, si procede
```

Contrato orientativo del filtro:

| Elemento | Contrato |
|---|---|
| Entrada | Texto por `stdin`; metadata MIME/origen por JSON o variables sin contenido |
| `exit 0` | `stdout` contiene texto transformado |
| `exit 10` | Sin cambios |
| `exit 20` | Bypass deliberado |
| Otro código | Error; conservar original |
| Tiempo máximo | 250 ms |
| Red | Prohibida |

Cuando el filtro core esté disponible, OmaPlain detectará su versión y desactivará su watcher automático propio. El servicio seguirá proporcionando panel, configuración, IPC y transformador. El core será el único dueño del evento y del historial.

## 12. Interfaz

### Decisión de superficie

Se necesita interfaz para entender el estado, configurar exclusiones y resolver incompatibilidades. Desde la `0.2.0` hay además un widget de barra y una entrada `.desktop`, y ninguno de los dos se activa solo ([`0010`](docs/decisions/0010-como-se-abre-el-panel.md)).

El panel se abre con:

```bash
omarchy-shell shell toggle io.github.r-bart.omaplain
```

Puede añadirse manualmente al menú de Omarchy o a un atajo. El servicio se carga al habilitar el plugin aunque el panel nunca se abra.

### Estructura del panel

Ancho objetivo de 520 px y alto máximo de 720 px o el espacio disponible. Una única columna con scroll interno cuando sea necesario. El panel hereda colores, tipografía, radios, espaciado, borders y focus ring de `qs.Commons` y `qs.Ui`; no define una paleta propia.

Dos páginas tras la misma cabecera: el portapapeles y los ajustes, detrás
del engranaje ([`0007`](docs/decisions/0007-la-pantalla-frecuente-informa.md)).

```text
┌──────────────────────────────────────────────────────┐
│ OmaPlain                                 [⚙ Opciones]│
│ ──────────────────────────────────────────────────── │
│ Esto se puede limpiar                                │
│ Así está y así quedaría.                             │
│ ┌──────────────────────────────────────────────────┐ │
│ │ AHORA                                        [◎] │ │
│ │ ▓▓▓▓▓▓▓ vaho: arrastra para limpiar ▓▓▓▓▓▓▓▓▓▓▓▓ │ │
│ └──────────────────────────────────────────────────┘ │
│ ┌──────────────────────────────────────────────────┐ │
│ │ QUEDARÍA                                     [◎] │ │
│ │ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ │ │
│ └──────────────────────────────────────────────────┘ │
│ ✕ Parámetros de seguimiento          (Seguimiento)   │
│ [        Aplicar al portapapeles                   ] │
│ ▸ Dejar en paz la próxima copia                      │
│ El original queda intacto si limpiar no es seguro.   │
└──────────────────────────────────────────────────────┘
```

Y detrás del engranaje: Idioma, Movimiento, Modo, Limpieza —con cuatro
opcionales bajo divulgación—, Aplicaciones ([`0011`](docs/decisions/0011-una-sola-seccion-de-aplicaciones.md))
y Ayuda y aprendizaje.

### Jerarquía

- El veredicto encabeza la vista: nombra lo que tienes, no lo que hace el producto ([`0013`](docs/decisions/0013-el-titular-nombra-lo-que-tienes.md)).
- La insignia de estado sólo aparece cuando hay algo que contar: pausado, omitiendo, arrancando o pidiendo atención. Un servicio que va bien se calla.
- «Aplicar al portapapeles» es la única acción primaria, y **sólo existe cuando hay algo que aplicar** ([`0015`](docs/decisions/0015-la-pantalla-frecuente-no-ofrece-un-boton-muerto.md)).
- «Dejar en paz la próxima copia» es una línea secundaria sin borde, y sólo con el automático puesto.
- Las preferencias son filas completas clicables, agrupadas en Idioma, Movimiento, Modo, Limpieza, Aplicaciones y Ayuda.
- No hay botón Guardar: cada cambio se persiste de inmediato y revierte visualmente si falla.
- Las opciones avanzadas apagadas no compiten con las recomendadas: van bajo divulgación.

### Estados del encabezado

| Estado | Título | Detalle | Tratamiento |
|---|---|---|---|
| Activo | — | Sin insignia y sin frase: un servicio que va bien no tiene nada que contar | Ausente |
| Recién limpiado | — | `Listo · última limpieza completada` | Neutro/confirmación |
| Pausado | `Limpieza pausada` | Las acciones manuales siguen disponibles | Atenuado |
| Procesando | `Limpiando…` | Tipo y tamaño, nunca contenido | Indicador si supera 400 ms; en principio no debería |
| Bypass | `No se ha modificado` | Motivo específico | Neutro |
| Error recuperable | `El texto original sigue intacto` | Acción concreta para reintentar | Warning + icono + texto |
| Helper caído | `OmaPlain no está observando` | `Reiniciar servicio` | Error + acción secundaria |

### Feedback

- Una limpieza manual correcta pone un sello de check sobre la fila del portapapeles durante 1,5 segundos, y el mensaje “Portapapeles limpio” bajo las acciones. El sello va en la fila y no en el botón porque el botón, al no quedar nada que aplicar, desaparece ([`0015`](docs/decisions/0015-la-pantalla-frecuente-no-ofrece-un-boton-muerto.md)).
- La limpieza automática no genera toast por defecto; sería ruido.
- Bypass esperado no es un error y no lanza notificación.
- Un error repetido del watcher sí crea una notificación accionable, limitada a una cada diez minutos.
- La previsualización llega cubierta y se olvida al cerrar el panel; lo sensible no se muestra nunca ([`0005`](docs/decisions/0005-previsualizacion-del-portapapeles.md)).
- El panel abierto vuelve a mirar el portapapeles en cada evento y tras cada acción manual. Una copia sin texto —una captura de pantalla— llega por el segundo vigilante, el que no pide tipo: `wl-paste --type text --watch` no ejecuta nada con una oferta sin texto, y sin ese segundo vigilante el panel se quedaba en la copia anterior.

### Iconografía

- Usar una sola familia ya presente en Omarchy Shell.
- Metáfora preferida: portapapeles con pequeño destello o escoba, acompañada siempre de texto en acciones ambiguas.
- Tamaño mínimo de 16 px con variante ópticamente ajustada; no escalar un glyph pequeño a un estado vacío grande.
- Estado no depende solo del color: icono, texto y tono cambian juntos.

### Teclado y accesibilidad

- `Esc` cierra el panel.
- `Tab` y `Shift+Tab` recorren controles en el mismo orden visual.
- `Space` cambia switches; `Enter` activa botones o añade una exclusión.
- Todos los controles usan primitives de Qt Quick Controls o componentes accesibles de Omarchy, no `MouseArea` sin semántica como botón.
- Cada switch tiene `Accessible.name`, descripción y estado.
- La fila completa de un switch tiene un hit target mínimo de 44 × 44 px y no contiene zonas muertas.
- Focus visible de 2 px con offset, usando el token de foco del tema.
- Los errores de campos combinan borde, icono y texto; nunca solo color.
- Al abrir el panel se enfoca el encabezado o la primera acción, no el campo avanzado.
- El panel mantiene focus exclusivo mientras está abierto y lo devuelve al invocador al cerrar.
- El orden del árbol accesible coincide con el orden visual.

### Microcopy canónica

| Situación | Texto |
|---|---|
| Acción primaria | `Limpiar portapapeles ahora` |
| Éxito | `Portapapeles limpio` |
| Imagen | `No se ha modificado: es una imagen` |
| Archivo | `No se ha modificado: contiene archivos` |
| Secreto | `Contenido sensible protegido` |
| Grande | `No se ha modificado: supera 1 MB` |
| Sin cambios | `Ya estaba limpio` |
| Fallo | `No se pudo limpiar. El texto original sigue intacto.` |
| Exclusión duplicada | `Esta aplicación ya está excluida` |
| Clase inválida | `Introduce una clase de aplicación válida` |
| Privacidad | `Todo ocurre en este equipo. OmaPlain no guarda el texto copiado.` |

## 13. Arquitectura técnica

### Componentes

```text
Hyprland / Wayland clipboard
          │
          ▼
  wl-paste --watch
          │
          ▼
┌──────────────────────────────┐
│ helper/omaplain (Python)     │
│ clasificación + transforms  │
│ loop guard + wl-copy         │
└──────────────┬───────────────┘
               │ estado sin contenido
               ▼
┌──────────────────────────────┐       ┌───────────────────────────┐
│ Service.qml                  │◀─────▶│ Panel.qml                 │
│ supervisor + IPC `omaplain`  │       │ preferencias + acciones   │
└──────────────┬───────────────┘       └───────────────────────────┘
               │
               ▼
  shell.json / XDG runtime state

En paralelo: omarchy.clipboard conserva su historial actual.
```

### Por qué hay un helper

Los plugins se ejecutan como código sin sandbox dentro del proceso permanente `omarchy-shell`. El parseo de texto arbitrario, control de tamaños, subprocesses y timeouts deben vivir en un proceso separado. `Service.qml` solo supervisa y expone estado; no procesa el contenido en JavaScript/QML.

### Árbol del repositorio

```text
omaplain/
├── manifest.json
├── io.github.r-bart.omaplain.desktop
├── io.github.r-bart.omaplain.svg   el icono del lanzador
├── Service.qml            supervisa el helper y expone estado
├── Panel.qml              las dos páginas: portapapeles y ajustes
├── BarWidget.qml          el icono de la barra: la marca
├── components/            filas, botones, cubierta, tour, marca, catálogo Strings.js
├── launcher/
│   └── omaplain-launcher-icon   hook de `theme-set`: repinta el icono
├── helper/
│   ├── omaplain           ejecutable
│   └── omaplain_lib/
│       ├── cli.py         subcomandos
│       ├── daemon.py      socket, generaciones, loop guard, peek
│       ├── clipboard.py   wl-paste, wl-copy, hyprctl
│       ├── classify.py    MIME → elegible o bypass
│       ├── transform.py   reglas puras
│       ├── config.py      validación y escritura 0600
│       └── status.py      status.json
├── data/
│   ├── tracking-parameters.json
│   └── structural-mime-types.json
├── tests/
│   ├── run.sh             la suite entera
│   ├── unit/
│   ├── fixtures/
│   ├── benchmark.py
│   └── soak.py
├── docs/decisions/        las decisiones, argumentadas
├── docs/notes/            planes cumplidos e informes
├── README.md, CHANGELOG.md, SECURITY.md, ATTRIBUTIONS.md, LICENSE
```

No hay instalador ni hook de instalación. Git conserva el bit ejecutable de `helper/omaplain`, y el plugin funciona desde su propio directorio.

### Manifest

```json
{
  "schemaVersion": 1,
  "id": "io.github.r-bart.omaplain",
  "name": "OmaPlain",
  "version": "0.2.0",
  "author": "OmaPlain contributors",
  "license": "GPL-3.0-or-later",
  "description": "Paste clean text by default while preserving files, images and secrets.",
  "kinds": ["service", "panel", "bar-widget"],
  "entryPoints": {
    "service": "Service.qml",
    "panel": "Panel.qml",
    "barWidget": "BarWidget.qml"
  },
  "barWidget": { "displayName": "OmaPlain", "category": "Utilities", "allowMultiple": false }
}
```

La versión del manifiesto es la única: `helper/omaplain_lib/__init__.py` y el `CHANGELOG` la repiten y un test las ata.

`io.github.r-bart.omaplain` evita el namespace reservado `omarchy.*`. Antes de publicar se debe comprobar que el ID no esté ocupado en el catálogo comunitario.

### Responsabilidades de `Service.qml`

- Recibir `shell`, `manifest` y exponer estado reactivo al panel.
- Leer nuestra entrada en el mismo orden en que el shell la escribe: primero `bar.layout`, si el icono está colocado, y si no `plugins[]`; y al escribir en la barra, dejar la misma copia en `plugins[]` ([`0012`](docs/decisions/0012-el-anillo-de-foco-y-donde-viven-los-ajustes.md)).
- Escribir preferencias con `shell.updateEntryInline("io.github.r-bart.omaplain", settings)`.
- Materializar una configuración de runtime con permisos `0600` para el helper.
- Lanzar el watcher con `setpriv --pdeathsig TERM`.
- Reiniciarlo con backoff si termina inesperadamente.
- Exponer `IpcHandler { target: "omaplain" }`.
- Leer eventos de estado estructurados, nunca stdout con contenido.

### Responsabilidades del helper

- Ejecutar y supervisar dos `wl-paste --watch`: uno de texto, que es el único que reescribe, y uno general que sólo avisa cuando la oferta no trae texto.
- Consultar MIME types y metadata antes de transformar.
- Serializar eventos con un lock para que dos copias rápidas no se crucen.
- Aplicar límites, clasificación, transformaciones e invariantes.
- Reescribir con `wl-copy --type text/plain;charset=utf-8`.
- Protegerse de su propio evento de reescritura.
- Implementar acciones manuales y `pasteClean`.
- Emitir JSON de estado sin texto, URL, título de ventana ni argumentos sensibles.

### Configuración canónica

Las preferencias viven inline en `~/.config/omarchy/shell.json`, según el contrato de Omarchy:

```json
{
  "id": "io.github.r-bart.omaplain",
  "automatic": true,
  "stripFormatting": true,
  "removeTracking": true,
  "removeInvisible": true,
  "normalizeLineEndings": true,
  "normalizeQuotes": false,
  "normalizeLists": false,
  "normalizeUnicodeNfc": false,
  "trimTrailingWhitespace": false,
  "sourceExclusions": [],
  "targetExclusions": [],
  "alwaysCovered": [],
  "blockedApps": [],
  "maxBytes": 1048576,
  "language": "auto",
  "reduceMotion": false,
  "onboardingVersion": 0
}
```

`language`, `reduceMotion` y `onboardingVersion` son sólo de interfaz: el helper los ignora al validar. Las cuatro listas son las de la [`0009`](docs/decisions/0009-privacidad-por-aplicacion.md).

Reglas:

- Valores desconocidos se ignoran para permitir downgrade.
- Valores ausentes toman los defaults del manifest o del servicio.
- Un tipo inválido revierte al default y produce un warning sin contenido.
- El helper nunca edita `shell.json`.
- `Service.qml` crea una snapshot derivada en `$XDG_RUNTIME_DIR/omaplain/config.json`; no es una segunda fuente de verdad.

### Estado

| Ruta | Contenido | Persistencia |
|---|---|---|
| `$XDG_RUNTIME_DIR/omaplain/config.json` | Snapshot de preferencias | Sesión, `0600` |
| `$XDG_RUNTIME_DIR/omaplain/status.json` | Estado, contadores, último resultado y marca del último evento | Sesión, `0600` |
| `$XDG_RUNTIME_DIR/omaplain/omaplain.sock` | Eventos, órdenes y `peek` | Sesión, `0600` |
| Memoria del helper | Hash de loop guard, origen de la última copia y transacción activa | No persiste |

No hay ningún fichero persistente entre sesiones.

No se crea una base de datos. El historial pertenece a Omarchy.

### IPC

| Llamada | Respuesta | Efecto |
|---|---|---|
| `omarchy-shell omaplain ping` | `ok` | Salud del servicio QML |
| `omarchy-shell omaplain status` | JSON | Estado sin contenido |
| `omarchy-shell omaplain cleanNow` | `accepted` o `busy` | Limpia el portapapeles actual |
| `omarchy-shell omaplain pasteClean` | `accepted` o `busy` | Limpia y pega en el target capturado |
| `omarchy-shell omaplain setAutomatic true` | `ok` | Activa modo automático |
| `omarchy-shell omaplain setAutomatic false` | `ok` | Pausa modo automático |
| `omarchy-shell omaplain reload` | `ok` | Recarga configuración derivada |

Las acciones son asíncronas: la llamada devuelve `accepted` y el resultado, sin contenido, aparece en `status`. Solo las cadenas literales `true` y `false` son válidas para `setAutomatic`. Los demás argumentos devuelven `invalid` sin cambiar estado.

Ejemplo de `status`:

```json
{
  "version": 1,
  "watcher": "running",
  "automatic": true,
  "lastResult": "cleaned",
  "lastReason": "rich_text",
  "lastAt": "2026-08-31T16:42:10Z",
  "lastBytes": 248,
  "session": {
    "cleaned": 18,
    "unchanged": 42,
    "bypassed": 7,
    "errors": 0
  }
}
```

### Máquina de estados

```text
STOPPED ──enable──▶ IDLE
IDLE ──clipboard event──▶ INSPECTING
INSPECTING ──unsafe/excluded──▶ BYPASSED ──▶ IDLE
INSPECTING ──eligible──▶ TRANSFORMING
TRANSFORMING ──same/plain──▶ UNCHANGED ──▶ IDLE
TRANSFORMING ──new/rich──▶ WRITING ──self event──▶ IDLE
TRANSFORMING/WRITING ──failure──▶ ERROR ──fail open──▶ IDLE
IDLE ──pause──▶ PAUSED ──resume──▶ IDLE
```

El evento generado por `WRITING` se reconoce mediante hash efímero, longitud y ventana temporal. Se consume una vez y no incrementa contadores de copia.

### Concurrencia

- Un lock por seat serializa las transformaciones.
- Cada evento recibe un número monotónico.
- Si llega un evento más nuevo antes de escribir, el anterior se cancela.
- El resultado solo se escribe si el clipboard actual aún coincide con el hash de entrada.
- El hash usa SHA-256 solo en memoria y se descarta en menos de cinco segundos.
- En multiseat, v1 atiende el seat por defecto; soporte explícito queda documentado como limitación.

### Dependencias

Dependencias runtime esperadas en Omarchy:

- `wl-clipboard >= 2.3` para `--watch`, `--sensitive` y `CLIPBOARD_STATE`. Se ejecutan dos vigilantes: `--type text`, que limpia, y uno sin tipo, que sólo avisa de las copias sin texto.
- `hyprctl` para metadata de ventana y para enviar el atajo de pegado con `eval`.
- Python 3 con biblioteca estándar.
- `setpriv` para `PDEATHSIG`.
- Quickshell y los módulos ya incluidos por Omarchy.

No se incorporan dependencias Python de red ni un entorno virtual. La instalación valida dependencias al arrancar y muestra una lista exacta si falta alguna; no ejecuta `sudo` ni instala paquetes.

## 14. Privacidad y seguridad

### Garantías

- Cero red en runtime.
- Cero telemetría.
- Cero contenido en logs, estado y notificaciones. En el panel, sólo cubierto, sólo mientras está abierto y nunca lo sensible ([`0005`](docs/decisions/0005-previsualizacion-del-portapapeles.md)).
- Cero persistencia propia del texto.
- Bypass de secretos sin que el demonio los lea, siempre que la plataforma los marque. `wl-paste` sí entuba el contenido al proceso efímero que avisa; ese proceso no lo lee.
- Bypass conservador de archivos, imágenes y estructuras.
- Sin `eval`, `sh -c`, plantillas de comandos ni interpolación de contenido.
- Todos los subprocesses reciben argv separados.
- Ficheros runtime `0600` dentro de un directorio `0700`.
- Límites de tiempo, bytes y crecimiento.

### Aclaración sobre el historial

OmaPlain no guarda contenido, pero el gestor de portapapeles de Omarchy puede guardar texto en su historial como ya hace sin OmaPlain. El panel debe explicarlo y enlazar la configuración del historial; no debe atribuir esa persistencia a OmaPlain ni ocultarla.

### Modelo de amenazas

| Amenaza | Mitigación |
|---|---|
| Secreto copiado desde un password manager | `CLIPBOARD_STATE` y MIME sensible provocan bypass sin que el demonio lo lea ni lo pida |
| Aplicación de origen que no sirve su oferta | La lectura tiene plazo (2 s) y las órdenes cortas también (1 s); después, fail open |
| Texto malformado | Decodificación estricta; bypass sin sustitución |
| URL especialmente construida | Parser estándar, allowlist de esquemas e invariantes host/ruta |
| Payload enorme | Límite previo de 1 MiB y timeout |
| Bucle de autoreescritura | Hash efímero + contador de evento + máximo una escritura |
| Dos copias en rápida sucesión | Lock, cancelación por generación y compare-before-write |
| Inyección de shell | Ningún contenido entra en comandos o logs |
| Plugin QML comprometido | Helper mínimo; revisión obligatoria porque plugins de Omarchy no tienen sandbox |
| Regla de tracking demasiado agresiva | URLs firmadas excluidas, fixtures y rollback de la regla |
| Daño a emoji o idiomas RTL | Preservar ZWJ/ZWNJ/variaciones/bidi y tener corpus multilingüe |

### Limitación honesta

Una aplicación que copie una contraseña sin ninguna marca de sensibilidad es indistinguible de texto normal para Wayland. OmaPlain puede excluir la clase de la aplicación, pero no puede prometer detección perfecta. Esta limitación debe figurar en README y ayuda.

## 15. Rendimiento y fiabilidad

### Objetivos

| Métrica | Objetivo |
|---|---|
| CPU en idle | 0 % medible; watcher bloqueado por evento |
| Memoria helper | Menos de 30 MiB RSS |
| Transformación p50, 10 KiB | Menos de 15 ms |
| Transformación p95, 100 KiB | Menos de 50 ms |
| Límite completo | Órdenes cortas 1 s, lectura del contenido 2 s; después, fail open |
| Escrituras por evento | 0 o 1 |
| Reinicio del watcher | 1 s, 2 s, 5 s, 10 s; máximo 30 s |
| Notificaciones de error | Máximo una por causa cada 10 min |

### Recuperación

- Si `wl-paste --watch` termina, `Service.qml` lo reinicia.
- Tres caídas en un minuto cambian el estado a degradado y notifican una vez.
- `pasteClean` y `cleanNow` pueden ejecutar una operación one-shot aunque el watcher automático esté caído.
- Si `wl-copy` falla, el original conserva el ownership; no se intenta limpiar el clipboard.
- Al destruir el servicio, `PDEATHSIG=TERM` elimina watchers hijos.

## 16. Pruebas

### Unitarias

- Clasificación de todos los MIME conocidos.
- Decodificación UTF-8, BOM y UTF-16; rechazo de entradas inválidas.
- Cada carácter invisible incluido y preservado.
- URLs con tracking, fragmentos, parámetros repetidos y encoding.
- URLs firmadas que deben quedar byte-a-byte iguales.
- Invariantes de tamaño, NUL, vacío y crecimiento.
- Configuración ausente, parcial, corrupta y con tipos incorrectos.
- Loop guard y su expiración.

### Corpus Unicode obligatorio

- Emoji familiares con ZWJ: `👨‍👩‍👧‍👦`.
- Emoji con selector de variación y tono de piel.
- Persa con ZWNJ.
- Árabe y hebreo con dirección bidireccional.
- Hindi y tailandés con marcas de combinación.
- CJK, símbolos matemáticos y texto normalizado/desnormalizado.
- Código que contiene espacios, tabs y caracteres escapados intencionados.

### Integración Wayland

| Caso | Resultado esperado |
|---|---|
| Firefox copia HTML + plain | Clipboard termina en plain; mismo texto |
| Chromium copia enlace con UTM | URL limpia; host/ruta preservados |
| Terminal copia texto | Limpieza sin alterar saltos intencionados |
| 1Password/Bitwarden con hint | Cero lectura, cero estado de contenido |
| Nautilus copia un archivo | MIME y operación intactos |
| Captura de pantalla | Imagen intacta |
| LibreOffice copia una fórmula/celda | Bypass por MIME o exclusión |
| LibreOffice copia rich text normal | Limpio cuando sea elegible |
| Dos copias en menos de 100 ms | Gana la última; ninguna sobrescritura tardía |
| Shell se reinicia durante copia | Clipboard actual no se borra |
| Helper recibe SIGTERM | Sale sin dejar watcher huérfano |
| Texto de 1 MiB | Procesa dentro del límite |
| Texto de 1 MiB + 1 byte | Bypass |
| Clipboard vacío/clear | Sin error ni escritura |

### Compatibilidad de historial

- Rich text con plain idéntico produce una sola entrada lógica.
- Una URL transformada documenta y reproduce el posible par original/limpia en modo standalone.
- El plugin nunca edita `clipboard-history.json`.
- Con el futuro filter API, solo la versión limpia llega al historial.

### Interfaz

- Navegación completa solo con teclado.
- Focus visible en cada control.
- Lector de pantalla anuncia label, estado y descripción de switches.
- La fila completa activa su switch.
- Errores de exclusión aparecen junto al campo.
- No aparece contenido del portapapeles en ningún estado, captura o accessibility label.
- Tema claro, oscuro, escalas 1×/1.5×/2× y panel en pantalla pequeña.
- Estado loading, empty, bypass, error y helper caído.

## 17. Criterios de aceptación de v1

### Funcionales

- [x] Copiar rich text con representación plain deja únicamente plain text pegable.
- [x] Archivos, imágenes, secretos y MIME estructurales quedan byte-a-byte bajo el owner original.
- [x] Las transformaciones recomendadas pueden activarse o apagarse de forma independiente.
- [x] Una exclusión de origen bloquea la limpieza automática de esa clase.
- [x] Una exclusión de destino bloquea la limpieza de `pasteClean`.
- [x] `cleanNow` informa de éxito, sin cambios, bypass o error sin revelar contenido.
- [x] `pasteClean` elige `Ctrl+V` o `Shift+Insert` y conserva el target inicial.
- [x] Un error deja el portapapeles original disponible.
- [x] No hay más de una reescritura por evento ni loops.

### Privacidad

- [x] `test_no_network.py` confirma que el helper no importa nada de red y que el único socket es de dominio Unix.
- [x] Logs, estado, notificaciones y las respuestas de IPC que no son `peek` no contienen texto, URLs, hashes persistentes ni títulos de ventana.
- [x] Contenido sensible marcado no llega al proceso transformador.
- [x] El panel renderiza la previsualización cubierta, la olvida al cerrar y nunca enseña lo sensible ([`0005`](docs/decisions/0005-previsualizacion-del-portapapeles.md)).

### Omarchy

- [x] `omarchy plugin validate ./omarchy-omaplain` finaliza correctamente.
- [x] El ID no usa `omarchy.*` ni colisiona con el catálogo.
- [x] Habilitar/deshabilitar funciona mediante `omarchy plugin` y `shell.json`.
- [x] Guardar QML provoca hot reload sin watchers duplicados.
- [x] Reiniciar `omarchy-shell` no deja procesos huérfanos.
- [x] No se modifica nada en `/usr/share/omarchy/`.
- [x] El plugin no instala paquetes, no usa `sudo` y no ejecuta install hooks.

### Calidad de interfaz

- [x] Solo hay una acción primaria visible.
- [x] Todos los controles tienen estados default, hover, focus, active, disabled y error cuando aplica.
- [x] Todos los hit targets son al menos 44 × 44 px.
- [x] Microcopy específica y en sentence case.
- [x] Tema y métricas provienen de Omarchy Shell.
- [x] Animaciones respetan reduced motion y no usan transiciones genéricas.

## 18. Entrega por fases

### Fase 0 — Spike técnico, 1–2 días

- Probar `wl-paste --watch` + `wl-copy` con Firefox, Chromium, Foot y LibreOffice.
- Enumerar MIME reales de texto, archivo, imagen, contraseña, celda, fórmula y corte.
- Medir el orden de eventos frente a `omarchy.clipboard`.
- Validar el envío del atajo en ventanas normales y terminales (se planeó con `hyprctl dispatch sendshortcut`; Hyprland 0.56 obligó a `hyprctl eval`, ver [`0002`](docs/decisions/0002-hyprland-input.md)).
- Resultado: matriz de compatibilidad y decisión go/no-go del modo automático standalone.

### Fase 1 — MVP comunitario, 4–6 días

- Helper con clasificador, format stripping, invisibles, URL cleanup y loop guard.
- `Service.qml`, IPC y panel mínimo.
- `cleanNow`, `pasteClean` y pausa.
- Exclusiones exactas por clase.
- Tests unitarios y de integración principales.
- Documentación de la limitación del historial.

### Fase 2 — Endurecimiento, 3–5 días

- Corpus Unicode y URLs firmadas.
- MIME de ofimática y gestores de archivos.
- Backoff, rate limits, health state y validación de configuración.
- QA de accesibilidad, temas y escalado.
- Paquete listo para catálogo comunitario.

### Fase 3 — Integración core opcional

- Proponer clipboard filter API a Omarchy.
- Añadir detección de API y desactivar el watcher duplicado.
- Garantizar historial con una sola versión y una sola transacción.
- Retirar el aviso de compatibilidad cuando la API esté activa.

### Fuera de v1

- Limpieza de varias URLs dentro de un párrafo.
- Perfiles por aplicación.
- Pausa temporizada.
- Reglas de tracking actualizables desde un origen firmado.
- Soporte multiseat configurable.

## 19. Riesgos y decisiones abiertas

| Riesgo o pregunta | Decisión provisional |
|---|---|
| ¿Modo automático duplica historial? | Formato idéntico se deduplica; cambios reales pueden duplicar hasta tener filter API |
| ¿Puede identificarse siempre el origen? | No; `activewindow` es best effort y no forma parte de la barrera de seguridad |
| ¿Se puede preservar rich text parcial? | No en v1; wl-clipboard publica un solo MIME mediante `wl-copy` |
| ¿Se puede restaurar el original? | No de forma fiel; no prometer undo de formato |
| ¿Qué hacer con HTML sin plain? | Bypass |
| ¿Qué hacer con scripts personalizados? | Fuera de alcance por seguridad y determinismo |
| ¿Qué licencia usar? | GPL-3.0-or-later encaja con wl-clipboard y facilita compartir mejoras; auditar datos vendorizados |
| ¿Bar widget? | Sí desde la `0.2.0`, declarado y no colocado ([`0010`](docs/decisions/0010-como-se-abre-el-panel.md)) |
| ¿Notificar cada limpieza? | No; solo feedback de acciones manuales y errores repetidos limitados |

## 20. Definición de “terminado”

OmaPlain está listo para preparar una publicación cuando cumple todos los criterios de aceptación, pasa la matriz real disponible más los fixtures de protocolo documentados, supera el soak equivalente de 28.800 eventos y una revisión confirma que ninguna ruta de logs o estado contiene el clipboard. La promoción a `1.0.0` sí exige uso real prolongado y repetir Firefox/password manager en aplicaciones instaladas.

La publicación inicial debe etiquetarse como `0.1.0` y describir el modo automático como compatible pero con la limitación conocida del historial cuando cambia el texto. La promesa “pegar limpio por defecto” solo pasa a `1.0.0` cuando el modo automático haya sido probado en uso real y la convivencia con el historial tenga una solución estable.

## 21. Referencias

Fuentes públicas y primarias consultadas:

- [Pure Paste — página oficial](https://sindresorhus.com/pure-paste)
- [Shell Plugins — manual oficial de Omarchy](https://omarchy.org/manual/shell-plugins/)
- [wl-clipboard — repositorio oficial](https://github.com/bugaevc/wl-clipboard)
- [Hyprland Dispatchers — documentación oficial](https://wiki.hypr.land/Configuring/Basics/Dispatchers/)

Fuentes locales auditadas en el baseline:

- `/usr/share/omarchy/shell/README.md`
- `/usr/share/omarchy/shell/plugins/README.md`
- `/usr/share/omarchy/shell/plugins/clipboard/manifest.json`
- `/usr/share/omarchy/shell/plugins/clipboard/Clipboard.qml`
- `/usr/share/omarchy/shell/plugins/clipboard/ClipboardHistory.js`
- `/usr/share/omarchy/shell/plugins/clipboard/capture.sh`
- `/usr/share/omarchy/default/hypr/bindings/clipboard.lua`
- `wl-clipboard(1)` versión 2.3.0

Esta especificación describe comportamiento independiente. No incorpora código, assets ni textos internos de Pure Paste.
