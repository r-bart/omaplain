# 0012 — El anillo de foco, y dónde viven los ajustes

- Fecha: 1 de septiembre de 2026
- Estado: aceptada

Dos arreglos que salieron de la misma revisión de los ajustes y que no son de
diseño de producto sino de plataforma: el panel estaba usando mal dos cosas del
shell.

## 1. Con el icono en la barra, ningún ajuste se guardaba

`updateEntryInline` del shell —la única vía para escribir la configuración de
un plugin— busca el id **primero en `bar.layout.left/center/right`** y, si lo
encuentra ahí, escribe ahí y **no toca `plugins[]`**:

```qml
if (!foundInLayout) {
  for (var j = 0; j < copy.plugins.length; j++) { ... }
}
```

`Service.entrySettings()` leía sólo `plugins[]`. Mientras OmaPlain no tuvo
`bar-widget` daba igual. Desde la [`0010`](./0010-como-se-abre-el-panel.md), en
cuanto el usuario coloca el icono, **el panel escribe en la barra y sigue
leyendo del array de plugins**: cada ajuste se guarda en un sitio y se lee de
otro.

El síntoma es completo y silencioso: el idioma no cambia, el movimiento
reducido no se activa, y las cuatro listas de la `0009` se marcan y vuelven a
salir vacías. `updateSetting` devuelve `true` en todos los casos, porque la
escritura sí ocurre.

**Decisión: `entryFor()` lee en el mismo orden en que el shell escribe** —las
tres secciones de la barra primero, `plugins[]` después—. No se toca
`updateEntryInline`, que es del kit.

### La red de seguridad

Leer bien no basta. Mientras el icono esté puesto, `plugins[]` se queda
congelado en el día en que se colocó; el día que el usuario lo quite, la
entrada de la barra se lleva sus ajustes con ella y el panel vuelve a leer una
configuración de otra época. El idioma, el movimiento reducido y las cuatro
listas de la `0009` retroceden semanas sin que nadie lo haya pedido.

**Decisión: cuando escribimos en la barra, dejamos la misma copia en
`plugins[]`**, que es el sitio canónico de los ajustes de un plugin. Va por
`mutateShellConfig`, que es la vía que el propio shell expone para esto: no se
toca `shell.json` por detrás, ni se escribe la entrada de nadie más.

Sólo se copia cuando difiere. `mutateShellConfig` persiste siempre, sin mirar
si algo cambió, y esto no puede convertirse en una escritura por cada lectura.

## 2. Enfocar un control lo apagaba

`focus-border-alpha` cae por defecto en `hover-cursor-border-alpha`, que vale
0,25 frente al 0,4 del borde normal. Medido en el panel real, sobre este tema y
contra el fondo de la tarjeta:

| Estado | Contraste |
|---|---|
| Reposo | **2,79:1** |
| **Con foco** | **1,82:1** |
| Relleno de foco | 1,16:1 |

Es decir: tomar el foco **baja** el contraste del contorno. En una página con
veinte controles navegables, el recorrido por teclado no dejaba rastro visible.
Escribiendo esta revisión me pasó a mí: pulsé Enter creyendo estar en un botón
y lancé el recorrido de bienvenida.

No es un defecto nuevo. [`PrimaryButton`](../../components/PrimaryButton.qml) ya
tuvo que dibujar el suyo por la misma razón, y hay un test que lo exige a
cualquier control propio que entre en el orden de tabulación. Lo que faltaba
era aplicarlo a los botones y las filas del kit, que son casi todo el panel.

**Decisión: el anillo lo dibujamos nosotros, por dentro, neutro.** Va en el
color del texto al **0,68** —el alfa de rótulo que el panel ya usa, sin
inventar un número— y mide **6,17:1** contra el fondo y **5,31:1** contra el
relleno de foco sobre el que se pinta. Con margen de sobra sobre el 3:1 que
pide la SC 1.4.11 para el contorno de un control.

Neutro y no de acento a propósito: en este panel el acento ya significa
«elegido» —lo lleva el idioma activo—, y un anillo de marca competiría con él.

Vive en [`PanelButton`](../../components/PanelButton.qml) y en
[`SettingRow`](../../components/SettingRow.qml). **Y por ahí tienen que pasar
todos**, que es lo que esta decisión se dejó a medias la primera vez: el
recorrido, la bienvenida, la demostración y el ojo de las filas seguían usando
el `Button` del kit a pelo, así que en el tour no se veía dónde estabas. Se
llegó a pulsar «Atrás» creyendo pulsar el botón final, y volver al principio
del recorrido parecía un fallo del botón final.

El test que debía cubrirlo miraba los ficheros con `activeFocusOnTab` escrito
dentro, y esos cuatro lo heredaban sin escribirlo: pasaba en verde con el fallo
delante. Ahora la regla es la que se puede comprobar de verdad — **ningún
componente usa el `Button` ni el `Toggle` del kit salvo los dos envoltorios que
ponen el anillo**.

## Lo que no se toca

El **borde en reposo de 2,79:1** se queda como está. Sale de
`normal-border-alpha = 0,4`, que es el valor por defecto de Omarchy: subirlo a
0,44 daría 3,11:1, pero es el tema del usuario y no el nuestro. Queda anotado
como defecto de plataforma, igual que el `placeholderTextColor` del kit.

## Enmienda · los dos contrastes de arriba son de un tema, no del 0,68

Los 6,17:1 y 5,31:1 que esta decisión da por el anillo, y el 2,79:1 del borde,
están medidos sobre `terminus`, que era el tema puesto. Un alfa mezcla hacia el
fondo sin mirar cuál es el fondo, así que ninguno de los tres es una propiedad
del número: son lo que ese número dio contra ese fondo.

Medido después en los treinta temas instalados, el 0,68 no llega al 4,5:1 de la
AA para **texto** en cuatro de ellos. El anillo aguanta —le basta el 3:1 de la
SC 1.4.11 y el peor da 3,21:1—, así que el argumento de esta decisión se
mantiene entero; lo que no se sostiene es leer 6,17:1 como una garantía.

La [`0022`](./0022-la-tinta-atenuada-lleva-suelo.md) le pone suelo, y los dos
defectos de plataforma de arriba están medidos y escritos para upstream en
[`UPSTREAM-2026-09-04.md`](../notes/UPSTREAM-2026-09-04.md).
