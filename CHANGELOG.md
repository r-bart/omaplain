# Changelog

Todos los cambios relevantes de OmaPlain se documentan aquí.

## 0.1.0 — 2026-08-31

Primera versión local lista para catálogo.

### Añadido

- Limpieza automática y bajo demanda de texto elegible.
- Retirada de rich text mediante la representación `text/plain`.
- Normalización conservadora de finales de línea, invisibles y URLs completas.
- Transformaciones opcionales independientes.
- `cleanNow`, `pasteClean`, `skipNext`, pausa y exclusiones por clase.
- Servicio, panel e IPC nativos de Omarchy Shell.
- Fail-open, compare-before-write, generaciones, loop guard y límite de 1 MiB.
- Estado privado sin contenido y recuperación con backoff.
- Tests unitarios, propiedades, benchmark, soak e integración Wayland.

### Seguridad

- Bypass de contenido sensible antes de consultar MIME o payload.
- Bypass de imágenes, archivos y formatos estructurales conocidos.
- Cero dependencias de red y cero contenido en logs, estado, IPC o panel.
- Señal de muerte del padre en daemon y watcher para impedir hijos huérfanos tras hot reload o cierre forzoso.

### Limitaciones conocidas

- El historial de Omarchy puede mostrar original y limpio cuando cambian caracteres.
- Los secretos sin marca de sensibilidad requieren una exclusión de aplicación.
- La atribución de origen en Wayland es best effort.
