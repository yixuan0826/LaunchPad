"""
Action executor for Rin Launcher (QML version).
Handles executing different types of actions: file, cmd, url, keymouse.
"""

from __future__ import annotations

import os
import sys
import subprocess
import time
import webbrowser
from pathlib import Path
from typing import Optional, Dict, Any, List

try:
    import ctypes
    from ctypes import wintypes
except ImportError:
    ctypes = None
    wintypes = None


class ActionExecutor:
    def __init__(self, config_manager):
        self.config_manager = config_manager

    def execute(self, action: Dict[str, Any]) -> bool:
        """Execute an action based on its type."""
        try:
            action_type = action.get("type", "file")
            if action_type == "file":
                return self._execute_file(action)
            elif action_type == "cmd":
                return self._execute_cmd(action)
            elif action_type == "url":
                return self._execute_url(action)
            elif action_type == "keymouse":
                return self._execute_keymouse(action)
            else:
                print(f"Unknown action type: {action_type}")
                return False
        except Exception as e:
            print(f"Failed to execute action '{action.get('name', 'Unknown')}': {e}")
            return False

    def _execute_file(self, action: Dict[str, Any]) -> bool:
        target = self._expand_variables(action.get("target", ""))
        if not target:
            return False

        path = Path(target)
        if not path.exists():
            # Try to find in PATH
            found = self._find_in_path(target)
            if found:
                path = Path(found)
            else:
                print(f"File not found: {target}")
                return False

        args = self._expand_variables(action.get("arguments", "")) if action.get("arguments") else ""
        working_dir = self._expand_variables(action.get("working_dir", "")) if action.get("working_dir") else str(path.parent)

        run_as = action.get("run_as", "user")
        if run_as == "admin":
            return self._run_as_admin(str(path), args, working_dir)
        else:
            return self._run_as_user(str(path), args, working_dir)

    def _execute_cmd(self, action: Dict[str, Any]) -> bool:
        command = self._expand_variables(action.get("target", ""))
        if not command:
            return False

        args = self._expand_variables(action.get("arguments", "")) if action.get("arguments") else ""
        working_dir = self._expand_variables(action.get("working_dir", "")) if action.get("working_dir") else os.getcwd()

        full_command = f"{command} {args}".strip()

        run_as = action.get("run_as", "user")
        if run_as == "admin":
            return self._run_cmd_as_admin(full_command, working_dir)
        else:
            return self._run_cmd_as_user(full_command, working_dir)

    def _execute_url(self, action: Dict[str, Any]) -> bool:
        url = self._expand_variables(action.get("target", ""))
        if not url:
            return False

        # Ensure URL has a scheme
        if not url.startswith(("http://", "https://", "ftp://", "file://", "mailto:")):
            url = "https://" + url

        try:
            webbrowser.open(url)
            return True
        except Exception as e:
            print(f"Failed to open URL: {e}")
            return False

    def _execute_keymouse(self, action: Dict[str, Any]) -> bool:
        try:
            from pynput import keyboard, mouse
        except ImportError:
            print("pynput not installed, cannot execute keymouse actions")
            return False

        kb = keyboard.Controller()
        ms = mouse.Controller()

        steps = action.get("keymouse_steps", [])
        for step in steps:
            if step.get("type") == "key":
                self._simulate_key(kb, step)
            elif step.get("type") == "mouse":
                self._simulate_mouse(ms, step)
            elif step.get("type") == "wait":
                time.sleep(step.get("duration", 0))

        return True

    def _simulate_key(self, kb: 'keyboard.Controller', step: Dict[str, Any]):
        key_str = step.get("key", "")
        action = step.get("action", "press")

        key = self._parse_key(key_str)
        if key is None:
            return

        if action == "press":
            kb.press(key)
        elif action == "release":
            kb.release(key)
        elif action == "click":
            kb.press(key)
            kb.release(key)

        duration = step.get("duration", 0)
        if duration > 0:
            time.sleep(duration)

    def _simulate_mouse(self, ms: 'mouse.Controller', step: Dict[str, Any]):
        action = step.get("action", "click")

        if action == "move":
            if step.get("x") is not None and step.get("y") is not None:
                ms.position = (step["x"], step["y"])
        elif action == "click":
            button = self._parse_mouse_button(step.get("button", "left"))
            if step.get("x") is not None and step.get("y") is not None:
                ms.position = (step["x"], step["y"])
            ms.click(button)
        elif action == "scroll":
            ms.scroll(step.get("dx", 0), step.get("dy", 0))

        duration = step.get("duration", 0)
        if duration > 0:
            time.sleep(duration)

    def _parse_key(self, key_str: str):
        from pynput import keyboard
        key_str = key_str.lower()

        special_keys = {
            "ctrl": keyboard.Key.ctrl,
            "alt": keyboard.Key.alt,
            "shift": keyboard.Key.shift,
            "win": keyboard.Key.cmd,
            "cmd": keyboard.Key.cmd,
            "super": keyboard.Key.cmd,
            "space": keyboard.Key.space,
            "enter": keyboard.Key.enter,
            "esc": keyboard.Key.esc,
            "escape": keyboard.Key.esc,
            "tab": keyboard.Key.tab,
            "backspace": keyboard.Key.backspace,
            "delete": keyboard.Key.delete,
            "up": keyboard.Key.up,
            "down": keyboard.Key.down,
            "left": keyboard.Key.left,
            "right": keyboard.Key.right,
            "home": keyboard.Key.home,
            "end": keyboard.Key.end,
            "pageup": keyboard.Key.page_up,
            "pagedown": keyboard.Key.page_down,
            "insert": keyboard.Key.insert,
            "f1": keyboard.Key.f1, "f2": keyboard.Key.f2, "f3": keyboard.Key.f3,
            "f4": keyboard.Key.f4, "f5": keyboard.Key.f5, "f6": keyboard.Key.f6,
            "f7": keyboard.Key.f7, "f8": keyboard.Key.f8, "f9": keyboard.Key.f9,
            "f10": keyboard.Key.f10, "f11": keyboard.Key.f11, "f12": keyboard.Key.f12,
            "numlock": keyboard.Key.num_lock,
            "capslock": keyboard.Key.caps_lock,
            "scrolllock": keyboard.Key.scroll_lock,
            "printscreen": keyboard.Key.print_screen,
            "pause": keyboard.Key.pause,
            "menu": keyboard.Key.menu,
        }

        if key_str in special_keys:
            return special_keys[key_str]

        if len(key_str) == 1:
            return key_str

        try:
            return getattr(keyboard.Key, key_str)
        except AttributeError:
            pass

        return None

    def _parse_mouse_button(self, button_str: str):
        from pynput import mouse
        button_map = {
            "left": mouse.Button.left,
            "right": mouse.Button.right,
            "middle": mouse.Button.middle,
        }
        return button_map.get(button_str.lower(), mouse.Button.left)

    def _run_as_user(self, path: str, args: str, working_dir: str) -> bool:
        try:
            if args:
                subprocess.Popen(
                    [path] + args.split(),
                    cwd=working_dir,
                    start_new_session=True
                )
            else:
                if sys.platform == "win32":
                    os.startfile(path)
                else:
                    subprocess.Popen(
                        [path], cwd=working_dir, start_new_session=True
                    )
            return True
        except Exception as e:
            print(f"Failed to run as user: {e}")
            return False

    def _run_as_admin(self, path: str, args: str, working_dir: str) -> bool:
        if sys.platform != "win32" or ctypes is None:
            print("Admin elevation only supported on Windows")
            return self._run_as_user(path, args, working_dir)

        try:
            if ctypes.windll.shell32.IsUserAnAdmin():
                return self._run_as_user(path, args, working_dir)

            sei = wintypes.SHELLEXECUTEINFOW()
            sei.cbSize = ctypes.sizeof(sei)
            sei.fMask = 0x00000040 | 0x00000400
            sei.hwnd = 0
            sei.lpVerb = "runas"
            sei.lpFile = path
            sei.lpParameters = args
            sei.lpDirectory = working_dir
            sei.nShow = 1

            if ctypes.windll.shell32.ShellExecuteExW(ctypes.byref(sei)):
                return True
            else:
                error = ctypes.GetLastError()
                if error == 1223:
                    print("User cancelled UAC prompt")
                else:
                    print(f"ShellExecuteEx failed with error: {error}")
                return False
        except Exception as e:
            print(f"Failed to run as admin: {e}")
            return False

    def _run_cmd_as_user(self, command: str, working_dir: str) -> bool:
        try:
            subprocess.Popen(
                command,
                cwd=working_dir,
                shell=True,
                start_new_session=True
            )
            return True
        except Exception as e:
            print(f"Failed to run command as user: {e}")
            return False

    def _run_cmd_as_admin(self, command: str, working_dir: str) -> bool:
        if sys.platform != "win32" or ctypes is None:
            print("Admin elevation only supported on Windows")
            return self._run_cmd_as_user(command, working_dir)

        try:
            if ctypes.windll.shell32.IsUserAnAdmin():
                return self._run_cmd_as_user(command, working_dir)

            sei = wintypes.SHELLEXECUTEINFOW()
            sei.cbSize = ctypes.sizeof(sei)
            sei.fMask = 0x00000040 | 0x00000400
            sei.hwnd = 0
            sei.lpVerb = "runas"
            sei.lpFile = "cmd.exe"
            sei.lpParameters = f"/c {command}"
            sei.lpDirectory = working_dir
            sei.nShow = 1

            if ctypes.windll.shell32.ShellExecuteExW(ctypes.byref(sei)):
                return True
            else:
                error = ctypes.GetLastError()
                if error == 1223:
                    print("User cancelled UAC prompt")
                else:
                    print(f"ShellExecuteEx failed with error: {error}")
                return False
        except Exception as e:
            print(f"Failed to run command as admin: {e}")
            return False

    def _find_in_path(self, name: str) -> Optional[str]:
        for path_dir in os.environ.get("PATH", "").split(os.pathsep):
            full_path = Path(path_dir) / name
            if full_path.exists():
                return str(full_path)
            if sys.platform == "win32":
                for ext in [".exe", ".bat", ".cmd", ".lnk"]:
                    full_path_ext = full_path.with_suffix(ext)
                    if full_path_ext.exists():
                        return str(full_path_ext)
        return None

    def _expand_variables(self, text: str) -> str:
        if not text:
            return ""

        # Environment variables
        text = os.path.expandvars(text)
        text = os.path.expanduser(text)

        # Custom variables
        replacements = {
            "{appdir}": str(Path(sys.executable).parent if getattr(sys, 'frozen', False) else Path.cwd()),
            "{configdir}": str(self.config_manager.config_dir),
            "{homedir}": str(Path.home()),
            "{tempdir}": os.environ.get("TEMP", "/tmp"),
            "{desktop}": str(Path.home() / "Desktop"),
            "{documents}": str(Path.home() / "Documents"),
            "{downloads}": str(Path.home() / "Downloads"),
        }

        for key, value in replacements.items():
            text = text.replace(key, value)

        return text