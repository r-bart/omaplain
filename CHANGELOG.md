# Changelog

Todos los cambios relevantes de OmaPlain se documentan aquí.

## 0.2.0 — 2026-08-31

Esta versión rehace el panel entero. La `0.1.0` funcionaba y no se dejaba
mirar: enseñaba una ilustración donde debía enseñar tu portapapeles, y sus
nueve controles no se veían por un import que faltaba.

### Añadido

- **Previsualización del portapapeles.** La pantalla principal enseña lo que
  tienes copiado y cómo quedaría, cubierto por un vaho que se levanta con el
  ojo o limpiándolo con el dedo. El contenido viaja por el socket y muere con
  la respuesta: no se guarda en ninguna parte ([`0005`](docs/decisions/0005-previsualizacion-del-portapapeles.md)).
- **Privacidad por aplicación.** Dos listas nuevas: las que llegan sin poder
  destaparse y las que OmaPlain ni lee ni enseña. La negativa vive en el
  helper, antes de leer, y no la levanta ninguna acción manual
  ([`0009`](docs/decisions/0009-privacidad-por-aplicacion.md)).
- **Inglés y español**, con selector y `auto` desde el locale del sistema.
- **Estado vacío que enseña.** Con el portapapeles vacío, un carrusel de tres
  ejemplos reales —un enlace con seguimiento, un párrafo con un invisible, una
  copia con formato— pierde lo que sobra delante de ti
  ([`0008`](docs/decisions/0008-el-estado-vacio.md)).
- **Demostración segura en el tour**: transforma texto propio del plugin, nunca
  el portapapeles, y es reversible.
- **Ajuste «Reducir movimiento»** que apaga las animaciones en toda la app.
- **Chips de tipos MIME**, la única forma de enseñar la retirada de formato:
  ahí no cambia ni un carácter.
- **Estado vacío en «Aplicaciones excluidas»**, que explica qué hace excluir
  antes de que haya nada que excluir.
- **Confirmación visual** de la limpieza manual, y el estado «omitir la próxima
  copia» visible en la cabecera.
- **Explicación desplegable** de por qué el original puede seguir en el
  historial de Omarchy.

### Cambiado

- **La primera experiencia enseña; la de todos los días informa.** El titular
  educativo y la ilustración salen de la pantalla frecuente y se quedan en la
  bienvenida y el tour, que es donde tienen trabajo
  ([`0007`](docs/decisions/0007-la-pantalla-frecuente-informa.md)).
- **El panel se parte en dos páginas**: el portapapeles y los ajustes, detrás
  del engranaje.
- El recorrido de primera ejecución pasa por los ajustes, con dos salidas
  visibles ([`0006`](docs/decisions/0006-orden-del-onboarding.md)).
- Los cuatro ajustes de limpieza opcionales van bajo divulgación; los cuatro
  que vienen puestos se quedan a la vista.
- Copy revisado de arriba abajo, en los dos idiomas.
- **La cabecera deja de anunciar el estado normal.** Un servicio que está
  corriendo es lo que se espera de él, y rotularlo «ACTIVO» gastaba la
  primera línea en decir que no pasa nada. La insignia aparece sólo cuando
  tiene algo que contar: pausado, omitiendo la próxima copia, arrancando o
  pidiendo atención. El nombre accesible sigue nombrando el estado siempre,
  porque ahí no hay un panel vivo delante del que deducirlo.

### Arreglado

- **Los nueve controles del panel eran invisibles.** `SettingRow.qml` usaba
  `Style.space()` sin importar `qs.Commons`, así que su altura colapsaba a
  cero. Se publicó así en la `0.1.0`.
- **El ojo se quedaba levantado al cambiar de copia**, de modo que revelar una
  vez enseñaba lo siguiente sin que nadie lo pidiera.
- **Un portapapeles vacío se contaba como error** de inspección.
- **`peek` decía «ya está limpio»** de un portapapeles con formato que sí se
  iba a reescribir.
- **El servicio no formaba su notificación de error**: llamaba al catálogo sin
  importarlo y lanzaba `ReferenceError` en cada arranque.
- La ayuda de la CLI imprimía `==SUPPRESS==` como si fuera un comando.
- **El panel decía «no hay nada que limpiar» de casi todo lo que no sabía
  clasificar.** Reconocía cinco motivos de los diecisiete que el helper puede
  emitir, y el resto caía en «OmaPlain lo ha mirado y lo deja como está»: un
  portapapeles de 1,4 MB que no llegó a leer, bytes que no son texto y —lo
  peor— **una copia de una aplicación bloqueada, justo la pantalla cuyo
  trabajo es demostrar que no la miró**. Cada negativa tiene ahora su titular
  y su explicación, y un test compara las dos listas.
- **Las frases del ojo se componían con la cabecera de la columna**, así que
  el tooltip y el `Accessible.name` decían «Show On the clipboard» y «Mostrar
  Quedaría».
- **La fila bajo llave seguía invitando a destaparse**: el vaho decía
  «arrastra para limpiar» y el lector de pantalla remataba con «o usa el botón
  del ojo», dos gestos que ahí no responden.
- **El botón principal no enseñaba el foco.** Sobre el relleno de acento sólo
  cambiaba 1 px de borde, y encima se oscurecía: enfocado y sin enfocar se
  veían iguales.
- **La demostración del tour estaba escrita en español dentro del QML**, así
  que en inglés la pantalla enseñaba `pan-de-masa-madre` mientras la frase de
  resultado hablaba de «the servings». Y usaba `ejemplo.com`, un dominio real,
  en vez del `example.com` que la RFC 2606 reserva para esto.
- **Tres cadenas estaban en la tabla del idioma equivocado**: el botón que
  cierra el tour y los dos rótulos de exclusión detectada.
- **El botón «Opciones» pisaba la regla de la cabecera.** La fila medía
  `space(38)` y el botón `space(44)`, dos números escritos a mano que se
  contradecían: centrado, sobresalía 3 unidades por arriba y por abajo, de
  modo que su borde inferior cruzaba la línea que cierra la cabecera. Ahora
  la fila la marca su propio control, y la regla pasa a ser hermana de la
  columna, con el mismo aire por arriba que por abajo en vez de quedar
  pegada al botón como si fuera su subrayado.
- **El engranaje vivía dentro de la cadena traducida**, en las dos tablas y
  separado del rótulo por dos espacios literales: se pintaba al tamaño de
  cuerpo en vez del de icono, y ese hueco no escalaba con el tema mientras
  el resto sí. Pasa a `iconText`, que es lo que el kit ofrece y lo que el
  panel ya usa en otros tres sitios. «Saltar» conserva el suyo porque su
  flecha va a la derecha, donde `iconText` no pinta.
- **La frase de estado estaba puesta con valores de rótulo.** El panel usa
  0,68 para rótulos y 0,72 con interlínea 1,45 para prosa que envuelve;
  esta iba con los primeros, más apagada y más apretada que el subtítulo
  que tiene tres líneas más abajo y que dice lo mismo. Medido sobre el
  render: pasa de 5,65:1 a 6,19:1.

### Seguridad

- El contenido del portapapeles puede llegar al panel; **no puede quedar
  escrito en ninguna parte**: ni estado, ni configuración, ni log, ni
  notificación, ni traza, ni truncado, ni resumido.
- `peek` es inerte: no avanza la generación, no consume la omisión, no escribe
  en el portapapeles y no toca el disco.
- De una aplicación bloqueada no se enseña ni la lista de tipos.

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
