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

  readonly property var settings: service && service.settings ? service.settings : ({})
  readonly property string pluginId: manifest && manifest.id ? String(manifest.id) : "io.github.r-bart.omaplain"
  readonly property string watcherState: service ? service.watcherState : "starting"
  readonly property int onboardingVersion: 1

  function open(payloadJson) {
    if (service) service.captureCurrentApp()
    viewMode = Number(setting("onboardingVersion", 0)) >= onboardingVersion ? "main" : "welcome"
    learningOrigin = viewMode === "welcome" ? "first-run" : "main"
    tourEntry = "welcome"
    tourStep = 0
    mainFocusTarget = "clean"
    opened = true
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
    showMain(true)
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

  onOpenedChanged: if (!opened) feedbackTimer.stop()
  onViewModeChanged: {
    if (!opened) return
    focusReady = false
    initialFocusTimer.restart()
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
    onTriggered: {
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
        else cleanButton.forceActiveFocus()
      }
      Qt.callLater(function() {
        root.focusReady = true
        if (root.viewMode === "main") {
          if (root.mainFocusTarget === "welcome") root.reveal(welcomeReplayButton)
          else if (root.mainFocusTarget === "tour") root.reveal(tourReplayButton)
        }
      })
    }
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

          StatusHeader {
            width: parent.width
            state: !root.setting("automatic", true) && root.watcherState === "running" ? "paused" : root.watcherState
            detail: root.statusDetail()
          }

          Grid {
            id: primaryActions
            width: parent.width
            columns: width < Style.space(410) ? 1 : 2
            columnSpacing: Style.space(8)
            rowSpacing: Style.space(8)

            PrimaryButton {
              id: cleanButton
              width: primaryActions.columns === 1
                ? primaryActions.width
                : Math.round((primaryActions.width - primaryActions.columnSpacing) * 0.58)
              text: service && service.actionBusy ? "Limpiando…" : "Limpiar portapapeles ahora"
              iconText: service && service.actionBusy ? "" : "󰅍"
              enabled: service && !service.actionBusy
              onClicked: root.runAction("cleanNow")
            }

            Button {
              id: skipButton
              width: primaryActions.columns === 1
                ? primaryActions.width
                : primaryActions.width - cleanButton.width - primaryActions.columnSpacing
              implicitHeight: Style.space(44)
              text: service && service.status && service.status.skipNext ? "Se omitirá la próxima copia" : "Omitir la próxima copia"
              focusable: true
              bordered: true
              foreground: Color.popups.text
              enabled: service && !service.actionBusy
              Accessible.role: Accessible.Button
              Accessible.name: text
              Accessible.onPressAction: root.runAction("skipNext")
              onClicked: root.runAction("skipNext")
            }
          }

          Text {
            width: parent.width
            height: Math.max(implicitHeight, Style.space(32))
            text: root.feedback !== ""
              ? root.feedback
              : "El original permanece intacto si la limpieza no es segura."
            color: root.feedback !== ""
              ? (root.feedbackError ? Color.urgent : Color.popups.text)
              : Util.alpha(Color.popups.text, 0.62)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
            Accessible.role: root.feedback !== "" ? Accessible.AlertMessage : Accessible.StaticText
            Accessible.name: text
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
              implicitHeight: 44
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
              implicitHeight: 44
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
                implicitHeight: 44
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
                implicitHeight: 44
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
                : Util.alpha(Color.popups.text, 0.62)
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
