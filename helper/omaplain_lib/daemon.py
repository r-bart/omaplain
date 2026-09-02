"""Long-running OmaPlain clipboard coordinator."""

from __future__ import annotations

import json
import os
import signal
import socket
import subprocess
import threading
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from .classify import Classification, classify
from .clipboard import ClipboardBackend, ClipboardError, ClipboardTooLarge, WindowTarget, digest
from .config import load_config
from .status import StatusStore
from .transform import TransformBypass, TransformResult, transform


@dataclass(frozen=True, slots=True)
class OperationResult:
    result: str
    reason: str
    byte_count: int = 0
    output: bytes | None = None

    def public(self) -> dict[str, object]:
        return {"result": self.result, "reason": self.reason, "bytes": self.byte_count}


class OmaPlainDaemon:
    def __init__(self, executable: str, config_path: str, status_path: str, socket_path: str):
        self.executable = str(Path(executable).resolve())
        self.config_path = Path(config_path)
        self.status_path = Path(status_path)
        self.socket_path = Path(socket_path)
        self.config, warnings = load_config(self.config_path)
        self.status = StatusStore(self.status_path, bool(self.config["automatic"]))
        self.status.update(configWarnings=warnings)
        self.backend = ClipboardBackend()
        self.stop_event = threading.Event()
        self.process_lock = threading.Lock()
        self.generation_lock = threading.Lock()
        self.generation = 0
        self.skip_until = 0.0
        # 0009: de dónde vino la última copia, sólo la clase de la
        # ventana. Es metadato: la 0007 prohíbe recordar el texto, no su
        # procedencia. No se persiste, no entra en `status.json` y muere
        # con el proceso.
        self.last_source: tuple[str, str] = ("", "")
        # La generación del evento que fijó `last_source`. Dos eventos casi
        # simultáneos llegan por hilos distintos y pueden ejecutarse en
        # orden inverso; sin esto el más viejo podía quedar como «último».
        self.last_source_generation = 0
        self.loop_guard: tuple[str, int, float] | None = None
        self.watcher: subprocess.Popen[bytes] | None = None
        self.server: socket.socket | None = None
        self.workers: set[threading.Thread] = set()
        self.workers_lock = threading.Lock()

    def _next_generation(self) -> int:
        with self.generation_lock:
            self.generation += 1
            return self.generation

    def _is_current(self, generation: int) -> bool:
        with self.generation_lock:
            return self.generation == generation

    def _runtime_setup(self) -> None:
        parent = self.socket_path.parent
        parent.mkdir(mode=0o700, parents=True, exist_ok=True)
        os.chmod(parent, 0o700)
        if self.socket_path.exists() or self.socket_path.is_socket():
            self.socket_path.unlink(missing_ok=True)

    def reload_config(self) -> list[str]:
        config, warnings = load_config(self.config_path)
        self.config = config
        self.status.update(automatic=bool(config["automatic"]), configWarnings=warnings)
        return warnings

    def _start_watcher(self) -> None:
        command = [
            # Quickshell may use SIGKILL when it hot-reloads a plugin. Giving
            # wl-paste its own parent-death signal prevents an orphan watcher
            # even when this daemon cannot execute its finally block.
            "setpriv", "--pdeathsig", "TERM", "--",
            "wl-paste", "--type", "text", "--watch",
            self.executable, "emit-event", "--socket", str(self.socket_path),
        ]
        try:
            self.watcher = subprocess.Popen(
                command, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
        except OSError:
            self.watcher = None

    def _supervise_watcher(self) -> None:
        delays = (1, 2, 5, 10, 30)
        failures: list[float] = []
        index = 0
        healthy_since: float | None = None
        while not self.stop_event.is_set():
            watcher = self.watcher
            if watcher is not None and watcher.poll() is None:
                now = time.monotonic()
                if healthy_since is None:
                    healthy_since = now
                # Un tramo sano de un minuto vuelve a poner la escalera de
                # reintentos al principio. Sin esto, una caída aislada tras
                # horas corriendo esperaba el último retardo alcanzado, que
                # podía ser el tope de treinta segundos.
                elif index and now - healthy_since >= 60:
                    index = 0
                self.status.update(watcher="running")
                if self.stop_event.wait(0.5):
                    break
                continue
            healthy_since = None
            now = time.monotonic()
            failures = [value for value in failures if now - value < 60]
            failures.append(now)
            self.status.update(watcher="degraded" if len(failures) >= 3 else "restarting")
            if self.stop_event.wait(delays[min(index, len(delays) - 1)]):
                break
            index = min(index + 1, len(delays) - 1)
            self._start_watcher()

    def _classification(self, state: str) -> tuple[Classification, list[str]]:
        if state in {"sensitive", "nil", "clear"}:
            return classify([], state), []
        types = self.backend.list_types()
        return classify(types, state), types

    @staticmethod
    def _classes(target: WindowTarget | None) -> tuple[str, str]:
        if target is None:
            return ("", "")
        return (target.app_class, target.initial_class)

    def _listed(self, key: str, classes: tuple[str, str]) -> bool:
        values = self.config.get(key, [])
        return any(name and name in values for name in classes)

    def _source_excluded(self, target: WindowTarget | None) -> bool:
        return self._listed("sourceExclusions", self._classes(target))

    def _source_blocked(self, target: WindowTarget | None) -> bool:
        """0009: la app de origen está en `blockedApps`.

        Sin `target` —el panel preguntando, o una limpieza manual— se usa el
        origen recordado del último evento: cuando el panel pregunta, la
        ventana enfocada ya es el propio panel.

        Origen desconocido no es origen bloqueado. Está decidido y dicho en
        la 0009: la atribución es best effort y la interfaz no promete más.
        """
        classes = self._classes(target) if target is not None else self.last_source
        return self._listed("blockedApps", classes)

    def _source_covered(self) -> bool:
        return self._listed("alwaysCovered", self.last_source)

    def _target_excluded(self, target: WindowTarget) -> bool:
        exclusions = self.config.get("targetExclusions", [])
        return target.app_class in exclusions or target.initial_class in exclusions

    def _skip_active(self) -> bool:
        if self.skip_until and time.monotonic() >= self.skip_until:
            self.skip_until = 0.0
            self.status.update(skipNext=False)
        return self.skip_until > 0

    def tick(self) -> None:
        """Caducidades que no dependen de que llegue nada.

        La omisión expira por tiempo, pero `_skip_active` sólo corría al
        llegar un evento de portapapeles o al pedir `status` por el socket.
        El panel no usa esa vía: relee `status.json` del disco una vez por
        segundo, y nadie despertaba al demonio. Con el escritorio quieto la
        marca se quedaba puesta indefinidamente y la cabecera seguía
        diciendo «omitiendo» pasados los sesenta segundos.

        El bucle de `accept` ya despierta cada 0,5 s, así que esto no añade
        ningún temporizador. La comparación va fuera del cerrojo para no
        pelearse con una limpieza en curso dos veces por segundo; sólo se
        toma cuando de verdad toca caducar.
        """
        if self.skip_until and time.monotonic() >= self.skip_until:
            with self.process_lock:
                self._skip_active()

    def _consume_skip(self) -> bool:
        if not self._skip_active():
            return False
        self.skip_until = 0.0
        self.status.update(skipNext=False)
        return True

    def _self_event(self, payload: bytes) -> bool:
        guard = self.loop_guard
        if guard is None:
            return False
        expected_hash, expected_size, expires = guard
        if time.monotonic() > expires:
            self.loop_guard = None
            return False
        if len(payload) == expected_size and digest(payload) == expected_hash:
            self.loop_guard = None
            return True
        return False

    def _inspect_and_transform(
        self, state: str, *, automatic: bool, generation: int, source: WindowTarget | None = None,
    ) -> tuple[OperationResult, list[str], str | None, bytes | None, TransformResult | None]:
        # 0009: antes que nada, ni siquiera los tipos. «Ni lee ni enseña» no
        # depende de que la limpieza sea automática: incluye la acción manual
        # y la pregunta del panel, que son las otras dos formas de leer.
        if self._source_blocked(source):
            return OperationResult("bypassed", "source_blocked"), [], None, None, None

        try:
            decision, types = self._classification(state)
        except ClipboardError:
            return OperationResult("error", "inspect_failed"), [], None, None, None
        if not decision.eligible:
            return OperationResult("bypassed", decision.reason), types, None, None, None

        if automatic and self._source_excluded(source):
            return OperationResult("bypassed", "source_excluded"), types, None, None, None

        assert decision.plain_mime is not None
        maximum = int(self.config["maxBytes"])
        try:
            payload = self.backend.read(decision.plain_mime, maximum)
        except ClipboardTooLarge:
            return OperationResult("bypassed", "too_large"), types, decision.plain_mime, None, None
        except ClipboardError:
            return OperationResult("error", "read_failed"), types, decision.plain_mime, None, None

        if automatic and self._self_event(payload):
            return OperationResult("self", "self_event", len(payload)), types, decision.plain_mime, payload, None
        if automatic and self._consume_skip():
            return OperationResult("bypassed", "skip_next", len(payload)), types, decision.plain_mime, payload, None

        try:
            transformed = transform(payload, decision.plain_mime, self.config)
        except TransformBypass as error:
            return OperationResult("bypassed", error.reason, len(payload)), types, decision.plain_mime, payload, None

        needs_format_write = bool(self.config.get("stripFormatting", True)) and decision.rich
        if not transformed.changed and not needs_format_write:
            return OperationResult("unchanged", "already_clean", len(payload)), types, decision.plain_mime, payload, transformed
        reason = transformed.transformations[0] if transformed.transformations else "rich_text"
        return OperationResult("ready", reason, len(payload), transformed.output), types, decision.plain_mime, payload, transformed

    def _clean(
        self, state: str, *, automatic: bool, generation: int, source: WindowTarget | None = None,
    ) -> OperationResult:
        operation, types, mime, original, transformed = self._inspect_and_transform(
            state, automatic=automatic, generation=generation, source=source,
        )
        if operation.result != "ready":
            return operation
        assert mime is not None and original is not None and transformed is not None
        if not self._is_current(generation):
            return OperationResult("bypassed", "superseded", len(original))
        if not self.backend.unchanged(mime, int(self.config["maxBytes"]), original, types):
            return OperationResult("bypassed", "clipboard_changed", len(original))

        output = transformed.output
        self.loop_guard = (digest(output), len(output), time.monotonic() + 5.0)
        try:
            self.backend.write(output)
        except ClipboardError:
            self.loop_guard = None
            return OperationResult("error", "write_failed", len(original))
        return OperationResult("cleaned", operation.reason, len(output), output)

    def _record(self, operation: OperationResult) -> None:
        if operation.result == "self":
            return
        result = operation.result if operation.result in {"cleaned", "unchanged", "bypassed"} else "error"
        self.status.record(result, operation.reason, operation.byte_count)

    def automatic_event(
        self, state: str, generation: int, source: WindowTarget | None = None,
    ) -> dict[str, object]:
        # Se recuerda antes de mirar si el automático está puesto: con el
        # automático apagado no habría a quién atribuir la copia siguiente.
        with self.generation_lock:
            if generation >= self.last_source_generation:
                self.last_source = self._classes(source)
                self.last_source_generation = generation
        # Y se deja constancia de que hubo evento, aunque no se procese: el
        # panel abierto relee `status.json` para saber si lo que enseña
        # sigue siendo lo que hay, y con el automático apagado no había
        # nada que cambiara ahí.
        automatic = bool(self.config.get("automatic", True))
        if not automatic:
            self.status.mark_event(write=True)
            return {"result": "paused", "reason": "automatic_disabled", "bytes": 0}
        with self.process_lock:
            operation = self._clean(state, automatic=True, generation=generation, source=source)
            # El evento de nuestra propia reescritura no es una copia nueva
            # y no se marca: el panel volvería a mirar y a cubrir las filas
            # sin que hubiera nada nuevo que ver. Para los demás, la marca
            # va en memoria y la escribe el `record` de este mismo evento.
            if operation.result != "self":
                self.status.mark_event()
            self._record(operation)
            return operation.public()

    def clean_now(self) -> dict[str, object]:
        generation = self._next_generation()
        with self.process_lock:
            operation = self._clean("data", automatic=False, generation=generation)
            self._record(operation)
            return operation.public()

    def paste_clean(self) -> dict[str, object]:
        target = self.backend.active_window()
        if target is None:
            operation = OperationResult("error", "no_target")
            self._record(operation)
            return operation.public() | {"pasted": False}
        if self._target_excluded(target):
            # 0009: en esta ventana «pegar limpio» pega sin limpiar. Se
            # pega lo que haya, tal cual, y se apunta como bypass.
            operation = OperationResult("bypassed", "target_excluded")
            self._record(operation)
        else:
            generation = self._next_generation()
            with self.process_lock:
                operation = self._clean("data", automatic=False, generation=generation)
                self._record(operation)

        if operation.result == "cleaned" and operation.output is not None:
            self.backend.wait_for_text(operation.output)
        try:
            self.backend.send_paste(target)
        except ClipboardError:
            failed = OperationResult("error", "paste_failed", operation.byte_count)
            self._record(failed)
            return failed.public() | {"pasted": False}
        return operation.public() | {"pasted": True}

    def skip_next(self) -> dict[str, object]:
        self.skip_until = time.monotonic() + 60.0
        self.status.update(skipNext=True)
        return {"result": "ok", "expiresIn": 60}

    # Tope de lo que se manda al panel para enseñarlo. El limite de
    # `maxBytes` sigue rigiendo lo que el motor acepta procesar; esto es
    # otra cosa: nadie lee un megabyte en una tarjeta de cien pixeles, y
    # mandarlo solo alarga el tiempo que ese texto pasa fuera del helper.
    PEEK_LIMIT = 4096

    @staticmethod
    def _clip(text: str) -> tuple[str, bool]:
        if len(text) <= OmaPlainDaemon.PEEK_LIMIT:
            return text, False
        return text[: OmaPlainDaemon.PEEK_LIMIT], True

    def peek(self) -> dict[str, object]:
        """Describe the current clipboard for the panel, without touching it.

        Deliberadamente inerte: no avanza la generacion, no consume
        `skipNext`, no reescribe el portapapeles y —sobre todo— no llama a
        `_record`, que es lo unico de esta clase que escribe en disco. La
        respuesta viaja por el socket 0600 y muere con ella.
        """
        with self.process_lock:
            # `automatic=False` es lo que mantiene el gesto inerte: en esa
            # rama ni se consume la omision ni se descartan eventos propios.
            operation, types, mime, original, transformed = self._inspect_and_transform(
                "data", automatic=False, generation=self.generation,
            )

        # 0009: de una app bloqueada no se enseña ni de qué está hecho lo que
        # hay dentro. Sin `types`, que es más de lo que se calla un bypass
        # normal, y sin nada que el panel pueda pedir para levantarlo.
        if operation.reason == "source_blocked":
            return {"result": "ok", "reason": "source_blocked", "types": [], "eligible": False}

        answer: dict[str, object] = {
            "result": "ok" if operation.result != "error" else "error",
            "reason": operation.reason,
            "types": types,
            "eligible": operation.result not in {"bypassed", "error"},
            # 0009: el panel lo pinta cubierto de entrada. El ojo levanta la
            # fila que hay delante; la copia siguiente vuelve a llegar así.
            "cover": self._source_covered(),
        }

        # Sin contenido: sensible, imagen, archivos, MIME estructural,
        # vacio, demasiado grande o fallo de lectura. La negativa es del
        # helper, no de la interfaz, asi que no hay peticion del panel que
        # la levante.
        if operation.result in {"bypassed", "error"} or original is None or mime is None:
            answer["eligible"] = False
            return answer

        try:
            before = original.decode("utf-8")
            after = (transformed.output if transformed else original).decode("utf-8")
        except UnicodeDecodeError:
            # Un texto que no decodifica no se puede enseñar honestamente.
            return {"result": "ok", "reason": "undecodable", "types": types, "eligible": False}

        before, clipped_before = self._clip(before)
        after, clipped_after = self._clip(after)

        # `changed` es lo que decide el panel, y tiene que significar «esto
        # se reescribiria», no «el texto seria distinto». Retirar formato
        # enriquecido no cambia un solo caracter y sin embargo reescribe: la
        # version con formato desaparece. Preguntarle a transformed.changed
        # hacia que el panel dijera «ya esta limpio» de algo que si se iba a
        # limpiar, que es justo la mentira que estos paneles no pueden decir.
        rewrites = operation.result == "ready"
        applied = list(transformed.transformations) if transformed else []
        if rewrites and not applied:
            applied = [operation.reason]

        answer.update(
            original=before,
            cleaned=after,
            applied=applied,
            changed=rewrites,
            truncated=clipped_before or clipped_after,
            bytes=len(original),
        )
        # Los tipos que quedarian: retirar el formato deja solo el texto
        # plano, y ese es el unico cambio visible en ese caso.
        if rewrites and mime:
            answer["typesAfter"] = [mime]
        return answer

    def command(self, name: str) -> dict[str, object]:
        if name == "status":
            self._skip_active()
            return self.status.snapshot()
        if name == "cleanNow":
            return self.clean_now()
        if name == "pasteClean":
            return self.paste_clean()
        if name == "skipNext":
            return self.skip_next()
        if name == "reload":
            return {"result": "ok", "warnings": self.reload_config()}
        if name == "peek":
            return self.peek()
        if name == "ping":
            return {"result": "ok"}
        return {"result": "invalid", "reason": "unknown_command"}

    def _handle(self, connection: socket.socket) -> None:
        try:
            connection.settimeout(1.0)
            raw = b""
            while len(raw) <= 8192 and not raw.endswith(b"\n"):
                part = connection.recv(2048)
                if not part:
                    break
                raw += part
            if len(raw) > 8192:
                response: dict[str, object] = {"result": "invalid", "reason": "request_too_large"}
            else:
                request = json.loads(raw.decode("utf-8"))
                # Un JSON válido que no sea un objeto —una lista, un
                # número— no es una petición; antes hacía saltar un
                # `AttributeError` fuera de la lista de excepciones.
                kind = request.get("kind") if isinstance(request, dict) else None
                if kind == "event":
                    generation = self._next_generation()
                    # Snapshot attribution before this event waits on the
                    # serialization lock. Wayland cannot guarantee the source,
                    # so this remains best effort and is never a safety gate.
                    source = self.backend.active_window()
                    response = self.automatic_event(str(request.get("state", "data")), generation, source)
                elif kind == "command":
                    response = self.command(str(request.get("name", "")))
                else:
                    response = {"result": "invalid", "reason": "bad_request"}
            # UTF-8 tal cual, sin `\uXXXX`: con el escape ASCII cada emoji
            # de un `peek` ocupaba doce bytes, y cuatro mil de ellos por
            # dos campos superaban el tope de respuesta del cliente.
            connection.sendall(
                json.dumps(response, ensure_ascii=False, separators=(",", ":")).encode("utf-8") + b"\n"
            )
        except (OSError, UnicodeError, json.JSONDecodeError, TypeError):
            pass
        finally:
            connection.close()

    def _spawn_handler(self, connection: socket.socket) -> None:
        def run() -> None:
            try:
                self._handle(connection)
            finally:
                with self.workers_lock:
                    self.workers.discard(threading.current_thread())

        worker = threading.Thread(target=run, name="omaplain-request", daemon=True)
        with self.workers_lock:
            self.workers.add(worker)
        worker.start()

    def run(self) -> int:
        self._runtime_setup()
        for signum in (signal.SIGINT, signal.SIGTERM):
            signal.signal(signum, lambda *_: self.stop_event.set())

        server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.server = server
        server.bind(str(self.socket_path))
        os.chmod(self.socket_path, 0o600)
        server.listen(32)
        server.settimeout(0.5)
        self._start_watcher()
        supervisor = threading.Thread(target=self._supervise_watcher, name="omaplain-watcher", daemon=True)
        supervisor.start()

        try:
            while not self.stop_event.is_set():
                try:
                    connection, _ = server.accept()
                except TimeoutError:
                    self.tick()
                    continue
                except OSError:
                    if self.stop_event.is_set():
                        break
                    continue
                self._spawn_handler(connection)
        finally:
            self.stop_event.set()
            server.close()
            watcher = self.watcher
            if watcher is not None and watcher.poll() is None:
                watcher.terminate()
                try:
                    watcher.wait(timeout=1.0)
                except subprocess.TimeoutExpired:
                    watcher.kill()
            supervisor.join(timeout=1.0)
            self.status.update(watcher="stopped")
            self.socket_path.unlink(missing_ok=True)
        return 0


# Tope de una respuesta del socket. Un `peek` trae dos campos de hasta
# `PEEK_LIMIT` caracteres en UTF-8 sin escapar —cuatro bytes por carácter
# como mucho— más el escape JSON de los de control; el resto de respuestas
# son de unas decenas de bytes.
RESPONSE_LIMIT = 262_144


def socket_request(socket_path: str, request: dict[str, Any], timeout: float = 1.5) -> dict[str, object]:
    client = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    client.settimeout(timeout)
    try:
        client.connect(socket_path)
        client.sendall(json.dumps(request, separators=(",", ":")).encode("utf-8") + b"\n")
        client.shutdown(socket.SHUT_WR)
        raw = b""
        while len(raw) <= RESPONSE_LIMIT and not raw.endswith(b"\n"):
            part = client.recv(4096)
            if not part:
                break
            raw += part
        if len(raw) > RESPONSE_LIMIT:
            return {"result": "error", "reason": "response_too_large"}
        return json.loads(raw.decode("utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError, TypeError):
        return {"result": "error", "reason": "service_unavailable"}
    finally:
        client.close()
