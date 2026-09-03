# 0020 — La marca se dibuja, y el punto sigue al tema donde lo pintamos nosotros

- Fecha: 3 de septiembre de 2026
- Estado: aceptada
- Toca las tres superficies de la [`0010`](./0010-como-se-abre-el-panel.md):
  la barra, el lanzador y la cabecera del panel

## Contexto

OmaPlain tenía una marca —un trazo que empieza ondulado y acaba recto, y un
punto donde reposa— y la enseñaba en un solo sitio: el icono del lanzador,
`io.github.r-bart.omaplain.svg`. En los otros dos no.

- **La barra** llevaba `󰅌`, el «pegar en claro» de Material Design Icons.
  Correcto y prestado: en una barra donde todos los iconos salen de esa misma
  familia, dice lo que hace la aplicación y no dice **cuál** es.
- **La cabecera del panel** llevaba «OmaPlain» en negrita y nada más. Como el
  nombre era todo lo que había, tenía que gritar para identificar, y competía
  por la mirada con el veredicto que va justo debajo.

Y el icono del lanzador no lo había visto nadie: la entrada `.desktop` se copia
a mano y el icono con ella ([`0010`](./0010-como-se-abre-el-panel.md)), y en
esta máquina no estaban copiados.

## Decisión

**Una marca, tres sitios, dos maneras de pintarla.**

- En el shell —barra y cabecera— se **dibuja** (`components/Mark.qml`): un
  `Shape` con la misma `d` del SVG, la misma caja de 24 × 24 y el mismo grosor.
- En el lanzador se **sirve el fichero**, que es lo único que el sistema de
  iconos sabe leer.
- El logotipo escribe el nombre en minúscula —`omaplain`— y siempre con el
  dibujo delante. Con la marca identificando, el texto puede bajar la voz.

La `d` es la misma cadena carácter por carácter, y
`tests/unit/test_launch_surfaces.py` la compara. Los puntos de control de esa
curva están calculados para que la curvatura sea igual a los dos lados de cada
nodo; «redondear un poco» uno de los dos ficheros deja dos marcas *parecidas*,
que es peor que dos marcas distintas.

## El punto y el tema

La pregunta que abrió esto era si el punto puede ir en el color del tema. La
respuesta es distinta a cada lado, y la diferencia no es un detalle de
implementación: es de quién es cada superficie.

**Dentro del shell, sí.** Lo pintamos nosotros, cuadro a cuadro, con el mismo
`Color.accent` que ya tiñe el sello del bypass y los interruptores. Cambia el
tema y cambia el punto, sin reiniciar nada. Es la única parte de la marca que
el tema mueve: el trazo va en la tinta del sitio —la de la barra, la del
panel— para acompañar a lo que tiene al lado.

Con una salvedad que conviene decir: hay temas que no declaran acento, y en
ésos `Color.accent` vale lo mismo que la tinta. Ahí el punto no desaparece
—sigue siendo un círculo al final de un trazo—, pero deja de ser un color.

**En el lanzador, no directamente.** El icono es un fichero que se dibuja tal
cual: `shell/plugins/menu/Menu.qml:1303` lo pone en un `Image` sin `colorize`
ni `MultiEffect`. Lo que sí se tiñe en ese mismo menú son sus propias filas,
quince líneas más arriba, y no son ficheros: son glifos de Nerd Font pintados
como texto con `color: root.foreground`. Ahí está la frontera, y no es del
lanzador: **lo que dibujamos nosotros se puede teñir; un fichero que dibuja un
`Image` se ve como está guardado.**

Así que teñirlo es escribir otro fichero. Se hace, y cómo se hace está en la
enmienda de abajo.

## Lo que se descartó

- **Traer el SVG al shell con un `Image`.** Una línea, y trae sus colores
  dentro: el trazo en `#1B201E` sobre un panel casi negro es tinta invisible.
  Habría hecho falta un fichero por tema.
- **Reescribir el SVG del lanzador al cambiar de tema.** Descartado aquí por
  tres motivos, y dos de los tres eran falsos. Ver la enmienda.
- **Un icono `-symbolic`.** GTK sabe teñirlos, pero tiñe el icono **entero** y
  de un solo color: adiós al punto, que es justamente lo que se quería teñir.
  Y el lanzador de Omarchy no tiene por qué ser GTK.
- **Quedarse con el glifo de la Nerd Font en la barra.** Es lo que menos
  trabajo daba y lo que peor resuelve el problema: la barra es donde más veces
  se ve la aplicación, y era donde no había marca.
- **Bajar la inicial también en la prosa.** «omaplain no lee imágenes» a
  principio de frase se lee como una errata. Un logotipo y un nombre propio son
  dos cosas distintas: el nombre en minúscula vale donde va con el dibujo
  delante, que es lo que lo hace un logotipo. En las cadenas se sigue
  escribiendo `OmaPlain`, y un test lo sujeta.

## Consecuencias

- `components/Mark.qml` es el cuarto componente que dibuja con `QtQuick.Shapes`
  (el halo, el arco del control y el grano son los otros). Va con el trazador
  de curvas, para que la misma marca salga nítida a 20 px en la barra y a 20 px
  en la cabecera sin dos juegos de números.
- La marca se recorta a su tinta —20,45 × 6,8 de las 24 × 24— y se pide por el
  ancho. Con la caja entera, las 17 unidades de aire de arriba y abajo
  convierten cualquier fila en una fila con un agujero.
- El nombre en minúscula llega a la entrada `.desktop`, al manifiesto y a la
  cabecera. Un test lee los tres a la vez, porque ninguno importa a los otros.


## Enmienda · el lanzador también, con un gancho y una ruta

Descarté repintar el icono del lanzador con tres motivos. Al ir a comprobarlos
uno por uno, dos no aguantaron.

**«Sin ningún gancho de plugin en el cambio de tema»: falso.**
`omarchy-theme-set` termina llamando a `omarchy-hook theme-set "$THEME_NAME"`,
y `~/.config/omarchy/hooks/theme-set.d/` existe desde la instalación, con su
`.sample` dentro explicando cómo se usa. El gancho estaba puesto; no lo busqué.
Y `omarchy-theme-color` resuelve la paleta del tema actual desde un script,
que es justo lo que hacía falta para pintar.

**«Una caché de iconos con la que competir»: cierto, y medido.** Dos
experimentos en el shell de verdad, con la entrada fijada arriba del menú de
aplicaciones para poder verla:

| qué se cambia | ¿lo ve el shell vivo? |
| --- | --- |
| el contenido del SVG, misma ruta | **no** — hasta que el shell reinicia |
| el `Icon=` de la entrada, ruta nueva | **sí**, al momento |

El motivo es que `Menu.qml` pinta con un `Image` cuya `source` es una URL de
fichero, y Qt cachea el pixmap por esa URL en un proceso que vive horas.
Reescribir el fichero deja la URL igual y la caché acierta con la imagen
vieja. Cambiar la ruta hace que falle, y entonces lee. `omarchy-theme-set` no
reinicia el shell a propósito —«the shell hot-reloads theme colors»—, así que
la vía del contenido dejaría el lanzador desfasado hasta el siguiente arranque.

**«Un fichero que OmaPlain no posee»: sigue siendo verdad, y por eso el hook
se limita.** Los iconos generados van a `~/.local/share/omaplain/icons/`, que
es nuestro; de la entrada del usuario se toca **una línea**, la del `Icon=`; y
sin entrada instalada el hook no hace nada y no la crea. Un test cuenta qué
ficheros aparecen tras una pasada y falla si sale alguno de más.

Queda el motivo estético, que era el bueno de los tres: una baldosa que cambia
de tono es más difícil de encontrar en una rejilla. Se sostiene menos de lo
que parecía, porque en esa rejilla se busca por **forma** —la onda con su
punto— y la forma no cambia. Y el reparto de color se eligió para que el
contraste esté garantizado en los dos modos:

- la baldosa va en `foreground` y el trazo en `background`, no al revés. El
  menú de aplicaciones se pinta con `background`: una baldosa de ese color se
  disuelve en la fila. Con este reparto, en un tema claro el icono se da la
  vuelta solo y sigue contrastando.
- el punto, en `accent`.

Instalarlo sigue siendo una decisión del usuario, como la propia entrada
`.desktop` ([`0010`](./0010-como-se-abre-el-panel.md)): es un enlace en
`theme-set.d` y una pasada a mano la primera vez. Sin él, el lanzador enseña
el icono de marca de siempre, que es el que este repositorio versiona.
