import QtQuick
import QtQuick.Controls as QQC
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "components/Strings.js" as Strings
import "components"

Item {
  id: root

  property var shell: null
  property var manifest: null
  property var service: null
  property bool opened: false
  // Un solo mensaje para un solo formulario. Antes eran dos, uno por
  // sección, y sólo uno de los dos llevaba la pista de las mayúsculas.
  property string appsError: ""
  property bool appsUrgent: false
  // La aplicación que acaba de traer el selector y todavía no tiene ninguna
  // regla. No se persiste: las cuatro listas son el almacén, y una app sin
  // regla no está en ninguna.
  property string pendingApp: ""
  property string feedback: ""
  property bool feedbackError: false
  property bool focusReady: false
  property string viewMode: "main"
  property string learningOrigin: "first-run"
  property string tourEntry: "welcome"
  property int tourStep: 0
  property real savedSettingsScroll: 0
  property string mainFocusTarget: "clean"
  property bool showBefore: false
  property bool showAfter: false
  // F.3: dura 1,5 s desde que el helper confirma que limpió de verdad.
  property bool cleanConfirmed: false
  // F.5: el desplegable del historial nace cerrado y no se recuerda: es una
  // explicación, no un ajuste.
  property bool historyOpen: false
  // Igual que el del historial: nacen cerrados y no se recuerdan. Son
  // ajustes que la mayoría no toca, no una preferencia sobre la vista.
  property bool optionalOpen: false
  // F.5: mientras el foco siga en el botón del resultado, el mensaje no se
  // va solo. Leerlo con el teclado no puede depender de leer rápido.
  readonly property bool holdingFeedback: applyButton && applyButton.activeFocus
  // La pantalla frecuente informa; los ajustes viven detrás del engranaje.
  property string panelPage: "clipboard"

  // F.1: el movimiento lo conduce el usuario. Sin un mando accesible no hay
  // forma de parar el carrusel del estado vacío, que es lo que pide la
  // WCAG 2.2.2, y Omarchy no expone ninguna preferencia de sistema de la
  // que colgarse.
  readonly property bool motionEnabled: !setting("reduceMotion", false)

  // Del ajuste del usuario, y si está en «auto» del locale del sistema.
  // Se pasa a cada componente en vez de guardarlo en el módulo JS, para que
  // los bindings se reevalúen solos al cambiarlo.
  readonly property string lang: {
    var chosen = String(setting("language", "auto"))
    if (chosen === "en" || chosen === "es") return chosen
    return Strings.fromLocale(Qt.locale().name)
  }

  // Cada motivo por el que el helper se niega a tocar el portapapeles, con
  // su titular y su explicación. Una sola tabla y no dos cadenas de `if`:
  // separadas, `structured` acabó con veredicto propio y explicación
  // genérica sin que nadie se diera cuenta.
  //
  // Los motivos no se inventan aquí: salen de `classify.py`, `transform.py`
  // y `daemon.py`, y `test_ui_contract.py` compara las dos listas. Si el
  // helper aprende a negarse por algo nuevo, el test lo caza antes de que
  // el panel diga «no hay nada que limpiar» de algo que sí lo tiene.
  readonly property var refusals: ({
    "sensitive":      { verdict: "verdict.sensitive",   detail: "detail.sensitive" },
    "image":          { verdict: "verdict.image",       detail: "detail.image" },
    "files":          { verdict: "verdict.files",       detail: "detail.files" },
    "empty":          { verdict: "verdict.empty",       detail: "detail.empty" },
    "structured":     { verdict: "verdict.structured",  detail: "detail.structured" },
    "too_large":      { verdict: "verdict.large",       detail: "detail.large" },
    "source_blocked": { verdict: "verdict.blocked",     detail: "detail.blocked" },
    "invalid_text":   { verdict: "verdict.unreadable",  detail: "detail.unreadable" },
    "undecodable":    { verdict: "verdict.unreadable",  detail: "detail.unreadable" },
    "read_failed":    { verdict: "verdict.failed",      detail: "detail.failed" },
    "inspect_failed": { verdict: "verdict.failed",      detail: "detail.failed" },
    // Sin texto plano que conservar: el portapapeles sólo trae la versión
    // con formato, o no trae texto en absoluto.
    "html_without_plain": { verdict: "verdict.richOnly", detail: "detail.richOnly" },
    "no_plain_text":  { verdict: "verdict.noText",      detail: "detail.noText" },
    // Bytes que no se dejan descodificar.
    "nul":            { verdict: "verdict.unreadable",  detail: "detail.unreadable" },
    "unsupported_encoding": { verdict: "verdict.unreadable", detail: "detail.unreadable" },
    // La limpieza saldría peor que el original, así que no se hace.
    "empty_output":   { verdict: "verdict.declined",    detail: "detail.declined" },
    "growth":         { verdict: "verdict.declined",    detail: "detail.declined" }
  })

  function refusal(field) {
    var why = root.peek ? String(root.peek.reason || "") : ""
    var entry = root.refusals[why]
    // El último recurso no puede afirmar nada sobre el contenido: un motivo
    // que este panel no conoce puede ser justo aquel en el que no se miró.
    return Strings.t(entry ? entry[field] : (field === "verdict" ? "verdict.nothing" : "detail.nothing"), root.lang)
  }

  readonly property string peekVerdict: {
    if (!service) return Strings.t("verdict.preparing", root.lang)
    if (!peek || peek.eligible !== true) return root.refusal("verdict")
    return peekChanges ? Strings.t("verdict.cleanable", root.lang) : Strings.t("verdict.clean", root.lang)
  }

  readonly property string peekDetail: {
    if (!peek || peek.eligible !== true) return root.refusal("detail")
    return peekChanges
      ? Strings.t("detail.cleanable", root.lang)
      : Strings.t("detail.clean", root.lang)
  }

  readonly property bool peekEmpty: peek && peek.eligible !== true
    && String(peek.reason || "") === "empty"
  readonly property var peekApplied: peek && peek.applied ? peek.applied : []
  readonly property var peekTypes: peek && peek.types ? peek.types : []
  readonly property var peekTypesAfter: peek && peek.typesAfter ? peek.typesAfter : []
  // El único caso en que el texto no cambia y sí se reescribe: se retira la
  // versión con formato. Ahí el antes y el después son los tipos.
  readonly property bool peekFormatOnly: peekChanges
    && String(peek.original || "") === String(peek.cleaned || "")

  function settingFor(rule) {
    if (rule === "tracking") return Strings.t("setting.tracking", root.lang)
    if (rule === "invisible") return Strings.t("setting.invisible", root.lang)
    if (rule === "line_endings") return Strings.t("setting.line_endings", root.lang)
    if (rule === "rich_text") return Strings.t("setting.rich_text", root.lang)
    if (rule === "quotes") return Strings.t("setting.quotes", root.lang)
    if (rule === "lists") return Strings.t("setting.lists", root.lang)
    if (rule === "unicode_nfc") return Strings.t("setting.unicode_nfc", root.lang)
    if (rule === "trailing_whitespace") return Strings.t("setting.trailing_whitespace", root.lang)
    return ""
  }

  readonly property var peek: service && service.peekResult ? service.peekResult : ({ eligible: false })
  readonly property bool peekReady: peek && peek.eligible === true
  readonly property bool peekChanges: peekReady && peek.changed === true
  // 0009: llega de una app de la lista «no destapar nunca».
  // Todo lo que se deja como está y no es un portapapeles vacío: imagen,
  // archivos, sensible, demasiado grande, formato estructural, app
  // bloqueada. Lo que tienen en común es que la pantalla no puede enseñar
  // el portapapeles —de una imagen no se lee ni un byte—, así que se queda
  // sin la mitad que en los demás estados ocupa la previsualización.
  readonly property bool peekBypass: peek && peek.eligible !== true
    && String(peek.reason || "") !== "empty"

  // La nota de pie cae en la genérica —«no hay ninguna acción que ofrecer
  // aquí»— cuando no es un `feedback`, ni «ya está limpio», ni bloqueada, ni
  // sensible. Ésa es la única que no dice nada que la pantalla no diga ya.
  readonly property bool peekGenericNote: feedback === "" && !peekReady
    && !peekBlocked && !(peek && peek.reason === "sensitive")

  readonly property bool peekCovered: peek && peek.cover === true
  readonly property bool peekBlocked: peek && String(peek.reason || "") === "source_blocked"

  // El ojo levanta la fila que hay delante, no las siguientes. Sin esto,
  // revelar una vez y copiar otra cosa enseñaba lo nuevo sin que nadie lo
  // pidiera, que es justo lo que la cubierta existe para impedir.
  onPeekChanged: {
    showBefore = false
    showAfter = false
    // Cinturón además de tirantes: si algo llegara con el panel cerrado,
    // se olvida aquí mismo.
    if (!opened && service && peek && peek.reason !== "unknown") service.forgetPeek()
  }

  readonly property var settings: service && service.settings ? service.settings : ({})
  readonly property string pluginId: manifest && manifest.id ? String(manifest.id) : "io.github.r-bart.omaplain"
  readonly property string watcherState: service ? service.watcherState : "starting"
  readonly property int onboardingVersion: 2
  // Marca el paso de ajustes del recorrido inicial: se enseñan, no se
  // imponen, así que llevan una salida visible y rotulada (decisión 0006).
  property bool onboardingSettings: false

  function ruleLabel(rule) {
    if (rule === "tracking") return Strings.t("rule.tracking", root.lang)
    if (rule === "invisible") return Strings.t("rule.invisible", root.lang)
    if (rule === "line_endings") return Strings.t("rule.line_endings", root.lang)
    if (rule === "rich_text") return Strings.t("rule.rich_text", root.lang)
    if (rule === "quotes") return Strings.t("rule.quotes", root.lang)
    if (rule === "lists") return Strings.t("rule.lists", root.lang)
    if (rule === "unicode_nfc") return Strings.t("rule.unicode_nfc", root.lang)
    if (rule === "trailing_whitespace") return Strings.t("rule.trailing_whitespace", root.lang)
    // Un BOM o un texto que no venía en UTF-8: se reescribe sin que ninguna
    // regla haya tocado un carácter, y no depende de ningún ajuste.
    if (rule === "encoding") return Strings.t("rule.encoding", root.lang)
    return rule
  }

  function chooseLanguage(value) {
    if (service) service.updateSetting("language", value)
  }

  function togglePage() {
    if (onboardingSettings) { finishOnboarding(); return }
    panelPage = panelPage === "settings" ? "clipboard" : "settings"
    // El selector ofrece lo que hay abierto *ahora*, no lo que había cuando
    // se abrió el panel.
    if (panelPage === "settings" && service) service.captureOpenWindows()
    scroll.contentY = 0
    Qt.callLater(root.applyViewFocus)
  }

  function open(payloadJson) {
    if (service) service.captureOpenWindows()
    viewMode = Number(setting("onboardingVersion", 0)) >= onboardingVersion ? "main" : "welcome"
    learningOrigin = viewMode === "welcome" ? "first-run" : "main"
    tourEntry = "welcome"
    tourStep = 0
    mainFocusTarget = "clean"
    opened = true
    peekStamp = eventStamp()
    if (service) service.requestPeek()
    feedback = ""
    appsError = ""
    pendingApp = ""
    focusReady = false
    scroll.contentY = 0
    initialFocusTimer.restart()
  }

  function close() {
    opened = false
    focusReady = false
    initialFocusTimer.stop()
    feedbackTimer.stop()
    appsError = ""
    pendingApp = ""
    // El contenido muere con el panel: es la promesa de la 0005 y de
    // `Service.forgetPeek`, que hasta aquí nadie llamaba. Sin esto el texto
    // seguía en memoria, volvía a las filas al reabrir hasta que llegaba
    // el vistazo nuevo, y las filas —con su vaho a 30 fps y el carrusel—
    // seguían vivas dentro de una ventana que no se veía.
    showBefore = false
    showAfter = false
    if (service) service.forgetPeek()
  }

  // La previsualización sigue al portapapeles mientras el panel está
  // abierto. Antes sólo se pedía al abrir: tras «Aplicar», tras omitir o
  // tras copiar otra cosa, las filas seguían diciendo «quedaría así» con
  // el botón habilitado.
  //
  // La señal es `status.json`: el helper apunta ahí cada evento —también
  // los que no procesa, con el automático apagado— y cada acción manual.
  // Se compara la marca en vez de reaccionar a cada relectura, porque el
  // servicio relee el fichero una vez por segundo aunque no haya cambiado.
  //
  // Una copia de imagen o de archivos sin texto no llega aquí: `wl-paste
  // --type text --watch` no ejecuta el comando cuando la oferta no trae
  // texto. Es un límite conocido y está escrito en el README.
  property string peekStamp: ""

  function eventStamp() {
    if (!service || !service.status) return ""
    // El contador va delante: dos eventos en el mismo microsegundo, o un
    // reloj que salta hacia atrás, no lo confunden.
    return String(service.status.eventSeq || 0) + "|"
      + String(service.status.lastEventAt || "") + "|" + String(service.status.lastAt || "")
  }

  function refreshPeek() {
    if (!opened || !service) return
    peekStamp = eventStamp()
    service.requestPeek()
  }

  function maybeRefreshPeek() {
    if (!opened || !service) return
    if (eventStamp() === peekStamp) return
    refreshPeek()
  }

  function dismiss() {
    if (shell && typeof shell.hide === "function") shell.hide(pluginId)
    else close()
  }

  function markOnboardingComplete() {
    if (service && Number(setting("onboardingVersion", 0)) < onboardingVersion)
      service.updateSetting("onboardingVersion", onboardingVersion)
  }

  function showWelcome(origin) {
    learningOrigin = origin || "settings"
    if (learningOrigin === "settings") {
      savedSettingsScroll = scroll.contentY
      mainFocusTarget = "welcome"
    }
    viewMode = "welcome"
  }

  function showTour(origin, entry) {
    learningOrigin = origin || "settings"
    tourEntry = entry || "settings"
    if (learningOrigin === "settings" && viewMode === "main") {
      savedSettingsScroll = scroll.contentY
      mainFocusTarget = "tour"
    }
    tourStep = 0
    viewMode = "tour"
  }

  function showMain(markComplete) {
    if (markComplete) markOnboardingComplete()
    viewMode = "main"
  }

  function advanceTour() {
    if (tourStep < 2) {
      tourStep += 1
      return
    }
    // Primera vez: los ajustes son el último paso del recorrido, con
    // salida. Repitiendo el tour desde ajustes, se vuelve por donde vino.
    if (learningOrigin === "first-run") showOnboardingSettings()
    else showMain(true)
  }

  function showOnboardingSettings() {
    onboardingSettings = true
    panelPage = "settings"
    viewMode = "main"
    scroll.contentY = 0
    Qt.callLater(root.applyViewFocus)
  }

  // Salga o configure, el recorrido termina siempre en la pantalla
  // principal, con su portapapeles real delante.
  function finishOnboarding() {
    onboardingSettings = false
    panelPage = "clipboard"
    markOnboardingComplete()
    scroll.contentY = 0
    Qt.callLater(root.applyViewFocus)
  }

  function retreatTour() {
    if (tourStep > 0) {
      tourStep -= 1
      return
    }
    if (tourEntry === "welcome") viewMode = "welcome"
    else showMain(false)
  }

  function setting(name, fallback) {
    var value = settings ? settings[name] : undefined
    return value === undefined || value === null ? fallback : value
  }

  function statusDetail() {
    if (!service) return Strings.t("status.unavailable", root.lang)
    if (service.dependencyError !== "") return Strings.f("status.deps", root.lang, service.dependencyError)
    if (watcherState === "degraded") return Strings.t("status.degraded", root.lang)
    if (watcherState === "restarting") return Strings.t("status.restarting", root.lang)
    if (!setting("automatic", true)) return Strings.t("status.paused", root.lang)
    if (service.status && service.status.lastResult === "cleaned") return Strings.t("status.done", root.lang)
    // Nada que contar. Las otras ramas informan de algo que está
    // pasando —pausado, se acaba de limpiar, falta una dependencia—; ésta
    // era la única que describía el producto, y describía
    // el producto justo en el caso más frecuente de todos.
    //
    // Era el titular educativo que la 0007 echó de esta pantalla, sobrevivido
    // como cadena por defecto: «OmaPlain ordena el formato y deja intacto
    // todo lo que no puede limpiar con seguridad», encima de un veredicto que
    // ya dice qué pasa con *tu* portapapeles. Mismo caso que la insignia
    // «ACTIVO»: un servicio que va bien y no tiene nada que contar, se calla.
    return ""
  }

  // Las reglas que cambian caracteres, que son todas menos retirar el
  // formato: ésa deja el texto igual y sólo quita la versión con formato.
  // Antes sólo se miraban dos, y la frase «ninguna regla activa cambia
  // caracteres» salía con los finales de línea —activos de fábrica— o las
  // comillas puestas, que sí los cambian y duplican el historial igual.
  readonly property var characterRules: [
    "removeTracking", "removeInvisible", "normalizeLineEndings",
    "normalizeQuotes", "normalizeLists", "normalizeUnicodeNfc", "trimTrailingWhitespace"
  ]

  function changesCharacters() {
    for (var i = 0; i < characterRules.length; i++)
      if (setting(characterRules[i], i < 3)) return true
    return false
  }

  function historyDetail() {
    if (!setting("automatic", true))
      return Strings.t("hint.manual", root.lang)
    if (changesCharacters())
      return Strings.t("settings.history", root.lang)
    return Strings.t("hint.chars", root.lang)
  }

  function actionMessage(raw) {
    var data = {}
    try { data = JSON.parse(String(raw || "{}")) } catch (error) {}
    feedbackError = data.result === "error"
    if (data.result === "cleaned") return Strings.t("fb.cleaned", root.lang)
    if (data.result === "unchanged") return Strings.t("fb.unchanged", root.lang)
    if (data.reason === "image") return Strings.t("fb.image", root.lang)
    if (data.reason === "files") return Strings.t("fb.files", root.lang)
    if (data.reason === "sensitive") return Strings.t("fb.sensitive", root.lang)
    if (data.reason === "too_large") return Strings.t("fb.large", root.lang)
    if (data.reason === "target_excluded" || data.reason === "source_excluded") return Strings.t("fb.excluded", root.lang)
    if (data.result === "bypassed") return Strings.t("fb.bypassed", root.lang)
    if (data.result === "error") return Strings.t("fb.error", root.lang)
    return ""
  }

  function runAction(name) {
    if (!service) return
    var result = service.cleanNow()
    if (result === "busy") {
      feedbackError = false
      feedback = Strings.t("err.busy", root.lang)
      feedbackTimer.restart()
    }
  }

  // Las cuatro listas de la 0009, con el nombre corto que usa la interfaz.
  readonly property var ruleKeys: ({
    covered: "alwaysCovered",
    blocked: "blockedApps",
    source: "sourceExclusions",
    target: "targetExclusions"
  })

  // Lo que se pinta: la unión de las cuatro listas, más la que acaba de
  // entrar y todavía no tiene regla. Ordenada a propósito — si el orden
  // saliera de las listas, marcar una regla movería la tarjeta bajo el dedo.
  function ruledApps() {
    var seen = ({})
    var names = []
    var keys = ["alwaysCovered", "blockedApps", "sourceExclusions", "targetExclusions"]
    for (var i = 0; i < keys.length; i++) {
      var values = setting(keys[i], [])
      if (!Array.isArray(values)) continue
      for (var j = 0; j < values.length; j++) {
        var value = String(values[j])
        if (value !== "" && seen[value] !== true) {
          seen[value] = true
          names.push(value)
        }
      }
    }
    if (pendingApp !== "" && seen[pendingApp] !== true) names.push(pendingApp)
    names.sort(function(first, second) {
      var a = first.toLowerCase()
      var b = second.toLowerCase()
      return a < b ? -1 : (a > b ? 1 : 0)
    })
    return names
  }

  function hasRule(kind, appClass) {
    var values = setting(ruleKeys[kind] || "sourceExclusions", [])
    return Array.isArray(values) && values.indexOf(appClass) !== -1
  }

  // Traer una aplicación no le pone ninguna regla: la deja delante para que
  // se elija. Es la única acción del formulario, así que ni Enter ni el
  // selector deciden ya por su cuenta a qué lista va nada.
  function addApp(value) {
    var name = String(value || "").trim()
    if (!service || !service.validAppClass(name)) {
      appsError = Strings.t("apps.invalid", root.lang)
      appsUrgent = true
      Qt.callLater(function() { root.reveal(appsMessage) })
      return
    }
    var repetida = ruledApps().indexOf(name) !== -1
    appsError = repetida ? Strings.t("apps.duplicate", root.lang) : ""
    appsUrgent = false
    pendingApp = name
    classField.text = ""
    Qt.callLater(function() { root.revealTop(appsList) })
  }

  function toggleRule(appClass, kind, next) {
    if (!service) return
    // El aviso de «ya tiene su tarjeta abajo» ha cumplido en cuanto se toca
    // una regla: dejarlo puesto tapa la pista del campo sin decir nada nuevo.
    if (!appsUrgent) appsError = ""
    if (next) service.addExclusion(kind, appClass)
    else service.removeExclusion(kind, appClass)
  }

  function removeApp(appClass) {
    if (service) {
      var kinds = ["covered", "blocked", "source", "target"]
      for (var i = 0; i < kinds.length; i++) service.removeExclusion(kinds[i], appClass)
    }
    if (pendingApp === appClass) pendingApp = ""
    appsError = ""
    appsUrgent = false
  }

  // Como `reveal`, pero alineando por arriba. `reveal` enseña el final de lo
  // que no cabe, que es lo que quieres para un control y lo contrario de lo
  // que quieres para una lista que acaba de crecer: dejaba al usuario en la
  // última tarjeta en vez de donde empieza lo que añadió.
  function revealTop(item) {
    if (viewMode !== "main" || !focusReady || !item || !contentColumn) return
    var top = item.mapToItem(contentColumn, 0, 0).y
    if (top < scroll.contentY || top > scroll.contentY + scroll.height - Style.space(48))
      scroll.contentY = Math.max(0, Math.min(scroll.contentHeight - scroll.height, top - Style.space(8)))
  }

  function reveal(item) {
    if (viewMode !== "main" || !focusReady || !item || !contentColumn) return
    var point = item.mapToItem(contentColumn, 0, 0)
    var top = point.y
    var bottom = top + item.height
    if (top < scroll.contentY) scroll.contentY = Math.max(0, top - Style.space(8))
    else if (bottom > scroll.contentY + scroll.height)
      scroll.contentY = Math.min(scroll.contentHeight - scroll.height, bottom - scroll.height + Style.space(8))
  }

  // A dónde va el foco cuando la acción que lo tenía desaparece: la
  // siguiente viva de la pantalla, y si no hay ninguna, el engranaje.
  function settleFocus() {
    if (!opened || viewMode !== "main" || panelPage !== "clipboard") return
    if (applyButton.visible) applyButton.forceActiveFocus()
    else optionsButton.forceActiveFocus()
  }

  function applyViewFocus() {
    if (!root.opened) return
    focusScope.forceActiveFocus()
    if (root.viewMode === "welcome") {
      welcomePage.forceInitialFocus()
    } else if (root.viewMode === "tour") {
      tourPage.forceInitialFocus()
    } else {
      scroll.contentY = root.learningOrigin === "settings" ? root.savedSettingsScroll : 0
      if (root.mainFocusTarget === "welcome") welcomeReplayButton.forceActiveFocus()
      else if (root.mainFocusTarget === "tour") tourReplayButton.forceActiveFocus()
      // 0015: el primario ya no está siempre. Sin nada que aplicar, el
      // foco va a la siguiente acción viva, y si no hay ninguna, al
      // engranaje, que siempre está.
      else settleFocus()
    }
    Qt.callLater(function() {
      root.focusReady = true
      if (root.viewMode === "main") {
        if (root.mainFocusTarget === "welcome") root.reveal(welcomeReplayButton)
        else if (root.mainFocusTarget === "tour") root.reveal(tourReplayButton)
      }
    })
  }

  onOpenedChanged: if (!opened) feedbackTimer.stop()
  onViewModeChanged: {
    if (!opened) return
    focusReady = false
    initialFocusTimer.stop()
    Qt.callLater(root.applyViewFocus)
  }

  Connections {
    target: root.service
    function onLastActionJsonChanged() {
      root.feedback = root.actionMessage(root.service.lastActionJson)
      if (root.feedback !== "") feedbackTimer.restart()
      var data = {}
      try { data = JSON.parse(String(root.service.lastActionJson || "{}")) } catch (error) {}
      if (data.result === "cleaned") {
        root.cleanConfirmed = true
        confirmTimer.restart()
      }
      // El vistazo nuevo no se pide aquí: la acción que cambia algo queda
      // apuntada en `status.json` y es la marca la que lo pide, una vez.
      // Pedirlo también aquí era pedirlo dos veces por cada «Aplicar».
    }
    function onStatusChanged() { root.maybeRefreshPeek() }
  }

  Timer {
    id: confirmTimer
    interval: 1500
    repeat: false
    onTriggered: root.cleanConfirmed = false
  }

  Timer {
    id: feedbackTimer
    interval: 2500
    repeat: false
    // Con el foco puesto en el resultado, el mensaje se queda: se vuelve a
    // armar el reloj en vez de borrarlo.
    onTriggered: if (root.holdingFeedback) feedbackTimer.restart(); else root.feedback = ""
  }

  Timer {
    id: initialFocusTimer
    interval: 180
    repeat: false
    onTriggered: root.applyViewFocus()
  }

  PanelWindow {
    id: window
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "omaplain-panel"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    Rectangle {
      anchors.fill: parent
      color: Color.menu.scrim

      MouseArea {
        anchors.fill: parent
        onClicked: root.dismiss()
      }
    }

    FocusScope {
      id: focusScope
      anchors.fill: parent
      focus: true
      Keys.onEscapePressed: root.dismiss()

      BorderSurface {
        id: card
        anchors.centerIn: parent
        width: Math.min(Style.space(520), parent.width - Style.space(32))

        // La altura sigue al contenido. Antes era fija, así que un estado
        // corto —una imagen, un secreto, el portapapeles vacío— dejaba
        // cientos de píxeles muertos debajo del texto.
        //
        // Sólo hay techo, para que los ajustes no se coman la pantalla. No
        // hay suelo: el estado más corto —el portapapeles vacío— ya trae
        // cabecera, estado, veredicto, explicación y nota, así que un
        // mínimo no protegía de nada y sólo dejaba hueco muerto debajo.
        readonly property real contentHeight: {
          if (root.viewMode === "welcome") return welcomePage.contentHeight
          if (root.viewMode === "tour") return tourPage.contentHeight
          return Style.space(20) + primaryColumn.implicitHeight
               + Style.space(12) + contentColumn.implicitHeight
               + Style.space(20)
        }
        // El techo de 720 protege a la vista de todos los días: los ajustes,
        // con sus desplegables abiertos, se comerían la pantalla entera.
        //
        // El onboarding no es esa vista. Se ve una vez en la vida, se lee de
        // arriba abajo y su acción primaria vive al final, así que cortarlo
        // por el techo dejaba «Siguiente» y la salida del tour por debajo del
        // borde: había que arrastrar la pantalla para poder continuarla. Ahí
        // el único techo razonable es la propia pantalla, que ya lo sujeta
        // todo en la línea de abajo.
        readonly property real ceiling: root.viewMode === "main"
          ? Style.space(720)
          : parent.height - Style.space(32)
        height: Math.min(ceiling, contentHeight, parent.height - Style.space(32))
        radius: Style.cornerRadius
        color: Color.popups.background
        borderSpec: Border.surfaceSpec("popups", "border", Color.popups.border, Math.max(1, Style.normalBorderWidth))

        MouseArea { anchors.fill: parent; onClicked: {} }

        WelcomePage {

          lang: root.lang
          id: welcomePage
          anchors.fill: parent
          visible: root.viewMode === "welcome"
          enabled: visible
          returning: root.learningOrigin === "settings"
          motionEnabled: root.motionEnabled
          onStartRequested: root.showTour(root.learningOrigin, "welcome")
          onDismissRequested: root.showMain(true)
        }

        TourPage {

          lang: root.lang
          id: tourPage
          anchors.fill: parent
          visible: root.viewMode === "tour"
          enabled: visible
          step: root.tourStep
          // Sólo acaba en los ajustes cuando de verdad va allí: la primera
          // vez, o repitiendo el recorrido desde los propios ajustes.
          endsInSettings: root.learningOrigin === "first-run" || root.panelPage === "settings"
          replaying: root.learningOrigin === "settings"
          motionEnabled: root.motionEnabled
          onBackRequested: root.retreatTour()
          onNextRequested: root.advanceTour()
          onDismissRequested: root.showMain(true)
        }

        Item {
          id: mainPage
          anchors.fill: parent
          visible: root.viewMode === "main"
          enabled: visible

        Column {
          id: primaryColumn
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.margins: Style.space(20)
          spacing: Style.space(12)

          // La fila la marca su propio control. Antes eran dos números
          // escritos a mano que se contradecían —fila `space(38)`, botón
          // `space(44)`— y el botón, centrado, sobresalía 3 unidades por
          // arriba y por abajo: su borde inferior cruzaba la regla que
          // cierra la cabecera en vez de quedarse encima de ella.
          Item {
            width: parent.width
            height: optionsButton.height

            Text {
              id: brandText
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              text: "OmaPlain"
              color: Color.popups.text
              font.family: Style.font.family
              // Un escalón por encima del subtítulo, pero sin llegar al del
              // veredicto: la cabecera es identidad, no contenido, y si
              // empatan compiten por la misma mirada.
              font.pixelSize: Style.font.title
              font.bold: true
              font.letterSpacing: -Style.spaceReal(0.2)
            }

            PanelButton {
              id: optionsButton
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              // El área táctil, no la altura del texto: con su relleno de
              // control el kit se quedaría en 38, por debajo del mínimo.
              // Ahora es la fila la que se adapta a esto, y no al revés.
              implicitHeight: Style.space(44)
              // El glifo va por `iconText`, no dentro de la cadena que se
              // traduce. Dentro del texto se pintaba al tamaño de cuerpo y
              // se separaba con dos espacios literales, que no escalan con
              // el tema; aquí lo pinta a `Style.font.icon` y lo separa con
              // `controlGap`, que sí. Además saca de las dos tablas de
              // idioma un carácter que allí no significa nada y que un
              // traductor puede perder o duplicar.
              //
              // «Saltar» conserva el suyo en la cadena: su flecha va a la
              // derecha del rótulo y `iconText` sólo pinta a la izquierda.
              iconText: root.onboardingSettings
                ? ""
                : (root.panelPage === "settings" ? "󰅁" : "󰢻")
              text: root.onboardingSettings
                ? Strings.t("nav.skip", root.lang)
                : (root.panelPage === "settings" ? Strings.t("nav.back", root.lang) : Strings.t("nav.options", root.lang))
              tooltipText: root.onboardingSettings
                ? Strings.t("nav.skip.a11y", root.lang)
                : (root.panelPage === "settings" ? Strings.t("nav.back.a11y", root.lang) : Strings.t("nav.options.a11y", root.lang))
              foreground: root.panelPage === "settings" ? Color.accent : Util.alpha(Color.popups.text, 0.68)
              Accessible.name: root.onboardingSettings
                ? Strings.t("nav.skip.a11y", root.lang)
                : (root.panelPage === "settings" ? Strings.t("nav.back.a11y", root.lang) : Strings.t("nav.options.a11y", root.lang))
              onClicked: root.togglePage()
            }
          }

          // La regla, hermana de la columna y no hija de la fila. Anclada al
          // fondo de la fila era el subrayado del botón: cero aire entre los
          // dos, aunque las alturas hubieran cuadrado. Aquí el `spacing` de
          // la columna le da la misma separación por arriba que por abajo,
          // que es lo que la convierte en un separador y no en un borde.
          Rectangle {
            width: parent.width
            height: Math.max(1, Style.normalBorderWidth)
            color: Util.alpha(Color.popups.text, 0.14)
          }

          StatusHeader {

            id: statusLine
            lang: root.lang
            width: parent.width
            visible: root.panelPage === "clipboard" && !statusLine.silent
            serviceState: !root.setting("automatic", true) && root.watcherState === "running" ? "paused" : root.watcherState
            detail: root.statusDetail()
            motionEnabled: root.motionEnabled
          }

          Text {
            width: parent.width
            visible: root.panelPage === "clipboard"
            text: root.peekVerdict
            color: Color.popups.text
            font.family: Style.font.family
            font.pixelSize: Style.font.heading
            font.bold: true
            font.letterSpacing: -Style.spaceReal(0.3)
            wrapMode: Text.WordWrap
            Accessible.role: Accessible.StaticText
            Accessible.name: text
          }

          Text {
            width: parent.width
            visible: root.panelPage === "clipboard"
            text: root.peekDetail
            color: Util.alpha(Color.popups.text, 0.72)
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            lineHeightMode: Text.ProportionalHeight
            lineHeight: 1.45
            wrapMode: Text.WordWrap
          }

        }

        Flickable {
          id: scroll
          anchors.top: primaryColumn.bottom
          anchors.topMargin: Style.space(12)
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          anchors.leftMargin: Style.space(20)
          anchors.rightMargin: Style.space(20)
          anchors.bottomMargin: Style.space(20)
          contentWidth: width
          contentHeight: contentColumn.implicitHeight
          clip: true
          boundsBehavior: Flickable.StopAtBounds
          flickableDirection: Flickable.VerticalFlick
          QQC.ScrollBar.vertical: QQC.ScrollBar { policy: QQC.ScrollBar.AsNeeded }

          Column {
            id: contentColumn
            width: scroll.width - (scroll.contentHeight > scroll.height ? Style.space(12) : 0)
            spacing: Style.space(12)

            // La pantalla frecuente. Informa sobre lo que hay ahora en el
            // portapapeles; no enseña el producto (decisión 0007).
            Column {
              id: clipboardPage
              width: contentColumn.width
              visible: root.panelPage === "clipboard"
              spacing: Style.space(12)

              ClipboardRow {

                lang: root.lang
                width: contentColumn.width
                visible: root.peekReady
                label: root.peekChanges ? Strings.t("row.now", root.lang) : Strings.t("row.single", root.lang)
                name: root.peekChanges ? Strings.t("row.name.now", root.lang) : Strings.t("row.name.single", root.lang)
                body: root.peekReady ? String(root.peek.original || "") : ""
                shown: root.showBefore
                confirmed: root.cleanConfirmed
                locked: root.peekCovered
                motionEnabled: root.motionEnabled
                seed: 11
                onRevealRequested: root.showBefore = true
                onHideRequested: root.showBefore = false
                onFocusEntered: function(item) { root.reveal(item) }
              }

              ClipboardRow {

                lang: root.lang
                width: contentColumn.width
                visible: root.peekChanges
                label: Strings.t("row.would", root.lang)
                name: Strings.t("row.name.would", root.lang)
                body: root.peekChanges ? String(root.peek.cleaned || "") : ""
                shown: root.showAfter
                confirmed: root.cleanConfirmed
                locked: root.peekCovered
                motionEnabled: root.motionEnabled
                seed: 29
                onRevealRequested: root.showAfter = true
                onHideRequested: root.showAfter = false
                onFocusEntered: function(item) { root.reveal(item) }
              }

              // Un portapapeles vacío no es un error ni una lista sin
              // elementos: es la pantalla que ve alguien que acaba de
              // llegar. Así que enseña de qué va esto y ofrece aprenderlo.
              EmptyCarousel {
                lang: root.lang
                width: parent.width
                visible: root.peekEmpty
                motionEnabled: root.motionEnabled
              }

              // Cuando sólo se retira el formato, las dos filas salen
              // idénticas: el cambio hay que enseñarlo aquí o no se ve.
              MimeChips {
                motionEnabled: root.motionEnabled
                lang: root.lang
                width: parent.width
                visible: root.peekFormatOnly
                types: root.peekTypes
                typesAfter: root.peekTypesAfter
              }

              // Un bypass no tiene portapapeles que enseñar, así que la
              // mitad de la pantalla que en los demás estados ocupa la
              // previsualización se quedaba vacía: el veredicto flotando y
              // debajo una frase que decía que no había nada que hacer. Esa
              // pantalla llegó a confundirse con el estado vacío.
              //
              // La 0007 dice «ni titular educativo ni ilustración» en la
              // pantalla frecuente, y su motivo es que el producto se explica
              // solo enseñando lo que hará con tu contenido. Aquí no hay
              // contenido que enseñar, así que ese motivo no llega. El dibujo
              // no es de marca ni se repite del onboarding: es «protege»,
              // que dibuja exactamente lo que este veredicto afirma. La
              // enmienda está en la propia 0007.
              //
              // Quieto, siempre. Esta pantalla se abre muchas veces al día y
              // una animación de entrada en cada apertura es justo lo que no
              // se le hace a un gesto frecuente; `motionEnabled: false` la
              // pinta en su estado final y sin recorrido.
              TransformationIllustration {
                lang: root.lang
                width: parent.width
                height: Style.space(124)
                variant: "unread"
                // De qué es la copia. La ilustración traduce el motivo del
                // rechazo a un dibujo, y lo que no reconoce lo pinta como
                // una hoja de texto, que no afirma nada.
                subject: root.peek ? String(root.peek.reason || "") : ""
                visible: root.peekBypass
                motionEnabled: false
              }

              // De un bypass no se enseña contenido, pero sí de qué está
              // hecho: es lo que permite entender por qué no se toca.
              MimeChips {
                motionEnabled: root.motionEnabled
                lang: root.lang
                width: parent.width
                visible: !root.peekReady && root.peekTypes.length > 0
                types: root.peekTypes
              }

              // El desglose es una cuenta de lo que pasa, no unas frases
              // sueltas: una sola superficie, con las filas separadas por un
              // filete y cada ajuste pegado a la suya.
              BorderSurface {
                width: parent.width
                visible: root.peekChanges
                implicitHeight: breakdownRows.implicitHeight
                radius: Style.cornerRadius
                color: Style.normalFillFor(Color.popups.text, Color.accent)
                borderSpec: Border.controlSpec("normal", Color.popups.text, Color.accent)
                clip: true

                Column {
                  id: breakdownRows
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.top: parent.top

                  Repeater {
                    model: root.peekApplied
                    delegate: Item {
                      required property string modelData
                      required property int index
                      width: breakdownRows.width
                      height: Math.max(Style.space(38), ruleText.implicitHeight + Style.space(16))

                      Accessible.role: Accessible.StaticText
                      Accessible.name: Strings.f("rule.removed.a11y", root.lang, root.ruleLabel(modelData), root.settingFor(modelData))

                      // Filete entre filas, nunca encima de la primera.
                      Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        height: Math.max(1, Style.normalBorderWidth)
                        color: Util.alpha(Color.popups.text, 0.14)
                        visible: index > 0
                      }

                      Text {
                        id: ruleText
                        anchors.left: parent.left
                        anchors.leftMargin: Style.space(11)
                        anchors.right: ruleChip.left
                        anchors.rightMargin: Style.space(8)
                        anchors.verticalCenter: parent.verticalCenter
                        text: "✕  " + root.ruleLabel(modelData)
                        color: Util.alpha(Color.popups.text, 0.72)
                        font.family: Style.font.family
                        font.pixelSize: Style.font.bodySmall
                        wrapMode: Text.WordWrap
                      }

                      Chip {
                        id: ruleChip
                        anchors.right: parent.right
                        anchors.rightMargin: Style.space(11)
                        anchors.verticalCenter: parent.verticalCenter
                        label: root.settingFor(modelData)
                        visible: label !== ""
                      }
                    }
                  }
                }
              }

              // 0015: sólo cuando hay algo que aplicar. Con el automático
              // puesto, que es el modo por defecto, el texto ya llega limpio
              // y este botón vivía gris casi siempre en la pantalla más
              // vista. Un botón apagado es para una condición que el usuario
              // puede resolver desde ahí; aquí no había nada que resolver.
              PrimaryButton {
                id: applyButton
                width: parent.width
                visible: root.peekChanges
                text: service && service.actionBusy ? Strings.t("action.applying", root.lang) : Strings.t("action.apply", root.lang)
                iconText: service && service.actionBusy ? "" : "󰅍"
                enabled: service && !service.actionBusy && root.peekChanges
                onClicked: root.runAction("cleanNow")
                // Al aplicar con Enter, el botón desaparece con el foco
                // dentro y Qt lo suelta: el mensaje de resultado se iba a
                // los 2,5 s sin que nadie lo leyera, que es justo el caso
                // de la F.5. El foco pasa a la siguiente acción viva.
                onActiveFocusChanged: if (!activeFocus && !visible && root.opened) Qt.callLater(root.settleFocus)
              }

              PanelButton {
                id: emptyHowButton
                width: parent.width
                // Sólo en el vacío ([`0013`]).
                //
                // Estuvo también en los bypass, y por un motivo que ya no
                // existe: allí la última línea era «no hay ninguna acción que
                // ofrecer aquí» y quien no entendía por qué su imagen no se
                // tocaba no tenía dónde averiguarlo. Ahora la pantalla lo dice
                // en dos líneas —qué tienes y qué no le hacemos—, así que no
                // queda nada que ir a buscar a un recorrido de tres pasos.
                //
                // Y un bypass se ve muchas veces al día —cada captura de
                // pantalla es uno—, que es justo donde la `0007` no quiere un
                // botón de aprender el producto. El vacío es lo contrario: se
                // ve al empezar sesión, es la pantalla de quien acaba de
                // llegar, y es la única sin ninguna acción de producto posible
                // —no hay nada que limpiar, ni que omitir— así que aprender es
                // la única salida honesta que se le puede ofrecer.
                visible: root.peekEmpty
                text: Strings.t("empty.how", root.lang)
                foreground: Color.accent
                Accessible.description: Strings.t("empty.how.a11y", root.lang)
                onFocusEntered: function(item) { root.reveal(item) }
                onClicked: root.showTour("main", "main")
              }

              Text {
                width: parent.width
                // La nota genérica se fue entera. Decía «aquí no hay acción
                // que ofrecer», que es una frase sobre el panel y no sobre tu
                // portapapeles: en el vacío iba debajo de un botón que sí
                // ofrecía una, y en un bypass la pantalla ya dice qué tienes y
                // qué no le hacemos. Nunca era el momento de decirla.
                //
                // Las otras tres se quedan: «ya está limpio», la de la app
                // bloqueada y la de contenido sensible dicen algo que la
                // pantalla no dice en ninguna otra parte. Y un `feedback`
                // nunca se calla.
                visible: !root.peekGenericNote
                text: root.feedback !== ""
                  ? root.feedback
                  : (root.peekReady
                    ? Strings.t("footnote.safe", root.lang)
                    : (root.peekBlocked
                      ? Strings.t("privacy.blockedState", root.lang)
                      : Strings.t("footnote.sensitive", root.lang)))
                color: root.feedback !== ""
                  ? (root.feedbackError ? Color.urgent : Color.popups.text)
                  : Util.alpha(Color.popups.text, 0.68)
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                wrapMode: Text.WordWrap
                Accessible.role: root.feedback !== "" ? Accessible.AlertMessage : Accessible.StaticText
                Accessible.name: text
              }
            }

            // Los ajustes, detrás del engranaje.
            Column {
              id: settingsPage
              width: contentColumn.width
              visible: root.panelPage === "settings"
              spacing: Style.space(12)

              // Último paso del recorrido. Los ajustes se enseñan, no se
              // imponen: aquí se explica por qué estás viéndolos, y hay dos
              // salidas — una en la cabecera y otra al final de la lista.
              BorderSurface {
                width: parent.width
                visible: root.onboardingSettings
                implicitHeight: bandCopy.implicitHeight + Style.space(24)
                radius: Style.cornerRadius
                color: Style.normalFillFor(Color.popups.text, Color.accent)
                borderSpec: Border.controlSpec("normal", Color.popups.text, Color.accent)

                Column {
                  id: bandCopy
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  anchors.leftMargin: Style.space(14)
                  anchors.rightMargin: Style.space(14)
                  spacing: Style.space(4)

                  Text {
                    text: Strings.t("onboarding.last", root.lang)
                    color: Color.accent
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: Style.spaceReal(0.9)
                  }

                  Text {
                    width: parent.width
                    text: Strings.t("onboarding.last.body", root.lang)
                    color: Util.alpha(Color.popups.text, 0.78)
                    font.family: Style.font.family
                    font.pixelSize: Style.font.bodySmall
                    lineHeightMode: Text.ProportionalHeight
                    lineHeight: 1.45
                    wrapMode: Text.WordWrap
                  }
                }
              }

              // El idioma va el primero: si alguien abre los ajustes por no
              // entender la interfaz, es lo primero que necesita encontrar.
              SectionHeading {
                text: Strings.t("settings.language", root.lang)
              }

              Grid {
                id: languageChoices
                width: parent.width
                columns: width < Style.space(360) ? 1 : 3
                columnSpacing: Style.space(8)
                rowSpacing: Style.space(8)

                Repeater {
                  model: [
                    { value: "auto", key: "settings.language.auto" },
                    { value: "en", key: "settings.language.en" },
                    { value: "es", key: "settings.language.es" }
                  ]
                  delegate: PanelButton {
                    required property var modelData
                    readonly property bool chosen: String(root.setting("language", "auto")) === modelData.value
                    width: (languageChoices.width - (languageChoices.columns - 1) * languageChoices.columnSpacing) / languageChoices.columns
                    text: Strings.t(modelData.key, root.lang)
                    foreground: chosen ? Color.accent : Util.alpha(Color.popups.text, 0.68)
                    Accessible.role: Accessible.RadioButton
                    Accessible.checked: chosen
                    onFocusEntered: function(item) { root.reveal(item) }
                    onClicked: root.chooseLanguage(modelData.value)
                  }
                }
              }

              // Vivía debajo del encabezado «Idioma», sin nada que dijera que
              // había salido de esa sección: con el espaciado uniforme, una
              // fila más era una fila más. Es un ajuste de movimiento, así
              // que tiene el suyo.
              SectionHeading {
                text: Strings.t("settings.motionSection", root.lang)
              }

              SettingRow {
                id: motionToggle
                width: parent.width
                label: Strings.t("settings.motion", root.lang)
                description: Strings.t("settings.motion.desc", root.lang)
                checked: root.setting("reduceMotion", false)
                onFocusEntered: function(item) { root.reveal(item) }
                onClicked: if (service) service.updateSetting("reduceMotion", !checked)
              }

              SectionHeading {
                text: Strings.t("settings.mode", root.lang)
              }

              SettingRow {
                id: automaticToggle
                width: parent.width
                label: Strings.t("settings.automatic", root.lang)
                description: Strings.t("settings.automatic.desc", root.lang)
                checked: root.setting("automatic", true)
                onFocusEntered: function(item) { root.reveal(item) }
                onClicked: if (service) service.updateSetting("automatic", !checked)
              }

              Text {
                width: parent.width
                text: root.historyDetail()
                // Prosa que envuelve: 0,72, como el resto de la prosa del
                // panel. 0,68 es el valor de los rótulos y los foregrounds
                // de control.
                color: Util.alpha(Color.popups.text, 0.72)
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                wrapMode: Text.WordWrap
              }

              // F.5: la explicación completa cabe aquí, desplegable, y no en
              // un tooltip: lo que hace falta leer despacio no puede vivir
              // colgado del ratón, donde el teclado no llega.
              PanelButton {
                id: historyWhyButton
                width: parent.width
                text: (root.historyOpen ? "▾  " : "▸  ") + Strings.t("history.why", root.lang)
                // Alineado con el texto que abre y con el resto de la columna. El
                // kit centra por defecto, y era el único bloque centrado de
                // una página alineada a la izquierda.
                leftAlign: true
                foreground: Util.alpha(Color.popups.text, 0.68)
                Accessible.name: Strings.t("history.why", root.lang)
                Accessible.description: Strings.t("history.why.body", root.lang)
                onFocusEntered: function(item) { root.reveal(item) }
                onClicked: root.historyOpen = !root.historyOpen
              }

              Text {
                width: parent.width
                visible: root.historyOpen
                text: Strings.t("history.why.body", root.lang)
                color: Util.alpha(Color.popups.text, 0.72)
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                wrapMode: Text.WordWrap
                lineHeightMode: Text.ProportionalHeight
                lineHeight: 1.4
              }

              SectionHeading {
                text: Strings.t("settings.cleaning", root.lang)
              }

              SettingRow {
                width: parent.width
                label: Strings.t("settings.formatting", root.lang)
                description: Strings.t("settings.formatting.desc", root.lang)
                checked: root.setting("stripFormatting", true)
                onFocusEntered: function(item) { root.reveal(item) }
                onClicked: if (service) service.updateSetting("stripFormatting", !checked)
              }

              SettingRow {
                width: parent.width
                label: Strings.t("settings.tracking", root.lang)
                description: Strings.t("settings.tracking.desc", root.lang)
                checked: root.setting("removeTracking", true)
                onFocusEntered: function(item) { root.reveal(item) }
                onClicked: if (service) service.updateSetting("removeTracking", !checked)
              }

              SettingRow {
                width: parent.width
                label: Strings.t("settings.invisible", root.lang)
                description: Strings.t("settings.invisible.desc", root.lang)
                checked: root.setting("removeInvisible", true)
                onFocusEntered: function(item) { root.reveal(item) }
                onClicked: if (service) service.updateSetting("removeInvisible", !checked)
              }

              SettingRow {
                width: parent.width
                label: Strings.t("settings.endings", root.lang)
                description: Strings.t("settings.endings.desc", root.lang)
                checked: root.setting("normalizeLineEndings", true)
                onFocusEntered: function(item) { root.reveal(item) }
                onClicked: if (service) service.updateSetting("normalizeLineEndings", !checked)
              }

              // F.5: los cuatro opcionales van bajo divulgación. La nota que
              // lo condicionaba decía «si el panel sigue creciendo»; con la
              // sección de privacidad, creció. Los cuatro que sí vienen
              // puestos de fábrica se quedan a la vista, porque explican lo
              // que el producto hace por defecto.
              PanelButton {
                id: optionalButton
                width: parent.width
                text: (root.optionalOpen ? "▾  " : "▸  ") + Strings.t("settings.optional", root.lang)
                leftAlign: true
                Accessible.name: Strings.t("settings.optional", root.lang)
                onFocusEntered: function(item) { root.reveal(item) }
                onClicked: root.optionalOpen = !root.optionalOpen
              }

              SettingRow {
                width: parent.width
                visible: root.optionalOpen
                label: Strings.t("settings.quotes", root.lang)
                description: Strings.t("settings.quotes.desc", root.lang)
                checked: root.setting("normalizeQuotes", false)
                onFocusEntered: function(item) { root.reveal(item) }
                onClicked: if (service) service.updateSetting("normalizeQuotes", !checked)
              }

              SettingRow {
                width: parent.width
                visible: root.optionalOpen
                label: Strings.t("settings.bullets", root.lang)
                description: Strings.t("settings.bullets.desc", root.lang)
                checked: root.setting("normalizeLists", false)
                onFocusEntered: function(item) { root.reveal(item) }
                onClicked: if (service) service.updateSetting("normalizeLists", !checked)
              }

              SettingRow {
                width: parent.width
                visible: root.optionalOpen
                label: Strings.t("settings.nfc", root.lang)
                description: Strings.t("settings.nfc.desc", root.lang)
                checked: root.setting("normalizeUnicodeNfc", false)
                onFocusEntered: function(item) { root.reveal(item) }
                onClicked: if (service) service.updateSetting("normalizeUnicodeNfc", !checked)
              }

              SettingRow {
                width: parent.width
                visible: root.optionalOpen
                label: Strings.t("settings.trim", root.lang)
                description: Strings.t("settings.trim.desc", root.lang)
                checked: root.setting("trimTrailingWhitespace", false)
                onFocusEntered: function(item) { root.reveal(item) }
                onClicked: if (service) service.updateSetting("trimTrailingWhitespace", !checked)
              }

              // 0011: una sola sección donde había dos formularios idénticos.
              // Las cuatro listas de la 0009 siguen siendo cuatro decisiones
              // independientes; lo que se ha fundido es el formulario, que
              // estaba escrito dos veces con dos rótulos que se diferenciaban
              // en una palabra.
              SectionHeading {
                text: Strings.t("apps.title", root.lang)
              }

              Text {
                width: parent.width
                text: Strings.t("apps.body", root.lang)
                color: Util.alpha(Color.popups.text, 0.72)
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                wrapMode: Text.WordWrap
              }

              // Lo que la lista no puede garantizar, dicho aquí y no en una
              // nota al pie: Wayland no dice quién copió.
              Text {
                width: parent.width
                text: Strings.t("apps.note", root.lang)
                color: Util.alpha(Color.popups.text, 0.72)
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                wrapMode: Text.WordWrap
              }

              // El selector. Ofrece las ventanas abiertas y no las
              // aplicaciones instaladas: la clase que da Hyprland es la misma
              // contra la que compara el demonio, y de las 93 entradas
              // `.desktop` de un escritorio real sólo 23 declaran su
              // `StartupWMClass`. Un catálogo de instaladas daría a elegir
              // nombres que generan reglas que nunca disparan.
              Text {
                text: Strings.t("apps.open", root.lang)
                color: Util.alpha(Color.popups.text, 0.68)
                font.family: Style.font.family
                font.pixelSize: Style.font.body
              }

              Flow {
                id: openWindowChoices
                width: parent.width
                spacing: Style.space(8)

                Repeater {
                  model: service ? service.openWindows : []
                  delegate: PanelButton {
                    required property string modelData
                    text: modelData
                    Accessible.name: Strings.f("apps.open.a11y", root.lang, modelData)
                    onFocusEntered: function(item) { root.reveal(item) }
                    onClicked: root.addApp(modelData)
                  }
                }
              }

              Text {
                width: parent.width
                visible: !service || !service.openWindows || service.openWindows.length === 0
                text: Strings.t("apps.open.none", root.lang)
                color: Util.alpha(Color.popups.text, 0.72)
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                wrapMode: Text.WordWrap
              }

              Text {
                id: classFieldLabel
                text: Strings.t("apps.class", root.lang)
                // El rótulo de un campo, no un encabezado de sección. Iba
                // en negrita a color pleno —11,33:1, exactamente lo mismo que
                // «Privacidad» o «Limpieza», y a un solo escalón de tamaño—
                // así que en pantalla eran indistinguibles y este rótulo abría
                // una sección que no existe.
                color: Util.alpha(Color.popups.text, 0.68)
                font.family: Style.font.family
                font.pixelSize: Style.font.body

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: classField.forceActiveFocus()
                }
              }

              TextField {
                id: classField
                width: parent.width
                implicitHeight: Style.space(44)
                font.pixelSize: Math.max(16, Style.font.body)
                placeholderText: "org.example.Application"
                // El del kit sale de `Qt.darker(foreground, 1.6)` y mide
                // 4,19:1 contra el relleno del campo, por debajo del 4,5
                // que pide la AA para texto. Aquí no es decoración: es la
                // única pista de qué hay que teclear. 0,68 —el alfa de
                // rótulo que el panel ya usa— da 5,55:1.
                placeholderTextColor: Util.alpha(Color.popups.text, 0.68)
                selectByMouse: true
                maximumLength: 256
                Accessible.name: Strings.t("apps.class", root.lang)
                Accessible.description: root.appsError !== ""
                  ? root.appsError
                  : Strings.t("apps.class.hint", root.lang)
                inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
                // Enter hace lo único que hay que hacer aquí. Antes había dos
                // botones idénticos de confirmar y Enter elegía uno de los dos
                // sin decir cuál.
                onAccepted: root.addApp(classField.text)
                onTextChanged: if (root.appsError !== "") root.appsError = ""
                onActiveFocusChanged: if (activeFocus) root.reveal(classField)
              }

              PanelButton {
                id: addAppButton
                width: parent.width
                text: Strings.t("apps.add", root.lang)
                onFocusEntered: function(item) { root.reveal(item) }
                onClicked: root.addApp(classField.text)
              }

              Text {
                id: appsMessage
                width: parent.width
                text: root.appsError !== ""
                  ? (root.appsUrgent ? "⚠ " + root.appsError : root.appsError)
                  : Strings.t("apps.class.hint", root.lang)
                color: root.appsUrgent && root.appsError !== ""
                  ? Color.urgent
                  : Util.alpha(Color.popups.text, 0.68)
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                wrapMode: Text.WordWrap
                // Alerta sólo lo que lo es. «Ya tiene su tarjeta abajo» no
                // interrumpe a nadie: es la pista del campo con otro texto.
                Accessible.role: root.appsUrgent && root.appsError !== ""
                  ? Accessible.AlertMessage
                  : Accessible.StaticText
                Accessible.name: text
              }

              EmptyState {
                width: contentColumn.width
                visible: root.ruledApps().length === 0
                title: Strings.t("apps.none.title", root.lang)
                body: Strings.t("apps.none.body", root.lang)
              }

              // La lista va debajo del formulario y no encima: crece, y si
              // creciera por arriba el formulario se movería bajo la mano
              // cada vez que se añade una aplicación.
              Column {
                id: appsList
                width: parent.width
                spacing: Style.space(24)

                Repeater {
                  model: root.ruledApps()
                  delegate: AppRules {
                    required property string modelData
                    width: appsList.width
                    lang: root.lang
                    appClass: modelData
                    covered: root.hasRule("covered", modelData)
                    blocked: root.hasRule("blocked", modelData)
                    source: root.hasRule("source", modelData)
                    target: root.hasRule("target", modelData)
                    onRuleToggled: function(kind, next) { root.toggleRule(modelData, kind, next) }
                    onRemoveRequested: function(value) { root.removeApp(value) }
                    onFocusEntered: function(item) { root.reveal(item) }
                  }
                }
              }

              // La promesa, antes de «Ayuda y aprendizaje». Vivía dentro del
              // párrafo de «Aplicaciones», heredada de cuando esa sección se
              // llamaba «Privacidad»: allí explicaba una cosa bajo el título
              // de otra. Aquí no reabre la sección que la `0011` fundió —no
              // trae formulario ni encabezado— y deja de ser lo único que el
              // panel no decía en ninguna parte.
              //
              // Va antes del último bloque y no después: el foco no para en
              // un párrafo, así que puesta al final sólo se veía arrastrando
              // la pantalla. Aquí entra en el mismo golpe de vista que los
              // dos botones que sí toman el foco.
              Text {
                width: parent.width
                text: Strings.t("settings.privacy", root.lang)
                color: Util.alpha(Color.popups.text, 0.72)
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                lineHeightMode: Text.ProportionalHeight
                lineHeight: 1.4
                wrapMode: Text.WordWrap
              }

              SectionHeading {
                text: Strings.t("help.title", root.lang)
              }

              Text {
                width: parent.width
                text: Strings.t("help.body", root.lang)
                color: Util.alpha(Color.popups.text, 0.68)
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                lineHeightMode: Text.ProportionalHeight
                lineHeight: 1.45
                wrapMode: Text.WordWrap
              }

              Grid {
                id: learningActions
                width: parent.width
                columns: width < Style.space(360) ? 1 : 2
                columnSpacing: Style.space(8)
                rowSpacing: Style.space(8)

                PanelButton {
                  id: welcomeReplayButton
                  width: (learningActions.width - (learningActions.columns - 1) * learningActions.columnSpacing) / learningActions.columns
                  text: Strings.t("help.welcome", root.lang)
                  Accessible.description: Strings.t("help.welcome.a11y", root.lang)
                  onFocusEntered: function(item) { root.reveal(item) }
                  onClicked: root.showWelcome("settings")
                }

                PanelButton {
                  id: tourReplayButton
                  width: (learningActions.width - (learningActions.columns - 1) * learningActions.columnSpacing) / learningActions.columns
                  text: Strings.t("help.tour", root.lang)
                  Accessible.description: Strings.t("help.tour.a11y", root.lang)
                  onFocusEntered: function(item) { root.reveal(item) }
                  onClicked: root.showTour("settings", "settings")
                }
              }

              PrimaryButton {
                id: onboardingDoneButton
                width: parent.width
                visible: root.onboardingSettings
                text: Strings.t("onboarding.done", root.lang)
                onClicked: root.finishOnboarding()
              }


            }
          }
        }
        }
      }
    }
  }
}
