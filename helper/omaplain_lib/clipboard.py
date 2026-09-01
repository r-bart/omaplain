"""Wayland and Hyprland boundary for OmaPlain."""

from __future__ import annotations

import hashlib
import json
import re
import subprocess
import time
from dataclasses import dataclass
from typing import Sequence


PLAIN_OUTPUT_MIME = "text/plain;charset=utf-8"
_ADDRESS_RE = re.compile(r"^0x[0-9A-Fa-f]+$")


class ClipboardError(RuntimeError):
    pass


class ClipboardTooLarge(ClipboardError):
    pass


@dataclass(frozen=True, slots=True)
class WindowTarget:
    address: str
    app_class: str
    initial_class: str
    terminal: bool


def digest(payload: bytes) -> str:
    return hashlib.sha256(payload).hexdigest()


class ClipboardBackend:
    def __init__(self, timeout: float = 0.25):
        self.timeout = timeout

    def _capture(self, argv: Sequence[str], *, timeout: float | None = None) -> bytes:
        try:
            result = subprocess.run(
                list(argv), check=False, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                timeout=timeout or self.timeout,
            )
        except (OSError, subprocess.TimeoutExpired) as error:
            raise ClipboardError(type(error).__name__) from None
        if result.returncode != 0:
            raise ClipboardError("command_failed")
        return result.stdout

    def list_types(self) -> list[str]:
        """Los tipos que ofrece el portapapeles; lista vacía si no hay nada.

        `wl-paste --list-types` sale con código de error tanto cuando algo
        va mal como cuando simplemente no hay nada copiado. Tratar los dos
        casos igual convertía un portapapeles vacío —un estado corriente,
        el que tienes al arrancar la sesión— en un fallo: el panel decía
        «error» y el contador de la sesión se apuntaba una incidencia.

        Se distinguen por la salida. Si el comando se ejecutó y no imprimió
        nada, no hay tipos que listar. Si imprimió algo y aun así falló, es
        un fallo de verdad y se propaga.
        """
        try:
            output = self._capture(["wl-paste", "--list-types"])
        except ClipboardError as error:
            if str(error) == "command_failed":
                return []
            raise
        return [line.decode("utf-8", "replace").strip() for line in output.splitlines() if line.strip()]

    def read(self, mime: str, maximum: int) -> bytes:
        try:
            process = subprocess.Popen(
                ["wl-paste", "--no-newline", "--type", mime],
                stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
            )
        except OSError:
            raise ClipboardError("wl_paste_unavailable") from None
        assert process.stdout is not None
        try:
            payload = process.stdout.read(maximum + 1)
            if len(payload) > maximum:
                process.kill()
                process.communicate(timeout=0.1)
                raise ClipboardTooLarge("too_large")
            process.wait(timeout=self.timeout)
        except subprocess.TimeoutExpired:
            process.kill()
            process.communicate()
            raise ClipboardError("timeout") from None
        if process.returncode != 0:
            raise ClipboardError("read_failed")
        return payload

    def write(self, payload: bytes) -> None:
        try:
            result = subprocess.run(
                ["wl-copy", "--type", PLAIN_OUTPUT_MIME], input=payload,
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                timeout=self.timeout, check=False,
            )
        except (OSError, subprocess.TimeoutExpired):
            raise ClipboardError("write_failed") from None
        if result.returncode != 0:
            raise ClipboardError("write_failed")

    def unchanged(self, mime: str, maximum: int, expected: bytes, expected_types: Sequence[str]) -> bool:
        try:
            current_types = self.list_types()
            if tuple(current_types) != tuple(expected_types):
                return False
            return digest(self.read(mime, maximum)) == digest(expected)
        except ClipboardError:
            return False

    def wait_for_text(self, expected: bytes, maximum_wait: float = 0.25) -> bool:
        deadline = time.monotonic() + maximum_wait
        expected_hash = digest(expected)
        while time.monotonic() < deadline:
            try:
                types = self.list_types()
                plain = next((value for value in types if value.lower().split(";", 1)[0] == "text/plain"), None)
                if plain and digest(self.read(plain, len(expected) + 1)) == expected_hash:
                    return True
            except (ClipboardError, ClipboardTooLarge):
                pass
            time.sleep(0.01)
        return False

    def active_window(self) -> WindowTarget | None:
        try:
            raw = self._capture(["hyprctl", "activewindow", "-j"])
            data = json.loads(raw)
        except (ClipboardError, json.JSONDecodeError, TypeError):
            return None
        address = str(data.get("address", ""))
        if not _ADDRESS_RE.fullmatch(address):
            return None
        tags = [str(tag).rstrip("*") for tag in data.get("tags", []) if isinstance(tag, str)]
        return WindowTarget(
            address=address,
            app_class=str(data.get("class", "")),
            initial_class=str(data.get("initialClass", "")),
            terminal="terminal" in tags,
        )

    def open_windows(self, limit: int = 64) -> list[str]:
        """Las clases de las ventanas abiertas ahora mismo, sin repetir.

        Es la única lista que sirve para el filtro por aplicación: la clase
        que devuelve Hyprland es exactamente la cadena contra la que compara
        el demonio. Un catálogo de aplicaciones instaladas no lo es —en este
        equipo, 23 de 93 entradas `.desktop` declaran `StartupWMClass`—, así
        que ofrecerlo daría a elegir nombres que generan reglas que nunca
        disparan.

        **El título de la ventana no sale de aquí.** Nombra el documento
        abierto, y eso es contenido: la `0011` lo deja fuera a propósito.
        """
        try:
            raw = self._capture(["hyprctl", "clients", "-j"])
            data = json.loads(raw)
        except (ClipboardError, json.JSONDecodeError, TypeError):
            return []
        if not isinstance(data, list):
            return []
        seen: set[str] = set()
        classes: list[str] = []
        for entry in data:
            if not isinstance(entry, dict):
                continue
            value = str(entry.get("class", ""))
            if not value or len(value) > 256:
                continue
            if "\n" in value or "\r" in value:
                continue
            if value in seen:
                continue
            seen.add(value)
            classes.append(value)
        classes.sort(key=str.lower)
        return classes[:limit]

    def send_paste(self, target: WindowTarget, release_delay: float = 0.12) -> None:
        if not _ADDRESS_RE.fullmatch(target.address):
            raise ClipboardError("invalid_target")
        time.sleep(release_delay)
        mods, key = ("SHIFT", "INSERT") if target.terminal else ("CTRL", "V")
        # Hyprland 0.56 dispatchers are Lua-backed. All interpolated fields are
        # selected from literals above or constrained to a hexadecimal address;
        # clipboard content never enters this expression.
        expression = (
            'hl.dispatch(hl.dsp.send_shortcut({ mods = "'
            + mods + '", key = "' + key + '", window = "address:' + target.address + '" }))'
        )
        try:
            result = subprocess.run(
                ["hyprctl", "eval", expression],
                stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, timeout=self.timeout, check=False,
            )
        except (OSError, subprocess.TimeoutExpired):
            raise ClipboardError("paste_failed") from None
        if result.returncode != 0 or not result.stdout.startswith(b"ok"):
            raise ClipboardError("paste_failed")
