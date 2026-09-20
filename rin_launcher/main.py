"""Rin Launcher entry point.

Run with ``python -m rin_launcher.main`` (or ``python rin_launcher/main.py``).
"""

from __future__ import annotations

import logging
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
QML_ENTRY = PROJECT_ROOT / "qml" / "LauncherWindow.qml"
ICON_FILE = PROJECT_ROOT / "assets" / "icon.ico"

# RinUI is vendored as the ``Rin-UI`` submodule; a sibling checkout is also
# accepted so the app can run from a plain source tree.
for _candidate in (PROJECT_ROOT / "Rin-UI", PROJECT_ROOT.parent / "Rin-UI"):
    if (_candidate / "RinUI" / "__init__.py").is_file():
        sys.path.insert(0, str(_candidate))
        break
else:
    print("RinUI not found. Run 'git submodule update --init Rin-UI' first.", file=sys.stderr)
    raise SystemExit(1)

if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from PySide6.QtWidgets import QApplication

import RinUI  # noqa: F401  (imported first: it configures HiDPI before Qt starts)
from rin_launcher.action_executor import ActionExecutor
from rin_launcher.config_manager import ConfigManager
from RinUI import RinUIWindow

logger = logging.getLogger(__name__)


def _setup_logging(config_manager: ConfigManager) -> None:
    level_name = str(config_manager.config["settings"].get("logLevel", "INFO")).upper()
    logging.basicConfig(
        level=getattr(logging, level_name, logging.INFO),
        format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
        handlers=[
            logging.StreamHandler(sys.stdout),
            logging.FileHandler(config_manager.config_dir / "launcher.log", encoding="utf-8"),
        ],
    )


def main() -> int:
    app = QApplication(sys.argv)
    app.setApplicationName("Rin Launcher")
    app.setApplicationVersion("1.0.0")
    app.setOrganizationName("RinLauncher")
    app.setQuitOnLastWindowClosed(False)

    config_manager = ConfigManager()
    _setup_logging(config_manager)

    if not QML_ENTRY.is_file():
        logger.error("QML entry point is missing: %s", QML_ENTRY)
        return 1

    # Inject the backends into the root context *before* loading the QML, so the
    # very first binding already resolves ConfigManager.
    config_manager.action_executor = ActionExecutor(config_manager)
    window = RinUIWindow()
    window.engine.rootContext().setContextProperty("ConfigManager", config_manager)
    window.load(QML_ENTRY)

    if window.root_window is None:
        logger.error("Failed to load %s", QML_ENTRY)
        return 1

    if ICON_FILE.is_file():
        window.setIcon(ICON_FILE)

    config_manager.startWatching()

    if config_manager.config["settings"].get("startMinimized", False):
        window.root_window.hide()
    else:
        window.root_window.show()

    try:
        return app.exec()
    finally:
        config_manager.stopWatching()


if __name__ == "__main__":
    sys.exit(main())
