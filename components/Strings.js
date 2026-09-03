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
  "bar.a11y": "Open OmaPlain",
  "nav.options": "Options",
  "nav.back": "Back",
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
  "state.a11y.short": "OmaPlain, %1",

  // --- Estado del servicio y avisos ---
  "status.unavailable": "The service is not available yet.",
  "status.deps": "OmaPlain needs %1. Install it and open this panel again.",
  "status.degraded": "OmaPlain stopped watching the clipboard. Cleaning by hand still works.",
  "status.restarting": "Watching the clipboard again…",
  "status.paused": "Automatic cleaning is paused. Manual actions are still available.",
  "status.done": "Ready · last clean completed",
  "hint.manual": "Manual cleaning and Paste clean are still available.",
  "hint.chars": "No active rule changes characters, so the history keeps one version.",
  "fb.cleaned": "Clipboard cleaned",
  "fb.unchanged": "It was already clean",
  "fb.image": "Images are left alone",
  "fb.files": "Files are left alone",
  "fb.sensitive": "Sensitive content protected",
  "fb.large": "Over 1 MB, left alone",
  "fb.excluded": "That application has a rule of its own",
  "fb.bypassed": "Not text, so it is left alone",
  "fb.error": "Could not clean it. Your original is intact — try again.",

  // --- Veredictos sobre el portapapeles ---
  "verdict.cleanable": "This can be cleaned",
  "verdict.clean": "Already clean",
  "verdict.nothing": "Nothing to clean here",
  "verdict.sensitive": "A secret on your clipboard",
  "verdict.image": "An image on your clipboard",
  "verdict.files": "Files on your clipboard",
  "verdict.structured": "Structured data on your clipboard",
  "verdict.empty": "Waiting for your next copy",
  "verdict.preparing": "Getting ready…",
  // Una negativa por cada motivo por el que el helper se planta. Sin ellas
  // todas caían en «Nothing to clean here», que de un portapapeles de 1,4 MB
  // o de una app bloqueada es sencillamente falso.
  "verdict.large": "More than 1 MB on your clipboard",
  "verdict.blocked": "Never read, by your rule",
  "verdict.unreadable": "Not text OmaPlain can read",
  "verdict.failed": "The clipboard could not be read",
  "verdict.richOnly": "Formatting with no plain text",
  "verdict.noText": "No text to clean",
  "verdict.declined": "Left as it is",

  "detail.cleanable": "This is how it stands and how it would end up.",
  "detail.clean": "OmaPlain has looked at it and there is nothing to remove.",
  // Sin sujeto que mienta: esta frase es el último recurso, y se usa cuando
  // el motivo de la negativa no se conoce. Antes decía «has looked at it»,
  // que era justo lo contrario de lo que pasa con una app bloqueada.
  "detail.nothing": "OmaPlain leaves it as it is.",
  "detail.sensitive": "Your password manager marked this copy. OmaPlain does not read it, does not show it and does not rewrite it.",
  "detail.image": "OmaPlain does not read images. This one reaches its destination byte for byte.",
  "detail.files": "A file copy carries paths and permissions, not text. Rewriting it would break the paste.",
  "detail.empty": "Copy anything and this screen shows what OmaPlain would do with it — before it does it.",
  "detail.structured": "Rewriting a structured format would break what it means, so OmaPlain leaves it whole.",
  "detail.large": "OmaPlain stops before reading a copy this size, so it does not touch it either.",
  "detail.blocked": "OmaPlain did not look at this copy, so it cannot say what is inside.",
  "detail.unreadable": "OmaPlain cannot decode these bytes as text, and rewriting them blindly would risk breaking them.",
  "detail.richOnly": "This copy only offers a formatted version. There is no plain text to keep, so OmaPlain leaves it whole.",
  "detail.noText": "OmaPlain only rewrites plain text, and this copy does not offer any.",
  "detail.declined": "Cleaning this one would change more than it should, so OmaPlain steps back.",
  "detail.failed": "OmaPlain could not read the clipboard this time, so it changed nothing.",

  // --- Filas ---
  "row.now": "Now",
  "row.would": "Would be",
  "row.single": "On the clipboard",
  // El rótulo de la fila es una cabecera de columna —«Now», «Would be»—, y
  // metido en «Show %1» salía «Show Now». El nombre para la frase va aparte,
  // en minúscula y como sintagma nominal.
  "row.name.single": "what is on the clipboard",
  "row.name.now": "the current text",
  "row.name.would": "the result",
  "row.show": "Show %1",
  "row.hide": "Hide %1",
  "row.covered.a11y": "Content covered. Drag across it to clear it, or use the eye button.",
  "row.covered.locked.a11y": "Content covered, and it stays that way: it came from an app on your never-uncover list.",
  "fog.hint": "Drag to clear",

  // --- Reglas y ajustes que las gobiernan ---
  "rule.tracking": "Tracking parameters",
  "rule.invisible": "Invisible characters",
  "rule.line_endings": "Windows line endings",
  "rule.rich_text": "Rich formatting",
  "rule.quotes": "Curly quotes",
  "rule.lists": "List bullets",
  "rule.unicode_nfc": "Unicode composition",
  "rule.trailing_whitespace": "Spaces at the end of lines",
  "rule.encoding": "Non-UTF-8 encoding",
  "rule.removed.a11y": "Removed: %1, under the %2 setting",
  "setting.tracking": "Tracking",
  "setting.invisible": "Invisibles",
  "setting.line_endings": "Line endings",
  "setting.rich_text": "Formatting",
  "setting.quotes": "Quotes",
  "setting.lists": "Bullets",
  "setting.unicode_nfc": "NFC",
  "setting.trailing_whitespace": "End-of-line spaces",

  // --- Acciones ---
  "action.apply": "Apply to the clipboard",
  "action.applying": "Cleaning…",
  "footnote.safe": "The original stays intact if cleaning is not safe.",
  "footnote.sensitive": "Revealing is not available for content marked as sensitive.",

  // --- Ajustes ---
  "settings.language": "Language",
  "settings.language.auto": "System",
  "settings.language.en": "English",
  "settings.language.es": "Spanish",
  "settings.motionSection": "Motion",
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
  "settings.nfc.desc": "Combines accents into single characters. The text reads the same and its bytes change.",
  "settings.trim.desc": "Leaves indentation and line breaks alone.",


  // --- Ayuda ---
  "help.title": "Help and learning",
  "help.body": "Go back to the first explanation or repeat the walkthrough without changing your settings.",
  "help.welcome": "Review the welcome",
  "help.welcome.a11y": "Opens the OmaPlain explanation again",
  "help.tour": "Repeat the mini tour",
  "help.tour.a11y": "Starts the three-step walkthrough again",

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
  "tour.3.body": "Clean by hand, turn the automatic mode off, or give an application its own rules. The history is still Omarchy's.",
  "tour.3.note": "Everything happens on this machine.",
  "tour.back": "Back",
  "tour.back.first.a11y": "Back to the previous screen",
  "tour.back.a11y": "Back to the previous step",
  "tour.next": "Next",
  "tour.finish": "See the settings",
  "tour.done": "Finish",
  "tour.skip": "Skip the tour",
  "tour.leave": "Leave the recap",

  // --- Demostración del tour ---
  "demo.label": "Demonstration · sample text, never your clipboard",
  "demo.try": "Try it with an example",
  "demo.original": "See the original",
  "demo.replay": "Play it again",
  "demo.a11y.before": "Original example: %1",
  "demo.a11y.after": "Result: %1",

  // --- Último paso del recorrido ---
  "onboarding.last": "Last step",
  "onboarding.last.body": "This is what you can adjust. It already comes safely configured, so you can leave it as it is.",
  "onboarding.done": "Start using it",

  // --- Ilustración ---
  "state.preparing": "Getting the service ready…",
  "art.cleaning": "Cleaning rules",
  "art.exclude": "App rules",
  "settings.trim": "Trim end-of-line spaces",
  "art.automatic": "Automatic",
  // Las dos muestras del tour. Estaban escritas en el QML, en español, así
  // que en inglés la pantalla enseñaba una interfaz traducida con ejemplos
  // sin traducir —y la frase de resultado hablaba de «the servings»
  // señalando un `porciones=8`. El dominio es el reservado por la RFC 2606:
  // un ejemplo con seguimiento no se le cuelga a un negocio real.
  //
  // El original de la primera lleva un ZWSP al final, que es el carácter
  // invisible que la demo promete retirar.
  // El invisible va dentro del tramo que se retira, no colgando al final.
  // Así el trozo que desaparece es uno solo y continuo, que es lo que la
  // animación puede enseñar encogiéndose; el motor da el mismo resultado
  // en los dos sitios, y `test_demo_sample.py` lo comprueba.
  "demo.sample1.original": "https://example.com/sourdough-bread?utm_source=newsletter&utm_medium=email&fbclid=IwAR9x&​servings=8#baking",
  "demo.sample1.head": "https://example.com/sourdough-bread?",
  "demo.sample1.spare": "utm_source=newsletter&utm_medium=email&fbclid=IwAR9x&​",
  "demo.sample1.tail": "servings=8#baking",
  "demo.sample1.cleaned": "https://example.com/sourdough-bread?servings=8#baking",
  "demo.sample2.original": "https://example.com/invoice.pdf?expires=1735689600&signature=ab12cd34",
  "demo.sample2.cleaned": "https://example.com/invoice.pdf?expires=1735689600&signature=ab12cd34",
  "demo.outcome1": "Three tracking parameters gone, and an invisible character you could not see. The page, the servings and the spot it points to are still there.",
  "demo.outcome2": "No change: this link is signed, and trimming it would break it. When in doubt, OmaPlain would rather touch nothing.",
  "err.busy": "OmaPlain is already working on another action",
  "art.untouched": "Untouched",
  "art.decide": "You decide",
  "art.byteForByte": "Byte for byte, exactly as you copied it.",
  "art.images": "Images",
  "art.files": "Files",
  "art.secrets": "Secrets",
  "chips.a11y": "It offered %1. It would leave %2.",
  "chips.plain.a11y": "The clipboard offers %1.",
  "notify.title": "OmaPlain stopped cleaning",
  "notify.body": "Open the panel to check the service. What you copied is intact.",
  "history.why": "Why can the original still show up?",
  "history.why.body": "Cleaning replaces what is on the clipboard, but Omarchy's own history keeps every entry it saw. If a rule changed characters, the history may hold both versions until you clear it.",
  "privacy.blockedState": "That app is on your never-read list, so there is nothing here.",
  "row.locked": "This stays covered: it came from an app on your never-uncover list.",
  "settings.motion": "Reduce motion",
  "settings.motion.desc": "Stops the animations, including the examples that cycle on the empty screen.",
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
  "empty.sample.text.spare": "·invisible·",
  "empty.sample.text.tail": " needs 12 hours.",
  "empty.sample.rich.head": "Executive summary",
  "empty.sample.rich.spare": ", in bold and in colour",
  "empty.sample.rich.tail": ".",
  "art.copied": "Copied",
  "art.clean": "Clean",

  // --- Aplicaciones ---
  // Una sola sección, un solo formulario. Antes eran dos, con dos rótulos
  // que se diferenciaban en una palabra ([`0011`]).
  "apps.title": "Applications",
  "apps.body": "Some applications deserve different treatment. Pick one and choose which of the four rules apply to it.",
  "settings.privacy": "Everything happens on this machine. OmaPlain makes no network requests and stores none of the text you copy. The history belongs to Omarchy.",
  "apps.note": "OmaPlain recognises the window you copied from whenever Wayland lets it. It is a good filter, not a guarantee.",
  "apps.open": "Windows open right now",
  "apps.open.none": "No windows open to pick from right now. Type the class instead.",
  "apps.open.a11y": "Add %1 to the list below",
  "apps.class": "Or type its class",
  "apps.class.hint": "The exact Hyprland class. Capital letters matter.",
  "apps.add": "Add",
  "apps.duplicate": "That application already has a card below.",
  "apps.invalid": "That is not a valid application class.",
  "apps.none.title": "No application has rules of its own",
  "apps.none.body": "OmaPlain treats every application the same. Add one here to change what it reads, or what it cleans.",
  "apps.pending": "No rule yet. Nothing is saved until you set one.",
  "apps.remove": "Remove",
  "apps.remove.a11y": "Remove %1 and every rule it has",
  "rules.reading": "When reading",
  "rules.cleaning": "When cleaning",
  "rules.covered": "Never uncover",
  "rules.blocked": "Never read",
  "rules.source": "Don't clean its copies",
  "rules.target": "Don't paste clean here",

};

var ES = {
  "bar.a11y": "Abrir OmaPlain",
  "nav.options": "Opciones",
  "nav.back": "Volver",
  "nav.skip": "Saltar  󰅂",
  "nav.options.a11y": "Abrir opciones",
  "nav.back.a11y": "Volver al portapapeles",
  "nav.skip.a11y": "Saltar los ajustes e ir al panel",

  "state.active": "Activo",
  "state.paused": "Pausado",
  "state.starting": "Iniciando",
  "state.attention": "Necesita atención",
  "state.a11y": "OmaPlain, %1. %2",
  "state.a11y.short": "OmaPlain, %1",

  "status.unavailable": "El servicio todavía no está disponible.",
  "status.deps": "OmaPlain necesita %1. Instálalo y vuelve a abrir este panel.",
  "status.degraded": "OmaPlain ha dejado de vigilar el portapapeles. Limpiar a mano sigue funcionando.",
  "status.restarting": "Volviendo a vigilar el portapapeles…",
  "status.paused": "La limpieza automática está pausada. Las acciones manuales siguen disponibles.",
  "status.done": "Listo · última limpieza completada",
  "hint.manual": "La limpieza manual y «pegar limpio» siguen disponibles.",
  "hint.chars": "Ninguna regla activa cambia caracteres, así que el historial guarda una sola versión.",
  "fb.cleaned": "Portapapeles limpio",
  "fb.unchanged": "Ya estaba limpio",
  "fb.image": "Las imágenes no se tocan",
  "fb.files": "Los archivos no se tocan",
  "fb.sensitive": "Contenido sensible protegido",
  "fb.large": "Supera 1 MB, se deja igual",
  "fb.excluded": "Esa aplicación tiene una regla propia",
  "fb.bypassed": "No es texto, así que se deja igual",
  "fb.error": "No se pudo limpiar. Tu original está intacto; inténtalo otra vez.",

  "verdict.cleanable": "Esto se puede limpiar",
  "verdict.clean": "Ya está limpio",
  "verdict.nothing": "Nada que limpiar aquí",
  "verdict.sensitive": "Un secreto en tu portapapeles",
  "verdict.image": "Una imagen en tu portapapeles",
  "verdict.files": "Archivos en tu portapapeles",
  "verdict.structured": "Datos con estructura en tu portapapeles",
  "verdict.empty": "Esperando tu próxima copia",
  "verdict.preparing": "Preparando…",
  "verdict.large": "Más de 1 MB en tu portapapeles",
  "verdict.blocked": "No se lee, por tu regla",
  "verdict.unreadable": "No es texto que OmaPlain pueda leer",
  "verdict.failed": "No se ha podido leer el portapapeles",
  "verdict.richOnly": "Formato sin texto plano",
  "verdict.noText": "No hay texto que limpiar",
  "verdict.declined": "Se queda como está",

  "detail.cleanable": "Así está ahora y así quedaría.",
  "detail.clean": "OmaPlain lo ha mirado y no hay nada que retirar.",
  "detail.nothing": "OmaPlain lo deja como está.",
  "detail.sensitive": "Tu gestor de contraseñas marcó esta copia. OmaPlain no la lee, no la muestra y no la reescribe.",
  "detail.image": "OmaPlain no lee las imágenes. Ésta llega a su destino byte a byte.",
  "detail.files": "Copiar archivos lleva rutas y permisos, no texto. Reescribirlo rompería el pegado.",
  "detail.empty": "Copia cualquier cosa y esta pantalla te enseñará qué haría OmaPlain con ello, antes de hacerlo.",
  "detail.structured": "Reescribir un formato con estructura rompería lo que significa, así que OmaPlain lo deja entero.",
  "detail.large": "OmaPlain se para antes de leer una copia de este tamaño, así que tampoco la toca.",
  "detail.blocked": "OmaPlain no ha mirado esta copia, así que no puede decir qué hay dentro.",
  "detail.unreadable": "OmaPlain no puede descodificar estos bytes como texto, y reescribirlos a ciegas sería arriesgarse a romperlos.",
  "detail.richOnly": "Esta copia sólo ofrece una versión con formato. No hay texto plano que conservar, así que OmaPlain la deja entera.",
  "detail.noText": "OmaPlain sólo reescribe texto plano, y esta copia no ofrece ninguno.",
  "detail.declined": "Limpiar esta cambiaría más de lo que debe, así que OmaPlain se aparta.",
  "detail.failed": "OmaPlain no ha podido leer el portapapeles esta vez, así que no ha cambiado nada.",

  "row.now": "Ahora",
  "row.would": "Quedaría",
  "row.single": "En el portapapeles",
  "row.name.single": "lo que hay en el portapapeles",
  "row.name.now": "el texto actual",
  "row.name.would": "el resultado",
  "row.show": "Mostrar %1",
  "row.hide": "Ocultar %1",
  "row.covered.a11y": "Contenido cubierto. Arrástralo para limpiarlo, o usa el botón del ojo.",
  "row.covered.locked.a11y": "Contenido cubierto, y así se queda: viene de una aplicación de tu lista de no destapar.",
  "fog.hint": "Arrastra para limpiar",

  "rule.tracking": "Parámetros de seguimiento",
  "rule.invisible": "Caracteres invisibles",
  "rule.line_endings": "Finales de línea de Windows",
  "rule.rich_text": "Formato enriquecido",
  "rule.quotes": "Comillas tipográficas",
  "rule.lists": "Viñetas de lista",
  "rule.unicode_nfc": "Composición Unicode",
  "rule.trailing_whitespace": "Espacios al final de línea",
  "rule.encoding": "Codificación distinta de UTF-8",
  "rule.removed.a11y": "Se retira: %1, según el ajuste %2",
  "setting.tracking": "Seguimiento",
  "setting.invisible": "Invisibles",
  "setting.line_endings": "Finales de línea",
  "setting.rich_text": "Formato",
  "setting.quotes": "Comillas",
  "setting.lists": "Viñetas",
  "setting.unicode_nfc": "NFC",
  "setting.trailing_whitespace": "Espacios de fin de línea",

  "action.apply": "Aplicar al portapapeles",
  "action.applying": "Limpiando…",
  "footnote.safe": "El original permanece intacto si la limpieza no es segura.",
  "footnote.sensitive": "Revelar no está disponible para contenido marcado como sensible.",

  "settings.language": "Idioma",
  "settings.language.auto": "Del sistema",
  "settings.language.en": "Inglés",
  "settings.language.es": "Español",
  "settings.motionSection": "Movimiento",
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
  "settings.nfc.desc": "Junta los acentos en un solo carácter. El texto se lee igual y sus bytes cambian.",
  "settings.trim.desc": "No modifica la indentación ni los saltos.",


  "help.title": "Ayuda y aprendizaje",
  "help.body": "Vuelve a la explicación inicial o repite el recorrido sin cambiar tu configuración.",
  "help.welcome": "Revisar bienvenida",
  "help.welcome.a11y": "Abre de nuevo la explicación de OmaPlain",
  "help.tour": "Repetir mini tour",
  "help.tour.a11y": "Inicia de nuevo el recorrido de tres pasos",

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
  "tour.3.body": "Limpia manualmente, apaga el modo automático o dale a una aplicación sus propias reglas. El historial sigue siendo el de Omarchy.",
  "tour.3.note": "Todo ocurre en este equipo.",
  "tour.back": "Volver",
  "tour.back.first.a11y": "Volver a la pantalla anterior",
  "tour.back.a11y": "Volver al paso anterior",
  "tour.next": "Siguiente",
  "tour.finish": "Ver los ajustes",
  "tour.done": "Finalizar",
  "tour.skip": "Saltar el tour",
  "tour.leave": "Salir del repaso",

  "demo.label": "Demostración · texto de ejemplo, nunca tu portapapeles",
  "demo.try": "Probar con un ejemplo",
  "demo.original": "Ver el original",
  "demo.replay": "Verlo otra vez",
  "demo.a11y.before": "Ejemplo original: %1",
  "demo.a11y.after": "Resultado: %1",

  "onboarding.last": "Último paso",
  "onboarding.last.body": "Esto es lo que puedes ajustar. Ya viene todo configurado de forma segura, así que puedes dejarlo tal cual.",
  "onboarding.done": "Empezar a usarlo",

  "state.preparing": "Preparando el servicio…",
  "art.cleaning": "Reglas de limpieza",
  "art.exclude": "Reglas por app",
  "settings.trim": "Retirar espacios al final de línea",
  "art.automatic": "Automático",
  "demo.sample1.original": "https://example.com/pan-de-masa-madre?utm_source=boletin&utm_medium=email&fbclid=IwAR9x&​porciones=8#horneado",
  "demo.sample1.head": "https://example.com/pan-de-masa-madre?",
  "demo.sample1.spare": "utm_source=boletin&utm_medium=email&fbclid=IwAR9x&​",
  "demo.sample1.tail": "porciones=8#horneado",
  "demo.sample1.cleaned": "https://example.com/pan-de-masa-madre?porciones=8#horneado",
  "demo.sample2.original": "https://example.com/factura.pdf?expires=1735689600&signature=ab12cd34",
  "demo.sample2.cleaned": "https://example.com/factura.pdf?expires=1735689600&signature=ab12cd34",
  "demo.outcome1": "Fuera tres parámetros de seguimiento y un carácter invisible que no se veía. La página, las porciones y el punto al que apunta siguen ahí.",
  "demo.outcome2": "Sin cambios: este enlace va firmado y recortarlo lo rompería. Ante la duda, OmaPlain prefiere no tocar nada.",
  "err.busy": "OmaPlain ya está procesando otra acción",
  "art.untouched": "Intactos",
  "art.decide": "Tú decides",
  "art.byteForByte": "Byte a byte, exactamente como lo copiaste.",
  "art.images": "Imágenes",
  "art.files": "Archivos",
  "art.secrets": "Secretos",
  "chips.a11y": "Ofrecía %1. Quedaría %2.",
  "chips.plain.a11y": "El portapapeles ofrece %1.",
  "notify.title": "OmaPlain ha dejado de limpiar",
  "notify.body": "Abre el panel para revisar el servicio. Lo que copiaste está intacto.",
  "history.why": "¿Por qué puede seguir apareciendo el original?",
  "history.why.body": "Limpiar sustituye lo que hay en el portapapeles, pero el historial de Omarchy conserva cada entrada que vio pasar. Si una regla cambió caracteres, el historial puede guardar las dos versiones hasta que lo vacíes.",
  "privacy.blockedState": "Esa aplicación está en tu lista de no leer, así que aquí no hay nada.",
  "row.locked": "Esto se queda cubierto: viene de una aplicación de tu lista de no destapar.",
  "settings.motion": "Reducir movimiento",
  "settings.motion.desc": "Detiene las animaciones, incluidos los ejemplos que ciclan en la pantalla vacía.",
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
  "empty.sample.text.head": "La masa madre",
  "empty.sample.text.spare": "·invisible·",
  "empty.sample.text.tail": " necesita 12 horas.",
  "empty.sample.rich.head": "Resumen ejecutivo",
  "empty.sample.rich.spare": ", en negrita y con color",
  "empty.sample.rich.tail": ".",
  "art.copied": "Copiado",
  "art.clean": "Limpio",

  // --- Aplicaciones ---
  "apps.title": "Aplicaciones",
  "apps.body": "Hay aplicaciones que merecen otro trato. Elige una y decide cuáles de las cuatro reglas se le aplican.",
  "settings.privacy": "Todo ocurre en este equipo. OmaPlain no hace ninguna petición de red y no guarda nada del texto que copias. El historial pertenece a Omarchy.",
  "apps.note": "OmaPlain reconoce la ventana desde la que copiaste siempre que Wayland se lo permita. Es un buen filtro, no una garantía.",
  "apps.open": "Ventanas abiertas ahora mismo",
  "apps.open.none": "Ahora mismo no hay ninguna ventana que ofrecer. Escribe la clase.",
  "apps.open.a11y": "Añadir %1 a la lista de abajo",
  "apps.class": "O escribe su clase",
  "apps.class.hint": "La clase exacta de Hyprland. Las mayúsculas cuentan.",
  "apps.add": "Añadir",
  "apps.duplicate": "Esa aplicación ya tiene su tarjeta abajo.",
  "apps.invalid": "Eso no es una clase de aplicación válida.",
  "apps.none.title": "Ninguna aplicación tiene reglas propias",
  "apps.none.body": "OmaPlain trata igual a todas las aplicaciones. Añade una aquí para cambiar lo que lee, o lo que limpia.",
  "apps.pending": "Sin ninguna regla todavía. No se guarda nada hasta que marques una.",
  "apps.remove": "Quitar",
  "apps.remove.a11y": "Quitar %1 y todas sus reglas",
  "rules.reading": "Al leer",
  "rules.cleaning": "Al limpiar",
  "rules.covered": "No destapar nunca",
  "rules.blocked": "No leer nunca",
  "rules.source": "No limpiar lo que copie",
  "rules.target": "No pegar limpio ahí",

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
//
// De una sola pasada y con función, no con `replace(cadena, cadena)`: así
// un argumento que contenga `$&`, `$1` o un `%2` se inserta tal cual, en
// vez de expandirse o de recibir dentro el argumento siguiente. Hoy los
// argumentos son clases de ventana y rótulos, y una clase de ventana la
// pone la aplicación, no nosotros.
function f(key, lang, a, b, c) {
  var args = [a, b, c];
  return t(key, lang).replace(/%([123])/g, function(match, index) {
    var value = args[Number(index) - 1];
    return value === undefined ? match : String(value);
  });
}

// Del locale del sistema. Sólo se distinguen dos familias: cualquier
// variante de español va a español, y todo lo demás al inglés.
function fromLocale(name) {
  return String(name || "").toLowerCase().indexOf("es") === 0 ? "es" : "en";
}

function languages() { return ["en", "es"]; }
function keys() { var out = []; for (var k in EN) out.push(k); return out; }
