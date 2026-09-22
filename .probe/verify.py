"""无头验收：小窗三行槽位 / 材质 / 图标系统 / 四个页面 / 老配置迁移。

分段跑：静态断言 → QTimer 分阶段（等布局与 safePush）→ 逐页截图。
"""

import sys
from pathlib import Path

sys.path.insert(0, "/workspace")

from PySide6.QtCore import Q_ARG, QMetaObject, QObject, QTimer  # noqa: E402
from PySide6.QtGui import QGuiApplication  # noqa: E402
from PySide6.QtWidgets import QApplication  # noqa: E402

from rin_launcher.main import Launcher, _setup_logging  # noqa: E402

OUT = Path("/workspace/.probe/shots")
failures: list[str] = []


def check(label: str, condition: bool, detail: str = "") -> None:
    print(("  PASS  " if condition else "  FAIL  ") + label + (" | " + detail if detail else ""))
    if not condition:
        failures.append(label)


def current_page(main_root: QObject):
    """取 NavigationView 内部 StackView 的当前页（切页会销毁重建，每次都要重取）。"""
    stacks = [c for c in main_root.findChildren(QObject)
              if "StackView" in c.metaObject().className()]
    return stacks[0].property("currentItem") if stacks else None


def array_of(obj: QObject, name: str) -> list:
    """读 QML 的 JS 数组属性：QJSValue 得先 toVariant() 才能当 list 用。"""
    value = obj.property(name)
    return list(value.toVariant()) if value is not None else []


def main() -> int:  # noqa: C901
    app = QApplication(sys.argv)
    app.setApplicationName("Rin Launcher")
    app.setApplicationVersion("1.0.0")
    app.setOrganizationName("RinLauncherProbe")
    app.setQuitOnLastWindowClosed(False)

    launcher = Launcher(app)
    _setup_logging(launcher.config_manager)
    launcher.config_manager.resetToDefaults()
    config = launcher.config_manager

    print("[1] 建窗口")
    check("完整窗口加载成功", launcher.create_main_window())
    check("小窗加载成功", launcher.create_compact_window())
    compact_root = launcher.compact.root_window
    main_root = launcher.window.root_window

    print("[2] 小窗形态")
    screen = QGuiApplication.primaryScreen().availableGeometry()
    expected_h = max(400, round(screen.height() / 2))
    check("高度是桌面可用高度的一半", compact_root.height() == expected_h,
          f"{compact_root.height()} vs {expected_h}")
    check("贴右下角", (compact_root.x(), compact_root.y())
          == (screen.x() + screen.width() - 400 - 16,
              screen.y() + screen.height() - expected_h - 16),
          f"({compact_root.x()},{compact_root.y()})")
    flags = compact_root.flags()
    check("无边框 + 工具窗口", bool(flags & 0x800) and bool(flags & 0x0B), hex(flags))
    # Qt::WindowDoesNotAcceptFocus == 0x08000000
    check("不抢焦点的挂件", bool(flags & 0x200000), hex(flags))
    check("有 acrylicActive 属性", compact_root.property("acrylicActive") is not None)
    check("时钟状态已移除", compact_root.property("now") is None)

    title = compact_root.findChild(QObject, "compactTitle")
    check("标题是「启动台」", title is not None and title.property("text") == "启动台",
          title.property("text") if title else "None")

    print("[3] 三行槽位")
    app_row = compact_root.findChild(QObject, "appRow")
    tool_row = compact_root.findChild(QObject, "toolRow")
    storage_row = compact_root.findChild(QObject, "storageRow")
    check("三行都在", None not in (app_row, tool_row, storage_row))
    check("第一行默认 4 格", len(array_of(app_row, "slots")) == 4,
          str(len(array_of(app_row, "slots"))))
    check("第二行默认 6 格", len(array_of(tool_row, "slots")) == 6,
          str(len(array_of(tool_row, "slots"))))

    print("[4] 存储与磁盘是两个独立槽位")
    disks = array_of(compact_root, "storageSlots")
    kinds = [item.get("kind") for item in disks]
    check("第三行有独立槽位", len(disks) >= 2, str(kinds))
    check("U 盘与磁盘分开", "usb" in kinds and "path" in kinds, str(kinds))
    storage = compact_root.property("storage")
    check("存储卡片有容量信息", bool(storage.get("available")), str(storage.get("path")))

    print("[5] 槽位可增删排序（对齐档案编辑）")
    before = len(config.getLauncherSlots())
    config.addLauncherSlot(1, {"kind": "tool", "key": "quit"})
    check("能加一格", len(config.getLauncherSlots()) == before + 1,
          f"{before} -> {len(config.getLauncherSlots())}")
    check("加完小窗跟着变", len(array_of(tool_row, "slots")) == 7,
          str(len(array_of(tool_row, "slots"))))
    config.moveLauncherSlot(1, 6, -1)
    moved = [item["key"] for item in config.getSlotsInRow(1)]
    check("能前后挪", moved[-2] == "quit", str(moved))
    config.deleteLauncherSlot(1, 6)
    check("能删一格", len(config.getLauncherSlots()) == before,
          str(len(config.getLauncherSlots())))
    config.updateLauncherSlot(0, 0, {"label": "第一个"})
    apps = array_of(compact_root, "appSlots")
    check("能改标签", apps[0].get("name") == "第一个", str(apps[0].get("name")))
    config.updateLauncherSlot(0, 0, {"label": ""})

    print("[6] 图标系统")
    custom = config.getCustomIcons()
    check("图标库目录可用", isinstance(custom, list), str(len(custom)))
    extracted = config.extractIcon(str(Path("/workspace/assets/icon.png")))
    check("能从文件提取图标", extracted.startswith("file:"), extracted)
    if extracted:
        names = [item["key"] for item in config.getCustomIcons()]
        check("提取的图标进了图标库", extracted in names, str(len(names)))
        check("能删掉它", config.deleteCustomIcon(extracted))
        check("删完列表里没有了",
              extracted not in [item["key"] for item in config.getCustomIcons()])

    print("[7] 材质设置")
    settings = config.getSettings()
    check("完整窗口默认增强云母", settings.get("material") == "tabbed",
          str(settings.get("material")))
    check("小窗默认亚克力", settings.get("compactAcrylic") is True,
          str(settings.get("compactAcrylic")))
    check("不再有亚克力开关残留",
          not hasattr(config, "getCategorizedActions") and "blurBackground" not in settings)

    # safePush 有 pushInProgress 守卫，连点会排队；老老实实一页一页切。
    page_queue = ["records", "settings", "about", "launcher"]
    seen: list[str] = []

    def step_page() -> None:
        if not page_queue:
            QTimer.singleShot(900, verify_page)
            return
        main_root.setProperty("requestedPage", page_queue.pop(0))
        QTimer.singleShot(700, check_step)

    def check_step() -> None:
        page = current_page(main_root)
        seen.append(page.property("objectName") if page else "None")
        step_page()

    def phase_pages() -> None:
        print("[8] 四个页面都能打开")
        step_page()

    def verify_page() -> None:
        check("四个页面都能切到", len(set(seen)) == 4, str(seen))
        page = current_page(main_root)
        check("当前页是启动台设置",
              page is not None and page.property("rowApps") == 0
              and page.property("rowStorage") == 2,
              page.property("objectName") if page else "None")
        lists = [page.findChild(QObject, name)
                 for name in ("appSlotList", "toolSlotList", "storageSlotList")]
        check("三行各有一个列表编辑器", None not in lists)
        counts = [len(array_of(item, "slots")) for item in lists if item is not None]
        check("列表编辑器拿到了槽位", counts == [4, 6, 2], str(counts))
        field = page.findChild(QObject, "storagePathField")
        check("存储位置输入框在", field is not None)

        # 打开槽位编辑器，顺便截一张。
        QMetaObject.invokeMethod(page, "editSlot",
                                 Q_ARG("QVariant", 0), Q_ARG("QVariant", 0))
        QTimer.singleShot(900, phase_dialogs)

    def phase_dialogs() -> None:
        page = current_page(main_root)
        editors = [c for c in main_root.findChildren(QObject)
                   if "SlotEditorDialog" in c.metaObject().className()]
        check("槽位编辑器能打开", bool(editors) and editors[0].property("visible") is True,
              f"{len(editors)} 个")
        if editors:
            main_root.grabWindow().save(str(OUT / "dialog_slot.png"))
            # 再从槽位编辑器里开图标选择器。
            pickers = [c for c in editors[0].findChildren(QObject)
                       if "IconPickerDialog" in c.metaObject().className()]
            check("槽位编辑器里挂了图标选择器", bool(pickers))
            if pickers:
                QMetaObject.invokeMethod(pickers[0], "open")
        QTimer.singleShot(1200, phase_picker)

    def phase_picker() -> None:
        pickers = [c for c in main_root.findChildren(QObject)
                   if "IconPickerDialog" in c.metaObject().className()]
        opened = [c for c in pickers if c.property("visible") is True]
        check("图标选择器能打开", bool(opened), f"{len(pickers)} 个，{len(opened)} 个可见")
        if opened:
            main_root.grabWindow().save(str(OUT / "dialog_icons.png"))
            tabs = opened[0].findChild(QObject, "iconTabs")
            check("页签是 Segmented", tabs is not None)
        QTimer.singleShot(400, shots)

    # 截图顺序：先小窗，再逐页。（safePush 是异步的，连点只会排队，必须一页一页等。）
    shot_queue = [("launcher", "page_launcher.png"), ("records", "page_records.png"),
                  ("settings", "page_settings.png"), ("about", "page_about.png")]

    def shots() -> None:
        OUT.mkdir(parents=True, exist_ok=True)
        # 先把还开着的对话框关掉，否则截出来的每张都被弹窗盖住。
        for cls in ("IconPickerDialog", "SlotEditorDialog"):
            for dlg in main_root.findChildren(QObject):
                if cls in dlg.metaObject().className() and dlg.property("visible") is True:
                    QMetaObject.invokeMethod(dlg, "close")
        launcher.show_compact()
        QTimer.singleShot(900, shoot_compact)

    def shoot_compact() -> None:
        compact_root.grabWindow().save(str(OUT / "compact.png"))
        main_root.setHeight(1000)
        QTimer.singleShot(700, shoot_next_page)

    def shoot_next_page() -> None:
        if not shot_queue:
            print(f"\n截图写到 {OUT}")
            finish()
            return
        page, name = shot_queue.pop(0)
        main_root.setProperty("requestedPage", page)
        QTimer.singleShot(800, lambda: grab_page(name))

    def grab_page(name: str) -> None:
        main_root.grabWindow().save(str(OUT / name))
        shoot_next_page()

    def finish() -> None:
        print("\n=== 结果 ===")
        print("全部通过" if not failures else f"{len(failures)} 项失败: {failures}")
        config.resetToDefaults()
        config.stopWatching()
        app.exit(1 if failures else 0)

    QTimer.singleShot(900, phase_pages)
    launcher.show_compact()
    return app.exec()


if __name__ == "__main__":
    sys.exit(main())
