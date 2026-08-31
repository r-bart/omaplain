.pragma library

// Catálogo bilingüe.
//
// Ni el shell de Omarchy ni ningún plugin usan `qsTr`, y sin ficheros `.qm`
// compilados y un QTranslator instalado `qsTr` devuelve la cadena tal cual:
// maquinaria sin efecto. Así que el catálogo vive aquí, sin paso de
// compilación y legible de un vistazo.
//
// El idioma se pasa en cada llamada en vez de guardarse en el módulo, para
// que los bindings de QML se reevalúen solos cuando cambie.

var EN = {
  // --- Marca y navegación ---
  "app.name": "OmaPlain",
  "nav.options": "󰢻  Options",
  "nav.back": "󰅁  Back",
  "nav.skip": "Skip  󰅂",
  "nav.options.a11y": "Open options",
  "nav.back.a11y": "Back to the clipboard",
  "nav.skip.a11y": "Skip the settings and open the panel",

  // --- Estado del servicio ---
  "state.active": "Active",
  "state.paused": "Paused",
  "state.starting": "Starting",
  "state.attention": "Needs attention",
  "state.a11y": "OmaPlain, %1. %2",

  // --- Estado del servicio y avisos ---
  "status.unavailable": "The service is not available yet.",
  "status.deps": "Missing dependencies: %1",
  "status.degraded": "The watcher has failed several times. Manual actions are still available.",
  "status.restarting": "Restarting the watcher…",
  "status.paused": "Automatic cleaning is paused. Manual actions are still available.",
  "status.willskip": "The next eligible copy will be skipped.",
  "status.done": "Ready · last clean completed",
  "status.idle": "OmaPlain tidies the formatting and leaves intact everything it cannot clean safely.",
  "hint.manual": "Manual cleaning and «paste clean» are still available.",
  "hint.chars": "The automatic copy keeps the characters of the text.",
  "fb.cleaned": "Clipboard cleaned",
  "fb.unchanged": "It was already clean",
  "fb.image": "Not modified: it is an image",
  "fb.files": "Not modified: it holds files",
  "fb.sensitive": "Sensitive content protected",
  "fb.large": "Not modified: over 1 MB",
  "fb.excluded": "Not modified: excluded application",
  "fb.bypassed": "Not modified: unsupported content",
  "fb.skip": "The next copy will be skipped",
  "fb.error": "Could not clean it. The original text is intact.",

  // --- Veredictos sobre el portapapeles ---
  "verdict.cleanable": "This can be cleaned",
  "verdict.clean": "Already clean",
  "verdict.nothing": "Nothing to clean here",
  "verdict.sensitive": "Marked as sensitive",
  "verdict.image": "An image is left alone",
  "verdict.files": "Files, untouched",
  "verdict.structured": "Structured format, untouched",
  "verdict.empty": "Nothing copied yet",
  "verdict.preparing": "Getting ready…",

  "detail.cleanable": "This is how it stands and how it would end up.",
  "detail.clean": "OmaPlain has looked at it and there is nothing to remove.",
  "detail.nothing": "OmaPlain has looked at it and leaves it as it is.",
  "detail.sensitive": "Your password manager marked this copy. OmaPlain does not read it, does not show it and does not rewrite it.",
  "detail.image": "OmaPlain does not even read it. Screenshots reach their destination byte for byte.",
  "detail.files": "Copying files moves paths and permissions. Rewriting that would break the paste.",
  "detail.empty": "Copy something and you will see here what OmaPlain would do with it.",

  // --- Filas ---
  "row.now": "Now",
  "row.would": "Would be",
  "row.single": "On the clipboard",
  "row.show": "Show %1",
  "row.hide": "Hide %1",
  "row.covered.a11y": "Content covered. Drag across it to clear it, or use the eye button.",
  "fog.hint": "Drag to clear",

  // --- Reglas y ajustes que las gobiernan ---
  "rule.tracking": "Tracking parameters",
  "rule.invisible": "Invisible characters",
  "rule.line_endings": "CRLF line endings",
  "rule.rich_text": "Rich formatting",
  "rule.removed.a11y": "Removed: %1, under the %2 setting",
  "setting.tracking": "Tracking",
  "setting.invisible": "Invisibles",
  "setting.line_endings": "Line endings",
  "setting.rich_text": "Formatting",

  // --- Acciones ---
  "action.apply": "Apply to the clipboard",
  "action.applying": "Cleaning…",
  "action.skip": "Skip the next copy",
  "action.skipped": "Next copy skipped",
  "footnote.safe": "The original stays intact if cleaning is not safe.",
  "footnote.sensitive": "Revealing is not available for content marked as sensitive.",
  "footnote.nothing": "There is nothing to clean, so there is no action to offer.",

  // --- Ajustes ---
  "settings.language": "Language",
  "settings.language.auto": "System",
  "settings.language.en": "English",
  "settings.language.es": "Spanish",
  "settings.mode": "Mode",
  "settings.cleaning": "Cleaning",
  "settings.optional": "Optional",
  "settings.automatic": "Clean automatically",
  "settings.automatic.desc": "Turns every copy that is safe into plain text.",
  "settings.history": "The history may keep the original too when characters change.",
  "settings.formatting": "Remove rich formatting",
  "settings.formatting.desc": "Pastes using only the plain-text representation.",
  "settings.tracking": "Remove URL tracking",
  "settings.tracking.desc": "Only acts when the whole content is one URL.",
  "settings.invisible": "Remove non-semantic invisibles",
  "settings.invisible.desc": "Keeps emoji, RTL writing and language marks.",
  "settings.endings": "Normalise line endings",
  "settings.endings.desc": "Turns CRLF and CR into LF without dropping the final break.",
  "settings.quotes": "Normalise quotes",
  "settings.quotes.desc": "Turns typographic quotes into straight ones.",
  "settings.bullets": "Normalise bullets",
  "settings.bullets.desc": "Turns leading bullets into hyphens.",
  "settings.nfc": "Normalise Unicode NFC",
  "settings.nfc.desc": "May change the exact representation of the text.",
  "settings.trim": "Trim trailing spaces",
  "settings.trim.desc": "Removes the space at the end of each line.",

  // --- Exclusiones ---
  "excl.title": "Excluded applications",
  "excl.detected": "Exclude the detected application",
  "excl.detect": "Exclude %1 from automatic mode",
  "excl.none.title": "No application excluded",
  "excl.none.body": "OmaPlain cleans the text you copy in any application. Exclude one as a source so what you copy there passes untouched, or as a target so nothing is pasted clean into it.",
  "excl.class": "Application class",
  "excl.addSource": "Add as source",
  "excl.addTarget": "Add as target",
  "excl.case": "It is case sensitive.",
  "excl.source": "Source · automatic mode",
  "excl.target": "Target · paste clean",
  "excl.remove": "Remove",
  "excl.remove.a11y": "Remove %1",
  "excl.undetected": "No application detected",

  // --- Ayuda y privacidad ---
  "help.title": "Help and learning",
  "help.body": "Go back to the first explanation or repeat the walkthrough without changing your settings.",
  "help.welcome": "Review the welcome",
  "help.welcome.a11y": "Opens the OmaPlain explanation again",
  "help.tour": "Repeat the mini tour",
  "help.tour.a11y": "Starts the three-step walkthrough again",
  "privacy.title": "Privacy",
  "privacy.body": "Everything happens on this machine. OmaPlain does not store the copied text. The history belongs to Omarchy.",

  // --- Bienvenida ---
  "welcome.eyebrow.first": "First visit",
  "welcome.eyebrow.return": "OmaPlain guide",
  "welcome.title": "Clean text,\nno surprises.",
  "welcome.body": "OmaPlain turns eligible copies into plain text and keeps intact everything it cannot clean safely.",
  "welcome.card1.title": "Removes what is spare",
  "welcome.card1.body": "Formatting, tracking and non-semantic invisibles.",
  "welcome.card2.title": "Protects what matters",
  "welcome.card2.body": "Images, files and secrets pass untouched.",
  "welcome.card3.title": "Everything stays home",
  "welcome.card3.body": "No cloud, no telemetry, no history of its own.",
  "welcome.start": "See how it works",
  "welcome.enter": "Open the panel",
  "welcome.return": "Back to settings",
  "welcome.again": "You can come back to this guide from settings.",

  // --- Tour ---
  "tour.eyebrow": "How it works",
  "tour.eyebrow.replay": "Quick recap",
  "tour.step": "%1 of %2",
  "tour.step.a11y": "Step %1 of %2. %3",
  "tour.1.title": "Copy as you always do",
  "tour.1.body": "OmaPlain watches new text copies and cleans them automatically when it is safe. You do not need a new shortcut.",
  "tour.1.note": "Images and files pass untouched.",
  "tour.2.title": "Only what is spare",
  "tour.2.body": "It removes rich formatting, tracking parameters from whole URLs and non-semantic invisible characters.",
  "tour.2.note": "When in doubt, it keeps the original.",
  "tour.3.title": "You keep control",
  "tour.3.body": "Clean by hand, skip the next copy or exclude an application. The history is still Omarchy's.",
  "tour.3.note": "Everything happens on this machine.",
  "tour.back": "Back",
  "tour.back.first.a11y": "Back to the previous screen",
  "tour.back.a11y": "Back to the previous step",
  "tour.next": "Next",
  "tour.finish": "Open OmaPlain",
  "tour.skip": "Skip the tour",
  "tour.leave": "Leave the recap",

  // --- Demostración del tour ---
  "demo.label": "Demonstration · sample text, never your clipboard",
  "demo.try": "Try it with an example",
  "demo.original": "See the original",
  "demo.other": "Another example",
  "demo.other.a11y": "Another demonstration example",

  // --- Último paso del recorrido ---
  "onboarding.last": "Last step",
  "onboarding.last.body": "This is what you can adjust. It already comes safely configured, so you can leave it as it is.",
  "onboarding.done": "Open OmaPlain",

  // --- Ilustración ---
  "state.preparing": "Getting the service ready…",
  "art.skip": "Skip a copy",
  "art.exclude": "Exclude apps",
  "settings.trim2": "Trim end-of-line spaces",
  "art.copied": "Copied",
  "art.clean": "Clean"
};

var ES = {
  "app.name": "OmaPlain",
  "nav.options": "󰢻  Opciones",
  "nav.back": "󰅁  Volver",
  "nav.skip": "Saltar  󰅂",
  "nav.options.a11y": "Abrir opciones",
  "nav.back.a11y": "Volver al portapapeles",
  "nav.skip.a11y": "Saltar los ajustes e ir al panel",

  "state.active": "Activo",
  "state.paused": "Pausado",
  "state.starting": "Iniciando",
  "state.attention": "Necesita atención",
  "state.a11y": "OmaPlain, %1. %2",

  "status.unavailable": "El servicio todavía no está disponible.",
  "status.deps": "Faltan dependencias: %1",
  "status.degraded": "El watcher ha fallado varias veces. Las acciones manuales siguen disponibles.",
  "status.restarting": "Reiniciando el watcher…",
  "status.paused": "La limpieza automática está pausada. Las acciones manuales siguen disponibles.",
  "status.willskip": "Se omitirá la próxima copia elegible.",
  "status.done": "Listo · última limpieza completada",
  "status.idle": "OmaPlain ordena el formato y deja intacto todo lo que no puede limpiar con seguridad.",
  "hint.manual": "La limpieza manual y «pegar limpio» siguen disponibles.",
  "hint.chars": "La copia automática conserva los caracteres del texto.",
  "fb.cleaned": "Portapapeles limpio",
  "fb.unchanged": "Ya estaba limpio",
  "fb.image": "No se ha modificado: es una imagen",
  "fb.files": "No se ha modificado: contiene archivos",
  "fb.sensitive": "Contenido sensible protegido",
  "fb.large": "No se ha modificado: supera 1 MB",
  "fb.excluded": "No se ha modificado: aplicación excluida",
  "fb.bypassed": "No se ha modificado: contenido no compatible",
  "fb.skip": "Se omitirá la próxima copia",
  "fb.error": "No se pudo limpiar. El texto original sigue intacto.",

  "verdict.cleanable": "Esto se puede limpiar",
  "verdict.clean": "Ya está limpio",
  "verdict.nothing": "Nada que limpiar aquí",
  "verdict.sensitive": "Marcado como sensible",
  "verdict.image": "Una imagen no se toca",
  "verdict.files": "Archivos, intactos",
  "verdict.structured": "Formato estructurado, intacto",
  "verdict.empty": "Nada copiado todavía",
  "verdict.preparing": "Preparando…",

  "detail.cleanable": "Así está ahora y así quedaría.",
  "detail.clean": "OmaPlain lo ha mirado y no hay nada que retirar.",
  "detail.nothing": "OmaPlain lo ha mirado y lo deja como está.",
  "detail.sensitive": "Tu gestor de contraseñas marcó esta copia. OmaPlain no la lee, no la muestra y no la reescribe.",
  "detail.image": "OmaPlain ni la lee. Las capturas llegan a su destino byte a byte.",
  "detail.files": "Copiar archivos mueve rutas y permisos. Reescribir eso rompería el pegado.",
  "detail.empty": "Copia algo y aquí verás qué haría OmaPlain con ello.",

  "row.now": "Ahora",
  "row.would": "Quedaría",
  "row.single": "En el portapapeles",
  "row.show": "Mostrar %1",
  "row.hide": "Ocultar %1",
  "row.covered.a11y": "Contenido cubierto. Arrástralo para limpiarlo, o usa el botón del ojo.",
  "fog.hint": "Arrastra para limpiar",

  "rule.tracking": "Parámetros de seguimiento",
  "rule.invisible": "Caracteres invisibles",
  "rule.line_endings": "Finales de línea CRLF",
  "rule.rich_text": "Formato enriquecido",
  "rule.removed.a11y": "Se retira: %1, según el ajuste %2",
  "setting.tracking": "Seguimiento",
  "setting.invisible": "Invisibles",
  "setting.line_endings": "Saltos",
  "setting.rich_text": "Formato",

  "action.apply": "Aplicar al portapapeles",
  "action.applying": "Limpiando…",
  "action.skip": "Omitir la próxima copia",
  "action.skipped": "Próxima copia omitida",
  "footnote.safe": "El original permanece intacto si la limpieza no es segura.",
  "footnote.sensitive": "Revelar no está disponible para contenido marcado como sensible.",
  "footnote.nothing": "No hay nada que limpiar, así que no hay acción que ofrecer.",

  "settings.language": "Idioma",
  "settings.language.auto": "Del sistema",
  "settings.language.en": "Inglés",
  "settings.language.es": "Español",
  "settings.mode": "Modo",
  "settings.cleaning": "Limpieza",
  "settings.optional": "Opcionales",
  "settings.automatic": "Limpiar automáticamente",
  "settings.automatic.desc": "Convierte en texto limpio cada copia que sea segura.",
  "settings.history": "El historial puede conservar también el original cuando cambian caracteres.",
  "settings.formatting": "Retirar formato",
  "settings.formatting.desc": "Pega usando solo la representación de texto plano.",
  "settings.tracking": "Retirar parámetros de seguimiento",
  "settings.tracking.desc": "Solo actúa cuando todo el contenido es una URL segura.",
  "settings.invisible": "Retirar invisibles no semánticos",
  "settings.invisible.desc": "Conserva emoji, escritura RTL y marcas de idioma.",
  "settings.endings": "Normalizar finales de línea",
  "settings.endings.desc": "Convierte CRLF y CR en LF sin quitar el salto final.",
  "settings.quotes": "Normalizar comillas",
  "settings.quotes.desc": "Convierte comillas tipográficas en comillas rectas.",
  "settings.bullets": "Normalizar viñetas",
  "settings.bullets.desc": "Convierte viñetas al inicio de línea en guiones.",
  "settings.nfc": "Normalizar Unicode NFC",
  "settings.nfc.desc": "Puede cambiar la representación exacta del texto.",
  "settings.trim": "Recortar espacios finales",
  "settings.trim.desc": "Quita el espacio al final de cada línea.",

  "excl.title": "Aplicaciones excluidas",
  "excl.detected": "Excluir la aplicación detectada",
  "excl.detect": "Excluir %1 del modo automático",
  "excl.none.title": "Ninguna aplicación excluida",
  "excl.none.body": "OmaPlain limpia el texto que copies en cualquier aplicación. Excluye una como origen para que lo que copies en ella pase intacto, o como destino para no pegar limpio dentro de ella.",
  "excl.class": "Clase de aplicación",
  "excl.addSource": "Añadir como origen",
  "excl.addTarget": "Añadir como destino",
  "excl.case": "Distingue entre mayúsculas y minúsculas.",
  "excl.source": "Origen · modo automático",
  "excl.target": "Destino · pegar limpio",
  "excl.remove": "Quitar",
  "excl.remove.a11y": "Quitar %1",
  "excl.undetected": "No se ha detectado una aplicación",

  "help.title": "Ayuda y aprendizaje",
  "help.body": "Vuelve a la explicación inicial o repite el recorrido sin cambiar tu configuración.",
  "help.welcome": "Revisar bienvenida",
  "help.welcome.a11y": "Abre de nuevo la explicación de OmaPlain",
  "help.tour": "Repetir mini tour",
  "help.tour.a11y": "Inicia de nuevo el recorrido de tres pasos",
  "privacy.title": "Privacidad",
  "privacy.body": "Todo ocurre en este equipo. OmaPlain no guarda el texto copiado. El historial pertenece a Omarchy.",

  "welcome.eyebrow.first": "Primera visita",
  "welcome.eyebrow.return": "Guía de OmaPlain",
  "welcome.title": "Texto limpio,\nsin sorpresas.",
  "welcome.body": "OmaPlain convierte copias elegibles en texto plano y conserva intacto todo lo que no puede limpiar con seguridad.",
  "welcome.card1.title": "Limpia lo que sobra",
  "welcome.card1.body": "Formato, tracking e invisibles no semánticos.",
  "welcome.card2.title": "Protege lo importante",
  "welcome.card2.body": "Imágenes, archivos y secretos pasan intactos.",
  "welcome.card3.title": "Todo queda en casa",
  "welcome.card3.body": "Sin nube, telemetría ni historial propio.",
  "welcome.start": "Ver cómo funciona",
  "welcome.enter": "Ir al panel",
  "welcome.return": "Volver a ajustes",
  "welcome.again": "Podrás volver a esta guía desde ajustes.",

  "tour.eyebrow": "Cómo funciona",
  "tour.eyebrow.replay": "Repaso rápido",
  "tour.step": "%1 de %2",
  "tour.step.a11y": "Paso %1 de %2. %3",
  "tour.1.title": "Copia como siempre",
  "tour.1.body": "OmaPlain observa las nuevas copias de texto y las limpia automáticamente cuando es seguro. No necesitas cambiar de atajo.",
  "tour.1.note": "Imágenes y archivos pasan intactos.",
  "tour.2.title": "Limpia sólo lo que sobra",
  "tour.2.body": "Retira formato enriquecido, parámetros de seguimiento de URLs completas y caracteres invisibles no semánticos.",
  "tour.2.note": "Ante una duda, conserva el original.",
  "tour.3.title": "Tú mantienes el control",
  "tour.3.body": "Limpia manualmente, omite la próxima copia o excluye una aplicación. El historial sigue siendo el de Omarchy.",
  "tour.3.note": "Todo ocurre en este equipo.",
  "tour.back": "Volver",
  "tour.back.first.a11y": "Volver a la pantalla anterior",
  "tour.back.a11y": "Volver al paso anterior",
  "tour.next": "Siguiente",
  "tour.finish": "Abrir OmaPlain",
  "tour.skip": "Saltar el tour",
  "tour.leave": "Salir del repaso",

  "demo.label": "Demostración · texto de ejemplo, nunca tu portapapeles",
  "demo.try": "Probar con un ejemplo",
  "demo.original": "Ver el original",
  "demo.other": "Otro ejemplo",
  "demo.other.a11y": "Otro ejemplo de demostración",

  "onboarding.last": "Último paso",
  "onboarding.last.body": "Esto es lo que puedes ajustar. Ya viene todo configurado de forma segura, así que puedes dejarlo tal cual.",
  "onboarding.done": "Abrir OmaPlain",

  "state.preparing": "Preparando el servicio…",
  "art.skip": "Omitir una copia",
  "art.exclude": "Excluir aplicaciones",
  "settings.trim2": "Retirar espacios al final de línea",
  "art.copied": "Copiado",
  "art.clean": "Limpio"
};

// El inglés es el catálogo de referencia: si una clave falta en español se
// devuelve la inglesa, que es preferible a un hueco en la interfaz.
function t(key, lang) {
  var table = lang === "es" ? ES : EN;
  var value = table[key];
  if (value === undefined) value = EN[key];
  return value === undefined ? key : value;
}

// Sustituye %1, %2… por los argumentos, en el orden en que vengan.
function f(key, lang, a, b, c) {
  var out = t(key, lang);
  var args = [a, b, c];
  for (var i = 0; i < args.length; i++) {
    if (args[i] === undefined) continue;
    out = out.replace("%" + (i + 1), String(args[i]));
  }
  return out;
}

// Del locale del sistema. Sólo se distinguen dos familias: cualquier
// variante de español va a español, y todo lo demás al inglés.
function fromLocale(name) {
  return String(name || "").toLowerCase().indexOf("es") === 0 ? "es" : "en";
}

function languages() { return ["en", "es"]; }
function keys() { var out = []; for (var k in EN) out.push(k); return out; }
