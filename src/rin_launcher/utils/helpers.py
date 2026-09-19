from __future__ import annotations

import os
import sys
import ctypes
from pathlib import Path
from typing import Optional


def is_admin() -> bool:
    """Check if the current process has admin privileges."""
    try:
        return ctypes.windll.shell32.IsUserAnAdmin() != 0
    except Exception:
        return False


def run_as_admin(executable: str, args: str = "", working_dir: str = "") -> bool:
    """Run a command with admin privileges using UAC."""
    if sys.platform != "win32":
        return False

    try:
        sei = ctypes.wintypes.SHELLEXECUTEINFOW()
        sei.cbSize = ctypes.sizeof(sei)
        sei.fMask = 0x00000040 | 0x00000400
        sei.hwnd = 0
        sei.lpVerb = "runas"
        sei.lpFile = executable
        sei.lpParameters = args
        sei.lpDirectory = working_dir or os.getcwd()
        sei.nShow = 1

        return ctypes.windll.shell32.ShellExecuteExW(ctypes.byref(sei))
    except Exception:
        return False


def get_app_data_dir(app_name: str = "RinLauncher") -> Path:
    """Get the application data directory."""
    if sys.platform == "win32":
        base = Path(os.environ.get("APPDATA", Path.home() / "AppData" / "Roaming"))
    else:
        base = Path.home() / ".local" / "share"
    return base / app_name


def expand_variables(text: str, config_dir: Optional[Path] = None) -> str:
    """Expand environment variables and custom placeholders."""
    if not text:
        return ""

    # Environment variables
    text = os.path.expandvars(text)
    text = os.path.expanduser(text)

    # Custom variables
    replacements = {
        "{appdir}": str(Path(sys.executable).parent if getattr(sys, 'frozen', False) else Path.cwd()),
        "{configdir}": str(config_dir) if config_dir else "",
        "{homedir}": str(Path.home()),
        "{tempdir}": os.environ.get("TEMP", "/tmp"),
        "{desktop}": str(Path.home() / "Desktop"),
        "{documents}": str(Path.home() / "Documents"),
        "{downloads}": str(Path.home() / "Downloads"),
    }

    for key, value in replacements.items():
        text = text.replace(key, value)

    return text


def find_executable(name: str) -> Optional[str]:
    """Find an executable in PATH."""
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