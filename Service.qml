import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root

  property var shell: null
  property var manifest: null
  property string omarchyPath: Quickshell.env("OMARCHY_PATH")

  readonly property string pluginId: "io.github.r-bart.omaplain"
  readonly property string sourceDir: manifest && manifest.__sourceDir ? String(manifest.__sourceDir) : ""
  readonly property string helperPath: sourceDir ? sourceDir + "/helper/omaplain" : ""
  readonly property string runtimeBase: {
    var base = Quickshell.env("XDG_RUNTIME_DIR")
    return base ? base + "/omaplain" : ""
  }
  readonly property string configPath: runtimeBase ? runtimeBase + "/config.json" : ""
  readonly property string statusPath: runtimeBase ? runtimeBase + "/status.json" : ""
  readonly property string socketPath: runtimeBase ? runtimeBase + "/omaplain.sock" : ""

  property bool initialized: false
  property bool stopping: false
  property bool configPending: false
  property bool reloadPending: false
  property bool actionBusy: actionProcess.running
  property string lastActionJson: "{}"
  // Lo que el panel esta enseñando ahora mismo. Vive aqui y en ningun otro
  // sitio: no se persiste, no se registra y se tira al cerrar el panel.
  property var peekResult: ({ eligible: false, reason: "unknown", types: [] })
  property bool peekBusy: peekProcess.running
  property string currentAppClass: ""
  property string dependencyError: ""
  property int restartAttempt: 0
  property double lastErrorNotificationMs: 0
  property var settings: ({})
  // El servicio notifica aunque el panel esté cerrado, así que resuelve el
  // idioma por su cuenta en vez de heredarlo.
  readonly property string lang: {
    var chosen = String(settings && settings.language ? settings.language : "auto")
    if (chosen === "en" || chosen === "es") return chosen
    return Strings.fromLocale(Qt.locale().name)
  }
  property var status: ({
    version: 1,
    watcher: "starting",
    automatic: true,
    skipNext: false,
    lastResult: "none",
    lastReason: "none",
    lastAt: "",
    lastBytes: 0,
    configWarnings: [],
    session: { cleaned: 0, unchanged: 0, bypassed: 0, errors: 0 }
  })

  readonly property bool automatic: status.automatic !== false
  readonly property string watcherState: dependencyError !== "" ? "missing_dependencies" : String(status.watcher || "starting")
  readonly property bool watcherHealthy: watcherState === "running"

  function defaults() {
    return {
      automatic: true,
      stripFormatting: true,
      removeTracking: true,
      removeInvisible: true,
      normalizeLineEndings: true,
      normalizeQuotes: false,
      normalizeLists: false,
      normalizeUnicodeNfc: false,
      trimTrailingWhitespace: false,
      sourceExclusions: [],
      targetExclusions: [],
      maxBytes: 1048576,
      notifyOnError: true,
      onboardingVersion: 0,
      // Sólo de interfaz: el helper no lo necesita y lo ignora al leer la
      // configuración. «auto» toma el idioma del locale del sistema.
      language: "auto"
    }
  }

  function entrySettings() {
    var result = defaults()
    if (!shell || !shell.shellConfig || !Array.isArray(shell.shellConfig.plugins)) return result
    var entries = shell.shellConfig.plugins
    for (var i = 0; i < entries.length; i++) {
      var entry = entries[i]
      if (!entry || String(entry.id || "") !== pluginId) continue
      for (var key in result) {
        if (entry[key] !== undefined && entry[key] !== null) result[key] = entry[key]
      }
      break
    }
    return result
  }

  function ensureStarted() {
    if (initialized || !shell || !manifest || helperPath === "" || runtimeBase === "") return
    initialized = true
    settings = entrySettings()
    dependencyProcess.command = [helperPath, "check-dependencies"]
    dependencyProcess.running = true
  }

  function syncConfig() {
    if (!initialized || configPath === "" || helperPath === "") return
    if (configProcess.running) {
      configPending = true
      return
    }
    configPending = false
    settings = entrySettings()
    configProcess.command = [
      helperPath, "write-config", "--path", configPath,
      "--json", JSON.stringify(settings)
    ]
    configProcess.running = true
  }

  function startWatcher() {
    if (stopping || watchProcess.running || helperPath === "" || dependencyError !== "") return
    watchProcess.command = [
      "setpriv", "--pdeathsig", "TERM", "--",
      helperPath, "watch",
      "--config", configPath,
      "--status", statusPath,
      "--socket", socketPath
    ]
    watchProcess.running = true
  }

  function reloadStatus() {
    if (statusPath !== "") statusFile.reload()
  }

  function applyStatus(raw) {
    try {
      var parsed = JSON.parse(String(raw || ""))
      if (!parsed || parsed.version !== 1) return
      status = parsed
      if (String(parsed.watcher || "") === "running") restartAttempt = 0
      maybeNotifyWatcher(parsed)
    } catch (error) {
      // A writer may be between atomic rename and the watch callback. Keep the
      // last known-good snapshot; the periodic reload will recover.
    }
  }

  function maybeNotifyWatcher(nextStatus) {
    if (!nextStatus || nextStatus.watcher !== "degraded") return
    var settings = entrySettings()
    if (settings.notifyOnError === false) return
    var now = Date.now()
    if (now - lastErrorNotificationMs < 600000) return
    lastErrorNotificationMs = now
    notifyProcess.command = [
      "notify-send", "--app-name", "OmaPlain", "--urgency", "critical",
      Strings.t("notify.title", root.lang),
      Strings.t("notify.body", root.lang)
    ]
    notifyProcess.running = true
  }

  function runAction(name) {
    if (actionProcess.running || socketPath === "") return "busy"
    actionProcess.command = [helperPath, "control", "--socket", socketPath, name]
    actionProcess.running = true
    return "accepted"
  }

  function requestDaemonReload() {
    if (socketPath === "" || helperPath === "" || !watchProcess.running) return
    if (reloadProcess.running) {
      reloadPending = true
      return
    }
    reloadPending = false
    reloadProcess.command = [helperPath, "control", "--socket", socketPath, "reload"]
    reloadProcess.running = true
  }

  // Pedir un vistazo es una lectura: no consume la omision pendiente, no
  // avanza la generacion y no cuenta como operacion. Todo eso lo garantiza
  // el helper; aqui solo se transporta.
  function requestPeek() {
    if (peekProcess.running || socketPath === "" || helperPath === "") return "busy"
    peekProcess.command = [helperPath, "peek", "--socket", socketPath]
    peekProcess.running = true
    return "accepted"
  }

  // El contenido muere con el panel. Si se quedase, un segundo vistazo
  // podria enseñar por un instante lo que habia en el portapapeles anterior.
  function forgetPeek() {
    peekResult = { eligible: false, reason: "unknown", types: [] }
  }

  function cleanNow() { return runAction("cleanNow") }
  function pasteClean() { return runAction("pasteClean") }
  function skipNext() { return runAction("skipNext") }

  function reload() {
    syncConfig()
    return "ok"
  }

  function updateSetting(name, value) {
    var allowed = [
      "automatic", "stripFormatting", "removeTracking", "removeInvisible",
      "normalizeLineEndings", "normalizeQuotes", "normalizeLists",
      "normalizeUnicodeNfc", "trimTrailingWhitespace", "sourceExclusions",
      "targetExclusions", "maxBytes", "notifyOnError", "onboardingVersion",
      "language"
    ]
    if (allowed.indexOf(String(name)) === -1 || !shell || typeof shell.updateEntryInline !== "function")
      return false
    var next = entrySettings()
    next[String(name)] = value
    settings = next
    shell.updateEntryInline(pluginId, next)
    Qt.callLater(root.syncConfig)
    return true
  }

  function setAutomatic(value) {
    return updateSetting("automatic", value === true)
  }

  function validAppClass(value) {
    var text = String(value || "")
    return text !== "" && text.indexOf("\n") === -1 && text.indexOf("\r") === -1 && text.length <= 256
  }

  function addExclusion(kind, appClass) {
    var key = kind === "target" ? "targetExclusions" : "sourceExclusions"
    var value = String(appClass || "")
    if (!validAppClass(value)) return "invalid"
    var settings = entrySettings()
    var values = Array.isArray(settings[key]) ? settings[key].slice() : []
    if (values.indexOf(value) !== -1) return "duplicate"
    values.push(value)
    updateSetting(key, values)
    return "ok"
  }

  function removeExclusion(kind, appClass) {
    var key = kind === "target" ? "targetExclusions" : "sourceExclusions"
    var settings = entrySettings()
    var values = Array.isArray(settings[key]) ? settings[key].slice() : []
    var filtered = values.filter(function(value) { return value !== appClass })
    updateSetting(key, filtered)
    return "ok"
  }

  function captureCurrentApp() {
    if (helperPath === "") return
    if (captureProcess.running) captureProcess.running = false
    currentAppClass = ""
    captureProcess.command = [helperPath, "active-window"]
    captureProcess.running = true
  }

  onShellChanged: Qt.callLater(ensureStarted)
  onManifestChanged: Qt.callLater(ensureStarted)

  Connections {
    target: root.shell
    function onShellConfigChanged() { root.syncConfig() }
  }

  Component.onCompleted: Qt.callLater(ensureStarted)
  Component.onDestruction: {
    stopping = true
    restartTimer.stop()
    statusPoll.stop()
    if (watchProcess.running) watchProcess.running = false
  }

  Process {
    id: dependencyProcess
    stdout: StdioCollector { id: dependencyOutput; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        try {
          var parsed = JSON.parse(String(dependencyOutput.text || "{}"))
          root.dependencyError = Array.isArray(parsed.missing) ? parsed.missing.join(", ") : "unknown"
        } catch (error) {
          root.dependencyError = "unknown"
        }
        root.status = Object.assign({}, root.status, { watcher: "missing_dependencies" })
        return
      }
      root.dependencyError = ""
      root.syncConfig()
    }
  }

  Process {
    id: configProcess
    stdout: StdioCollector { waitForEnd: true }
    onExited: function(exitCode) {
      if (root.configPending) {
        Qt.callLater(root.syncConfig)
        return
      }
      if (exitCode !== 0) {
        root.status = Object.assign({}, root.status, { watcher: "config_error" })
        return
      }
      if (!watchProcess.running) root.startWatcher()
      else root.requestDaemonReload()
    }
  }

  Process {
    id: watchProcess
    onExited: function(exitCode) {
      if (root.stopping) return
      root.status = Object.assign({}, root.status, { watcher: "restarting" })
      root.restartAttempt += 1
      restartTimer.interval = Math.min(30000, [1000, 2000, 5000, 10000, 30000][Math.min(4, root.restartAttempt - 1)])
      restartTimer.restart()
    }
  }

  Timer {
    id: restartTimer
    interval: 1000
    repeat: false
    onTriggered: root.startWatcher()
  }

  Process {
    id: actionProcess
    stdout: StdioCollector { id: actionOutput; waitForEnd: true }
    onExited: function(exitCode) {
      var text = String(actionOutput.text || "{}").trim()
      root.lastActionJson = text || "{}"
      root.reloadStatus()
    }
  }

  Process {
    id: peekProcess
    stdout: StdioCollector { id: peekOutput; waitForEnd: true }
    onExited: function(exitCode) {
      var text = String(peekOutput.text || "").trim()
      if (text === "") { root.forgetPeek(); return }
      try {
        root.peekResult = JSON.parse(text)
      } catch (error) {
        // El mensaje de error no lleva el texto: una traza con el contenido
        // dentro seria justo la fuga que 0005 prohibe.
        root.forgetPeek()
      }
    }
  }

  Process {
    id: reloadProcess
    onExited: function(exitCode) {
      if (root.reloadPending) Qt.callLater(root.requestDaemonReload)
    }
  }

  Process {
    id: captureProcess
    command: []
    stdout: StdioCollector {
      id: captureOutput
      waitForEnd: true
      onStreamFinished: {
        try {
          var data = JSON.parse(String(text || "{}"))
          root.currentAppClass = String(data.appClass || data.initialClass || "")
        } catch (error) {
          root.currentAppClass = ""
        }
      }
    }
  }

  Process { id: notifyProcess }

  FileView {
    id: statusFile
    path: root.statusPath
    watchChanges: true
    printErrors: false
    onLoaded: root.applyStatus(text())
    onLoadFailed: function(error) {}
    onFileChanged: reload()
  }

  Timer {
    id: statusPoll
    interval: 1000
    running: root.initialized
    repeat: true
    triggeredOnStart: false
    onTriggered: root.reloadStatus()
  }

  IpcHandler {
    target: "omaplain"

    function ping(): string { return root.watcherHealthy ? "ok" : root.watcherState }
    function status(): string { return JSON.stringify(root.status) }
    function cleanNow(): string { return root.cleanNow() }
    function pasteClean(): string { return root.pasteClean() }
    function skipNext(): string { return root.skipNext() }
    function reload(): string { return root.reload() }
    function setAutomatic(value: string): string {
      if (value !== "true" && value !== "false") return "invalid"
      return root.setAutomatic(value === "true") ? "ok" : "error"
    }
  }
}
