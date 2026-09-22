"""临时探针：打开槽位编辑器，打印弹窗的几何与 parent 是谁。"""

import sys

sys.path.insert(0, "/workspace")

from PySide6.QtCore import Q_ARG, QMetaObject, QObject, QTimer  # noqa: E402
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


def current_page():
    stacks = [c for c in root.findChildren(QObject) if "StackView" in c.metaObject().className()]
    return stacks[0].property("currentItem") if stacks else None


def step1():
    root.setProperty("requestedPage", "launcher")
    QTimer.singleShot(900, step2)


def step2():
    page = current_page()
    print("page:", page.property("x"), page.property("y"),
          page.property("width"), page.property("height"))
    print("window:", root.width(), root.height())
    QMetaObject.invokeMethod(page, "editSlot", Q_ARG("QVariant", 0), Q_ARG("QVariant", 0))
    QTimer.singleShot(800, step3)


def step3():
    for dlg in root.findChildren(QObject):
        if "SlotEditorDialog" in dlg.metaObject().className():
            parent = dlg.property("parent")
            print("dialog x/y/w/h:", dlg.property("x"), dlg.property("y"),
                  dlg.property("width"), dlg.property("height"))
            print("dialog parent:", parent.metaObject().className() if parent else None,
                  parent.property("x") if parent else "",
                  parent.property("y") if parent else "",
                  parent.property("width") if parent else "",
                  parent.property("height") if parent else "")
    launcher.config_manager.stopWatching()
    app.quit()


QTimer.singleShot(1200, step1)
QTimer.singleShot(7000, app.quit)
sys.exit(app.exec())
