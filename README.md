# Rin Launcher

基于 **RinUI（PySide6 + QML）** 的桌面启动台，版式参考希沃桌面助手的「侧边栏 + 面板」。
启动台负责"点一下就用"，档案页负责"把东西管起来"，设置页负责"照自己的习惯调"。

- 主界面：`FluentWindow` + RinUI `NavigationView`（侧边导航 / 启动台 · 档案 · 设置）
- 图标：RinUI 的 Fluent 字体图标 + 随包的 50 个 [Lawnicons](https://github.com/LawnchairLauncher/lawnicons) SVG，可混用
- 配置：一份可读的 YAML，带自动备份、外部修改热加载
- 目标平台：Windows 10/11（UAC 提权、开机启动、注册表相关功能仅 Windows 可用）

---

## 功能特性

| | |
| --- | --- |
| 🚀 **启动台** | 分区网格 + 输入即筛的搜索，仿希沃的三段结构：软件区 / 工具区 / 简易设置 |
| 🖱 **右键菜单** | 条目上右键即可 打开 · 提权打开 · 编辑 · 复制 · 启停 · 上移 · 下移 · 删除 |
| 🗂 **档案编辑器** | 分区与条目的可视化增删改、排序、启停，全程不用手改 YAML |
| ⚙️ **完整设置页** | 常规 / 外观 / 搜索 / 热键 / 高级 / 关于，改完立即生效 |
| 📌 **系统托盘** | 显示隐藏、跳转页面、打开配置目录、重载配置、退出 |
| ⌨️ **全局热键** | 默认 `Ctrl+Space`，在设置页点一下直接录制组合键 |
| 🎯 **四种动作** | 文件/程序、命令行、网址、键鼠模拟 |
| 🔐 **管理员提权** | 条目级 `run_as: admin`，触发 UAC |
| 🎨 **主题** | 浅色 / 深色 / 跟随系统、强调色、Windows 11 亚克力背景 |

---

## 界面导览

### 启动台

自上而下三块，对齐希沃侧边栏的组织方式：

1. **顶部工具条** — 搜索框、`新建条目`、一键折叠/展开全部分区、重载配置
2. **软件区** — 按分区成组的条目卡片网格。分区标题栏可点击折叠，卡片右键出菜单
3. **工具区** — 打开配置目录、重载配置、跳档案、跳设置、以管理员身份重启
4. **简易设置** — 主题模式、窗口置顶、托盘图标、条目尺寸，改完即写盘

### 档案

左边是分区清单（改名 / 换图标 / 排序 / 删除），右边是选中分区里的条目
（启停开关 + 上移 / 下移 / 编辑 / 复制 / 删除）。右上角可导入导出整份配置。
顶部的过滤框按名字或悬停提示筛选条目。

未选中分区时右侧显示**全部条目**。

### 设置

| 分组 | 内容 |
| --- | --- |
| 常规 | 开机自动启动、启动时最小化、系统托盘图标、窗口置顶 |
| 外观 | 主题模式、强调色、背景模糊、条目尺寸、网格列数、动画效果 |
| 搜索 | 搜索引擎模板 |
| 热键 | 全局热键录制（含恢复默认） |
| 高级 | 自动提权、提权前确认、日志级别、配置管理（打开目录/文件、导入、导出、提权重启、恢复默认） |
| 关于 | 版本、项目仓库、第三方组件与许可证链接 |

### 托盘与热键

托盘菜单：`显示 / 隐藏 Rin Launcher`、`启动台`、`档案`、`设置`、`打开配置目录`、
`重新加载配置`、`退出`；左键单击托盘图标等于显示/隐藏切换。

窗口右上角的关闭按钮**不会退出程序**：托盘可用时收进托盘，托盘不可用（或在设置里
关掉了托盘）才真正退出。

全局热键默认 `Ctrl+Space`。热键必须**至少含一个修饰键**（Ctrl / Alt / Shift / Win）——
裸键会拦截系统里的正常输入，所以留空或只按一个普通键都不会注册。

---

## 快速开始

### 环境要求

- Python 3.10+
- PySide6 6.6+
- 全局热键需要 `pynput`，配置热加载需要 `watchdog`（都已在 `requirements.txt` 里）

RinUI 已经**内联**在 `RinUI/`（MIT，非子模块），不需要额外 clone。

### 安装

```bash
git clone https://github.com/yixuan0826/RinLauncher.git
cd RinLauncher
pip install -r requirements.txt
```

### 运行

```bash
python -m rin_launcher.main
```

首次运行会在配置目录生成一份带默认分区的 `config.yaml`，并直接显示启动台。

### 打包

```bash
pip install pyinstaller
pyinstaller build.spec
# 产物：dist/RinLauncher.exe
```

`build.spec` 会把 `qml/`、`RinUI/`、`assets/` 一并打进去——QML、字体、图标都不是
Python 模块，漏掉任何一个都会导致运行期找不到资源。

---

## 配置文件

路径：`%APPDATA%\RinLauncher\config.yaml`

同目录下还有：

- `backups/config.yaml.bak.<时间戳>` — 每次写入前自动备份，保留最近 10 份
- `launcher.log` — 运行日志，级别由 `settings.logLevel` 决定

配置文件被外部程序改动时会自动重新加载（0.5 秒防抖）；程序自己写盘的那一次会被忽略，
不会来回打架。也可以随时点托盘或工具区的「重新加载配置」手动触发。

### 完整示例

```yaml
version: 1

actions:
  - id: "9f3c1a7b"
    name: "命令提示符"
    icon: "lawnicons:generic_shell"   # 也可以用 ic_fluent_* 字体图标
    type: "cmd"                       # file | cmd | url | keymouse
    target: "cmd.exe"
    arguments: ""
    working_dir: ""
    run_as: "user"                    # user | admin（admin 会触发 UAC）
    keymouse_steps: []                # 仅 keymouse 使用
    category: "开发工具"               # 按「名字」引用分区
    enabled: true
    hotkey: ""                        # 展示在卡片上的提示，不参与全局热键
    tooltip: "打开命令行"
    order: 0                          # 分区内排序，越小越靠前

categories:
  - id: "c1a2b3d4"
    name: "开发工具"
    icon: "lawnicons:generic_braces"
    order: 2                          # 分区排序，越小越靠前
    expanded: true

settings:
  theme: "system"                     # system | light | dark
  accentColor: "#0078d4"
  showTray: true
  startMinimized: false
  autoStart: false
  alwaysOnTop: true
  globalHotkey: "Ctrl+Space"
  gridColumns: 8                      # 每行摆几个条目
  itemSize: 96                        # 条目卡片边长（72–144）
  blurBackground: true
  logLevel: "INFO"                    # DEBUG | INFO | WARNING | ERROR
```

### settings 字段

| 键 | 默认值 | 作用 |
| --- | --- | --- |
| `theme` | `system` | 主题模式，改动即时切换 |
| `accentColor` | `#0078d4` | 强调色，改动即时切换 |
| `showTray` | `true` | 是否创建托盘图标；关掉后关闭窗口即退出 |
| `startMinimized` | `false` | 启动时不显示窗口，只驻留托盘 |
| `autoStart` | `false` | 开机自启，写 `HKCU\...\Run`（仅 Windows） |
| `alwaysOnTop` | `true` | 窗口置顶 |
| `globalHotkey` | `Ctrl+Space` | 全局热键 |
| `gridColumns` | `8` | 启动台每行的条目数 |
| `itemSize` | `96` | 条目卡片边长 |
| `blurBackground` | `true` | 亚克力背景（仅 Windows 生效） |
| `logLevel` | `INFO` | 日志级别，**改动需重启生效** |
| `language` | `zh_CN` | 预留，界面目前只有中文 |
| `fontFamily` / `fontSize` | `Microsoft YaHei UI` / `12` | 预留，尚未接入 |
| `searchEngine` | Bing | 预留，见「已知限制」 |
| `animationEnabled` | `true` | 预留，见「已知限制」 |
| `adminAutoElevate` | `true` | 预留，见「已知限制」 |
| `confirmAdminActions` | `true` | 预留，见「已知限制」 |

> **分区在条目里是按名字引用的**，所以：
> - 重命名分区会自动级联更新引用它的条目；
> - 删除分区时，其中的条目会被移到「默认」分区，不会丢；
> - 手改 YAML 造成的孤儿条目（引用了不存在的分区）也会归集到「默认」分区。
>
> 同一个分区名不要重复，否则分组结果会变得不可预期（编辑器里会拦下来）。

---

## 动作类型

| 类型 | 字段 | 说明 |
| --- | --- | --- |
| `file` | `target`、`arguments`、`working_dir`、`run_as` | `target` 可以是绝对路径、相对路径，或 PATH 里的可执行文件名（如 `notepad.exe`） |
| `cmd` | `target` + `arguments` | 两者拼成一条命令交给 shell 执行 |
| `url` | `target` | 缺少协议时自动补 `https://` |
| `keymouse` | `keymouse_steps` | 按顺序回放按键 / 鼠标 / 等待 |

## 键鼠序列

`keymouse_steps` 是一个列表，元素有三种：

```yaml
- type: "key"                     # 按键
  key: "ctrl+c"                   # 支持单字符、ctrl/alt/shift/win、f1-f12、方向键等
  action: "click"                 # press | release | click
  duration: 0.1                   # 该步之后的停顿（秒）

- type: "mouse"                   # 鼠标
  action: "click"                 # click | move | scroll
  button: "left"                  # left | right | middle
  x: 960                          # 屏幕绝对坐标；click/move 用，留空表示保持原位
  y: 540
  dx: 0                           # scroll 用
  dy: -3
  duration: 0.1

- type: "wait"                    # 纯等待
  duration: 0.5                   # 秒
```

编辑器里 `duration` 以**毫秒**填，写进 YAML 时换算成秒。

## 变量替换

`target` / `arguments` / `working_dir` 支持：

| 占位符 | 含义 |
| --- | --- |
| `{appdir}` | 程序所在目录（打包后是 exe 所在目录，开发运行时是当前工作目录） |
| `{configdir}` | 配置目录 |
| `{homedir}` | 用户主目录 |
| `{tempdir}` | 临时目录 |
| `{desktop}` `{documents}` `{downloads}` | 对应的用户文件夹 |

另外 `~` 和环境变量（如 `%APPDATA%`）也会被展开。

---

## 图标系统

条目和分区的 `icon` 字段支持两种写法，由 `qml/components/AppIcon.qml` 统一渲染：

| 写法 | 来源 |
| --- | --- |
| `ic_fluent_folder_open_20_regular` | RinUI 内置的 Fluent System Icons 字体图标 |
| `lawnicons:generic_shell` | `assets/icons/lawnicons/` 下的 Lawnicons SVG，按主题色着色 |

**图标名必须真实存在**，否则会渲染成空白。可查范围：

- Fluent：[`RinUI/assets/fonts/FluentSystemIcons-Index.js`](RinUI/assets/fonts/FluentSystemIcons-Index.js)（全部可用名）
- 条目编辑器的图标选择器里内置了 107 个常用 Fluent 名 + 全部 50 个随包 Lawnicons，分两个标签页

需要更多 Lawnicons：

```bash
python scripts/vendor_lawnicons.py --source /path/to/lawnicons/svgs
```

脚本会按 `BUNDLED` 清单把图标复制进 `assets/icons/lawnicons/`，并给缺少 `viewBox` 的文件
补上 `viewBox="0 0 192 192"` —— Qt 的 SVG 渲染器依赖它才能正确缩放，上游有相当一部分
文件只写了 `width`/`height`。这是一处对上游文件的修改，按 Apache-2.0 §4(b) 的要求已在
`assets/icons/lawnicons/NOTICE` 里标注。

---

## 目录结构

```
.
├── rin_launcher/                # Python 后端
│   ├── main.py                  # 入口：装配窗口 / 托盘 / 热键
│   ├── config_manager.py        # 配置读写，对 QML 暴露 camelCase 接口
│   ├── action_executor.py       # 四种动作的执行引擎
│   ├── hotkey.py                # 全局热键（pynput 监听，信号回主线程）
│   ├── tray.py                  # 系统托盘（QSystemTrayIcon + QMenu）
│   └── elevation.py             # Windows UAC 提权 / 开机启动
├── qml/
│   ├── LauncherWindow.qml       # 主窗口（FluentWindow + NavigationView）
│   ├── pages/                   # 启动台 / 档案 / 设置
│   ├── dialogs/                 # 条目编辑器、分区编辑器、图标选择器、确认框
│   ├── components/              # AppIcon / EntryTile / CategorySection / FormRow …
│   └── qmldir
├── RinUI/                       # RinUI 库（内联，MIT）
├── assets/
│   ├── icon.ico / icon.png      # 应用图标
│   └── icons/lawnicons/         # 50 个 Lawnicons SVG + LICENSE + NOTICE
├── scripts/
│   ├── build_icon.py            # 从 honkai_star_rail.svg 生成 ico / png
│   └── vendor_lawnicons.py      # 从上游挑选并并入 Lawnicons
├── build.spec                   # PyInstaller 配置
└── requirements.txt
```

## 实现说明

**为什么用 `FluentWindow` + `NavigationView`？**
`FluentWindowBase` 的内容区 `contentArea` 是一个普通 `Item`，不是 Layout。把页面直接挂在
窗口下并写 `Layout.fillWidth` / `Layout.fillHeight` 是**完全无效**的，页面会被算成 0×0，
表现为"窗口打开了但一片空白"。`NavigationView` 自带侧边导航和页面栈，既绕开了这个坑，
骨架也正好对上"侧边栏 + 面板"的形态。

**QML 与 Python 之间怎么通信？**
后端只有一个上下文属性 `ConfigManager`。所有读写都是它的 `@Slot`，QML 侧调
`ConfigManager.xxx()`；写成功后会发出 `configChanged`，页面据此重取数据，因此各个对话框
不需要反过来通知谁刷新。少数需要落到操作系统上的设置（热键、置顶、托盘）由
`ConfigManager` 再发一个专用信号，`main.py` 接住后应用到窗口。

**设置页为什么有防抖？**
滑杆和输入框会连续产生改动，设置页先攒进 `pending`，再由 350ms 的定时器合并成一次
`updateSettings()`；离开页面时会强制冲刷。而且当值没有真的变化时直接跳过写盘。

## 已知限制

- **四个设置项目前只存不用**：`searchEngine`、`animationEnabled`、`adminAutoElevate`、
  `confirmAdminActions` 会被写进配置、界面也能改，但还没有代码消费它们。`fontFamily`、
  `fontSize`、`language` 同理（且未出现在界面上）。
- **托盘依赖系统支持**：`QSystemTrayIcon.isSystemTrayAvailable()` 为假时不会创建托盘，
  此时关闭窗口等于退出程序。
- **提权与开机启动仅 Windows**：`elevation.py` 走的是 `ShellExecuteExW` 与注册表。非 Windows
  平台上执行 `run_as: admin` 的条目会**直接失败**（日志里给出一条 warning），不会静默降级成
  普通启动。
- **RinUI 自身的控制台告警**：`Dialog.qml` 里 `Overlay.overlay` 为空时的 `TypeError`、
  `Slider.qml` 的同类告警，以及 `propertyCache` 的成员覆盖提示，都是库内部行为，
  不影响功能（本项目的对话框都显式指定了尺寸）。

---

## 第三方组件与许可证

本项目以 **GPL-3.0-or-later** 发布（见 [`LICENSE`](LICENSE)）。

| 组件 | 许可证 | 位置 |
| --- | --- | --- |
| [RinUI](https://github.com/RinLit-233-shiroko/Rin-UI) | MIT | [`RinUI/LICENSE`](RinUI/LICENSE) |
| [Lawnicons](https://github.com/LawnchairLauncher/lawnicons) | Apache-2.0 | [`assets/icons/lawnicons/LICENSE`](assets/icons/lawnicons/LICENSE) |
| [Fluent UI System Icons](https://github.com/microsoft/fluentui-system-icons) | MIT | 随 RinUI 提供 |

Lawnicons 的图标为适配 Qt 做过修改（补 `viewBox`），已按 Apache-2.0 §4(b) 在
[`assets/icons/lawnicons/NOTICE`](assets/icons/lawnicons/NOTICE) 中标注。Apache-2.0 §6 不授予
商标权：`honkai_star_rail.svg` 是 Lawnicons 对第三方产品标识的单色演绎，此处仅用作本程序
图标，不代表任何关联或背书；其余随包图标均为 Lawnicons 贡献的 `generic_*` 通用图案。

## 致谢

- [RinUI](https://github.com/RinLit-233-shiroko/Rin-UI) — Fluent Design 风格的 QML UI 库
- [Lawnicons](https://github.com/LawnchairLauncher/lawnicons) — 图标
- [PySide6](https://wiki.qt.io/Qt_for_Python) — Python Qt 绑定
