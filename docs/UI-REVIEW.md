# Revisión de interfaz

Fecha: 31 de agosto de 2026. Panel probado en Omarchy Shell a 2560×1440 con el tema oscuro activo.

## Resultado

La interfaz queda aprobada para la prueba de aceptación local. Mantiene el lenguaje visual nativo de Omarchy y no incorpora sombras, gradientes, paleta ni movimiento propios.

La revisión cubrió código, render real, ratón, teclado, foco, scroll, validación y feedback. Se corrigieron estos hallazgos:

- Los mensajes de acción y ayuda ya no aparecen retirando o añadiendo altura al layout.
- Los cambios de estado de una línea a dos conservan la altura mínima del encabezado.
- Un error de exclusión se muestra junto al campo y el scroll lo lleva al viewport.
- El error solo se limpia al editar el valor, no al perder el foco con el mismo valor inválido.
- El label de clase enfoca el campo; `Enter` envía y el input usa texto de 16 px.
- Los dos botones de exclusión pasan a una columna cuando el ancho disponible es menor de 360 px.

## Superficies y movimiento

La jerarquía existente es la adecuada: scrim, tarjeta principal, encabezado, acciones y controles. Todos usan `BorderSurface`, `Button`, `Toggle`, `TextField`, colores y bordes del sistema. Añadir elevación propia rompería la adaptación a temas de Omarchy.

No se añadieron animaciones. Es una utilidad frecuente y orientada a teclado; las transiciones de color de los controles nativos ya comunican hover, pulsación y foco sin introducir latencia ni movimiento. Por tanto, el plugin no necesita una excepción adicional para movimiento reducido.

## Evidencia automatizada

- Validador oficial del manifiesto: correcto.
- Suite: 45 pruebas, 0 fallos.
- Benchmark: p95 de 1,938 ms para 1 MiB en esta ejecución.
- Soak acelerado de ocho horas: 28.800 eventos, una escritura y cero errores.
- `git diff --check`: correcto.

## Prueba de aceptación del usuario

1. Abre el panel con `omarchy-shell shell summon io.github.r-bart.omaplain '{}'`.
2. Comprueba que entiendes en menos de cinco segundos el estado, la acción principal y cómo omitir una copia.
3. Recorre todo con `Tab` y `Shift+Tab`; el foco debe ser visible y el panel debe hacer scroll sin perderlo.
4. En «Clase de aplicación», pulsa `Enter` con el campo vacío. El error debe quedar visible. Escribe un carácter: debe volver inmediatamente al texto de ayuda.
5. Pulsa «Limpiar portapapeles ahora» con un texto con formato no sensible. El resultado debe aparecer bajo las acciones sin desplazar «Modo».
6. Desactiva y reactiva «Limpiar automáticamente». El texto de contexto debe cambiar sin saltos y el historial nativo debe seguir disponible.
7. Cierra con `Escape`, vuelve a abrir y confirma que el foco inicial está en «Limpiar portapapeles ahora».

No uses secretos reales para la prueba. Un texto como `Hola` con negrita y una URL de prueba con `utm_source` son suficientes.
