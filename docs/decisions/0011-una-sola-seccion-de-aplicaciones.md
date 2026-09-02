# 0011 — Una sola sección de aplicaciones

- Fecha: 1 de septiembre de 2026
- Estado: aceptada
- Enmienda a: [`0009`](./0009-privacidad-por-aplicacion.md), en su última
  consecuencia de interfaz
- Depende de: [`0005`](./0005-previsualizacion-del-portapapeles.md), que fija
  qué puede cruzar la frontera del helper

## Contexto

Los ajustes tenían dos secciones —«Privacidad» y «Aplicaciones excluidas»— con
**el mismo formulario escrito dos veces**. Medido sobre el panel real:

| | Privacidad | Excluidas |
|---|---|---|
| Rótulo | «Clase de la aplicación» | «Clase de aplicación» |
| Campo | `org.example.Application` | `org.example.Application` |
| App detectada | **Usar foot** *(rellena)* | **Dejar de limpiar lo que copie foot** *(añade)* |
| Confirmar | No destapar nunca · No leer nunca | No limpiar lo que copie · No pegar limpio ahí |
| Pista | — | «Las mayúsculas cuentan.» |

Los dos rótulos son la misma frase con una palabra de diferencia. Eso no fue
una decisión: fue una copia que derivó.

Debajo había tres asimetrías que sí importaban:

1. **Los dos botones de app detectada hacían cosas distintas.** Uno rellenaba
   el campo y el otro añadía a `sourceExclusions` sin preguntar. El comentario
   del primero explicaba bien por qué no decidía —«hay dos listas y la app
   detectada no dice a cuál va»—, y ese argumento valía igual para el segundo.
2. **Enter elegía lista a escondidas.** `onAccepted` confirmaba una de las dos
   opciones, y los dos botones eran visualmente idénticos, así que nada decía
   cuál se iba a disparar.
3. **La pista de las mayúsculas sólo estaba bajo un campo**, y la descripción
   accesible del otro reutilizaba `excl.class.hint` —«clase exacta de Hyprland
   **que se excluirá**»— en una sección donde no se excluye nada.

## Decisión

**La aplicación es el sujeto. Una sección, un formulario, cuatro reglas.**

Se elige la aplicación una vez y se decide después. Cada aplicación con al
menos una regla se pinta como una tarjeta con sus cuatro interruptores,
agrupados en «Al leer» y «Al limpiar».

### Por qué esto no contradice la 0009

La `0009` cierra con: *«La sección Privacidad de los ajustes va separada de las
exclusiones de limpieza, con su propio encabezado y su propio estado vacío.»*
Eso es lo que se enmienda, y sólo eso.

Lo que la `0009` defiende es que **las cuatro decisiones sean independientes**:
*«fundirlas obligaría a aceptar la una para tener la otra»*. Ese argumento
protege las decisiones, no los formularios. Cuatro interruptores separados por
aplicación es **más** separación que dos botones pegados de los que Enter
elegía uno sin decirlo. La escalera de tres peldaños de la `0009` —normal,
`alwaysCovered`, `blockedApps`— no se toca, y ahora se ve entera de un vistazo
en la tarjeta de cada aplicación.

Las cuatro listas siguen siendo cuatro listas en `shell.json` y en el helper.
Lo único que cambia es dónde se marcan.

### Traer una aplicación no le pone ninguna regla

El selector y el campo hacen lo mismo y sólo eso: dejar la aplicación delante.
Como es la única acción del formulario, Enter ya no elige nada a escondidas.

Una aplicación sin reglas **no está en ninguna lista**, porque las cuatro
listas son el almacén y no hay dónde guardarla. Así que la tarjeta lo dice —«Sin
ninguna regla todavía. No se guarda nada hasta que marques una»— en vez de
dejar que parezca guardada. Vive en una propiedad del panel que muere al
cerrarlo.

La lista de tarjetas va **ordenada alfabéticamente y debajo del formulario**.
Ordenada, porque si el orden saliera de las cuatro listas, marcar una regla
movería la tarjeta bajo el dedo. Debajo, porque la lista crece y el formulario
no debe moverse cada vez que se añade una aplicación.

## El selector: ventanas abiertas, no aplicaciones instaladas

La pregunta era si se podían ofrecer «las aplicaciones instaladas». **No se
puede, y ofrecerlas sería peor que no ofrecer nada.**

El filtro compara contra la clase de ventana de Hyprland. El catálogo de
aplicaciones instaladas son las entradas `.desktop`, cuyo `id` no es esa clase;
la que sí lo sería es `StartupWMClass`, y en un escritorio real de este
proyecto **93 entradas instaladas declaran 23 de ellas** —un 25%—. Un selector
construido sobre eso daría a elegir, tres de cada cuatro veces, un nombre que
genera una regla que **nunca dispara**. En un filtro de privacidad, una regla
que calla y no actúa es el peor resultado posible.

Las ventanas abiertas sí sirven: `hyprctl clients -j` devuelve la cadena exacta
contra la que compara el demonio. Además mejora lo que había: el botón de «app
detectada» ofrecía sólo la última ventana enfocada; el selector las ofrece
todas, sin repetir y ordenadas.

El campo libre se queda para las aplicaciones que ahora mismo no están
abiertas.

### El título de la ventana no cruza la frontera

`open-windows` devuelve **sólo clases**. El título nombra el documento abierto,
y eso es contenido: la `0005` no lo deja pasar y aquí no hay ninguna razón para
pedir una excepción. La clase ya la leía el demonio para atribuir el origen
(`0009`), así que el dato no es nuevo; lo nuevo es enumerar en vez de preguntar
por una sola ventana.

## Descartado

**Un catálogo de aplicaciones instaladas.** Ver arriba: el 75% no declara su
clase. Se podrá usar más adelante para ponerle **nombre e icono** a una clase
que sí la declare, que es enriquecer lo que ya hay, no sustituirlo.

**Autocompletar dentro del campo.** El desplegable tapa contenido, necesita su
propio modelo de foco y teclado, y no aporta nada sobre unos botones a la vista
cuando la lista de ventanas abiertas cabe en dos filas.

**Fundir también las cuatro listas en una sola con modos.** Es exactamente lo
que la `0009` descartó, y por el mismo motivo.

## Consecuencias

- Siete secciones de ajustes pasan a seis; veinticinco controles, a veinte.
- `ExcludedAppRow.qml` desaparece; entran `AppRules.qml` y `PanelButton.qml`.
- El helper gana `open-windows`. `active-window` se queda como superficie de
  diagnóstico, pero el panel ya no la usa: `Service.currentAppClass` y
  `captureCurrentApp()` se van con ella.
- Veintisiete cadenas del catálogo se retiran y entran veintidós `apps.*` y
  `rules.*`.
- El selector se refresca al abrir el panel y al entrar en los ajustes, porque
  ofrece lo que hay abierto **ahora**.
