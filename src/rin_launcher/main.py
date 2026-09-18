#!/usr/bin/env python3
"""Rin Launcher - Main entry point."""

import sys
import os
import logging
from pathlib import Path

# Add src to path for development
src_path = Path(__file__).parent.parent
if str(src_path) not in sys.path:
    sys.path.insert(0, str(src_path))

from PySide6.QtWidgets import QApplication
from PySide6.QtGui import QGuiApplication
from PySide6.QtCore import Qt

from rin_launcher.core.config_manager import ConfigManager
from rin_launcher.ui.launcher_window import LauncherWindow


def setup_logging(config_manager: ConfigManager):
    """Setup logging based on config."""
    log_level = getattr(logging, config_manager.config.settings.log_level, logging.INFO)
    logging.basicConfig(
        level=log_level,
        format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
        handlers=[
            logging.StreamHandler(sys.stdout),
            logging.FileHandler(config_manager.config_dir / "launcher.log", encoding="utf-8")
        ]
    )


def main():
    # Enable high DPI scaling
    QGuiApplication.setHighDpiScaleFactorRoundingPolicy(
        Qt.HighDpiScaleFactorRoundingPolicy.PassThrough
    )

    app = QApplication(sys.argv)
    app.setApplicationName("Rin Launcher")
    app.setApplicationVersion("1.0.0")
    app.setOrganizationName("RinLauncher")
    app.setQuitOnLastWindowClosed(False)

    # Setup config and logging
    config_manager = ConfigManager()
    setup_logging(config_manager)

    logger = logging.getLogger(__name__)
    logger.info("Starting Rin Launcher")

    # Create main window
    window = LauncherWindow(config_manager)

    # Start config file watcher
    config_manager.start_watching()

    # Show launcher if not start_minimized
    if not config_manager.config.settings.start_minimized:
        window.show_launcher()
    else:
        window.hide_launcher()

    # Run application
    exit_code = app.exec()

    # Cleanup
    config_manager.stop_watching()
    logger.info("Rin Launcher exited")

    sys.exit(exit_code)


if __name__ == "__main__":
    main()