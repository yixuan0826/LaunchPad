"""冒烟：两个窗口能不能加载出来、有没有 QML 报错。"""

import sys

sys.path.insert(0, "/workspace")

from PySide6.QtCore import QTimer  # noqa: E402
from PySide6.QtWidgets import QApplication  # noqa: E402

from rin_launcher.main import Launcher, _setup_logging  # noqa: E402


def main() -> int:
    app = QApplication(sys.argv)
    app.setApplicationName("Rin Launcher")
    app.setApplicationVersion("1.0.0")
    app.setOrganizationName("RinLauncherSmoke")
    app.setQuitOnLastWindowClosed(False)

    launcher = Launcher(app)
    _setup_logging(launcher.config_manager)

    print("reset:", launcher.config_manager.resetToDefaults())
    print("main:", launcher.create_main_window())
    print("compact:", launcher.create_compact_window())

    def done() -> None:
        print("done")
        app.exit(0)

    QTimer.singleShot(2500, done)
    launcher.show_compact()
    return app.exec()


if __name__ == "__main__":
    sys.exit(main())
