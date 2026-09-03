# Handoff · Activos gráficos y animaciones de OmaPlain

## Qué es esto

El rediseño completo de los activos gráficos del panel de OmaPlain, con sus animaciones
especificadas al milisegundo, listo para transcribir a QML sobre la base de código que ya
existe en `31.omaplain`.

Cubre once pantallas: la bienvenida, los tres pasos del tour, el último paso del recorrido
(ajustes), los cinco estados de la pantalla frecuente y la página de ajustes.

## Los ficheros de este paquete son referencia de diseño, no código a copiar

Los dos `.dc.html` son **prototipos en HTML**: existen para fijar la apariencia y el
comportamiento con precisión, y para poder verlos correr. **No son código de producción.**

El trabajo es **recrear estos diseños en QML**, dentro del entorno que ya tiene el plugin:
`Quickshell`, `qs.Commons`, `qs.Ui`, `BorderSurface`, `PanelButton`, `PrimaryButton`,
`SettingRow`, `Chip`, y el catálogo bilingüe de `components/Strings.js`. Nada de este paquete
introduce dependencias nuevas: **no hace falta `ShaderEffect`, ni desenfoque de fondo, ni
`Canvas`, ni ningún recurso externo.** Todo se resuelve con `Rectangle`, `Gradient`,
`NumberAnimation`, `Repeater` y una textura de ruido en repetición.

## Fidelidad

**Alta fidelidad en composición, movimiento y copia. Media en tipografía.**

- Composición, tamaños, colores, opacidades y coreografía: definitivos. Están medidos en
  píxeles reales sobre el ancho real del panel (520 px) y hay que reproducirlos.
- Copia: **verbatim de `components/Strings.js`**. Los prototipos están en inglés porque es
  la tabla `EN` del catálogo; la `ES` no cambia de estructura. No reescribas ni una cadena.
- Tipografía: los tamaños de `Style.font.*` que usan los prototipos son **estimaciones**
  (ver `TOKENS.md`). Sustitúyelos por los del tema y reajusta sólo alturas de línea si algo
  desborda; ninguna otra medida depende de ellos.

## Cómo leer el paquete

| Fichero | Contiene |
|---|---|
| `ANIMACIONES.md` | Los seis motores de animación, con curvas, tiempos, disparadores y su traducción a QML. **Es el documento principal.** |
| `ESTADOS.md` | Las once pantallas: qué las dispara, qué activo monta cada una, qué se anima y qué no. |
| `TOKENS.md` | Colores, alfas, tipografía, espaciado, radios, y la receta del cristal. |
| `STRINGS.md` | Las claves que entran y salen de `Strings.js`, y los tests que hay que tocar. |
| `OmaPlain Navegable.dc.html` | Prototipo **navegable**: un panel a tamaño real, con navegación de verdad y un mando para elegir el contenido del portapapeles. Es el que hay que abrir para *entender* el producto. |
| `OmaPlain Panel Prototipo.dc.html` | Prototipo de **revisión**: las once pantallas en fila con un reloj común y notas de diseño. Es el que hay que abrir para *comparar* pantallas y leer el por qué de cada decisión. |
| `support.js` | Runtime de los prototipos. No se transcribe: sólo hace falta para que los `.html` abran. |

Abre los `.html` directamente en un navegador. En el navegable, el mando de abajo no es
producto: es el escritorio simulado.

## Las dos reglas que gobiernan todo

Si sólo te llevas dos cosas de este paquete:

**1. Cae lo que es texto real; se comprime lo que es una pieza.**
Los caracteres que se van de una cadena de verdad —la demo del tour, la fila del
resultado— se sueltan y rebotan en el suelo. Los tramos abstractos de una ilustración, lo
que sobra en el carrusel y un chip MIME entero **no caen**: se ponen en acento y se
comprimen hacia su izquierda. Ninguna pantalla mezcla los dos gestos.

**2. Nunca hay dos animaciones que pidan atención en la misma pantalla.**
Cada pantalla tiene un solo acontecimiento. Las dos que repiten movimiento en bucle —el
sónar y el carrusel del portapapeles vacío— no sueltan ni comprimen nada.

## Alcance y decisiones heredadas

- **`FogCover` queda fuera de alcance.** Se mantiene tal cual está hoy. Cuando se retome, la
  pregunta allí no es estética sino de coste: es lo único del panel que repinta sin parar
  mientras haya filas cubiertas.
- **La decisión 0007 sigue en pie**: la pantalla frecuente informa, no enseña el producto. La
  única ilustración que aparece en ella es la del bypass, y va **quieta** (`motionEnabled:
  false` desde `Panel.qml`), porque un bypass se ve muchas veces al día.
- **La decisión 0008 sigue en pie**: la coreografía del ciclo del carrusel no se toca ni un
  milisegundo. Lo único que cambia dentro es qué dibuja `CopySpecimen`.
- **La decisión 0015 sigue en pie**: sin nada que aplicar no hay botón primario.
- **F.1 / WCAG 2.2.2**: `reduceMotion` apaga las seis animaciones y pinta cada pantalla en su
  estado final. Ninguna pierde información al hacerlo — ver la sección «Reducir movimiento»
  de `ANIMACIONES.md`.

## Orden de implementación sugerido

1. `TOKENS.md` → la receta del cristal como componente reutilizable (`GlassSurface.qml`
   sobre `BorderSurface`). Todo lo demás la usa.
2. `TransformationIllustration.qml` variante `transform` con el motor de compresión
   (`ANIMACIONES.md` §2). Es el activo de la bienvenida y el más sencillo de los animados.
3. `CopySpecimen.qml` a cristal (§5). Cambia el dibujo, no la coreografía: el riesgo es bajo
   y arregla la incoherencia más visible del panel.
4. `DemoTransformation.qml` con el motor de caída (§1). Es el más delicado: hay que partir la
   cadena en caracteres sin tocar `Strings.js`.
5. `ClipboardRow.qml` (§1, atado a `revealed`).
6. `MimeChips.qml` (§2, un chip entero comprimiéndose).
7. Variante `protect` con la cinta del control de seguridad y el grano (§3).
8. Variante `control` con los interruptores y el recorrido automático (§4).
9. `StatusHeader.qml`, el sónar (§6).
10. `Strings.js` y los tests (`STRINGS.md`).
