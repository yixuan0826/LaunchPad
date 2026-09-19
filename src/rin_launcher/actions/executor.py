from __future__ import annotations

import os
import sys
import subprocess
import threading
import time
import webbrowser
from pathlib import Path
from typing import Optional

import psutil

from ..core.models import Action, ActionType, KeyMouseStep, RunAs


class ActionExecutor:
    def __init__(self, config_manager):
        self.config_manager = config_manager
        self._admin_cache: dict[str, bool] = {}

    def execute(self, action: Action) -> bool:
        """Execute an action based on its type."""
        try:
            if action.type == ActionType.FILE:
                return self._execute_file(action)
            elif action.type == ActionType.CMD:
                return self._execute_cmd(action)
            elif action.type == ActionType.URL:
                return self._execute_url(action)
            elif action.type == ActionType.KEYMOUSE:
                return self._execute_keymouse(action)
            else:
                print(f"Unknown action type: {action.type}")
                return False
        except Exception as e:
            print(f"Failed to execute action '{action.name}': {e}")
            return False

    def _execute_file(self, action: Action) -> bool:
        target = self._expand_variables(action.target)
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

        args = self._expand_variables(action.arguments) if action.arguments else ""
        working_dir = self._expand_variables(action.working_dir) if action.working_dir else str(path.parent)

        if action.run_as == RunAs.ADMIN:
            return self._run_as_admin(str(path), args, working_dir)
        else:
            return self._run_as_user(str(path), args, working_dir)

    def _execute_cmd(self, action: Action) -> bool:
        command = self._expand_variables(action.target)
        if not command:
            return False

        args = self._expand_variables(action.arguments) if action.arguments else ""
        working_dir = self._expand_variables(action.working_dir) if action.working_dir else os.getcwd()

        full_command = f"{command} {args}".strip()

        if action.run_as == RunAs.ADMIN:
            return self._run_cmd_as_admin(full_command, working_dir)
        else:
            return self._run_cmd_as_user(full_command, working_dir)

    def _execute_url(self, action: Action) -> bool:
        url = self._expand_variables(action.target)
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

    def _execute_keymouse(self, action: Action) -> bool:
        try:
            from pynput import keyboard, mouse
        except ImportError:
            print("pynput not installed, cannot execute keymouse actions")
            return False

        kb = keyboard.Controller()
        ms = mouse.Controller()

        for step in action.keymouse_steps:
            if step.type == "key" and step.key:
                self._simulate_key(kb, step)
            elif step.type == "mouse":
                self._simulate_mouse(ms, step)
            elif step.type == "wait":
                time.sleep(step.duration)

        return True

    def _simulate_key(self, kb: 'keyboard.Controller', step: KeyMouseStep):
        key_str = step.key
        action = step.action or "press"

        # Parse key
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

        if step.duration > 0:
            time.sleep(step.duration)

    def _simulate_mouse(self, ms: 'mouse.Controller', step: KeyMouseStep):
        action = step.action or "click"

        if action == "move":
            if step.x is not None and step.y is not None:
                ms.position = (step.x, step.y)
        elif action == "click":
            button = self._parse_mouse_button(step.button)
            if step.x is not None and step.y is not None:
                ms.position = (step.x, step.y)
            ms.click(button)
        elif action == "scroll":
            ms.scroll(step.dx or 0, step.dy or 0)

        if step.duration > 0:
            time.sleep(step.duration)

    def _parse_key(self, key_str: str):
        from pynput import keyboard
        key_str = key_str.lower()

        # Special keys
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

        # Single character
        if len(key_str) == 1:
            return key_str

        # Try to get from keyboard.Key
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
                os.startfile(path) if sys.platform == "win32" else subprocess.Popen(
                    [path], cwd=working_dir, start_new_session=True
                )
            return True
        except Exception as e:
            print(f"Failed to run as user: {e}")
            return False

    def _run_as_admin(self, path: str, args: str, working_dir: str) -> bool:
        if sys.platform != "win32":
            print("Admin elevation only supported on Windows")
            return self._run_as_user(path, args, working_dir)

        try:
            import ctypes
            from ctypes import wintypes

            # Check if already admin
            if ctypes.windll.shell32.IsUserAnAdmin():
                return self._run_as_user(path, args, working_dir)

            # Use ShellExecuteEx with "runas" verb
            sei = ctypes.wintypes.SHELLEXECUTEINFOW()
            sei.cbSize = ctypes.sizeof(sei)
            sei.fMask = 0x00000040 | 0x00000400  # SEE_MASK_NOCLOSEPROCESS | SEE_MASK_FLAG_NO_UI
            sei.hwnd = 0
            sei.lpVerb = "runas"
            sei.lpFile = path
            sei.lpParameters = args
            sei.lpDirectory = working_dir
            sei.nShow = 1  # SW_SHOWNORMAL

            if ctypes.windll.shell32.ShellExecuteExW(ctypes.byref(sei)):
                return True
            else:
                error = ctypes.GetLastError()
                if error == 1223:  # ERROR_CANCELLED (user cancelled UAC)
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
        if sys.platform != "win32":
            print("Admin elevation only supported on Windows")
            return self._run_cmd_as_user(command, working_dir)

        try:
            import ctypes
            from ctypes import wintypes

            if ctypes.windll.shell32.IsUserAnAdmin():
                return self._run_cmd_as_user(command, working_dir)

            # Run cmd.exe with the command as admin
            sei = ctypes.wintypes.SHELLEXECUTEINFOW()
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
            # Try with extensions on Windows
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

    def is_admin(self) -> bool:
        try:
            import ctypes
            return ctypes.windll.shell32.IsUserAnAdmin() != 0
        except Exception:
            return False

    def restart_as_admin(self) -> bool:
        """Restart the current application with admin privileges."""
        if sys.platform != "win32":
            return False

        if self.is_admin():
            return True

        try:
            import ctypes
            from ctypes import wintypes

            if getattr(sys, 'frozen', False):
                # Running as compiled executable
                exe_path = sys.executable
            else:
                # Running as script
                exe_path = sys.executable
                params = " ".join([f'"{arg}"' for arg in sys.argv[1:]])

            sei = ctypes.wintypes.SHELLEXECUTEINFOW()
            sei.cbSize = ctypes.sizeof(sei)
            sei.fMask = 0x00000040
            sei.hwnd = 0
            sei.lpVerb = "runas"
            sei.lpFile = exe_path
            sei.lpParameters = " ".join([f'"{arg}"' for arg in sys.argv[1:]])
            sei.nShow = 1

            if ctypes.windll.shell32.ShellExecuteExW(ctypes.byref(sei)):
                # Exit current process
                os._exit(0)
            return False
        except Exception as e:
            print(f"Failed to restart as admin: {e}")
            return False