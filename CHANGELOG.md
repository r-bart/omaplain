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

- **Una sola sección de aplicaciones.** «Privacidad» y «Aplicaciones excluidas»
  montaban el mismo formulario dos veces, con dos rótulos que se diferenciaban
  en una palabra y dos botones de «app detectada» que hacían cosas distintas.
  Ahora eliges la aplicación una vez y decides después: cada una lleva sus
  cuatro reglas como cuatro interruptores independientes, agrupados en «Al
  leer» y «Al limpiar». Siete secciones de ajustes pasan a seis y veinticinco
  controles a veinte ([`0011`](docs/decisions/0011-una-sola-seccion-de-aplicaciones.md)).
- **Un selector de ventanas abiertas** sustituye a los botones de «app
  detectada». Ofrece todas las ventanas y no sólo la última enfocada, y la
  clase que da es exactamente la que compara el demonio. No son las
  aplicaciones instaladas a propósito: de 93 entradas `.desktop` de un
  escritorio real, sólo 23 declaran su clase de ventana, así que tres de cada
  cuatro darían una regla que nunca dispara. El título de la ventana no cruza
  la frontera del helper.
- **Enter ya no elige lista a escondidas.** Había dos botones idénticos de
  confirmar y `onAccepted` disparaba uno de los dos sin decir cuál. Ahora el
  formulario tiene una sola acción: traer la aplicación.
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
- **El panel se puede abrir sin escribir un comando**
  ([`0010`](docs/decisions/0010-como-se-abre-el-panel.md)). Hasta ahora el
  manifiesto declaraba `service` y `panel`, y un `panel` sólo existe cuando
  alguien lo invoca: no había ninguna superficie desde la que invocarlo. Se
  añade un **widget de barra** —clic izquierdo para abrir y cerrar— y una
  **entrada `.desktop`** para el lanzador. Ninguna de las dos se activa sola:
  el icono lo coloca `bar.layout` en `shell.json`, que es el mando que
  Omarchy ya tiene para esto, y la entrada del lanzador se copia a mano
  porque el plugin no vive en `XDG_DATA_DIRS`. Sigue sin haber atajo global
  ni cambios en la configuración de Hyprland.
- **La cabecera deja de predicar.** De las ocho frases de estado, siete
  informan de algo que está pasando —pausado, va a omitir, se acaba de
  limpiar, falta una dependencia— y la octava describía el producto:
  «OmaPlain ordena el formato y deja intacto todo lo que no puede limpiar
  con seguridad». Era la rama **por defecto**, así que predicaba justo en el
  caso más frecuente, encima de un veredicto que ya dice qué pasa con *tu*
  portapapeles. Es el titular educativo que la `0007` echó de esta pantalla,
  sobrevivido como cadena. Ahora, sin nada que contar, la cabecera de estado
  desaparece entera en vez de dejar su hueco.
- **El dibujo del estado vacío se lee.** La barra de dirección tapaba el 40%
  de la hoja de detrás, líneas de texto incluidas, y las dos formas se veían
  como una sola mancha; y el halo iba a acento del 10% sobre un fondo muy
  oscuro, que no llega a brillar y sí a ensuciar. Baja la barra y sube el
  halo: dos objetos, uno delante del otro.
- **Los estados que no se tocan dejan de ser una pantalla en blanco.** Con
  una imagen, un archivo, algo sensible, algo demasiado grande o una
  aplicación bloqueada, el panel no tiene portapapeles que enseñar —de una
  imagen no se lee ni un byte—, así que la mitad que en los demás estados
  ocupa la previsualización se quedaba vacía, con el veredicto flotando y
  debajo «no hay ninguna acción que ofrecer aquí». Esa pantalla llegó a
  confundirse con el estado vacío. Ahora lleva el dibujo de *Imágenes /
  Archivos / Secretos*, que es lo que ese veredicto afirma, y la salida al
  tour. La nota genérica se calla cuando aparece esa salida, porque decir
  que no hay nada que ofrecer encima de un botón que ofrece algo es falso
  ([enmienda de la `0007`](docs/decisions/0007-la-pantalla-frecuente-informa.md)).
- **Los ajustes vuelven a leerse como secciones.** Los encabezados eran
  `Text` sueltos en una columna de espaciado uniforme, así que recibían el
  mismo aire por los dos lados —21 px arriba y 24 abajo, medidos, y esos dos
  números eran el ascendente y el descendente de la letra, no diseño—.
  Con 19 px entre filas, la página tenía tres valores casi idénticos
  haciendo tres trabajos distintos y se leía como una lista plana de veinte
  filas. Ahora hay un `SectionHeading` que abre su sección: 43 px encima
  contra 24 debajo, y 19 entre filas del mismo grupo.
- **«Reducir movimiento» tiene su propia sección.** Vivía debajo del
  encabezado «Idioma», sin nada que dijera que había salido de él.
- **El onboarding ya no se lee arrastrando.** La tarjeta tenía un techo de
  `space(720)` para que los ajustes no se comieran la pantalla, y el paso 2
  del tour lo tocaba: «Siguiente» y la salida quedaban por debajo del borde,
  de modo que había que desplazar la pantalla para poder continuarla. La
  bienvenida y el tour crecen ahora hasta su contenido, con la pantalla como
  único límite; la vista de todos los días conserva su techo intacto.
- **El paso 2 del tour se enseña solo, y baja de cinco mandos a cuatro.** La
  muestra pierde sus parámetros de seguimiento delante de ti al entrar, en
  vez de esperar a que alguien pulse. Con eso, «Otro ejemplo» sobraba: la
  `0004` pide una acción primaria por vista y ahí la primaria es
  «Siguiente». Queda un solo botón de la demostración, que con movimiento
  sirve para volver a mirar y sin movimiento es quien hace la
  demostración. La segunda muestra —el enlace firmado que no se toca— sigue
  en el catálogo y bajo test: su lección ya la daba con palabras el aviso de
  encima.
- **La cabecera deja de anunciar el estado normal.** Un servicio que está
  corriendo es lo que se espera de él, y rotularlo «ACTIVO» gastaba la
  primera línea en decir que no pasa nada. La insignia aparece sólo cuando
  tiene algo que contar: pausado, omitiendo la próxima copia, arrancando o
  pidiendo atención. El nombre accesible sigue nombrando el estado siempre,
  porque ahí no hay un panel vivo delante del que deducirlo.

### Arreglado

- **Con el icono en la barra, ningún ajuste se guardaba.** `updateEntryInline`
  del shell escribe en `bar.layout` cuando encuentra ahí el id del plugin, y
  sólo entonces deja `plugins[]` en paz; el panel leía siempre de `plugins[]`.
  Desde que OmaPlain declara `bar-widget`, cada ajuste se guardaba en un sitio
  y se leía de otro: ni el idioma, ni el movimiento reducido, ni las cuatro
  listas de privacidad se quedaban puestos, y sin ningún error a la vista.
  Además, mientras el icono está en la barra, `plugins[]` se quedaba congelado
  en el día en que se colocó: quitarlo devolvía los ajustes a los de entonces.
  Ahora se mantiene una copia al día, por la vía que el shell expone
  ([`0012`](docs/decisions/0012-el-anillo-de-foco-y-donde-viven-los-ajustes.md)).
- **Enfocar un control lo apagaba.** El borde de foco del kit sale de
  `focus-border-alpha`, que cae en 0,25 frente al 0,4 del borde normal: medido
  en el panel, 2,79:1 en reposo y **1,82:1 con el foco puesto**. Con veinte
  controles navegables, el recorrido por teclado no dejaba rastro. Los botones
  y las filas dibujan ahora su propio anillo, neutro y a 6,17:1.
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
- **El tour tenía tres bordes izquierdos distintos en la misma columna.**
  El aviso y la demostración estaban topados a `space(420)` y centrados, y
  la rejilla de acciones iba a ancho completo: 613 px los botones, 560 las
  otras dos cajas. Las superficies pasan a seguir el ancho de la pila. El
  párrafo del paso conserva su tope, que ahí no es una caja mal medida sino
  una columna de lectura: envuelve a unos 57 caracteres.
- **Todas las filas de ajuste medían lo mismo, mirara o no el contenido.**
  `SettingRow` sobreescribía la altura con `Math.max(Style.space(44), 54)` y
  con eso tiraba el cálculo del kit, que es
  `Math.max(54, content.implicitHeight + Style.spacing.huge)`. Las filas con
  descripción de dos líneas iban apretadas contra sus bordes; ahora pasan de
  56 a 75 px y el resto se queda como estaba.
- **Dos rótulos de campo se disfrazaban de encabezado de sección.**
  «Clase de aplicación» iba en negrita a color pleno —11,33:1, exactamente
  lo mismo que «Privacidad», y a un solo escalón de tamaño—, así que abría
  una sección que no existía.
- **Los dos desplegables eran los únicos bloques centrados** de una página
  alineada a la izquierda, y abren texto que sí empieza a la izquierda.
- **El texto de ejemplo del campo daba 4,19:1**, por debajo del 4,5 que pide
  la AA, y ahí no es decoración: es la única pista de qué hay que teclear.
  Pasa a 5,55:1 con el alfa de rótulo que el panel ya usa.
- **Dos párrafos que envuelven iban con el alfa de los rótulos.** El panel
  usa 0,68 para rótulos y foregrounds de control y 0,72 para prosa.
- **Los dos naipes de la ilustración no medían lo mismo.** El de «CLEAN»
  estaba escrito 4 puntos más alto que el de «COPIED» —126 contra 122— sin
  que nada lo pidiera, y como además va relleno a opacidad plena contra el
  0,72 del otro, y una forma más clara sobre fondo oscuro ya se lee más
  grande de por sí, las dos cosas empujaban en la misma dirección. Ahora el
  tamaño se declara una vez y lo comparten.
- **El nombre accesible de la muestra estaba escrito en español dentro del
  QML**, así que en inglés un lector de pantalla decía «Ejemplo original:
  https://…». Es el mismo fallo que la demo ya había tenido con su texto, en
  la única línea que se había quedado sin mirar. Y ahora anuncia el estado
  asentado, no el fotograma: a media animación el texto es un recorte que no
  existe en ninguna parte.
- **La demostración daba dos saltos de maquetación.** La caja de la muestra
  encogía de dos líneas a una al limpiarse, y la frase del resultado
  aparecía de la nada: entre las dos empujaban los botones hacia arriba y
  hacia abajo justo cuando el ojo iba hacia ellos. La caja reserva ahora la
  altura del original, que es el estado más alto, y la frase ocupa su sitio
  siempre.
- **«Omitir la próxima copia» no caducaba por tiempo.** Se prometen sesenta
  segundos; con el escritorio quieto la marca se quedaba puesta
  indefinidamente y la cabecera seguía diciéndolo. La caducidad era perezosa
  y sólo corría al llegar un evento o al pedir `status` **por el socket**, y
  el panel no usa esa vía: relee `status.json` del disco. Nadie despertaba
  al demonio. El bucle de `accept` ya lo hace cada 0,5 s, así que la
  comprobación va ahí, sin temporizador nuevo. El test que existía
  preguntaba justo por el socket, de modo que pasaba con el fallo delante.

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
