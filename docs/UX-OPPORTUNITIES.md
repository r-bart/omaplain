# Oportunidades de diferenciación UI/UX

Este inventario parte de la dirección Transformación ya implementada. No es una
lista de efectos pendientes: cada idea debe demostrar que mejora comprensión,
feedback o control sin enseñar contenido real del portapapeles.

## Prioridad alta

### 1. Confirmación visual de la transformación

Después de una limpieza manual correcta, la hoja «Limpio» puede asentarse y
mostrar su sello durante unos 1,5 segundos. La transición debe afectar sólo a
`opacity` y `scale`, durar menos de 220 ms y tener una vía explícita de
movimiento reducido antes de implementarse.

Valor: conecta el clic con el resultado sin depender únicamente del mensaje de
texto.

### 2. Estado «omitir una copia» dentro del héroe

Cuando `skipNext` está activo, el encabezado puede sustituir temporalmente la
escena por una sola hoja apartada y el copy «La próxima copia pasará intacta».
No debe usar una cuenta atrás: el estado expira por evento o por tiempo y un
reloj añade presión sin ayudar a decidir.

Valor: convierte un estado hoy textual en una consecuencia visible.

### 3. Demostración segura en el tour — implementada

`DemoTransformation.qml`, en el paso 2. Transforma texto propio del plugin,
nunca el portapapeles, es reversible por el mismo botón y va rotulada como
demostración.

Los ejemplos son URLs enteras porque es la única forma que el motor reescribe:
`clean_tracking_url` se rinde en cuanto el texto contiene un espacio, así que
una demostración construida sobre prosa con un enlace dentro prometería una
limpieza que no ocurre. El par enseña las dos mitades: una URL con seguimiento
que se limpia y una URL firmada que se respeta.

`tests/unit/test_demo_sample.py` pasa cada original por el transform real y
compara con el resultado rotulado, de modo que la demostración no puede
sobrevivir a un cambio de regla que la convierta en mentira.

Valor: prueba la promesa del producto sin pedir confianza ni acceso adicional.

## Prioridad media

- Agrupar los ajustes opcionales bajo una divulgación «Limpieza avanzada» si el
  panel sigue creciendo; hoy el volumen aún no justifica ocultarlos.
- Explicar «por qué puede aparecer el original en el historial» mediante un
  bloque desplegable junto al texto actual, no mediante un tooltip.
- Convertir exclusiones en filas con estado y origen detectado cuando exista un
  patrón real de varias aplicaciones; no añadir iconos de apps hasta disponer
  de una fuente coherente.
- Hacer que el feedback de acción persista mientras el usuario mantiene el foco
  en la zona de resultado, en vez de depender siempre de 2,5 segundos.

## Evitar

- Animar la apertura habitual del panel o escalonar todos sus controles.
- Mostrar una previsualización del contenido real del portapapeles.
- Añadir partículas, brillos permanentes o una ilustración en bucle.
- Usar el rosa como éxito y como acción primaria a la vez; la confirmación debe
  sumar forma y texto, no otro significado cromático.
- Reemplazar el historial nativo de Omarchy desde esta interfaz.
