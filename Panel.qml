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

  // Del ajuste del usuario, y si está en «auto» del locale del sistema.
  // Se pasa a cada componente en vez de guardarlo en el módulo JS, para que
  // los bindings se reevalúen solos al cambiarlo.
  readonly property string lang: {
    var chosen = String(setting("language", "auto"))
    if (chosen === "en" || chosen === "es") return chosen
    return Strings.fromLocale(Qt.locale().name)
  }

  readonly property string peekVerdict: {
    if (!service) return Strings.t("verdict.preparing", root.lang)
    if (!peek || peek.eligible !== true) {
      var why = peek ? String(peek.reason || "") : ""
      if (why === "sensitive") return Strings.t("verdict.sensitive", root.lang)
      if (why === "image") return Strings.t("verdict.image", root.lang)
      if (why === "files") return Strings.t("verdict.files", root.lang)
      if (why === "empty") return Strings.t("verdict.empty", root.lang)
      if (why === "structured") return Strings.t("verdict.structured", root.lang)
      return Strings.t("verdict.nothing", root.lang)
    }
    return peekChanges ? Strings.t("verdict.cleanable", root.lang) : Strings.t("verdict.clean", root.lang)
  }

  readonly property string peekDetail: {
    if (!peek || peek.eligible !== true) {
      var why = peek ? String(peek.reason || "") : ""
      if (why === "sensitive") return Strings.t("detail.sensitive", root.lang)
      if (why === "image") return Strings.t("detail.image", root.lang)
      if (why === "files") return Strings.t("detail.files", root.lang)
      if (why === "empty") return Strings.t("detail.empty", root.lang)
      return Strings.t("detail.nothing", root.lang)
    }
    return peekChanges
      ? Strings.t("detail.cleanable", root.lang)
      : Strings.t("detail.clean", root.lang)
  }

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
    if (rule === "tracking") return Strings.t("rule.tracking", root.lang)
    if (rule === "invisible") return Strings.t("rule.invisible", root.lang)
    if (rule === "line_endings") return Strings.t("rule.line_endings", root.lang)
    if (rule === "rich_text") return Strings.t("rule.rich_text", root.lang)
    return rule
  }

  function chooseLanguage(value) {
    if (service) service.updateSetting("language", value)
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
    if (!service) return Strings.t("status.unavailable", root.lang)
    if (service.dependencyError !== "") return Strings.f("status.deps", root.lang, service.dependencyError)
    if (watcherState === "degraded") return Strings.t("status.degraded", root.lang)
    if (watcherState === "restarting") return Strings.t("status.restarting", root.lang)
    if (!setting("automatic", true)) return Strings.t("status.paused", root.lang)
    if (service.status && service.status.skipNext === true) return Strings.t("status.willskip", root.lang)
    if (service.status && service.status.lastResult === "cleaned") return Strings.t("status.done", root.lang)
    return Strings.t("status.idle", root.lang)
  }

  function historyDetail() {
    if (!setting("automatic", true))
      return Strings.t("hint.manual", root.lang)
    if (setting("removeTracking", true) || setting("removeInvisible", true))
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
    if (data.result === "ok") return Strings.t("fb.skip", root.lang)
    if (data.result === "error") return Strings.t("fb.error", root.lang)
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
      fieldError = Strings.t("excl.undetected", root.lang)
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

          lang: root.lang
          id: welcomePage
          anchors.fill: parent
          visible: root.viewMode === "welcome"
          enabled: visible
          returning: root.learningOrigin === "settings"
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
              id: brandText
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              text: Strings.t("app.name", root.lang)
              color: Color.popups.text
              font.family: Style.font.family
              // Un escalón por encima del subtítulo, pero sin llegar al del
              // veredicto: la cabecera es identidad, no contenido, y si
              // empatan compiten por la misma mirada.
              font.pixelSize: Style.font.title
              font.bold: true
              font.letterSpacing: -Style.spaceReal(0.2)
            }

            Button {
              id: optionsButton
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              implicitHeight: Style.space(44)
              text: root.onboardingSettings
                ? Strings.t("nav.skip", root.lang)
                : (root.panelPage === "settings" ? Strings.t("nav.back", root.lang) : Strings.t("nav.options", root.lang))
              tooltipText: root.onboardingSettings
                ? Strings.t("nav.skip.a11y", root.lang)
                : (root.panelPage === "settings" ? Strings.t("nav.back.a11y", root.lang) : Strings.t("nav.options.a11y", root.lang))
              focusable: true
              bordered: true
              foreground: root.panelPage === "settings" ? Color.accent : Util.alpha(Color.popups.text, 0.68)
              Accessible.role: Accessible.Button
              Accessible.name: root.onboardingSettings
                ? Strings.t("nav.skip.a11y", root.lang)
                : (root.panelPage === "settings" ? Strings.t("nav.back.a11y", root.lang) : Strings.t("nav.options.a11y", root.lang))
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

            lang: root.lang
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

                lang: root.lang
                width: contentColumn.width
                visible: root.peekReady
                label: root.peekChanges ? Strings.t("row.now", root.lang) : Strings.t("row.single", root.lang)
                body: root.peekReady ? String(root.peek.original || "") : ""
                shown: root.showBefore
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
                  text: service && service.actionBusy ? Strings.t("action.applying", root.lang) : Strings.t("action.apply", root.lang)
                  iconText: service && service.actionBusy ? "" : "󰅍"
                  enabled: service && !service.actionBusy && root.peekChanges
                  onClicked: root.runAction("cleanNow")
                }

                Button {
                  id: skipButton2
                  width: (clipboardActions.width - (clipboardActions.columns - 1) * clipboardActions.columnSpacing) / clipboardActions.columns
                  implicitHeight: Style.space(44)
                  text: service && service.status && service.status.skipNext ? Strings.t("action.skipped", root.lang) : Strings.t("action.skip", root.lang)
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
                    ? Strings.t("footnote.safe", root.lang)
                    : (root.peek && root.peek.reason === "sensitive"
                      ? Strings.t("footnote.sensitive", root.lang)
                      : Strings.t("footnote.nothing", root.lang)))
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
              Text {
                text: Strings.t("settings.language", root.lang)
                color: Color.popups.text
                font.family: Style.font.family
                font.pixelSize: Style.font.subtitle
                font.bold: true
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
                  delegate: Button {
                    required property var modelData
                    readonly property bool chosen: String(root.setting("language", "auto")) === modelData.value
                    width: (languageChoices.width - (languageChoices.columns - 1) * languageChoices.columnSpacing) / languageChoices.columns
                    implicitHeight: Style.space(44)
                    text: Strings.t(modelData.key, root.lang)
                    focusable: true
                    bordered: true
                    foreground: chosen ? Color.accent : Util.alpha(Color.popups.text, 0.68)
                    Accessible.role: Accessible.RadioButton
                    Accessible.name: text
                    Accessible.checked: chosen
                    Accessible.onPressAction: root.chooseLanguage(modelData.value)
                    onActiveFocusChanged: if (activeFocus) root.reveal(this)
                    onClicked: root.chooseLanguage(modelData.value)
                  }
                }
              }

              Text {
                text: Strings.t("settings.mode", root.lang)
                color: Color.popups.text
                font.family: Style.font.family
                font.pixelSize: Style.font.subtitle
                font.bold: true
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
                color: Util.alpha(Color.popups.text, 0.68)
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                wrapMode: Text.WordWrap
              }

              Text {
                text: Strings.t("settings.cleaning", root.lang)
                color: Color.popups.text
                font.family: Style.font.family
                font.pixelSize: Style.font.subtitle
                font.bold: true
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

              Text {
                text: Strings.t("settings.optional", root.lang)
                color: Color.popups.text
                font.family: Style.font.family
                font.pixelSize: Style.font.subtitle
                font.bold: true
              }

              SettingRow {
                width: parent.width
                label: Strings.t("settings.quotes", root.lang)
                description: Strings.t("settings.quotes.desc", root.lang)
                checked: root.setting("normalizeQuotes", false)
                onFocusEntered: function(item) { root.reveal(item) }
                onClicked: if (service) service.updateSetting("normalizeQuotes", !checked)
              }

              SettingRow {
                width: parent.width
                label: Strings.t("settings.bullets", root.lang)
                description: Strings.t("settings.bullets.desc", root.lang)
                checked: root.setting("normalizeLists", false)
                onFocusEntered: function(item) { root.reveal(item) }
                onClicked: if (service) service.updateSetting("normalizeLists", !checked)
              }

              SettingRow {
                width: parent.width
                label: Strings.t("settings.nfc", root.lang)
                description: Strings.t("settings.nfc.desc", root.lang)
                checked: root.setting("normalizeUnicodeNfc", false)
                onFocusEntered: function(item) { root.reveal(item) }
                onClicked: if (service) service.updateSetting("normalizeUnicodeNfc", !checked)
              }

              SettingRow {
                width: parent.width
                label: Strings.t("settings.trim2", root.lang)
                description: "No modifica la indentación ni los saltos."
                checked: root.setting("trimTrailingWhitespace", false)
                onFocusEntered: function(item) { root.reveal(item) }
                onClicked: if (service) service.updateSetting("trimTrailingWhitespace", !checked)
              }

              Text {
                text: Strings.t("excl.title", root.lang)
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
                  : Strings.t("excl.detected", root.lang)
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
                title: Strings.t("excl.none.title", root.lang)
                body: Strings.t("excl.none.body", root.lang)
              }

              Repeater {
                model: root.setting("sourceExclusions", [])
                delegate: ExcludedAppRow {
                  required property string modelData
                  width: contentColumn.width
                  appClass: modelData
                  scopeLabel: Strings.t("excl.source", root.lang)
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
                  scopeLabel: Strings.t("excl.target", root.lang)
                  onFocusEntered: function(item) { root.reveal(item) }
                  onRemoveRequested: function(value) { if (service) service.removeExclusion("target", value) }
                }
              }

              Text {
                id: classFieldLabel
                text: Strings.t("excl.class", root.lang)
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
                Accessible.name: Strings.t("excl.class", root.lang)
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
                  text: Strings.t("excl.addSource", root.lang)
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
                  text: Strings.t("excl.addTarget", root.lang)
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
                  : Strings.t("excl.case", root.lang)
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
                text: Strings.t("help.title", root.lang)
                color: Color.popups.text
                font.family: Style.font.family
                font.pixelSize: Style.font.subtitle
                font.bold: true
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

                Button {
                  id: welcomeReplayButton
                  width: (learningActions.width - (learningActions.columns - 1) * learningActions.columnSpacing) / learningActions.columns
                  implicitHeight: Style.space(44)
                  text: Strings.t("help.welcome", root.lang)
                  focusable: true
                  bordered: true
                  foreground: Color.popups.text
                  Accessible.role: Accessible.Button
                  Accessible.name: text
                  Accessible.description: Strings.t("help.welcome.a11y", root.lang)
                  Accessible.onPressAction: root.showWelcome("settings")
                  onActiveFocusChanged: if (activeFocus) root.reveal(welcomeReplayButton)
                  onClicked: root.showWelcome("settings")
                }

                Button {
                  id: tourReplayButton
                  width: (learningActions.width - (learningActions.columns - 1) * learningActions.columnSpacing) / learningActions.columns
                  implicitHeight: Style.space(44)
                  text: Strings.t("help.tour", root.lang)
                  focusable: true
                  bordered: true
                  foreground: Color.popups.text
                  Accessible.role: Accessible.Button
                  Accessible.name: text
                  Accessible.description: Strings.t("help.tour.a11y", root.lang)
                  Accessible.onPressAction: root.showTour("settings", "settings")
                  onActiveFocusChanged: if (activeFocus) root.reveal(tourReplayButton)
                  onClicked: root.showTour("settings", "settings")
                }
              }

              Text {
                text: Strings.t("privacy.title", root.lang)
                color: Color.popups.text
                font.family: Style.font.family
                font.pixelSize: Style.font.subtitle
                font.bold: true
              }

              PrimaryButton {
                id: onboardingDoneButton
                width: parent.width
                visible: root.onboardingSettings
                text: Strings.t("onboarding.done", root.lang)
                iconText: "✓"
                onClicked: root.finishOnboarding()
              }

              Text {
                width: parent.width
                text: Strings.t("privacy.body", root.lang)
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
