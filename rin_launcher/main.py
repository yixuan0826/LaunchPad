"""Rin Launcher entry point.

Run with ``python -m rin_launcher.main`` (or ``python rin_launcher/main.py``).
"""

from __future__ import annotations

import logging
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
QML_ENTRY = PROJECT_ROOT / "qml" / "LauncherWindow.qml"
COMPACT_ENTRY = PROJECT_ROOT / "qml" / "CompactWindow.qml"
ICON_FILE = PROJECT_ROOT / "assets" / "icon.ico"

# RinUI is vendored in-tree (MIT), so the package root just has to be importable.
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

import RinUI  # noqa: F401  (imported first: it configures HiDPI before Qt starts)
from PySide6.QtCore import Qt  # noqa: E402
from PySide6.QtWidgets import QApplication  # noqa: E402
from RinUI import RinUIWindow  # noqa: E402

from rin_launcher.action_executor import ActionExecutor  # noqa: E402
from rin_launcher.config_manager import ConfigManager  # noqa: E402
from rin_launcher.hotkey import GlobalHotkey  # noqa: E402
from rin_launcher.tray import TrayIcon  # noqa: E402

logger = logging.getLogger(__name__)


def _setup_logging(config_manager: ConfigManager) -> None:
    level_name = str(config_manager.config["settings"].get("logLevel", "INFO")).upper()
    handlers: list[logging.Handler] = [
        logging.FileHandler(config_manager.config_dir / "launcher.log", encoding="utf-8"),
    ]
    # 打包成无控制台的窗口程序后 stdout 是 None，加 StreamHandler 只会刷一堆
    # "no attribute 'write'"。
    if sys.stdout is not None:
        handlers.append(logging.StreamHandler(sys.stdout))

    logging.basicConfig(
        level=getattr(logging, level_name, logging.INFO),
        format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
        handlers=handlers,
    )


class Launcher:
    """Owns the windows plus the OS-level pieces (tray, hotkey, window flags)."""

    def __init__(self, app: QApplication):
        self.app = app
        self.config_manager = ConfigManager()
        self.config_manager.action_executor = ActionExecutor(self.config_manager)

        # 两个 QML 根：常驻桌面右下角的小窗（启动台）和完整窗口（档案 / 设置）。
        self.window: RinUIWindow | None = None
        self.compact: RinUIWindow | None = None
        self.tray = TrayIcon(ICON_FILE)
        self.hotkey = GlobalHotkey()
        self._tray_wired = False

        self._wire_config()

    # ------------------------------------------------------------------
    # Setup
    # ------------------------------------------------------------------
    def _wire_config(self) -> None:
        """Re-apply the OS-level settings whenever they change in the UI."""
        settings = self.config_manager.config["settings"]
        self.config_manager.hotkeyChanged.connect(self.apply_hotkey)
        self.config_manager.alwaysOnTopChanged.connect(self.apply_always_on_top)
        self.config_manager.trayEnabledChanged.connect(self.apply_tray)
        self.config_manager.showToast.connect(
            lambda message, _severity: self.tray.show_message("Rin Launcher", message))

        self.apply_hotkey(str(settings.get("globalHotkey", "")))
        self.apply_tray(bool(settings.get("showTray", True)))

    def _wire_tray(self) -> None:
        # 托盘可以在设置里反复开关，重复连接会让一次点击触发多次。
        if self._tray_wired:
            return
        self._tray_wired = True
        self.tray.toggleLauncherRequested.connect(self.toggle_compact)
        self.tray.showLauncherRequested.connect(self.show_compact)
        self.tray.hideLauncherRequested.connect(self.hide_compact)
        self.tray.openPageRequested.connect(self.handle_tray_page)
        self.tray.openConfigFolderRequested.connect(self.config_manager.openConfigFolder)
        self.tray.reloadConfigRequested.connect(self.config_manager.reloadConfig)
        self.tray.quitRequested.connect(self.quit)

    # ------------------------------------------------------------------
    # Window creation
    # ------------------------------------------------------------------
    def create_main_window(self) -> bool:
        if not QML_ENTRY.is_file():
            logger.error("QML entry point is missing: %s", QML_ENTRY)
            return False

        # Inject the backend before loading, so the first binding already sees it.
        window = RinUIWindow()
        window.engine.rootContext().setContextProperty("ConfigManager", self.config_manager)
        window.load(QML_ENTRY)

        if window.root_window is None:
            logger.error("Failed to load %s", QML_ENTRY)
            return False

        self.window = window
        if ICON_FILE.is_file():
            window.setIcon(ICON_FILE)

        # QML 的关闭按钮只发信号，由这里决定是收起还是真的退出。
        root = window.root_window
        if hasattr(root, "closeRequested"):
            root.closeRequested.connect(self.on_close_requested)
        return True

    def create_compact_window(self) -> bool:
        if not COMPACT_ENTRY.is_file():
            logger.error("Compact QML entry point is missing: %s", COMPACT_ENTRY)
            return False

        window = RinUIWindow()
        window.engine.rootContext().setContextProperty("ConfigManager", self.config_manager)
        window.load(COMPACT_ENTRY)

        if window.root_window is None:
            logger.error("Failed to load %s", COMPACT_ENTRY)
            return False

        self.compact = window
        root = window.root_window
        # 小窗是独立的 QML 根，够不到主窗口，跨窗口的请求统一走信号回到这里。
        root.openMainRequested.connect(self.show_main_page)
        root.hideRequested.connect(self.hide_compact)
        root.quitRequested.connect(self.quit)

        # ThemeManager 挂在共享的 rootContext 上，后建的窗口会把它顶掉。小窗不是
        # RinUI 窗口，主题与背景效果都归主窗口管，所以在这里把它钉回主窗口那一份。
        if self.window is not None:
            self.window.engine.rootContext().setContextProperty(
                "ThemeManager", self.window.theme_manager)

        self.apply_always_on_top(
            bool(self.config_manager.config["settings"].get("alwaysOnTop", True)))
        return True

    # ------------------------------------------------------------------
    # OS integration
    # ------------------------------------------------------------------
    def apply_hotkey(self, sequence: str) -> None:
        if not self.hotkey.register(sequence):
            logger.info("No global hotkey registered (configured value: %r)", sequence)

    def apply_always_on_top(self, enabled: bool) -> None:
        """常驻小窗跟着 settings.alwaysOnTop 走；主窗口保持普通窗口行为。"""
        if self.compact is None or self.compact.root_window is None:
            return
        root = self.compact.root_window
        flags = root.flags()
        flags = flags | Qt.WindowStaysOnTopHint if enabled else flags & ~Qt.WindowStaysOnTopHint
        if flags == root.flags():
            return
        was_visible = root.isVisible()
        root.setFlags(flags)
        if was_visible:  # changing flags hides the window on some platforms
            root.show()

    def apply_tray(self, enabled: bool) -> None:
        if enabled:
            if self.tray.start():
                self._wire_tray()
        else:
            self.tray.stop()

    # ------------------------------------------------------------------
    # Window operations (also invoked from the tray)
    # ------------------------------------------------------------------
    @staticmethod
    def _visible(window: RinUIWindow | None) -> bool:
        return (
            window is not None
            and window.root_window is not None
            and window.root_window.isVisible()
        )

    def show_compact(self) -> None:
        if self.compact is None or self.compact.root_window is None:
            return
        root = self.compact.root_window
        root.show()
        root.raise_()
        root.requestActivate()

    def hide_compact(self) -> None:
        if self.compact is not None and self.compact.root_window is not None:
            self.compact.root_window.hide()

    def toggle_compact(self) -> None:
        if self._visible(self.compact):
            self.hide_compact()
        else:
            self.show_compact()

    def show_main_page(self, page: str) -> None:
        """打开完整窗口并切到指定页（小窗的「打开完整窗口」也走这里）。"""
        if self.window is None or self.window.root_window is None:
            return
        root = self.window.root_window
        root.show()
        root.raise_()
        root.requestActivate()
        root.setProperty("requestedPage", page)

    def hide_main(self) -> None:
        if self.window is not None and self.window.root_window is not None:
            self.window.root_window.hide()

    def handle_tray_page(self, page: str) -> None:
        """托盘菜单里的「启动台」现在指常驻小窗，档案 / 设置才开完整窗口。"""
        if page == "launcher":
            self.show_compact()
        else:
            self.show_main_page(page)

    def on_close_requested(self) -> None:
        """完整窗口的关闭按钮只收起自己 —— 常驻小窗还在，程序不该跟着退出。"""
        self.hide_main()
        if not self.tray.started and not self._visible(self.compact):
            # 没有托盘、小窗也没显示：再没有任何入口能把它叫回来了。
            self.quit()

    def quit(self) -> None:
        self.hotkey.unregister()
        self.tray.stop()
        self.config_manager.stopWatching()
        self.app.quit()

    def run(self) -> int:
        self.config_manager.startWatching()
        if not self.config_manager.config["settings"].get("startMinimized", False):
            self.show_compact()

        try:
            return self.app.exec()
        finally:
            self.quit()


def main() -> int:
    app = QApplication(sys.argv)
    app.setApplicationName("Rin Launcher")
    app.setApplicationVersion("1.0.0")
    app.setOrganizationName("RinLauncher")
    app.setQuitOnLastWindowClosed(False)  # the tray keeps the app alive

    launcher = Launcher(app)
    _setup_logging(launcher.config_manager)

    if not launcher.create_main_window():
        return 1
    if not launcher.create_compact_window():
        return 1

    launcher.hotkey.activated.connect(launcher.toggle_compact)
    return launcher.run()


if __name__ == "__main__":
    sys.exit(main())
