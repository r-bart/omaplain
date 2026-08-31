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

  readonly property var settings: service && service.settings ? service.settings : ({})
  readonly property string pluginId: manifest && manifest.id ? String(manifest.id) : "omapaste.cleaner"
  readonly property string watcherState: service ? service.watcherState : "starting"

  function open(payloadJson) {
    if (service) service.captureCurrentApp()
    opened = true
    feedback = ""
    fieldError = ""
    scroll.contentY = 0
    initialFocusTimer.restart()
  }

  function close() {
    opened = false
    feedbackTimer.stop()
    fieldError = ""
  }

  function dismiss() {
    if (shell && typeof shell.hide === "function") shell.hide(pluginId)
    else close()
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
    return "Listo para limpiar texto elegible."
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
      feedback = "OmaPaste ya está procesando otra acción"
      feedbackTimer.restart()
    }
  }

  function submitExclusion(scope) {
    if (!service) return
    var value = classField.text.trim()
    var result = service.addExclusion(scope, value)
    if (result === "invalid") {
      fieldError = "Introduce una clase de aplicación válida"
      return
    }
    if (result === "duplicate") {
      fieldError = "Esta aplicación ya está excluida"
      return
    }
    fieldError = ""
    classField.text = ""
  }

  function excludeDetected() {
    if (!service || !service.currentAppClass) {
      fieldError = "No se ha detectado una aplicación"
      return
    }
    classField.text = service.currentAppClass
    submitExclusion("source")
  }

  function reveal(item) {
    if (!item || !contentColumn) return
    var point = item.mapToItem(contentColumn, 0, 0)
    var top = point.y
    var bottom = top + item.height
    if (top < scroll.contentY) scroll.contentY = Math.max(0, top - Style.space(8))
    else if (bottom > scroll.contentY + scroll.height)
      scroll.contentY = Math.min(scroll.contentHeight - scroll.height, bottom - scroll.height + Style.space(8))
  }

  onOpenedChanged: if (!opened) feedbackTimer.stop()

  Connections {
    target: root.service
    function onLastActionJsonChanged() {
      root.feedback = root.actionMessage(root.service.lastActionJson)
      if (root.feedback !== "") feedbackTimer.restart()
    }
  }

  Timer {
    id: feedbackTimer
    interval: 1500
    repeat: false
    onTriggered: root.feedback = ""
  }

  Timer {
    id: initialFocusTimer
    interval: 80
    repeat: false
    onTriggered: {
      if (!root.opened) return
      scroll.contentY = 0
      cleanButton.forceActiveFocus()
      Qt.callLater(function() {
        scroll.contentY = 0
        root.reveal(cleanButton)
      })
    }
  }

  PanelWindow {
    id: window
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "omapaste-panel"
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

        Flickable {
          id: scroll
          anchors.fill: parent
          anchors.margins: Style.space(20)
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

            StatusHeader {
              width: parent.width
              state: !root.setting("automatic", true) && root.watcherState === "running" ? "paused" : root.watcherState
              detail: root.statusDetail()
            }

            Button {
              id: cleanButton
              width: parent.width
              implicitHeight: 48
              text: service && service.actionBusy ? "Limpiando…" : "Limpiar portapapeles ahora"
              iconText: service && service.actionBusy ? "" : "󰅍"
              focusable: true
              bordered: true
              selected: true
              foreground: Color.popups.text
              enabled: service && !service.actionBusy
              Accessible.role: Accessible.Button
              Accessible.name: text
              Accessible.onPressAction: root.runAction("cleanNow")
              onActiveFocusChanged: if (activeFocus) root.reveal(cleanButton)
              onClicked: root.runAction("cleanNow")
            }

            Button {
              id: skipButton
              width: parent.width
              implicitHeight: 44
              text: service && service.status && service.status.skipNext ? "Se omitirá la próxima copia" : "Omitir la próxima copia"
              focusable: true
              bordered: true
              foreground: Color.popups.text
              enabled: service && !service.actionBusy
              Accessible.role: Accessible.Button
              Accessible.name: text
              Accessible.onPressAction: root.runAction("skipNext")
              onActiveFocusChanged: if (activeFocus) root.reveal(skipButton)
              onClicked: root.runAction("skipNext")
            }

            Text {
              visible: root.feedback !== ""
              width: parent.width
              text: root.feedback
              color: root.feedbackError ? Color.urgent : Color.popups.text
              font.family: Style.font.family
              font.pixelSize: Style.font.body
              wrapMode: Text.WordWrap
              Accessible.role: Accessible.AlertMessage
              Accessible.name: text
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
              visible: root.setting("automatic", true)
                && (root.setting("removeTracking", true) || root.setting("removeInvisible", true))
              width: parent.width
              text: "El historial puede conservar también el original cuando cambian caracteres."
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
              text: "Clase de aplicación"
              color: Color.popups.text
              font.family: Style.font.family
              font.pixelSize: Style.font.body
              font.bold: true
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
              Accessible.description: "Clase exacta de Hyprland que se excluirá"
              onAccepted: root.submitExclusion("source")
              onEditingFinished: if (root.fieldError !== "" && text.trim() !== "") root.fieldError = ""
              onActiveFocusChanged: if (activeFocus) root.reveal(classField)
            }

            Row {
              width: parent.width
              spacing: Style.space(8)

              Button {
                id: addSourceButton
                width: (parent.width - parent.spacing) / 2
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
                width: (parent.width - parent.spacing) / 2
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
              visible: root.fieldError !== ""
              width: parent.width
              text: "⚠ " + root.fieldError
              color: Color.urgent
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
              Accessible.role: Accessible.AlertMessage
              Accessible.name: root.fieldError
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
              text: "Todo ocurre en este equipo. OmaPaste no guarda el texto copiado. El historial pertenece a Omarchy."
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
