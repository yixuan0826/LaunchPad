#!/usr/bin/env python3
"""
Rin Launcher - Main entry point (QML version).
A launcher application similar to Seewo Desktop Assistant, built with RinUI (QML).
"""

import sys
import os
import logging
from pathlib import Path

# Add project root to path
PROJECT_ROOT = Path(__file__).parent.parent
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

# Add RinUI to path if it exists locally
RINUI_PATH = PROJECT_ROOT / "Rin-UI"
if RINUI_PATH.exists() and str(RINUI_PATH) not in sys.path:
    sys.path.insert(0, str(RINUI_PATH))

# Import RinUI first to set up HiDPI
import RinUI
from RinUI import RinUIWindow, ThemeManager

from PySide6.QtCore import QUrl, Qt, QTimer, QCoreApplication
from PySide6.QtGui import QGuiApplication, QIcon
from PySide6.QtWidgets import QApplication

# Import our modules
from python.config_manager import ConfigManager
from python.action_executor import ActionExecutor


def setup_logging(config_manager: ConfigManager):
    """Setup logging based on config."""
    log_level = getattr(logging, config_manager.config["settings"].get("log_level", "INFO"), logging.INFO)
    logging.basicConfig(
        level=log_level,
        format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
        handlers=[
            logging.StreamHandler(sys.stdout),
            logging.FileHandler(config_manager.config_dir / "launcher.log", encoding="utf-8")
        ]
    )


def main():
    # Enable high DPI scaling (handled by RinUI import)
    # QGuiApplication.setHighDpiScaleFactorRoundingPolicy(
    #     Qt.HighDpiScaleFactorRoundingPolicy.PassThrough
    # )

    app = QApplication(sys.argv)
    app.setApplicationName("Rin Launcher")
    app.setApplicationVersion("1.0.0")
    app.setOrganizationName("RinLauncher")
    app.setQuitOnLastWindowClosed(False)

    # Setup config and logging
    config_manager = ConfigManager()
    setup_logging(config_manager)

    logger = logging.getLogger(__name__)
    logger.info("Starting Rin Launcher (QML version)")

    # Create action executor
    action_executor = ActionExecutor(config_manager)

    # Create RinUI window
    qml_file = PROJECT_ROOT / "qml" / "LauncherWindow.qml"
    if not qml_file.exists():
        logger.error(f"QML file not found: {qml_file}")
        return 1

    # Use RinUIWindow which handles QML engine setup properly
    window = RinUIWindow(qml_file)
    
    # Expose config manager and action executor to QML
    window.engine.rootContext().setContextProperty("ConfigManager", config_manager)
    window.engine.rootContext().setContextProperty("ActionExecutor", action_executor)

    if not window.root_window:
        logger.error("Failed to load QML")
        return 1

    # Set window icon
    icon_path = PROJECT_ROOT / "assets" / "icon.ico"
    if icon_path.exists():
        window.setIcon(icon_path)

    # Start config file watcher
    config_manager.start_watching()

    # Setup global hotkey (Ctrl+Space)
    # Note: For global hotkeys in QML, we'd need a native implementation
    # For now, we'll use a simple timer-based approach or rely on the window being always on top
    
    # Show launcher if not start_minimized
    if not config_manager.config["settings"].get("startMinimized", False):
        window.root_window.show()
    else:
        window.root_window.hide()

    # Run application
    exit_code = app.exec()

    # Cleanup
    config_manager.stop_watching()
    logger.info("Rin Launcher exited")

    return exit_code


if __name__ == "__main__":
    sys.exit(main())