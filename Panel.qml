import QtQuick
import QtQuick.Controls as QQC
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "components"

Item {
  id: root

  property var shell: null
  property var manifest: null
  property var service: null
  property bool opened: false
  property string fieldError: ""
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
  // La pantalla frecuente informa; los ajustes viven detrás del engranaje.
  property string panelPage: "clipboard"

  readonly property string peekVerdict: {
    if (!service) return "Preparando…"
    if (!peek || peek.eligible !== true) {
      var why = peek ? String(peek.reason || "") : ""
      if (why === "sensitive") return "Marcado como sensible"
      if (why === "image") return "Una imagen no se toca"
      if (why === "files") return "Archivos, intactos"
      if (why === "empty") return "Nada copiado todavía"
      if (why === "structured") return "Formato estructurado, intacto"
      return "Nada que limpiar aquí"
    }
    return peekChanges ? "Esto se puede limpiar" : "Ya está limpio"
  }

  readonly property string peekDetail: {
    if (!peek || peek.eligible !== true) {
      var why = peek ? String(peek.reason || "") : ""
      if (why === "sensitive") return "Tu gestor de contraseñas marcó esta copia. OmaPlain no la lee, no la muestra y no la reescribe."
      if (why === "image") return "OmaPlain ni la lee. Las capturas llegan a su destino byte a byte."
      if (why === "files") return "Copiar archivos mueve rutas y permisos. Reescribir eso rompería el pegado."
      if (why === "empty") return "Copia algo y aquí verás qué haría OmaPlain con ello."
      return "OmaPlain lo ha mirado y lo deja como está."
    }
    return peekChanges
      ? "Así está ahora y así quedaría."
      : "OmaPlain lo ha mirado y no hay nada que retirar."
  }

  readonly property var peekApplied: peek && peek.applied ? peek.applied : []
  readonly property var peekTypes: peek && peek.types ? peek.types : []
  readonly property var peekTypesAfter: peek && peek.typesAfter ? peek.typesAfter : []
  // El único caso en que el texto no cambia y sí se reescribe: se retira la
  // versión con formato. Ahí el antes y el después son los tipos.
  readonly property bool peekFormatOnly: peekChanges
    && String(peek.original || "") === String(peek.cleaned || "")

  function settingFor(rule) {
    if (rule === "tracking") return "Seguimiento"
    if (rule === "invisible") return "Invisibles"
    if (rule === "line_endings") return "Saltos"
    if (rule === "rich_text") return "Formato"
    return ""
  }

  readonly property var peek: service && service.peekResult ? service.peekResult : ({ eligible: false })
  readonly property bool peekReady: peek && peek.eligible === true
  readonly property bool peekChanges: peekReady && peek.changed === true

  readonly property var settings: service && service.settings ? service.settings : ({})
  readonly property string pluginId: manifest && manifest.id ? String(manifest.id) : "io.github.r-bart.omaplain"
  readonly property string watcherState: service ? service.watcherState : "starting"
  readonly property int onboardingVersion: 2
  // Marca el paso de ajustes del recorrido inicial: se enseñan, no se
  // imponen, así que llevan una salida visible y rotulada (decisión 0006).
  property bool onboardingSettings: false

  function ruleLabel(rule) {
    if (rule === "tracking") return "Parámetros de seguimiento"
    if (rule === "invisible") return "Caracteres invisibles"
    if (rule === "line_endings") return "Finales de línea CRLF"
    if (rule === "rich_text") return "Formato enriquecido"
    return rule
  }

  function togglePage() {
    if (onboardingSettings) { finishOnboarding(); return }
    panelPage = panelPage === "settings" ? "clipboard" : "settings"
    scroll.contentY = 0
    Qt.callLater(root.applyViewFocus)
  }

  function open(payloadJson) {
    if (service) service.captureCurrentApp()
    viewMode = Number(setting("onboardingVersion", 0)) >= onboardingVersion ? "main" : "welcome"
    learningOrigin = viewMode === "welcome" ? "first-run" : "main"
    tourEntry = "welcome"
    tourStep = 0
    mainFocusTarget = "clean"
    opened = true
    if (service) service.requestPeek()
    feedback = ""
    fieldError = ""
    focusReady = false
    scroll.contentY = 0
    initialFocusTimer.restart()
  }

  function close() {
    opened = false
    focusReady = false
    initialFocusTimer.stop()
    feedbackTimer.stop()
    fieldError = ""
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
    if (!service) return "El servicio todavía no está disponible."
    if (service.dependencyError !== "") return "Faltan dependencias: " + service.dependencyError
    if (watcherState === "degraded") return "El watcher ha fallado varias veces. Las acciones manuales siguen disponibles."
    if (watcherState === "restarting") return "Reiniciando el watcher…"
    if (!setting("automatic", true)) return "La limpieza automática está pausada. Las acciones manuales siguen disponibles."
    if (service.status && service.status.skipNext === true) return "Se omitirá la próxima copia elegible."
    if (service.status && service.status.lastResult === "cleaned") return "Listo · última limpieza completada"
    return "OmaPlain ordena el formato y deja intacto todo lo que no puede limpiar con seguridad."
  }

  function historyDetail() {
    if (!setting("automatic", true))
      return "La limpieza manual y «pegar limpio» siguen disponibles."
    if (setting("removeTracking", true) || setting("removeInvisible", true))
      return "El historial puede conservar también el original cuando cambian caracteres."
    return "La copia automática conserva los caracteres del texto."
  }

  function actionMessage(raw) {
    var data = {}
    try { data = JSON.parse(String(raw || "{}")) } catch (error) {}
    feedbackError = data.result === "error"
    if (data.result === "cleaned") return "Portapapeles limpio"
    if (data.result === "unchanged") return "Ya estaba limpio"
    if (data.reason === "image") return "No se ha modificado: es una imagen"
    if (data.reason === "files") return "No se ha modificado: contiene archivos"
    if (data.reason === "sensitive") return "Contenido sensible protegido"
    if (data.reason === "too_large") return "No se ha modificado: supera 1 MB"
    if (data.reason === "target_excluded" || data.reason === "source_excluded") return "No se ha modificado: aplicación excluida"
    if (data.result === "bypassed") return "No se ha modificado: contenido no compatible"
    if (data.result === "ok") return "Se omitirá la próxima copia"
    if (data.result === "error") return "No se pudo limpiar. El texto original sigue intacto."
    return ""
  }

  function runAction(name) {
    if (!service) return
    var result = name === "cleanNow" ? service.cleanNow() : service.skipNext()
    if (result === "busy") {
      feedbackError = false
      feedback = "OmaPlain ya está procesando otra acción"
      feedbackTimer.restart()
    }
  }

  function submitExclusion(scope) {
    if (!service) return
    var value = classField.text.trim()
    var result = service.addExclusion(scope, value)
    if (result === "invalid") {
      fieldError = "Introduce una clase de aplicación válida"
      Qt.callLater(function() { root.reveal(fieldMessage) })
      return
    }
    if (result === "duplicate") {
      fieldError = "Esta aplicación ya está excluida"
      Qt.callLater(function() { root.reveal(fieldMessage) })
      return
    }
    fieldError = ""
    classField.text = ""
  }

  function excludeDetected() {
    if (!service || !service.currentAppClass) {
      fieldError = "No se ha detectado una aplicación"
      Qt.callLater(function() { root.reveal(fieldMessage) })
      return
    }
    classField.text = service.currentAppClass
    submitExclusion("source")
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
      else applyButton.forceActiveFocus()
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
    }
  }

  Timer {
    id: feedbackTimer
    interval: 2500
    repeat: false
    onTriggered: root.feedback = ""
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
        height: Math.min(Style.space(720), parent.height - Style.space(32))
        radius: Style.cornerRadius
        color: Color.popups.background
        borderSpec: Border.surfaceSpec("popups", "border", Color.popups.border, Math.max(1, Style.normalBorderWidth))

        MouseArea { anchors.fill: parent; onClicked: {} }

        WelcomePage {
          id: welcomePage
          anchors.fill: parent
          visible: root.viewMode === "welcome"
          enabled: visible
          returning: root.learningOrigin === "settings"
          onStartRequested: root.showTour(root.learningOrigin, "welcome")
          onDismissRequested: root.showMain(true)
        }

        TourPage {
          id: tourPage
          anchors.fill: parent
          visible: root.viewMode === "tour"
          enabled: visible
          step: root.tourStep
          replaying: root.learningOrigin === "settings"
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

          Item {
            width: parent.width
            height: Style.space(38)

            Text {
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              text: "OmaPlain"
              color: Color.popups.text
              font.family: Style.font.family
              font.pixelSize: Style.font.subtitle
              font.bold: true
            }

            Button {
              id: optionsButton
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              implicitHeight: Style.space(44)
              text: root.onboardingSettings
                ? "Saltar  󰅂"
                : (root.panelPage === "settings" ? "󰅁  Volver" : "󰢻  Opciones")
              tooltipText: root.onboardingSettings
                ? "Saltar los ajustes e ir al panel"
                : (root.panelPage === "settings" ? "Volver al portapapeles" : "Abrir opciones")
              focusable: true
              bordered: true
              foreground: root.panelPage === "settings" ? Color.accent : Util.alpha(Color.popups.text, 0.68)
              Accessible.role: Accessible.Button
              Accessible.name: root.onboardingSettings
                ? "Saltar los ajustes e ir al panel"
                : (root.panelPage === "settings" ? "Volver al portapapeles" : "Abrir opciones")
              Accessible.onPressAction: root.togglePage()
              onClicked: root.togglePage()
            }

            Rectangle {
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.bottom: parent.bottom
              height: Math.max(1, Style.normalBorderWidth)
              color: Util.alpha(Color.popups.text, 0.14)
            }
          }

          StatusHeader {
            width: parent.width
            visible: root.panelPage === "clipboard"
            state: !root.setting("automatic", true) && root.watcherState === "running" ? "paused" : root.watcherState
            detail: root.statusDetail()
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
                width: contentColumn.width
                visible: root.peekReady
                label: root.peekChanges ? "Ahora" : "En el portapapeles"
                body: root.peekReady ? String(root.peek.original || "") : ""
                shown: root.showBefore
                seed: 11
                onRevealRequested: root.showBefore = true
                onHideRequested: root.showBefore = false
                onFocusEntered: function(item) { root.reveal(item) }
              }

              ClipboardRow {
                width: contentColumn.width
                visible: root.peekChanges
                label: "Quedaría"
                body: root.peekChanges ? String(root.peek.cleaned || "") : ""
                shown: root.showAfter
                seed: 29
                onRevealRequested: root.showAfter = true
                onHideRequested: root.showAfter = false
                onFocusEntered: function(item) { root.reveal(item) }
              }

              // Cuando sólo se retira el formato, las dos filas salen
              // idénticas: el cambio hay que enseñarlo aquí o no se ve.
              MimeChips {
                width: parent.width
                visible: root.peekFormatOnly
                types: root.peekTypes
                typesAfter: root.peekTypesAfter
              }

              // De un bypass no se enseña contenido, pero sí de qué está
              // hecho: es lo que permite entender por qué no se toca.
              MimeChips {
                width: parent.width
                visible: !root.peekReady && root.peekTypes.length > 0
                types: root.peekTypes
              }

              // El desglose: qué regla actuó y qué ajuste la gobierna.
              Column {
                width: parent.width
                visible: root.peekChanges
                spacing: Style.space(6)

                Repeater {
                  model: root.peekApplied
                  delegate: Item {
                    required property string modelData
                    width: clipboardPage.width
                    height: Math.max(ruleText.implicitHeight, ruleChip.implicitHeight)

                    Accessible.role: Accessible.StaticText
                    Accessible.name: "Se retira: " + root.ruleLabel(modelData)
                      + ", según el ajuste " + root.settingFor(modelData)

                    Text {
                      id: ruleText
                      anchors.left: parent.left
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
                      anchors.verticalCenter: parent.verticalCenter
                      label: root.settingFor(modelData)
                      visible: label !== ""
                    }
                  }
                }
              }

              Grid {
                id: clipboardActions
                width: parent.width
                // De una imagen, un archivo o un secreto no hay nada que
                // aplicar ni que omitir: no se llegó a mirar.
                visible: root.peekReady
                columns: width < Style.space(410) ? 1 : 2
                columnSpacing: Style.space(8)
                rowSpacing: Style.space(8)

                PrimaryButton {
                  id: applyButton
                  width: (clipboardActions.width - (clipboardActions.columns - 1) * clipboardActions.columnSpacing) / clipboardActions.columns
                  text: service && service.actionBusy ? "Limpiando…" : "Aplicar al portapapeles"
                  iconText: service && service.actionBusy ? "" : "󰅍"
                  enabled: service && !service.actionBusy && root.peekChanges
                  onClicked: root.runAction("cleanNow")
                }

                Button {
                  id: skipButton2
                  width: (clipboardActions.width - (clipboardActions.columns - 1) * clipboardActions.columnSpacing) / clipboardActions.columns
                  implicitHeight: Style.space(44)
                  text: service && service.status && service.status.skipNext ? "Próxima copia omitida" : "Omitir la próxima copia"
                  focusable: true
                  bordered: true
                  foreground: Color.popups.text
                  enabled: service && !service.actionBusy
                  Accessible.role: Accessible.Button
                  Accessible.name: text
                  Accessible.onPressAction: root.runAction("skipNext")
                  onActiveFocusChanged: if (activeFocus) root.reveal(skipButton2)
                  onClicked: root.runAction("skipNext")
                }
              }

              Text {
                width: parent.width
                text: root.feedback !== ""
                  ? root.feedback
                  : (root.peekReady
                    ? "El original permanece intacto si la limpieza no es segura."
                    : (root.peek && root.peek.reason === "sensitive"
                      ? "Revelar no está disponible para contenido marcado como sensible."
                      : "No hay nada que limpiar, así que no hay acción que ofrecer."))
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
                    text: "Último paso"
                    color: Color.accent
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: Style.spaceReal(0.9)
                  }

                  Text {
                    width: parent.width
                    text: "Esto es lo que puedes ajustar. Ya viene todo configurado de forma segura, así que puedes dejarlo tal cual."
                    color: Util.alpha(Color.popups.text, 0.78)
                    font.family: Style.font.family
                    font.pixelSize: Style.font.bodySmall
                    lineHeightMode: Text.ProportionalHeight
                    lineHeight: 1.45
                    wrapMode: Text.WordWrap
                  }
                }
              }

              Text {
                text: "Modo"
                color: Color.popups.text
                font.family: Style.font.family
                font.pixelSize: Style.font.subtitle
                font.bold: true
              }

              SettingRow {
                id: automaticToggle
                width: parent.width
                label: "Limpiar automáticamente"
                description: "Convierte en texto limpio cada copia que sea segura."
                checked: root.setting("automatic", true)
                onFocusEntered: function(item) { root.reveal(item) }
                onClicked: if (service) service.updateSetting("automatic", !checked)
              }

              Text {
                width: parent.width
                text: root.historyDetail()
                color: Util.alpha(Color.popups.text, 0.68)
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                wrapMode: Text.WordWrap
              }

              Text {
                text: "Limpieza"
                color: Color.popups.text
                font.family: Style.font.family
                font.pixelSize: Style.font.subtitle
                font.bold: true
              }

              SettingRow {
                width: parent.width
                label: "Retirar formato"
                description: "Pega usando solo la representación de texto plano."
                checked: root.setting("stripFormatting", true)
                onFocusEntered: function(item) { root.reveal(item) }
                onClicked: if (service) service.updateSetting("stripFormatting", !checked)
              }

              SettingRow {
                width: parent.width
                label: "Retirar parámetros de seguimiento"
                description: "Solo actúa cuando todo el contenido es una URL segura."
                checked: root.setting("removeTracking", true)
                onFocusEntered: function(item) { root.reveal(item) }
                onClicked: if (service) service.updateSetting("removeTracking", !checked)
              }

              SettingRow {
                width: parent.width
                label: "Retirar invisibles no semánticos"
                description: "Conserva emoji, escritura RTL y marcas de idioma."
                checked: root.setting("removeInvisible", true)
                onFocusEntered: function(item) { root.reveal(item) }
                onClicked: if (service) service.updateSetting("removeInvisible", !checked)
              }

              SettingRow {
                width: parent.width
                label: "Normalizar finales de línea"
                description: "Convierte CRLF y CR en LF sin quitar el salto final."
                checked: root.setting("normalizeLineEndings", true)
                onFocusEntered: function(item) { root.reveal(item) }
                onClicked: if (service) service.updateSetting("normalizeLineEndings", !checked)
              }

              Text {
                text: "Opcionales"
                color: Color.popups.text
                font.family: Style.font.family
                font.pixelSize: Style.font.subtitle
                font.bold: true
              }

              SettingRow {
                width: parent.width
                label: "Normalizar comillas"
                description: "Convierte comillas tipográficas en comillas rectas."
                checked: root.setting("normalizeQuotes", false)
                onFocusEntered: function(item) { root.reveal(item) }
                onClicked: if (service) service.updateSetting("normalizeQuotes", !checked)
              }

              SettingRow {
                width: parent.width
                label: "Normalizar viñetas"
                description: "Convierte viñetas al inicio de línea en guiones."
                checked: root.setting("normalizeLists", false)
                onFocusEntered: function(item) { root.reveal(item) }
                onClicked: if (service) service.updateSetting("normalizeLists", !checked)
              }

              SettingRow {
                width: parent.width
                label: "Normalizar Unicode NFC"
                description: "Puede cambiar la representación exacta del texto."
                checked: root.setting("normalizeUnicodeNfc", false)
                onFocusEntered: function(item) { root.reveal(item) }
                onClicked: if (service) service.updateSetting("normalizeUnicodeNfc", !checked)
              }

              SettingRow {
                width: parent.width
                label: "Retirar espacios al final de línea"
                description: "No modifica la indentación ni los saltos."
                checked: root.setting("trimTrailingWhitespace", false)
                onFocusEntered: function(item) { root.reveal(item) }
                onClicked: if (service) service.updateSetting("trimTrailingWhitespace", !checked)
              }

              Text {
                text: "Aplicaciones excluidas"
                color: Color.popups.text
                font.family: Style.font.family
                font.pixelSize: Style.font.subtitle
                font.bold: true
              }

              Button {
                id: detectedButton
                width: parent.width
                implicitHeight: Style.space(44)
                text: service && service.currentAppClass
                  ? "Excluir " + service.currentAppClass + " del modo automático"
                  : "Excluir la aplicación detectada"
                focusable: true
                bordered: true
                foreground: Color.popups.text
                Accessible.role: Accessible.Button
                Accessible.name: text
                Accessible.onPressAction: root.excludeDetected()
                onActiveFocusChanged: if (activeFocus) root.reveal(detectedButton)
                onClicked: root.excludeDetected()
              }

              EmptyState {
                width: contentColumn.width
                visible: root.setting("sourceExclusions", []).length === 0
                  && root.setting("targetExclusions", []).length === 0
                title: "Ninguna aplicación excluida"
                body: "OmaPlain limpia el texto que copies en cualquier aplicación. Excluye una como origen para que lo que copies en ella pase intacto, o como destino para no pegar limpio dentro de ella."
              }

              Repeater {
                model: root.setting("sourceExclusions", [])
                delegate: ExcludedAppRow {
                  required property string modelData
                  width: contentColumn.width
                  appClass: modelData
                  scopeLabel: "Origen · modo automático"
                  onFocusEntered: function(item) { root.reveal(item) }
                  onRemoveRequested: function(value) { if (service) service.removeExclusion("source", value) }
                }
              }

              Repeater {
                model: root.setting("targetExclusions", [])
                delegate: ExcludedAppRow {
                  required property string modelData
                  width: contentColumn.width
                  appClass: modelData
                  scopeLabel: "Destino · pegar limpio"
                  onFocusEntered: function(item) { root.reveal(item) }
                  onRemoveRequested: function(value) { if (service) service.removeExclusion("target", value) }
                }
              }

              Text {
                id: classFieldLabel
                text: "Clase de aplicación"
                color: Color.popups.text
                font.family: Style.font.family
                font.pixelSize: Style.font.body
                font.bold: true

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
                selectByMouse: true
                maximumLength: 256
                Accessible.name: "Clase de aplicación"
                Accessible.description: root.fieldError !== ""
                  ? root.fieldError
                  : "Clase exacta de Hyprland que se excluirá"
                inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
                onAccepted: root.submitExclusion("source")
                onTextChanged: if (root.fieldError !== "") root.fieldError = ""
                onActiveFocusChanged: if (activeFocus) root.reveal(classField)
              }

              Grid {
                width: parent.width
                columns: width < Style.space(360) ? 1 : 2
                columnSpacing: Style.space(8)
                rowSpacing: Style.space(8)

                Button {
                  id: addSourceButton
                  width: (parent.width - (parent.columns > 1 ? parent.columnSpacing : 0)) / parent.columns
                  implicitHeight: Style.space(44)
                  text: "Añadir como origen"
                  focusable: true
                  bordered: true
                  foreground: Color.popups.text
                  Accessible.role: Accessible.Button
                  Accessible.name: text
                  Accessible.onPressAction: root.submitExclusion("source")
                  onActiveFocusChanged: if (activeFocus) root.reveal(addSourceButton)
                  onClicked: root.submitExclusion("source")
                }

                Button {
                  id: addTargetButton
                  width: (parent.width - (parent.columns > 1 ? parent.columnSpacing : 0)) / parent.columns
                  implicitHeight: Style.space(44)
                  text: "Añadir como destino"
                  focusable: true
                  bordered: true
                  foreground: Color.popups.text
                  Accessible.role: Accessible.Button
                  Accessible.name: text
                  Accessible.onPressAction: root.submitExclusion("target")
                  onActiveFocusChanged: if (activeFocus) root.reveal(addTargetButton)
                  onClicked: root.submitExclusion("target")
                }
              }

              Text {
                id: fieldMessage
                width: parent.width
                text: root.fieldError !== ""
                  ? "⚠ " + root.fieldError
                  : "Distingue entre mayúsculas y minúsculas."
                color: root.fieldError !== ""
                  ? Color.urgent
                  : Util.alpha(Color.popups.text, 0.68)
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                wrapMode: Text.WordWrap
                Accessible.role: root.fieldError !== "" ? Accessible.AlertMessage : Accessible.StaticText
                Accessible.name: text
              }

              Text {
                text: "Ayuda y aprendizaje"
                color: Color.popups.text
                font.family: Style.font.family
                font.pixelSize: Style.font.subtitle
                font.bold: true
              }

              Text {
                width: parent.width
                text: "Vuelve a la explicación inicial o repite el recorrido sin cambiar tu configuración."
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

                Button {
                  id: welcomeReplayButton
                  width: (learningActions.width - (learningActions.columns - 1) * learningActions.columnSpacing) / learningActions.columns
                  implicitHeight: Style.space(44)
                  text: "Revisar bienvenida"
                  focusable: true
                  bordered: true
                  foreground: Color.popups.text
                  Accessible.role: Accessible.Button
                  Accessible.name: text
                  Accessible.description: "Abre de nuevo la explicación de OmaPlain"
                  Accessible.onPressAction: root.showWelcome("settings")
                  onActiveFocusChanged: if (activeFocus) root.reveal(welcomeReplayButton)
                  onClicked: root.showWelcome("settings")
                }

                Button {
                  id: tourReplayButton
                  width: (learningActions.width - (learningActions.columns - 1) * learningActions.columnSpacing) / learningActions.columns
                  implicitHeight: Style.space(44)
                  text: "Repetir mini tour"
                  focusable: true
                  bordered: true
                  foreground: Color.popups.text
                  Accessible.role: Accessible.Button
                  Accessible.name: text
                  Accessible.description: "Inicia de nuevo el recorrido de tres pasos"
                  Accessible.onPressAction: root.showTour("settings", "settings")
                  onActiveFocusChanged: if (activeFocus) root.reveal(tourReplayButton)
                  onClicked: root.showTour("settings", "settings")
                }
              }

              Text {
                text: "Privacidad"
                color: Color.popups.text
                font.family: Style.font.family
                font.pixelSize: Style.font.subtitle
                font.bold: true
              }

              PrimaryButton {
                id: onboardingDoneButton
                width: parent.width
                visible: root.onboardingSettings
                text: "Abrir OmaPlain"
                iconText: "✓"
                onClicked: root.finishOnboarding()
              }

              Text {
                width: parent.width
                text: "Todo ocurre en este equipo. OmaPlain no guarda el texto copiado. El historial pertenece a Omarchy."
                color: Util.alpha(Color.popups.text, 0.72)
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                wrapMode: Text.WordWrap
              }
            }
          }
        }
        }
      }
    }
  }
}
