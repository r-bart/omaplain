.pragma library

// La tinta atenuada del panel, con suelo de contraste.
//
// El panel escribía su texto secundario como `Util.alpha(Color.popups.text,
// 0.68)` en veintitantos sitios. El 0,68 estaba medido —6,17:1 sobre el tema
// con el que se midió, según la `0012`— y ése es justamente el problema: es un
// número medido sobre **un** tema. Un alfa fijo mezcla el texto hacia el fondo
// sin mirar cuál es el fondo, así que no puede prometer ninguna ratio.
//
// Medido sobre los treinta temas instalados con
// `docs/notes/contraste-del-kit.py`, el 0,68 se queda por debajo del 4,5:1 que
// la WCAG 2.1 SC 1.4.3 pide para texto en cuatro: `rose-pine` (3,21:1),
// `catppuccin-latte` (3,32:1), `everforest` (4,31:1) y `tokyo-night` (4,46:1).
// Los dos peores son temas claros, donde mezclar un texto oscuro hacia un
// fondo claro pierde más.
//
// Es el mismo defecto que le estamos reportando al kit de Omarchy en
// `docs/notes/UPSTREAM-2026-09-04.md`, y se arregla con la misma receta que
// ese informe propone: **el alfa que se pide, con suelo de contraste**. Se
// atenúa lo que el diseño quiere, y se para antes de cruzar el suelo.
//
// Con el 0,68 pedido, veintiséis de los treinta temas conservan exactamente el
// atenuado de siempre; los otros cuatro suben lo justo. Ninguno baja del suelo.
//
// El fondo se pasa en cada llamada, igual que el idioma en `Strings.js`, para
// que los bindings de QML se reevalúen solos al cambiar de tema.

// Los dos suelos de la WCAG 2.1, en AA.
var TEXTO = 4.5      // SC 1.4.3, texto
var CONTORNO = 3.0   // SC 1.4.11, el contorno de un componente

// Los dos atenuados que el panel pide. Salen de la `0012` y del handoff, y no
// se tocan: lo que este módulo añade no es otro número, es el suelo por debajo
// del cual esos números no pueden bajar.
//
// El 0,68 es para rótulos y `foreground`s de control; la prosa que envuelve va
// un punto más alta, que es la distinción que el panel ya hacía. Sin suelo, el
// 0,68 no llega a la AA en cuatro de los treinta temas y el 0,72 en dos.
var ATENUADO = 0.68
var PROSA = 0.72

function _lineal(c) {
  return c <= 0.03928 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4)
}

function _luminancia(c) {
  return 0.2126 * _lineal(c.r) + 0.7152 * _lineal(c.g) + 0.0722 * _lineal(c.b)
}

function _contraste(a, b) {
  var la = _luminancia(a)
  var lb = _luminancia(b)
  return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05)
}

function _mezcla(color, alfa, fondo) {
  return Qt.rgba(color.r * alfa + fondo.r * (1 - alfa),
                 color.g * alfa + fondo.g * (1 - alfa),
                 color.b * alfa + fondo.b * (1 - alfa),
                 1)
}

// El alfa mínimo que alcanza `suelo`, nunca por debajo del pedido.
//
// El contraste de la mezcla contra el fondo crece con el alfa —de 1:1 con el
// fondo puro a la razón completa con el texto puro—, así que se biseca. Si ni
// el texto entero llega al suelo, devuelve el texto entero: es lo más legible
// que ese tema tiene, y atenuarlo sería peor por partida doble.
function _conSuelo(texto, fondo, pedido, suelo) {
  if (_contraste(_mezcla(texto, pedido, fondo), fondo) >= suelo) return pedido
  if (_contraste(texto, fondo) < suelo) return 1.0
  var lo = pedido
  var hi = 1.0
  for (var i = 0; i < 24; i++) {
    var mid = (lo + hi) / 2
    if (_contraste(_mezcla(texto, mid, fondo), fondo) >= suelo) hi = mid
    else lo = mid
  }
  return hi
}

// El texto secundario: rótulos, pistas, detalles bajo un titular. Suelo de
// texto, 4,5:1.
function secondary(texto, fondo) {
  return Qt.rgba(texto.r, texto.g, texto.b, _conSuelo(texto, fondo, ATENUADO, TEXTO))
}

// La prosa que envuelve: descripciones, notas, el detalle del historial. Un
// punto por encima del rótulo, y el mismo suelo.
function prose(texto, fondo) {
  return Qt.rgba(texto.r, texto.g, texto.b, _conSuelo(texto, fondo, PROSA, TEXTO))
}

// Cualquier otro atenuado de texto, con el mismo suelo. Es para los dos sitios
// que piden un valor propio —el cuerpo del último paso del tour al 0,78 y el
// rótulo de las tarjetas de la ilustración al 0,6— y no para inventar un
// tercer atenuado de uso general: si aparece un tercero repetido, se le pone
// nombre aquí arriba como a los otros dos.
function dim(texto, fondo, alfa) {
  return Qt.rgba(texto.r, texto.g, texto.b, _conSuelo(texto, fondo, alfa, TEXTO))
}

// El anillo de foco y los contornos que dibujamos nosotros. Suelo de
// contorno, 3:1 — más bajo porque no es texto.
//
// Con el 0,68 pedido ningún tema de los treinta necesita subir, así que hoy
// esto devuelve siempre el mismo color que antes. Va igualmente: el número que
// lo hacía cierto era una medida, y un tema nuevo no tiene por qué respetarla.
function ring(texto, fondo) {
  return Qt.rgba(texto.r, texto.g, texto.b, _conSuelo(texto, fondo, ATENUADO, CONTORNO))
}
