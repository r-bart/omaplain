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
- El nombre se escribe de tres maneras y cada una tiene su sitio: `omaplain`
  donde va con la marca delante —cabecera del panel y manifiesto—, `Omaplain`
  en el lanzador y `OmaPlain` en la prosa. Un test las lee a la vez y comprueba
  que son la misma palabra, porque ningún fichero importa a los otros y desde
  dentro de cualquiera de ellos una cuarta forma no se ve.

  El lanzador se sale del logotipo por lo que es esa pantalla: **una lista de
  nombres.** La marca está ahí, pero en la columna de iconos, igual que la de
  todas las demás filas; no forma pareja con el texto. Y el nombre se lee junto
  a «Aether», «Basecamp» y «Document Viewer», donde una minúscula no dice
  «marca», dice «errata». Un logotipo necesita que el dibujo esté haciendo de
  identificador, y ahí no lo está.


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

Y el motivo estético, que era el bueno de los tres, se resuelve **quitando la
baldosa**. La primera versión la teñía: baldosa en `foreground`, trazo en
`background`. Funcionaba y no decía nada — `foreground` es el color del texto,
o sea un casi-blanco en cualquier tema oscuro, así que el icono siempre salía
como una baldosa clara y sólo le cambiaba el matiz. Puesto sobre el tema que
lo estrenó era indistinguible del icono de marca, porque ese tema tiene el
primer plano crema.

Sin baldosa el problema desaparece en lugar de resolverse:

- el trazo va en `foreground`, que es el negativo de aquello sobre lo que se
  pinta. Contrasta en un tema claro por el mismo motivo que en uno oscuro, y
  no hay que elegir un relleno que valga para los dos.
- el punto, en `accent`. Es la única parte con color propio, igual que en la
  barra y en la cabecera del panel.

Es además el mismo dibujo que `components/Mark.qml` pone en la barra: sin
baldosa, el icono del lanzador y el de la barra pasan a ser la misma cosa.

**Y por eso son dos ficheros.** El icono de marca conserva la suya y tiene que
conservarla: ése no sabe nada del tema, y su trazo casi negro sobre un menú
casi negro no se ve. La baldosa es lo que le permite valer sobre cualquier
fondo. El plano, `launcher/mark.svg`, sólo lo usa el hook, que sí sabe de qué
color pintar. Comparten la `d`, y un test compara las tres — las dos y la del
QML.

Lo que se paga: la marca es tres veces más ancha que alta, así que sin baldosa
pesa menos que sus vecinos en una rejilla de iconos cuadrados. Se gana ancho,
no alto, y el 8 % de lienzo que sobra es el aire del punto.

Instalarlo sigue siendo una decisión del usuario, como la propia entrada
`.desktop` ([`0010`](./0010-como-se-abre-el-panel.md)): es un enlace en
`theme-set.d` y una pasada a mano la primera vez. Sin él, el lanzador enseña
el icono de marca de siempre, que es el que este repositorio versiona.
