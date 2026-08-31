# 0003 — Renombrar el producto a OmaPlain

- Estado: aceptada
- Fecha: 31 de agosto de 2026

## Contexto

La revisión final de los catálogos descubrió `io.github.pkayokay.omapaste`, un gestor de historial comunitario llamado Omapaste e inspirado en Paste. Su alcance es distinto al limpiador tipo Pure Paste de este repositorio, pero compartir el nombre generaría confusión de búsqueda, soporte y marca.

El índice oficial `plugins.omarchy.org` y el marketplace comunitario se comprobaron en sus revisiones `1204ef31415d6d1f6e287e7d7a6c729aa8670ad3` y `15d86b06cf6e905ce4fb360b79fd78c39c27610c`. No contenían `OmaPlain` ni `io.github.r-bart.omaplain`.

## Decisión

El producto pasa a llamarse **OmaPlain** y usa el ID global `io.github.r-bart.omaplain`. También se renombran repositorio local, helper, paquete Python, IPC, namespace de layer-shell y directorio runtime.

## Consecuencias

- El nombre describe mejor la conversión a plain text.
- No colisiona ni parece una continuación del gestor Omapaste existente.
- La implementación sigue siendo clean-room y no incorpora código del otro proyecto.
- Cualquier instrucción previa que use `omapaste.cleaner` queda obsoleta antes de la primera release.
