# 0004 — Convertir «Transformación» en la experiencia de producto

- Estado: aceptada
- Fecha: 31 de agosto de 2026

## Contexto

El prototipo de identidad comparó tres direcciones para el panel: **Sistema**,
**Transformación** y **Tipográfica**. La dirección Transformación comunica mejor
el trabajo de OmaPlain antes de que el usuario lea los ajustes: una copia con
ruido se convierte en texto uniforme y la interfaz explica a la vez el límite
de seguridad.

La identidad no debe quedarse en un encabezado decorativo. Una persona que
instala el plugin necesita entender qué cambia, qué queda intacto y dónde
recuperar el control antes de confiarle el portapapeles.

## Decisión

- Promover la dirección **Transformación** al panel de producción.
- Mostrar una bienvenida sólo en la primera apertura. Su finalización se guarda
  como `onboardingVersion`, no como varios booleanos independientes.
- Encadenar desde la bienvenida un tour de tres pasos: copiar, limpiar con
  criterio y mantener el control.
- Permitir revisar la bienvenida y repetir el tour desde «Ayuda y aprendizaje»
  en el panel.
- Construir la ilustración con QML y tokens de Omarchy. No se incorporan
  imágenes raster, colores fijos ni una segunda familia de iconos.
- Mantener una sola acción primaria por vista. Las salidas y retrocesos son
  secundarios o terciarios.
- No promover todavía la animación de entrada del prototipo. El panel es una
  utilidad frecuente y Quickshell no expone una preferencia de movimiento
  reducido; la revisión de microinteracciones se hará como una fase separada.

## Direcciones descartadas

- **Sistema**: correcta y muy nativa, pero no explica la transformación ni crea
  una identidad reconocible.
- **Tipográfica**: ofrece una marca más expresiva, pero convierte el nombre en
  protagonista y deja en segundo plano la promesa de seguridad.

## Consecuencias

- La primera apertura es educativa; las siguientes aterrizan directamente en
  la acción principal.
- Volver a ver la guía no restablece ajustes ni reinicia el estado de primera
  ejecución.
- Una versión futura puede incrementar `onboardingVersion` si necesita enseñar
  un cambio de comportamiento material.

## Enmienda — 31 de agosto de 2026

La decisión dejó fuera la animación con este motivo:

> No promover todavía la animación de entrada del prototipo. El panel es una
> utilidad frecuente y Quickshell no expone una preferencia de movimiento
> reducido; la revisión de microinteracciones se hará como una fase separada.

La fase separada es la `F`, y la puerta queda abierta. Lo que ha cambiado no es
que Quickshell exponga ahora esa preferencia —sigue sin exponerla, comprobado en
`Commons/`— sino que **la conduce el usuario**: un ajuste «Reducir movimiento»
que apaga el movimiento en toda la app.

El plan de la fase decía «propiedad que los componentes aceptan y las probes
conducen, no un ajuste de usuario». Se cambia por un motivo concreto: el
carrusel del estado vacío cicla sin fin, y sin un mando accesible no hay forma
de pararlo, que es lo que pide la WCAG 2.2.2. Una propiedad que sólo conducen
las pruebas es una vía de movimiento reducido que ningún usuario puede tomar.

Con eso, las animaciones que la `0004` aplazó entran, separadas en dos topes
que no se mezclan:

- **Respuesta a una acción** —el sello de la limpieza, la pulsación—: por debajo
  de 300 ms y sólo `transform` y `opacity`.
- **Demostraciones** —la ilustración de la bienvenida, el carrusel—: duran lo
  que hace falta para leerlas, porque nadie las ha pedido y están ahí para eso.

Lo que la `0004` descartaba sigue descartado: no se anima la apertura habitual
del panel ni se escalonan sus controles.
