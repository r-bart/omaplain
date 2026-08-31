"""Command-line entry point for OmaPlain."""

from __future__ import annotations

import argparse
import json
import os
import shutil
import sys
from pathlib import Path

from . import __version__
from .classify import classify, safe_type_metadata
from .clipboard import ClipboardBackend, ClipboardError, ClipboardTooLarge
from .config import DEFAULTS, load_config, validate_config, write_config
from .daemon import OmaPlainDaemon, socket_request
from .transform import TransformBypass, transform


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="omaplain", description="Clean text on the Wayland clipboard safely.")
    parser.add_argument("--version", action="version", version=f"%(prog)s {__version__}")
    commands = parser.add_subparsers(dest="command", required=True)

    commands.add_parser("check-dependencies", help="Check required runtime commands.")
    commands.add_parser("inspect", help="Inspect clipboard types without printing its content.")
    commands.add_parser("active-window", help="Print content-free active-window metadata.")

    transform_parser = commands.add_parser("transform", help="Transform stdin and write clean text to stdout.")
    transform_parser.add_argument("--mime", default="text/plain;charset=utf-8")
    transform_parser.add_argument("--config")

    config_parser = commands.add_parser("write-config", help="Validate and atomically write a runtime config.")
    config_parser.add_argument("--path", required=True)
    config_parser.add_argument("--json", required=True)

    watch = commands.add_parser("watch", help="Run the clipboard daemon.")
    watch.add_argument("--config", required=True)
    watch.add_argument("--status", required=True)
    watch.add_argument("--socket", required=True)

    emit = commands.add_parser("emit-event", help=argparse.SUPPRESS)
    emit.add_argument("--socket", required=True)

    control = commands.add_parser("control", help="Call the running daemon.")
    control.add_argument("--socket", required=True)
    control.add_argument("name", choices=("ping", "status", "cleanNow", "pasteClean", "skipNext", "reload"))
    return parser


def _print_json(value: object) -> None:
    print(json.dumps(value, ensure_ascii=False, separators=(",", ":")))


def _check_dependencies() -> int:
    required = ["wl-copy", "wl-paste", "hyprctl", "setpriv", "python3"]
    missing = [name for name in required if shutil.which(name) is None]
    _print_json({"ok": not missing, "missing": missing, "version": __version__})
    return 0 if not missing else 1


def _inspect() -> int:
    backend = ClipboardBackend()
    try:
        types = backend.list_types()
    except ClipboardError:
        _print_json({"result": "bypassed", "reason": "empty", "typeCount": 0})
        return 0
    decision = classify(types, "data")
    result = safe_type_metadata(types)
    result.update({"result": "eligible" if decision.eligible else "bypassed", "reason": decision.reason})
    _print_json(result)
    return 0


def _active_window() -> int:
    target = ClipboardBackend().active_window()
    if target is None:
        _print_json({"result": "unavailable"})
        return 1
    _print_json({
        "result": "ok",
        "address": target.address,
        "appClass": target.app_class,
        "initialClass": target.initial_class,
        "terminal": target.terminal,
    })
    return 0


def _transform(args: argparse.Namespace) -> int:
    config = dict(DEFAULTS)
    if args.config:
        config, _ = load_config(args.config)
    maximum = int(config["maxBytes"])
    payload = sys.stdin.buffer.read(maximum + 1)
    if len(payload) > maximum:
        _print_json({"result": "bypassed", "reason": "too_large"})
        return 20
    try:
        result = transform(payload, args.mime, config)
    except TransformBypass as error:
        print(error.reason, file=sys.stderr)
        return 20
    sys.stdout.buffer.write(result.output)
    return 0 if result.changed else 10


def _write_config(args: argparse.Namespace) -> int:
    try:
        raw = json.loads(args.json)
    except json.JSONDecodeError:
        _print_json({"result": "error", "reason": "invalid_json"})
        return 1
    warnings = write_config(args.path, raw)
    _print_json({"result": "ok", "warnings": warnings})
    return 0


def main(argv: list[str] | None = None) -> int:
    args = _parser().parse_args(argv)
    if args.command == "check-dependencies":
        return _check_dependencies()
    if args.command == "inspect":
        return _inspect()
    if args.command == "active-window":
        return _active_window()
    if args.command == "transform":
        return _transform(args)
    if args.command == "write-config":
        return _write_config(args)
    if args.command == "emit-event":
        state = os.environ.get("CLIPBOARD_STATE", "data")
        socket_request(args.socket, {"kind": "event", "state": state}, timeout=0.4)
        return 0
    if args.command == "control":
        response = socket_request(args.socket, {"kind": "command", "name": args.name})
        _print_json(response)
        return 0 if response.get("result") != "error" else 1
    if args.command == "watch":
        executable = str(Path(sys.argv[0]).resolve())
        daemon = OmaPlainDaemon(executable, args.config, args.status, args.socket)
        return daemon.run()
    return 2
