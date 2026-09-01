# Revisión de interfaz

Fecha: 31 de agosto de 2026. Panel probado en Omarchy Shell a 2048×1152 y
2560×1440 con el tema oscuro Nightcall.

## Resultado

La dirección **Transformación** queda aprobada para la prueba de aceptación
local. La experiencia tiene tres superficies coherentes:

1. Una bienvenida de primera ejecución que explica valor, límites y privacidad.
2. Un tour de tres pasos sobre copia, limpieza segura y control.
3. El panel frecuente, con la misma metáfora visual en un encabezado compacto.

La bienvenida deja de aparecer cuando `onboardingVersion` alcanza `1`. Tanto
ella como el tour se pueden abrir de nuevo desde «Ayuda y aprendizaje» sin
alterar la configuración.

## Hallazgos corregidos

| Antes | Después | Por qué |
| --- | --- | --- |
| El encabezado comunicaba sólo nombre y estado. | La copia con ruido se transforma visualmente en texto uniforme junto a la promesa «Texto limpio, sin sorpresas». | La función se entiende antes de leer los ajustes. |
| Las dos acciones principales ocupaban todo el ancho y competían entre sí. | «Limpiar portapapeles ahora» usa el acento; omitir queda como acción secundaria. | Una sola acción primaria fija la jerarquía. |
| Una primera apertura llevaba directamente a controles técnicos. | La bienvenida explica qué cambia, qué se protege y dónde vive el historial. | La confianza precede a la configuración. |
| La guía no tenía una ruta de retorno. | Dos controles en ajustes repiten la bienvenida o el tour y restauran foco y scroll al volver. | La ayuda deja de ser desechable sin desorientar. |
| En una ventana baja, el foco de una acción final podía quedar fuera del viewport. | Bienvenida y tour revelan el control enfocado dentro de su `Flickable`. | El recorrido completo sigue siendo visible por teclado. |

## Superficies, tipografía y movimiento

- Todos los colores, bordes, radios, tamaños y espaciados proceden de `Color`,
  `Border` y `Style`; no hay colores de tema fijados en el QML.
- La ilustración es QML nativo, usa tres roles cromáticos y se ignora en el
  árbol accesible porque el texto contiguo comunica la misma información.
- Los titulares usan la escala de Omarchy, leading compacto y cortes manuales
  sólo donde la composición lo necesita.
- No se añadieron animaciones de entrada ni cambios de paso. La utilidad es
  frecuente y Quickshell no expone todavía una preferencia de movimiento
  reducido. Los controles conservan únicamente el feedback cromático nativo.

## Evidencia

- Primera ejecución: bienvenida → tres pasos → panel.
- Persistencia: cierre y reapertura aterrizan directamente en el panel.
- Revisión: bienvenida y tour abren desde ajustes y regresan al mismo scroll.
- Teclado: foco inicial, `Tab`, `Shift+Tab`, `Return`, `Space` y `Escape`.
- Servicio: watcher `running`, automático activo y `configWarnings` vacío.
- Validador oficial: correcto.
- Suite: 45 pruebas, 0 fallos.
- Soak acelerado: 28.800 eventos, una escritura y cero errores.

## Prueba de aceptación del usuario

1. Para revisar la experiencia ahora, abre el panel y usa `Shift+Tab` desde la
   acción principal: llegarás a «Repetir mini tour» y «Revisar bienvenida».
2. Comprueba que la bienvenida explica en menos de diez segundos qué limpia y
   qué conserva.
3. Completa los tres pasos con teclado y confirma que «Abrir OmaPlain» termina
   en el panel habitual.
4. Reabre el panel: la bienvenida no debe aparecer de nuevo.
5. En ajustes, repite cualquiera de las dos guías y sal; el scroll debe volver
   a «Ayuda y aprendizaje».
6. Cambia temporalmente «Limpiar automáticamente» y confirma que estado, texto
   auxiliar y color cambian juntos sin mover la estructura del encabezado.

No uses secretos reales para la prueba. Un texto con negrita y una URL de
ejemplo con `utm_source` son suficientes.

## Post-review de accesibilidad y pulido

La revisión posterior a la integración resolvió estos cuatro riesgos antes de
continuar con microinteracciones:

- Los textos secundarios usan una opacidad mínima de `0.68`; las parejas de
  referencia Nightcall, Periphery, Dawn y Quattrocento Light superan `4.5:1`.
- Las tarjetas de bienvenida comparten altura cuando forman una misma fila.
- Los cambios entre bienvenida, tour y panel transfieren el foco en el siguiente
  ciclo de Qt; los `180 ms` quedan reservados a la apertura del layer-shell.
- Las acciones de exclusión escalan con `Style.space(44)` y el estado de omisión
  usa una etiqueta corta que conserva el padding del botón.
