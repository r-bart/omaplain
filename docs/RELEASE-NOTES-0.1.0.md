# OmaPlain 0.1.0

Primera entrega local de OmaPlain, un limpiador de portapapeles para Omarchy.

## Lo importante

- Limpia rich text, tracking, finales de línea e invisibles conservadores.
- Mantiene intactos archivos, imágenes, secretos marcados y MIME estructurales.
- Incluye modo automático, limpieza manual, pegar limpio, pausa y omitir próxima copia.
- Todo ocurre localmente; no hay telemetría, red ni historial propio.
- El panel sigue el tema y los componentes de Omarchy Shell.

## Compatibilidad validada

Chromium, Foot, Nautilus y LibreOffice se probaron con copias reales. Imágenes y secretos marcados se probaron con owners Wayland controlados. Firefox y password manager gráfico se cubrieron mediante sus contratos MIME interoperables porque no estaban instalados en el host.

## Limitaciones que debes conocer

El historial nativo puede mostrar el original y la versión limpia cuando una regla cambia caracteres. Los secretos que una aplicación publique como texto normal no pueden detectarse de forma fiable; excluye esa aplicación. La identificación del origen en Wayland es best effort.

## Verificación

La release pasa 45 tests unitarios/de propiedades, el validador oficial, un soak acelerado de 28.800 eventos y pruebas reales de reinicio, hot reload, caída forzosa, permisos, red y límites de tamaño. Consulta [TEST-REPORT.md](TEST-REPORT.md).
