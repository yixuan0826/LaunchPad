"""Executes launcher actions: file, cmd, url and keymouse sequences."""

from __future__ import annotations

import logging
import os
import shutil
import subprocess
import sys
import time
import webbrowser
from pathlib import Path
from typing import Any

from rin_launcher.elevation import is_admin, run_elevated

logger = logging.getLogger(__name__)

_URL_SCHEMES = ("http://", "https://", "ftp://", "file://", "mailto:")

# Human-friendly key name -> pynput ``Key`` member.  Function keys are generated
# rather than listed, and single characters are handled before the lookup.
_SPECIAL_KEYS = {
    "ctrl": "ctrl", "alt": "alt", "shift": "shift", "win": "cmd", "cmd": "cmd",
    "super": "cmd", "space": "space", "enter": "enter", "return": "enter",
    "esc": "esc", "escape": "esc", "tab": "tab", "backspace": "backspace",
    "delete": "delete", "insert": "insert", "home": "home", "end": "end",
    "pageup": "page_up", "pagedown": "page_down", "up": "up", "down": "down",
    "left": "left", "right": "right", "numlock": "num_lock", "capslock": "caps_lock",
    "scrolllock": "scroll_lock", "printscreen": "print_screen", "pause": "pause",
    "menu": "menu",
    **{f"f{index}": f"f{index}" for index in range(1, 13)},
}


def _resolve_key(name: str):
    """Map a recorded key name to a pynput key, or None when unrecognised."""
    from pynput import keyboard

    name = (name or "").strip().lower()
    if not name:
        return None
    if len(name) == 1:
        return name
    return getattr(keyboard.Key, _SPECIAL_KEYS.get(name, name), None)


class ActionExecutor:
    """Runs one launcher action and reports whether it succeeded."""

    def __init__(self, config_manager):
        self.config_manager = config_manager
        self._handlers = {
            "file": self._run_file,
            "cmd": self._run_cmd,
            "url": self._run_url,
            "keymouse": self._run_keymouse,
        }

    def execute(self, action: dict[str, Any]) -> bool:
        kind = action.get("type", "file")
        handler = self._handlers.get(kind)
        if handler is None:
            logger.warning("Unknown action type: %r", kind)
            return False
        try:
            return handler(action)
        except Exception:
            logger.exception("Failed to execute action %r", action.get("name", "?"))
            return False

    # ------------------------------------------------------------------
    # Variable expansion
    # ------------------------------------------------------------------
    def _expand(self, text: str | None) -> str:
        """Expand ``%ENV%``/``~`` and the launcher's ``{placeholder}`` tokens."""
        if not text:
            return ""
        resolved = os.path.expanduser(os.path.expandvars(text))
        frozen = getattr(sys, "frozen", False)
        replacements = {
            "{appdir}": str(Path(sys.executable).parent if frozen else Path.cwd()),
            "{configdir}": str(self.config_manager.config_dir),
            "{homedir}": str(Path.home()),
            "{tempdir}": os.environ.get("TEMP", "/tmp"),
            "{desktop}": str(Path.home() / "Desktop"),
            "{documents}": str(Path.home() / "Documents"),
            "{downloads}": str(Path.home() / "Downloads"),
        }
        for token, value in replacements.items():
            resolved = resolved.replace(token, value)
        return resolved

    # ------------------------------------------------------------------
    # Action handlers
    # ------------------------------------------------------------------
    def _run_file(self, action: dict[str, Any]) -> bool:
        target = self._expand(action.get("target"))
        if not target:
            return False
        # Accept an absolute/relative path or anything resolvable via PATH.
        program = target if Path(target).exists() else shutil.which(target)
        if not program:
            logger.error("File not found: %s", target)
            return False

        args = self._expand(action.get("arguments"))
        cwd = self._expand(action.get("working_dir")) or str(Path(program).parent)
        return self._spawn(program, args, cwd, elevated=action.get("run_as") == "admin")

    def _run_cmd(self, action: dict[str, Any]) -> bool:
        command = self._expand(action.get("target"))
        if not command:
            return False

        args = self._expand(action.get("arguments"))
        cwd = self._expand(action.get("working_dir")) or os.getcwd()
        shell_command = f"{command} {args}".strip()

        if action.get("run_as") == "admin" and not is_admin():
            return run_elevated("cmd.exe", f"/c {shell_command}", cwd)
        return self._spawn_shell(shell_command, cwd)

    def _run_url(self, action: dict[str, Any]) -> bool:
        url = self._expand(action.get("target"))
        if not url:
            return False
        if not url.startswith(_URL_SCHEMES):
            url = f"https://{url}"
        try:
            return webbrowser.open(url)
        except Exception:
            logger.exception("Failed to open %s", url)
            return False

    def _run_keymouse(self, action: dict[str, Any]) -> bool:
        try:
            from pynput import keyboard, mouse
        except ImportError:
            logger.error("pynput is not installed, cannot run keymouse actions")
            return False

        keys = keyboard.Controller()
        pointer = mouse.Controller()
        for step in action.get("keymouse_steps") or []:
            step_type = step.get("type")
            if step_type == "key":
                self._send_key(keys, step)
            elif step_type == "mouse":
                self._send_mouse(pointer, step)
            elif step_type == "wait":
                time.sleep(step.get("duration", 0))
        return True

    # ------------------------------------------------------------------
    # Process launching
    # ------------------------------------------------------------------
    def _spawn(self, program: str, args: str, cwd: str, elevated: bool) -> bool:
        if elevated and not is_admin():
            return run_elevated(program, args, cwd)
        try:
            if args:
                subprocess.Popen([program, *args.split()], cwd=cwd, start_new_session=True)
            elif sys.platform == "win32":
                os.startfile(program)  # lets the shell apply the file's default verb
            else:
                subprocess.Popen([program], cwd=cwd, start_new_session=True)
        except OSError:
            logger.exception("Failed to launch %s", program)
            return False
        return True

    @staticmethod
    def _spawn_shell(command: str, cwd: str) -> bool:
        try:
            subprocess.Popen(command, cwd=cwd, shell=True, start_new_session=True)
        except OSError:
            logger.exception("Failed to run command: %s", command)
            return False
        return True

    # ------------------------------------------------------------------
    # Input simulation
    # ------------------------------------------------------------------
    @staticmethod
    def _send_key(controller, step: dict[str, Any]) -> None:
        key = _resolve_key(step.get("key", ""))
        if key is None:
            return
        command = step.get("action", "press")
        if command in ("press", "click"):
            controller.press(key)
        if command in ("release", "click"):
            controller.release(key)
        ActionExecutor._pause(step)

    @staticmethod
    def _send_mouse(controller, step: dict[str, Any]) -> None:
        from pynput import mouse

        x, y = step.get("x"), step.get("y")
        command = step.get("action", "click")

        if command == "move":
            if x is not None and y is not None:
                controller.position = (x, y)
        elif command == "click":
            if x is not None and y is not None:
                controller.position = (x, y)
            controller.click(getattr(mouse.Button, step.get("button", "left"), mouse.Button.left))
        elif command == "scroll":
            controller.scroll(step.get("dx", 0), step.get("dy", 0))
        ActionExecutor._pause(step)

    @staticmethod
    def _pause(step: dict[str, Any]) -> None:
        duration = step.get("duration", 0)
        if duration:
            time.sleep(duration)
