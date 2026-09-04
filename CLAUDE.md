# Trabajar en OmaPlain

Reglas cortas, todas aprendidas rompiendo algo. Lo que no está aquí está
argumentado en [`SPEC.md`](SPEC.md) y en [`docs/decisions/`](docs/decisions).

## Antes de dar nada por hecho

- **`tests/run.sh` es la suite entera.** Unitarias con `ResourceWarning`
  como error, benchmark, soak, `qmllint`, el QML ejecutado dentro de un
  Quickshell (`tests/qml.sh`) y el validador de Omarchy. Los tres últimos
  se saltan solos sin Omarchy delante.
- **Un componente nuevo se prueba en `tests/qml/TestRoot.qml`.** Los tipos
  de Quickshell viven dentro de su binario, así que `qmltestrunner` no
  sirve: la única forma de ejecutar nuestro QML es un Quickshell dentro de
  un compositor, y eso es lo que `tests/qml.sh` levanta.
- **Después de tocar un `.qml`, `omarchy restart shell`.**
  `rescanPlugins` no basta: Qt conserva el QML ya compilado para esa URL y
  el panel sigue enseñando la versión anterior **sin dar ningún error**.
- **Un cambio de interfaz se comprueba en el panel real.** Los tests de
  contrato leen el fuente; no ven un binding que no se evalúa. Los de
  `tests/qml/` sí lo ejecutan, pero sólo de los componentes: `Panel.qml` y
  `Service.qml` necesitan el shell entero y siguen siendo cosa de mirar.
- **El panel real no corre este repositorio.** Omarchy carga otro clon en
  `~/.config/omarchy/plugins/io.github.r-bart.omaplain`, así que mirar el
  panel sin llevarle antes la rama —`git -C <esa ruta> fetch <este repo>
  <rama> && git -C <esa ruta> merge --ff-only FETCH_HEAD`— es mirar la
  versión anterior y creer que se ha comprobado algo. **Y el shell se para
  antes de tocar ese directorio**, no después: reescribirlo en caliente
  dispara recargas encadenadas del plugin. Parar, sincronizar, arrancar.
- **`pkill -f` con un patrón que diga «quickshell» u «omarchy» se mata a sí
  mismo**: la línea de órdenes del propio `bash -c` contiene el patrón. Se
  mata por PID.
- **Y matarlo por PID no lo para: está supervisado y vuelve en un par de
  segundos**, con PID nuevo. Así que «parar antes de tocar el directorio» no
  se consigue con un `kill`; lo que se consigue es sincronizar mientras
  arranca, que es el caso que la regla de arriba quería evitar. Sincroniza y
  reinicia después con `omarchy restart shell`, contando con que el clon se
  reescribe con el shell vivo.
- **Esta máquina la comparten varias sesiones.** El shell puede reiniciarse
  por su cuenta a mitad de una medida. Toda medida sobre `/proc/<pid>` tiene
  que releer el PID al final y descartarse si cambió: si no, sale una cifra
  negativa y parece un error de aritmética.
- **Lo que se ve en el arnés depende del compositor de prueba.** Ahí
  `Style.cornerRadius` vale cero, así que ningún fallo de esquinas
  redondeadas se manifiesta; y un `ShellRoot` sin ventana no dibuja nada,
  así que un `Canvas` no pinta. Lo que haya que ver se monta dentro de la
  `PanelWindow` de `TestRoot.qml`.

## Lo que este proyecto promete

- **El contenido del portapapeles no se persiste en ningún sitio.** Ni
  estado, ni configuración, ni log, ni notificación, ni traza de error, ni
  mensaje de excepción. Sólo cruza el socket `0600` hacia el panel abierto,
  y muere al cerrarlo.
- **La duda provoca bypass.** Ante un MIME desconocido, un texto que no
  decodifica o una operación sensible, no se toca nada.
- **Como máximo una reescritura por evento**, comparando antes de escribir.

Si un cambio roza cualquiera de las tres, va con su decisión numerada en
`docs/decisions/` antes que con código.

## Al tocar el helper

- Todo proceso externo lleva plazo. Una aplicación de origen que no sirve
  su oferta dejaba el demonio colgado con el cerrojo cogido.
- Los plazos del cliente del socket tienen que cubrir lo que el demonio
  puede tardar con el cerrojo cogido; si no, el panel inventa un error.
- Lo que se apunta en `status.json` lo lee el panel una vez por segundo.
  Marcar ahí un evento que no es una copia nueva hace que el panel vuelva a
  cubrir filas que el usuario acababa de destapar.

## Al tocar el panel

- Un botón deshabilitado es para una condición que se puede resolver desde
  esa misma pantalla. Si no, no se enseña ([`0015`](docs/decisions/0015-la-pantalla-frecuente-no-ofrece-un-boton-muerto.md)).
- **Una caja no saca su alto de un hijo que se centra contra ella.** Es un
  ciclo de trazado: Qt no converge y se queda girando en el hilo de
  interfaz, sin un solo error en el log y con el shell entero sin
  responder. Aguanta escondido mientras el contenido sólo se mueve un
  momento —una animación de una pasada dura lo que dura— y sale a la luz en
  cuanto algo cicla. El mínimo va en el contenido, no en la caja.
- **Un bucle nuevo se mide en el proceso, no sólo se mira.** Cuatro
  aperturas y cierres del panel y `awk '{print ($14+$15)}' /proc/<pid>/stat`
  antes y después: en reposo tiene que quedarse por debajo del 1 %. El
  arnés no lo ve —su cadena de trazado es más corta que la del panel— y a
  ojo un hilo atascado se parece a un shell lento.
- **Todo lo que cicla se para al ocultarse.** Ya pasó con el vaho y el
  carrusel corriendo dentro de una ventana cerrada, y volvió a pasar con la
  cinta del tour detrás del paso 2. Un `visible` leído desde QML ya es la
  visibilidad efectiva —incluye a los padres—, así que un `running:` colgado
  de él basta; lo que arranca una función a mano hay que pararlo a mano.
- Si un control puede desaparecer con el foco dentro, hay que decir a dónde
  va el foco después.
- Las cadenas van en `components/Strings.js`, en los dos idiomas. Un test
  compara las dos tablas.

## Idioma

README y `SECURITY.md` en inglés; decisiones, `SPEC.md`, planes, notas y
comentarios en español ([`0014`](docs/decisions/0014-el-idioma-del-repositorio.md)).
