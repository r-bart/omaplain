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
  "status.deps": "OmaPlain needs %1. Install it and open this panel again.",
  "status.degraded": "OmaPlain stopped watching the clipboard. Cleaning by hand still works.",
  "status.restarting": "Watching the clipboard again…",
  "status.paused": "Automatic cleaning is paused. Manual actions are still available.",
  "status.willskip": "The next eligible copy will be skipped.",
  "status.done": "Ready · last clean completed",
  "status.idle": "OmaPlain tidies the formatting and leaves intact everything it cannot clean safely.",
  "hint.manual": "Manual cleaning and «paste clean» are still available.",
  "hint.chars": "No active rule changes characters, so the history keeps one version.",
  "fb.cleaned": "Clipboard cleaned",
  "fb.unchanged": "It was already clean",
  "fb.image": "Images are left alone",
  "fb.files": "Files are left alone",
  "fb.sensitive": "Sensitive content protected",
  "fb.large": "Over 1 MB, left alone",
  "fb.excluded": "That application is excluded",
  "fb.bypassed": "Not text, so it is left alone",
  "fb.skip": "The next copy will be skipped",
  "fb.error": "Could not clean it. Your original is intact — try again.",

  // --- Veredictos sobre el portapapeles ---
  "verdict.cleanable": "This can be cleaned",
  "verdict.clean": "Already clean",
  "verdict.nothing": "Nothing to clean here",
  "verdict.sensitive": "Marked as sensitive",
  "verdict.image": "An image is left alone",
  "verdict.files": "Files, untouched",
  "verdict.structured": "Structured format, untouched",
  "verdict.empty": "Waiting for your next copy",
  "verdict.preparing": "Getting ready…",

  "detail.cleanable": "This is how it stands and how it would end up.",
  "detail.clean": "OmaPlain has looked at it and there is nothing to remove.",
  "detail.nothing": "OmaPlain has looked at it and leaves it as it is.",
  "detail.sensitive": "Your password manager marked this copy. OmaPlain does not read it, does not show it and does not rewrite it.",
  "detail.image": "OmaPlain does not even read it. Screenshots reach their destination byte for byte.",
  "detail.files": "Copying files moves paths and permissions. Rewriting that would break the paste.",
  "detail.empty": "Copy anything and this screen shows what OmaPlain would do with it — before it does it.",

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
  "rule.line_endings": "Windows line endings",
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
  "settings.history": "Omarchy's history may keep the original as well when characters change.",
  "settings.formatting": "Remove rich formatting",
  "settings.formatting.desc": "Pastes using only the plain-text representation.",
  "settings.tracking": "Remove link tracking",
  "settings.tracking.desc": "Only when the clipboard is one whole link. Signed links are left alone.",
  "settings.invisible": "Remove invisible characters",
  "settings.invisible.desc": "Keeps emoji, right-to-left writing and language marks.",
  "settings.endings": "Normalise line endings",
  "settings.endings.desc": "Turns CRLF and CR into LF without dropping the final break.",
  "settings.quotes": "Normalise quotes",
  "settings.quotes.desc": "Turns typographic quotes into straight ones.",
  "settings.bullets": "Normalise bullets",
  "settings.bullets.desc": "Turns leading bullets into hyphens.",
  "settings.nfc": "Normalise Unicode NFC",
  "settings.nfc.desc": "May change the exact representation of the text.",
  "settings.trim.desc": "Leaves indentation and line breaks alone.",

  // --- Exclusiones ---
  "excl.title": "Excluded applications",
  "excl.detected": "Dejar de limpiar lo que copie esta app",
  "excl.detect": "Dejar de limpiar lo que copie %1",
  "excl.none.title": "No application excluded",
  "excl.none.body": "OmaPlain cleans the text you copy in any application. Exclude one as a source so what you copy there passes untouched, or as a target so nothing is pasted clean into it.",
  "excl.class": "Application class",
  "excl.addSource": "Don't clean its copies",
  "excl.addTarget": "Don't paste clean here",
  "excl.case": "Capital letters matter.",
  "excl.source": "Its copies are not cleaned",
  "excl.target": "Nothing is pasted clean into it",
  "excl.remove": "Remove",
  "excl.remove.a11y": "Remove %1",
  "excl.undetected": "No application detected. Type its class below.",

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
  "welcome.card1.title": "Removes what you don't need",
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
  "tour.2.title": "Only what you don't need",
  "tour.2.body": "It removes rich formatting, tracking parameters from whole URLs and non-semantic invisible characters.",
  "tour.2.note": "When in doubt, it keeps the original.",
  "tour.3.title": "You keep control",
  "tour.3.body": "Clean by hand, skip the next copy or exclude an application. The history is still Omarchy's.",
  "tour.3.note": "Everything happens on this machine.",
  "tour.back": "Back",
  "tour.back.first.a11y": "Back to the previous screen",
  "tour.back.a11y": "Back to the previous step",
  "tour.next": "Next",
  "tour.finish": "Ver los ajustes",
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
  "onboarding.done": "Start using it",

  // --- Ilustración ---
  "state.preparing": "Getting the service ready…",
  "art.skip": "Skip a copy",
  "art.exclude": "Exclude apps",
  "settings.trim": "Trim end-of-line spaces",
  "excl.class.hint": "The exact Hyprland class to exclude.",
  "art.automatic": "Automatic",
  "demo.outcome1": "Three tracking parameters gone, and an invisible character you could not see. The page, the servings and the spot it points to are still there.",
  "demo.outcome2": "No change: this link is signed, and trimming it would break it. When in doubt, OmaPlain would rather touch nothing.",
  "err.busy": "OmaPlain is already working on another action",
  "err.duplicate": "That application is already excluded",
  "err.invalidClass": "Type a valid application class, like org.example.App",
  "art.images": "Images",
  "art.files": "Files",
  "art.secrets": "Secrets",
  "art.notWatching": "Not watching",
  "chips.a11y": "It offered %1. It would leave %2.",
  "chips.plain.a11y": "The clipboard offers %1.",
  "notify.title": "OmaPlain stopped cleaning",
  "notify.body": "Open the panel to check the service. What you copied is intact.",
  "empty.how": "See how it works",
  "empty.how.a11y": "Opens the three-step walkthrough",
  "empty.kind.link": "A link from a newsletter",
  "empty.kind.text": "A paragraph copied from a page",
  "empty.kind.rich": "Text with formatting from an editor",
  "empty.art.a11y": "Examples of what you can copy, with what OmaPlain would remove marked in the accent colour.",
  // Los tres ejemplos del carrusel, partidos en lo que se queda, lo que
  // sobra y el resto. `tests/unit/test_empty_samples.py` pasa cada uno por
  // el motor en los dos idiomas: si una regla cambia, la pantalla no puede
  // seguir prometiendo una limpieza que ya no ocurre.
  "empty.sample.link.head": "example.com/offer?",
  "empty.sample.link.spare": "utm_source=newsletter&",
  "empty.sample.link.tail": "size=42",
  "empty.sample.text.head": "Sourdough bread",
  "empty.sample.text.spare": "·ZWSP·",
  "empty.sample.text.tail": " needs 12 hours.",
  "empty.sample.rich.head": "Executive summary",
  "empty.sample.rich.spare": ", in bold and in colour",
  "empty.sample.rich.tail": ".",
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
  "status.deps": "OmaPlain necesita %1. Instálalo y vuelve a abrir este panel.",
  "status.degraded": "OmaPlain ha dejado de vigilar el portapapeles. Limpiar a mano sigue funcionando.",
  "status.restarting": "Volviendo a vigilar el portapapeles…",
  "status.paused": "La limpieza automática está pausada. Las acciones manuales siguen disponibles.",
  "status.willskip": "Se omitirá la próxima copia elegible.",
  "status.done": "Listo · última limpieza completada",
  "status.idle": "OmaPlain ordena el formato y deja intacto todo lo que no puede limpiar con seguridad.",
  "hint.manual": "La limpieza manual y «pegar limpio» siguen disponibles.",
  "hint.chars": "Ninguna regla activa cambia caracteres, así que el historial guarda una sola versión.",
  "fb.cleaned": "Portapapeles limpio",
  "fb.unchanged": "Ya estaba limpio",
  "fb.image": "Las imágenes no se tocan",
  "fb.files": "Los archivos no se tocan",
  "fb.sensitive": "Contenido sensible protegido",
  "fb.large": "Supera 1 MB, se deja igual",
  "fb.excluded": "Esa aplicación está excluida",
  "fb.bypassed": "No es texto, así que se deja igual",
  "fb.skip": "Se omitirá la próxima copia",
  "fb.error": "No se pudo limpiar. Tu original está intacto; inténtalo otra vez.",

  "verdict.cleanable": "Esto se puede limpiar",
  "verdict.clean": "Ya está limpio",
  "verdict.nothing": "Nada que limpiar aquí",
  "verdict.sensitive": "Marcado como sensible",
  "verdict.image": "Una imagen no se toca",
  "verdict.files": "Archivos, intactos",
  "verdict.structured": "Formato estructurado, intacto",
  "verdict.empty": "Esperando tu próxima copia",
  "verdict.preparing": "Preparando…",

  "detail.cleanable": "Así está ahora y así quedaría.",
  "detail.clean": "OmaPlain lo ha mirado y no hay nada que retirar.",
  "detail.nothing": "OmaPlain lo ha mirado y lo deja como está.",
  "detail.sensitive": "Tu gestor de contraseñas marcó esta copia. OmaPlain no la lee, no la muestra y no la reescribe.",
  "detail.image": "OmaPlain ni la lee. Las capturas llegan a su destino byte a byte.",
  "detail.files": "Copiar archivos mueve rutas y permisos. Reescribir eso rompería el pegado.",
  "detail.empty": "Copia cualquier cosa y esta pantalla te enseñará qué haría OmaPlain con ello, antes de hacerlo.",

  "row.now": "Ahora",
  "row.would": "Quedaría",
  "row.single": "En el portapapeles",
  "row.show": "Mostrar %1",
  "row.hide": "Ocultar %1",
  "row.covered.a11y": "Contenido cubierto. Arrástralo para limpiarlo, o usa el botón del ojo.",
  "fog.hint": "Arrastra para limpiar",

  "rule.tracking": "Parámetros de seguimiento",
  "rule.invisible": "Caracteres invisibles",
  "rule.line_endings": "Finales de línea de Windows",
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
  "settings.history": "El historial de Omarchy puede conservar también el original cuando cambian caracteres.",
  "settings.formatting": "Retirar formato enriquecido",
  "settings.formatting.desc": "Pega usando solo la representación de texto plano.",
  "settings.tracking": "Retirar seguimiento de enlaces",
  "settings.tracking.desc": "Sólo cuando el portapapeles es un enlace entero. Los enlaces firmados no se tocan.",
  "settings.invisible": "Retirar caracteres invisibles",
  "settings.invisible.desc": "Conserva emoji, escritura de derecha a izquierda y marcas de idioma.",
  "settings.endings": "Normalizar finales de línea",
  "settings.endings.desc": "Convierte CRLF y CR en LF sin quitar el salto final.",
  "settings.quotes": "Normalizar comillas",
  "settings.quotes.desc": "Convierte comillas tipográficas en comillas rectas.",
  "settings.bullets": "Normalizar viñetas",
  "settings.bullets.desc": "Convierte viñetas al inicio de línea en guiones.",
  "settings.nfc": "Normalizar Unicode NFC",
  "settings.nfc.desc": "Puede cambiar la representación exacta del texto.",
  "settings.trim.desc": "No modifica la indentación ni los saltos.",

  "excl.title": "Aplicaciones excluidas",
  "excl.detected": "Excluir la aplicación detectada",
  "excl.detect": "Excluir %1 del modo automático",
  "excl.none.title": "Ninguna aplicación excluida",
  "excl.none.body": "OmaPlain limpia el texto que copies en cualquier aplicación. Excluye una como origen para que lo que copies en ella pase intacto, o como destino para no pegar limpio dentro de ella.",
  "excl.class": "Clase de aplicación",
  "excl.addSource": "No limpiar lo que copie",
  "excl.addTarget": "No pegar limpio ahí",
  "excl.case": "Las mayúsculas cuentan.",
  "excl.source": "Sus copias no se limpian",
  "excl.target": "No se pega limpio dentro",
  "excl.remove": "Quitar",
  "excl.remove.a11y": "Quitar %1",
  "excl.undetected": "No se ha detectado ninguna aplicación. Escribe su clase abajo.",

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
  "tour.2.title": "Sólo lo que sobra",
  "tour.2.body": "Retira formato enriquecido, parámetros de seguimiento de URLs completas y caracteres invisibles no semánticos.",
  "tour.2.note": "Ante una duda, conserva el original.",
  "tour.3.title": "Tú mantienes el control",
  "tour.3.body": "Limpia manualmente, omite la próxima copia o excluye una aplicación. El historial sigue siendo el de Omarchy.",
  "tour.3.note": "Todo ocurre en este equipo.",
  "tour.back": "Volver",
  "tour.back.first.a11y": "Volver a la pantalla anterior",
  "tour.back.a11y": "Volver al paso anterior",
  "tour.next": "Siguiente",
  "tour.finish": "Empezar a usarlo",
  "tour.skip": "Saltar el tour",
  "tour.leave": "Salir del repaso",

  "demo.label": "Demostración · texto de ejemplo, nunca tu portapapeles",
  "demo.try": "Probar con un ejemplo",
  "demo.original": "Ver el original",
  "demo.other": "Otro ejemplo",
  "demo.other.a11y": "Otro ejemplo de demostración",

  "onboarding.last": "Último paso",
  "onboarding.last.body": "Esto es lo que puedes ajustar. Ya viene todo configurado de forma segura, así que puedes dejarlo tal cual.",
  "onboarding.done": "Empezar a usarlo",

  "state.preparing": "Preparando el servicio…",
  "art.skip": "Omitir una copia",
  "art.exclude": "Excluir aplicaciones",
  "settings.trim": "Retirar espacios al final de línea",
  "excl.class.hint": "Clase exacta de Hyprland que se excluirá.",
  "art.automatic": "Automático",
  "demo.outcome1": "Fuera tres parámetros de seguimiento y un carácter invisible que no se veía. La página, las porciones y el punto al que apunta siguen ahí.",
  "demo.outcome2": "Sin cambios: este enlace va firmado y recortarlo lo rompería. Ante la duda, OmaPlain prefiere no tocar nada.",
  "err.busy": "OmaPlain ya está procesando otra acción",
  "err.duplicate": "Esta aplicación ya está excluida",
  "err.invalidClass": "Escribe una clase de aplicación válida, como org.example.App",
  "art.images": "Imágenes",
  "art.files": "Archivos",
  "art.secrets": "Secretos",
  "art.notWatching": "Sin vigilar",
  "chips.a11y": "Ofrecía %1. Quedaría %2.",
  "chips.plain.a11y": "El portapapeles ofrece %1.",
  "notify.title": "OmaPlain ha dejado de limpiar",
  "notify.body": "Abre el panel para revisar el servicio. Lo que copiaste está intacto.",
  "empty.how": "Ver cómo funciona",
  "empty.how.a11y": "Abre el recorrido de tres pasos",
  "empty.kind.link": "Un enlace de un boletín",
  "empty.kind.text": "Un párrafo copiado de una web",
  "empty.kind.rich": "Texto con formato de un editor",
  "empty.art.a11y": "Ejemplos de lo que puedes copiar, con lo que OmaPlain retiraría marcado en color de acento.",
  // Ver la nota de la tabla inglesa: estos tres se comprueban contra el
  // motor, y el del enlace tiene que perder exactamente su `utm_`.
  "empty.sample.link.head": "example.com/oferta?",
  "empty.sample.link.spare": "utm_source=boletin&",
  "empty.sample.link.tail": "talla=42",
  "empty.sample.text.head": "El pan de masa madre",
  "empty.sample.text.spare": "·ZWSP·",
  "empty.sample.text.tail": " necesita 12 horas.",
  "empty.sample.rich.head": "Resumen ejecutivo",
  "empty.sample.rich.spare": ", en negrita y con color",
  "empty.sample.rich.tail": ".",
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
