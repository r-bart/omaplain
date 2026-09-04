# 0023 — A qué Omarchy se ata la 1.0

- Fecha: 4 de septiembre de 2026
- Estado: aceptada el 4 de septiembre de 2026
- Cierra el `C.3` de [`PLAN-1.0.md`](../../PLAN-1.0.md): «decidir la política:
  ¿la 1.0 se ata a Omarchy 4.x?»

## Contexto

Omarchy va por **`4.0.0.alpha`** —así se identifica el shell del paquete
`4.0.1-1`, que es contra el que se desarrolla— y OmaPlain va a publicar una
`1.0`. Un `1.0` encima de un `4.0.0.alpha` es una promesa de estabilidad
apoyada en algo que no promete ninguna.

Es el riesgo dominante del plan, y no es teórico. Ya nos ha mordido una vez:
`updateEntryInline` cambió de sitio dónde escribe los ajustes de un plugin
—`bar.layout` antes que `plugins[]`—, y el panel siguió leyendo del array. El
resultado era completo y **silencioso**: el idioma no cambiaba, el movimiento
reducido no se activaba, las cuatro listas de la
[`0009`](./0009-privacidad-por-aplicacion.md) volvían vacías, y `updateSetting`
devolvía `true` en todos los casos porque la escritura sí ocurría
([`0012`](./0012-el-anillo-de-foco-y-donde-viven-los-ajustes.md)).

## Qué promete la `1.0`, y qué no puede prometer

La [`C.1`](../../PLAN-1.0.md) lo dice: **la promesa es que la promesa es
estable.** Lo que OmaPlain no toca hoy no lo tocará mañana, y la configuración
de un usuario sobrevive a las actualizaciones.

Eso es nuestro y lo podemos cumplir en cualquier Omarchy. Lo que no podemos
prometer es que el panel **funcione** sobre una versión de Omarchy que no ha
existido cuando publicamos: no depende de nosotros, y decir lo contrario sería
inventarse una garantía sobre código ajeno.

## Decisión

**La `1.0` se declara probada contra Omarchy 4.x, y no se ata a ella por la
fuerza.**

Tres piezas, y ninguna es un candado:

### 1. La versión probada se dice, en el README

En esas palabras y con las dos referencias, porque el paquete y el shell no
dicen lo mismo: *desarrollado contra el paquete `4.0.1-1`, cuyo shell se
identifica como `4.0.0.alpha`*. Ya está escrito; lo que la `1.0` añade es que
esa línea pasa a ser parte de lo que se publica y se actualiza con cada
versión.

Fuera de 4.x no se promete nada. No se prohíbe: no se promete.

### 2. No hay puerta de versión, y no se construye

**El manifiesto no tiene dónde ponerla.** El esquema que valida
`omarchy-plugin-validate` conoce `schemaVersion` —que es la versión del propio
esquema, hoy `1`— y ningún campo de versión mínima de Omarchy. Comprobado
sobre el validador instalado.

Y aunque lo tuviera, no la querríamos. Una puerta de versión convierte una
incógnita en un fallo seguro: el día que Omarchy pase a `4.1` o a `5.0`, un
plugin con candado deja de arrancar aunque no haya cambiado nada de lo que usa,
y el usuario pierde una herramienta que funcionaba por un número. En una
plataforma en alfa, donde los números se mueven más que el código, eso está mal
casi siempre.

`check-dependencies` seguirá comprobando lo que sí es una dependencia real y
comprobable: que `wl-copy`, `wl-paste`, `hyprctl`, `setpriv` y `python3` están.
Comandos, no versiones.

### 3. El mecanismo de verdad son los tests que vigilan el kit

Son tres, y leen el shell instalado en vez de creerse lo que recordamos de él:

| Test | Qué vigila |
|---|---|
| `test_el_shell_sigue_buscando_en_la_barra_primero` | Que `updateEntryInline` sigue mirando `bar.layout` antes que `plugins[]` — el orden del que copiamos nuestra lectura |
| `test_el_shell_sigue_ofreciendo_mutate` | Que `mutateShellConfig` existe y sigue persistiendo, que es la vía por la que escribimos |
| `test_el_kit_sigue_apagando_el_foco` | Que `focus-border-alpha` sigue cayendo en el de hover — el día que deje de hacerlo, nuestro anillo sobra y hay que revisar la [`0012`](./0012-el-anillo-de-foco-y-donde-viven-los-ajustes.md) en vez de arrastrarlo |

Los tres se saltan solos sin Omarchy delante, así que la CI no los ve. Se
ejecutan aquí, que es donde está el shell.

**Ésta es la parte que hay que mantener.** Un test que vigila el kit no protege
al usuario de nada por sí mismo: lo que hace es que la noticia nos llegue a
nosotros antes que a él. La regla que sale de aquí es que **cada vez que el
panel copie una suposición sobre el kit, esa suposición va con su test.** Los
tres de arriba existen porque una se coló sin él.

### 4. Y una prueba a mano en cada actualización de Omarchy

Los tests leen el fuente del kit; no ven un cambio de comportamiento que no
cambie el texto que leen. Así que cuando Omarchy suba de versión: correr
`tests/run.sh` con el shell nuevo delante, abrir el panel, y mirar las once
pantallas. Es lo que este repositorio ya hace y lo que no se puede automatizar
mientras `Panel.qml` y `Service.qml` sigan sin arnés.

## Lo que se descartó

- **Atar la `1.0` a 4.x con un candado.** Ver arriba: no hay dónde declararlo,
  y construirlo convertiría cada subida de versión de Omarchy en una avería
  garantizada para quien lo tenga instalado.
- **No decir nada y que se descubra al usar.** Es lo que hay hoy y no es
  aceptable en un `1.0`: quien instala tiene derecho a saber contra qué se
  probó, sobre todo cuando la plataforma se declara en alfa.
- **Esperar a que Omarchy salga de alfa.** Podría tardar meses y no cambia
  nada de lo que este plugin promete. La `1.0` es sobre nuestra promesa, no
  sobre la madurez de la plataforma; y decir contra qué se probó es
  exactamente lo que hace honesta esa distinción.
- **Publicar una `0.9` en su lugar.** Sería más humilde y menos cierto: lo que
  hay es una promesa que ya no queremos cambiar debajo de nadie, y ése es el
  significado que la [`C.1`](../../PLAN-1.0.md) le da al número.

## Consecuencias

- El README declara la versión probada y dice que fuera de 4.x no se promete.
  Un test lo sujeta, para que no se quede atrás como se quedó el resto del
  README antes de rehacerlo.
- Cuando una versión nueva de Omarchy se pruebe, se actualiza esa línea y se
  dice en el `CHANGELOG`. Es una línea, y es lo único que la política pide de
  mantenimiento continuo.
- Los tres tests que vigilan el kit se mantienen y se amplían. Si alguno se
  pone rojo, es noticia y no ruido: significa que el kit ha cambiado debajo.
- `docs/COMPATIBILITY.md` sigue siendo la matriz de aplicaciones de origen, que
  es otra cosa y no cambia con esto.
