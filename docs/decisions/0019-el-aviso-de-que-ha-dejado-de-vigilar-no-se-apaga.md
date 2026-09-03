# 0019 — El aviso de que ha dejado de vigilar no se apaga

- Fecha: 3 de septiembre de 2026
- Estado: aceptada
- Misma familia que la [`0016`](./0016-la-omision-de-una-copia-no-se-gana-su-sitio.md):
  lo que no se gana su sitio en la interfaz tampoco se lo gana en el código

## Contexto

`notifyOnError` estaba en la configuración desde el principio. Una revisión de
la página de Ajustes la encontró en un estado raro: **existe, funciona y no se
puede cambiar.** Está en los valores de serie, el helper la valida,
`Service.updateSetting` la acepta y `Service.maybeNotifyWatcher` la lee. Pero
no hay ningún control en la página, y no había un solo test que la tocara.

Lo primero que se pensó fue exponerla. «No me avises de errores» suena a
preferencia legítima, y estaba a un `SettingRow` de distancia.

## El argumento

Al mirar **qué** apaga, la respuesta cambió.

No apaga «las notificaciones de error». Apaga la **única** notificación que
OmaPlain manda en toda su vida: la que avisa de que el vigilante del
portapapeles se ha caído. Una sola, limitada a una cada diez minutos, y
únicamente cuando el estado pasa a `degraded`.

Es decir: es la única señal de que el producto **ha dejado de hacer lo que
promete**.

Y este producto trabaja donde no lo miras. Limpia cada copia por su cuenta, en
segundo plano, y su valor entero está en que puedes dejar de pensar en ello.
Un interruptor para callar ese aviso es un interruptor para que una herramienta
de privacidad falle en silencio — y el que lo pulse será justamente quien más
confíe en que sigue funcionando.

La cabecera del panel también lo dice, pero sólo si abres el panel. Con el
automático puesto y todo yendo bien, un usuario puede pasar semanas sin
abrirlo. El aviso es la única vía que sale de la ventana.

## Decisión

**Se retira entera: de los valores de serie, de la validación del helper, del
IPC del panel y de la lista de claves que se pueden escribir.**

No se expone, y no se queda escondida. Las dos salidas eran peores:

- **Exponerla** es ofrecer un modo de fallo silencioso en un producto cuya
  promesa es que no tienes que vigilarlo.
- **Dejarla como escotilla** es mantener un camino que nadie recorre, que hay
  que seguir probando, y que además sólo encontraría quien leyera el fuente —
  que es exactamente el usuario que sabría apagar el servicio entero si le
  molestara.

El aviso se queda, sin condición. Es una cada diez minutos y sólo cuando el
vigilante se ha caído: no hay ruido que ahorrar.

## Lo que se descartó

- **Cambiarla por «avisar sólo una vez por sesión».** Cambia la frecuencia de
  algo que ya ocurre como mucho seis veces por hora, y sólo cuando el producto
  está roto. No hay problema que resolver.
- **Dejarla y ponerle un test.** Un test que sujeta una opción que no debería
  existir es trabajo que hay que mantener para siempre.

## Consecuencias

- Un usuario ya no puede silenciar el único aviso del producto. Quien no lo
  quiera, apaga el servicio, que es explícito y se ve.
- La configuración pierde una clave. No es un formato persistente entre
  sesiones, así que no hay migración; una configuración vieja que la traiga la
  ignora la validación, como cualquier otra clave desconocida.
- `SPEC.md` §17 deja de listarla.
