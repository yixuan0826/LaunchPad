# Rin Launcher

基于 **RinUI（PySide6 + QML）** 的启动台应用，版式参考希沃桌面助手的「侧边栏 + 面板」。

## 功能特性

- 🚀 **启动台** — 分区网格 + 实时搜索，仿希沃的三段结构（软件区 / 工具区 / 简易设置）
- 🗂 **档案编辑器** — 分区与条目的可视化增删改、排序、启停、复制，无需手改 YAML
- ⚙️ **完整设置页** — 常规 / 外观 / 搜索 / 热键 / 高级 / 关于，改动即时生效
- 🖱 **右键菜单** — 条目上右键即可打开、提权打开、编辑、复制、启停、上下移、删除
- 📌 **系统托盘** — 显示隐藏、跳转页面、打开配置目录、重载配置、退出
- ⌨️ **全局热键** — 默认 `Ctrl+Space` 唤起启动台，可在设置页直接录制组合键
- 🎯 **多种动作类型** — 文件/程序、命令行、网址、键鼠模拟
- 🔐 **管理员提权** — 条目级提权开关，支持自动 UAC
- 🎨 **主题** — 浅色/深色/跟随系统、强调色、Windows 11 Mica/Acrylic 背景
- 📝 **YAML 配置** — 可读、可导入导出、带自动备份并监听外部修改

## 界面

| 页面 | 作用 |
| --- | --- |
| 启动台 | 搜索、分区网格、工具区、简易设置（主题 / 置顶 / 托盘 / 图标尺寸） |
| 档案 | 左侧分区清单 + 右侧条目列表，所有编辑都发生在这里 |
| 设置 | 全局配置，含热键录制、配置导入导出与重置 |

窗口用 `FluentWindow` + RinUI 的 `NavigationView` 搭骨架：`NavigationView` 自带侧边栏，
正好对上希沃「侧边栏 + 内容面板」的形态。

## 项目结构

```
.
├── rin_launcher/
│   ├── main.py              # 入口：装配窗口、托盘、热键
│   ├── config_manager.py    # 配置读写（对 QML 暴露 camelCase 接口）
│   ├── action_executor.py   # 动作执行引擎
│   ├── hotkey.py            # 全局热键（pynput，独立线程回主线程）
│   ├── tray.py              # 系统托盘（QSystemTrayIcon + QMenu）
│   └── elevation.py         # Windows UAC 提权 / 开机启动
├── qml/
│   ├── LauncherWindow.qml   # 主窗口（FluentWindow + NavigationView）
│   ├── pages/               # 启动台 / 档案 / 设置 三个页面
│   ├── dialogs/             # 条目编辑器、分区编辑器、图标选择器、确认框
│   ├── components/          # AppIcon、EntryTile、CategorySection、FormRow 等
│   └── qmldir
├── RinUI/                   # RinUI 库（内联，MIT，非子模块）
├── assets/
│   ├── icon.ico / icon.png  # 应用图标（由 scripts/build_icon.py 生成）
│   └── icons/lawnicons/     # Lawnicons 图标子集 + LICENSE + NOTICE
└── scripts/
    ├── build_icon.py        # 从 honkai_star_rail.svg 生成 ico/png
    └── vendor_lawnicons.py  # 从上游挑选并并入 Lawnicons 图标
```

## 依赖

- Python 3.10+
- PySide6 6.6+

RinUI 已经**内联**在 `RinUI/`（MIT），无需 clone 子模块，`pip install -r requirements.txt` 即可。

## 安装与运行

```bash
git clone https://github.com/yixuan0826/LaunchPad.git
cd LaunchPad
pip install -r requirements.txt
python -m rin_launcher.main
```

## 打包发布

```bash
pip install pyinstaller
pyinstaller build.spec
# 产物在 dist/RinLauncher.exe
```

## 配置文件

位置：`%APPDATA%\RinLauncher\config.yaml`（每次写入前会自动备份到 `backups/`，
文件被外部程序改动时也会自动重新加载）。

```yaml
version: 1
actions:
  - id: "abc123"
    name: "命令提示符"
    icon: "lawnicons:generic_shell"   # 也可以是 ic_fluent_* 字体图标
    type: "cmd"
    target: "cmd.exe"
    arguments: ""
    working_dir: ""
    run_as: "user"                    # user | admin
    keymouse_steps: []                # 仅 keymouse 类型使用
    category: "开发工具"               # 引用分区名
    enabled: true
    hotkey: ""
    tooltip: ""
    order: 0

categories:
  - id: "cat1"
    name: "开发工具"
    icon: "lawnicons:generic_braces"
    order: 2
    expanded: true

settings:
  theme: "system"                     # system | light | dark
  showTray: true
  startMinimized: false
  autoStart: false
  alwaysOnTop: true
  globalHotkey: "Ctrl+Space"
  searchEngine: "https://www.bing.com/search?q={query}"
  gridColumns: 8                      # 每行摆几个条目
  itemSize: 96
  animationEnabled: true
  blurBackground: true
  accentColor: "#0078d4"
  adminAutoElevate: true
  confirmAdminActions: true
  logLevel: "INFO"
```

> 分区在条目里是**按名字**引用的：重命名分区会级联更新条目，删除分区会把其中的
> 条目移到「默认」分区，手改配置产生的孤儿条目也会自动归集过去，不会凭空消失。

## 动作类型

| 类型 | 说明 |
| --- | --- |
| `file` | `target` 是可执行文件或任意文件；`arguments` / `working_dir` / `run_as` |
| `cmd` | `target` + `arguments` 拼成一条 shell 命令执行 |
| `url` | `target` 是网址，缺少协议时自动补 `https://` |
| `keymouse` | 用 `keymouse_steps` 描述按键 / 鼠标 / 等待序列 |

`keymouse_steps` 的三种步骤：

```yaml
- { type: "key",   key: "ctrl+c", action: press|release|click, duration: 0.1 }
- { type: "mouse", action: click|move|scroll, x: 100, y: 200, dx: 0, dy: 0, button: left|right|middle }
- { type: "wait",  duration: 0.5 }
```

## 变量替换

`target` / `arguments` / `working_dir` 里可用：

- `{appdir}` `{configdir}` `{homedir}` `{tempdir}` `{desktop}` `{documents}` `{downloads}`
- `~` 以及 `%APPDATA%` 之类的环境变量

## 图标系统

两种写法可以混用，`qml/components/AppIcon.qml` 会把它们统一：

| 写法 | 来源 |
| --- | --- |
| `ic_fluent_folder_open_20_regular` | RinUI 内置的 Fluent System Icons 字体图标 |
| `lawnicons:generic_shell` | `assets/icons/lawnicons/` 下随包的 Lawnicons SVG（按主题色着色） |

图标名必须真实存在，否则会渲染成空白：Fluent 的可查
`RinUI/assets/fonts/FluentSystemIcons-Index.js`，条目的图标选择器里也内置了常用清单。

需要更多 Lawnicons 时：

```bash
python scripts/vendor_lawnicons.py --source /path/to/lawnicons/svgs
```

脚本会同步写入 `assets/icons/lawnicons/`，并给缺 `viewBox` 的文件补上
`viewBox="0 0 192 192"`（Qt 的 SVG 渲染器依赖它才能正确缩放）。

## 许可证

本项目以 **GPL-3.0-or-later** 发布。随附的第三方组件：

| 组件 | 许可证 | 位置 |
| --- | --- | --- |
| [RinUI](https://github.com/RinLit-233-shiroko/Rin-UI) | MIT | `RinUI/LICENSE` |
| [Lawnicons](https://github.com/LawnchairLauncher/lawnicons) | Apache-2.0 | `assets/icons/lawnicons/LICENSE` |

Lawnicons 的图标为适配 Qt 做过修改（补 `viewBox`），按 Apache-2.0 §4(b) 的要求在
`assets/icons/lawnicons/NOTICE` 里作了标注。

## 致谢

- [RinUI](https://github.com/RinLit-233-shiroko/Rin-UI) — Fluent Design 风格的 QML UI 库
- [Lawnicons](https://github.com/LawnchairLauncher/lawnicons) — 图标
- [PySide6](https://wiki.qt.io/Qt_for_Python) — Python Qt 绑定
- [Fluent UI System Icons](https://github.com/microsoft/fluentui-system-icons)
