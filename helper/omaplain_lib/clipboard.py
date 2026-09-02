"""Wayland and Hyprland boundary for OmaPlain."""

from __future__ import annotations

import hashlib
import json
import os
import re
import select
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
    """Los cuatro procesos que tocan el portapapeles, con plazo cada uno.

    `timeout` acota las órdenes cortas —listar tipos, escribir, preguntar a
    Hyprland—: un viaje de ida y vuelta al compositor, que en un equipo
    cargado puede tardar más de los 250 ms que había. `read_timeout` acota
    la lectura entera del contenido, que la sirve la aplicación de origen y
    no el compositor: un navegador la genera al pedirla, y una aplicación
    congelada no la sirve nunca. Sin este segundo plazo la lectura se
    quedaba esperando para siempre con el cerrojo del demonio cogido.
    """

    def __init__(self, timeout: float = 1.0, read_timeout: float = 2.0):
        self.timeout = timeout
        self.read_timeout = read_timeout

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

        Se distinguen por cómo falla. Si el comando arrancó y salió con
        error, se toma como portapapeles vacío: es lo que `wl-paste` hace
        cuando no hay nada copiado, y también lo que hace sin display,
        que aquí no se distingue. Si no llegó a arrancar o se pasó de
        plazo, es un fallo de verdad y se propaga como `inspect_failed`.
        """
        try:
            output = self._capture(["wl-paste", "--list-types"])
        except ClipboardError as error:
            if str(error) == "command_failed":
                return []
            raise
        return [line.decode("utf-8", "replace").strip() for line in output.splitlines() if line.strip()]

    def read(self, mime: str, maximum: int, timeout: float | None = None) -> bytes:
        """Lee el contenido, hasta `maximum` bytes y dentro de un plazo.

        Se espera al fin de la tubería aunque ya se tengan `maximum` bytes:
        es lo que distingue «cabe justo» de «hay más». Una fuente que sirve
        exactamente `maximum` y se queda colgada sale por plazo, no por
        tamaño; es el único caso en que se confunden y es de laboratorio.
        """
        try:
            process = subprocess.Popen(
                ["wl-paste", "--no-newline", "--type", mime],
                stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
            )
        except OSError:
            raise ClipboardError("wl_paste_unavailable") from None
        assert process.stdout is not None
        budget = self.read_timeout if timeout is None else timeout
        deadline = time.monotonic() + budget
        payload = bytearray()
        descriptor = process.stdout.fileno()
        try:
            # Se lee a trozos y con plazo. `stdout.read(n)` bloquea hasta
            # tener los `n` bytes o el fin de la tubería, y quien escribe en
            # ella es la aplicación de origen, no wl-paste: si no sirve la
            # oferta, no hay fin de tubería que esperar.
            while len(payload) <= maximum:
                remaining = deadline - time.monotonic()
                if remaining <= 0:
                    raise subprocess.TimeoutExpired("wl-paste", budget)
                ready, _, _ = select.select([descriptor], [], [], remaining)
                if not ready:
                    continue
                chunk = os.read(descriptor, 65_536)
                if not chunk:
                    break
                payload += chunk
            if len(payload) > maximum:
                # Ya está matado: el fin de la tubería es inmediato. Con un
                # plazo aquí, un equipo cargado convertía «demasiado grande»
                # en «timeout» y el bypass se apuntaba como error.
                process.kill()
                process.communicate()
                raise ClipboardTooLarge("too_large")
            process.wait(timeout=max(0.05, deadline - time.monotonic()))
        except subprocess.TimeoutExpired:
            process.kill()
            process.communicate()
            raise ClipboardError("timeout") from None
        finally:
            process.stdout.close()
        if process.returncode != 0:
            raise ClipboardError("read_failed")
        return bytes(payload)

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
        """¿Sigue el portapapeles como cuando se leyó?

        La segunda lectura va con la mitad del plazo: la primera ya
        demostró que la fuente sirve, y si ahora tarda el doble es que algo
        cambió debajo. Sin esto una fuente lenta retenía el cerrojo del
        demonio dos veces el plazo entero antes de decidir nada.
        """
        try:
            current_types = self.list_types()
            if tuple(current_types) != tuple(expected_types):
                return False
            current = self.read(mime, maximum, timeout=self.read_timeout / 2)
            return digest(current) == digest(expected)
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
        # `hyprctl` contesta `{}` sin ventana activa; cualquier otra cosa
        # que no sea un objeto tampoco es una ventana.
        if not isinstance(data, dict):
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
