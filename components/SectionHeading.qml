import QtQuick
import qs.Commons

// El título de una sección de los ajustes.
//
// Un encabezado pertenece a lo que va debajo, no a lo que va encima. Sueltos
// dentro de una `Column` con `spacing` uniforme recibían el mismo aire por
// los dos lados: medido en el panel real, 21 px arriba y 24 abajo. Y esos dos
// números no eran diseño, eran el ascendente y el descendente de la letra.
//
// Con eso, y con 19 px entre filas normales, la página tenía tres valores
// casi idénticos —19, 21, 24— haciendo tres trabajos distintos, así que se
// leía como una lista plana de veinte filas en vez de como seis secciones.
//
// El `topPadding` es lo que abre la sección; el `spacing` de la columna ya
// basta para pegar el título a su primer control.
Text {
  id: root

  // Cuánto se separa de la sección anterior, por encima de lo que ya pone la
  // columna. Con el `spacing: space(12)` del panel, arriba queda más o menos
  // el doble que abajo, que es lo que hace que el título mire hacia abajo.
  property real gap: Style.space(14)

  // Los glifos pueden pintar por encima de la caja que `Text` les reserva
  // —la nota del kit en `PanelSectionHeader.qml` lo documenta para esta misma
  // familia—, y dentro de un `Flickable` con `clip` esa esquirla se pierde.
  topPadding: gap + Math.ceil(font.pixelSize * 0.15)

  color: Color.popups.text
  font.family: Style.font.family
  font.pixelSize: Style.font.subtitle
  font.bold: true

  Accessible.role: Accessible.Heading
  Accessible.name: text
}
