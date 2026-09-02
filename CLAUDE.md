# Trabajar en OmaPlain

Reglas cortas, todas aprendidas rompiendo algo. Lo que no está aquí está
argumentado en [`SPEC.md`](SPEC.md) y en [`docs/decisions/`](docs/decisions).

## Antes de dar nada por hecho

- **`tests/run.sh` es la suite entera.** Unitarias con `ResourceWarning`
  como error, benchmark, soak, `qmllint` contra el shell instalado y el
  validador de Omarchy. Los dos últimos se saltan sin Omarchy delante.
- **Después de tocar un `.qml`, `omarchy restart shell`.**
  `rescanPlugins` no basta: Qt conserva el QML ya compilado para esa URL y
  el panel sigue enseñando la versión anterior **sin dar ningún error**.
- **Un cambio de interfaz se comprueba en el panel real.** Los tests de
  contrato leen el fuente; no ven un binding que no se evalúa.

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
- Si un control puede desaparecer con el foco dentro, hay que decir a dónde
  va el foco después.
- Las cadenas van en `components/Strings.js`, en los dos idiomas. Un test
  compara las dos tablas.

## Idioma

README y `SECURITY.md` en inglés; decisiones, `SPEC.md`, planes, notas y
comentarios en español ([`0014`](docs/decisions/0014-el-idioma-del-repositorio.md)).
