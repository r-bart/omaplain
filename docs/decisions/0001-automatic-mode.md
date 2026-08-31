# 0001 — Mantener el modo automático standalone

- Estado: aceptada
- Fecha: 31 de agosto de 2026

## Contexto

OmaPlain y `omarchy.clipboard` observan el mismo clipboard. Era necesario demostrar que dos watchers no causan loops, pérdida de datos o sobrescrituras tardías.

## Decisión

La release `0.1.0` incluirá modo automático standalone, activado por defecto, con:

- daemon único y eventos por socket;
- loop guard efímero en memoria;
- generaciones monotónicas;
- cancelación por evento más nuevo;
- compare-before-write;
- bypass conservador y fail-open.

La interfaz advertirá que una URL o texto realmente transformado puede conservar también su versión original en el historial de Omarchy.

## Consecuencias

- OmaPlain funciona sin cambios en Omarchy core.
- El historial puede mostrar dos variantes cuando cambian caracteres.
- El usuario puede desactivar URL/invisibles o usar `pasteClean` si prefiere conservar explícitamente el original.
- Se mantiene una futura filter API como mejora opcional.

