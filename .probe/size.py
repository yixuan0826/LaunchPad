"""临时探针：打印主窗口实际尺寸，确认截图为什么是 1024 宽。"""

import sys

sys.path.insert(0, "/workspace")

from PySide6.QtCore import QTimer  # noqa: E402
from PySide6.QtWidgets import QApplication  # noqa: E402

from rin_launcher.main import Launcher, _setup_logging  # noqa: E402

app = QApplication(sys.argv)
app.setApplicationName("Rin Launcher")
app.setOrganizationName("RinLauncherProbe")
app.setQuitOnLastWindowClosed(False)

launcher = Launcher(app)
_setup_logging(launcher.config_manager)
launcher.create_main_window()
root = launcher.window.root_window


def report() -> None:
    print("root:", root.width(), root.height(), "dpr:", root.devicePixelRatio())
    print("window:", root.property("width"), root.property("height"))
    grab = root.grabWindow()
    print("grab:", grab.width(), grab.height())
    launcher.config_manager.stopWatching()
    app.quit()


QTimer.singleShot(2500, report)
sys.exit(app.exec())
