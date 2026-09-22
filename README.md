# Rin Launcher

基于 **RinUI（PySide6 + QML）** 的桌面启动台。常驻在桌面右下角的**小窗**负责「点一下就用」，
**完整窗口**负责「把东西管起来、照自己的习惯调」。

- 常驻小窗：无边框亚克力挂件，锚在桌面右下角（不抢焦点、不进任务栏），高度固定为桌面可用高度的一半，可拖动并记住位置
- 完整窗口：`FluentWindow` + RinUI `NavigationView`（侧边导航 / 启动台 · 档案 · 设置 · 关于），材质走 RinUI 的**增强云母**
- 启动台三行都是**可增删排序的槽位**：常用应用 / 快捷功能 / 存储与磁盘，每格能换内容、改名字、换图标
- 图标：RinUI 的 Fluent 字体图标、随包的 [Lawnicons](https://github.com/LawnchairLauncher/lawnicons) SVG、
  自己导入的 svg/png/ico，以及从 exe/dll/lnk 里抠出来的图标
- 配置：一份可读的 YAML，带自动备份、外部修改热加载
- 目标平台：Windows 10/11（UAC 提权、开机启动、亚克力与无焦点窗口仅 Windows 可用）

---

## 功能特性

| | |
| --- | --- |
| 🪟 **常驻小窗** | 亚克力材质的无焦点挂件锚在桌面右下角、高度为桌面一半；三行槽位可增删排序，可拖动并记住位置 |
| 🚀 **启动台设置** | 完整窗口的「启动台」页直接编辑小窗那三行：加一格 / 换内容 / 改名字 / 换图标 / 前后挪 / 删掉，改完小窗立即刷新 |
| 💾 **U 盘与磁盘分开** | 「可移动磁盘（自动检测）」和「指定的文件/文件夹/磁盘」是两种独立槽位，各自一格，互不影响 |
| 🖱 **右键菜单** | 小窗每一格右键：打开 · 提权打开 · 编辑这一格 · 再加一格 |
| 🗂 **档案编辑器** | 分区与条目的可视化增删改、排序、启停、批量操作，全程不用手改 YAML |
| 🎨 **图标选择器** | 四个来源分页（内置 / 随包 / 我的 / 从程序提取），选中态一目了然，支持导入 svg·png·ico 与从 exe·dll 提取 |
| ⚙️ **完整设置页** | 顶部锚点跳转 常规 / 外观 / 启动台 / 热键 / 高级，改完立即生效；「关于」是独立一页 |
| 📌 **系统托盘** | 显示、隐藏、跳转页面、打开配置目录、重载配置、退出 |
| ⌨️ **全局热键** | 默认 `Ctrl+Space`，在设置页点一下直接录制组合键 |
| 🎯 **四种动作** | 文件/程序、命令行、网址、键鼠模拟 |
| 🔐 **管理员提权** | 条目级 `run_as: admin`，触发 UAC |
| 🎨 **主题** | 浅色 / 深色 / 跟随系统、强调色、窗口材质（增强云母 / 云母 / 不透明） |

---

## 界面导览

程序起来后有两块界面：**常驻小窗**（启动台）和**完整窗口**（启动台 · 档案 · 设置 · 关于）。

### 常驻小窗（启动台）

一块无边框的**亚克力挂件**贴在桌面右下角，高度是桌面可用高度的一半。它点得动，但
**不接受焦点、不进任务栏** —— 用起来像桌面上的一个部件，而不是一个会抢走当前焦点的窗口。
自上而下：

1. **标题条** — 左边是程序图标（无底板）+「启动台」字样，右边一个小钉子提示是否置顶；
   这一条同时是拖拽区
2. **第一行 · 常用应用** — 大格子，左键启动，右键出菜单
3. **第二行 · 快捷功能** — 小格子，放内置动作：启动台设置、档案管理、设置、配置目录、
   配置文件、重载配置、提权重启、隐藏小窗、退出程序
4. **第三行 · 存储与磁盘** — 最左边那张固定卡片是配置好的存储目录（显示剩余空间与占用条），
   后面跟着两种**互相独立**的磁盘入口：自动检测的「可移动磁盘」和指定的「文件/文件夹/磁盘」
5. **底部条** — `打开完整窗口` + 启动台设置 / 档案 / 设置 / 更多（更多 → 启动台设置… ·
   档案管理… · 设置… · 回到右下角 · 刷新磁盘信息 · 隐藏小窗 · 退出）

三行都**不是定死的**：每一行有自己的槽位列表，可以加、删、前后挪，每格还能改名字、换图标 ——
都在完整窗口的「启动台」页里配。引用失效（条目被删掉或停用）的槽位会自动跳过，不会留下
半透明的空位。

每一格的右键菜单是 `打开` · `以管理员身份打开`（仅 `file` / `cmd` 条目）· `编辑这一格…` ·
`再加一格…`。

拖标题条就能移动窗口，位置写进 `settings.compactPos`，下次启动回到原处；想让它重新贴回
右下角，用「更多 → 回到右下角」。

窗口**不会被关闭按钮关掉**（它本来就没有标题栏）—— 隐藏与退出都在「更多」菜单和托盘里。

### 完整窗口

侧边四页：

- **启动台** — 小窗那三行的列表编辑器。每一行一个列表，每项都能上移 / 下移 / 编辑 / 删除，
  行尾是「加一格」；第三行另有一栏填固定的存储目录（可手填、可「浏览…」、可直接打开）。
  改完立即写盘，小窗跟着刷新。
- **档案** — 左边是分区清单（改名 / 换图标 / 排序 / 删除），右边是选中分区里的条目。
  顶部工具条管整页：导入 / 导出 / 新建分区 / 新建条目；条目区自己还有过滤框和全选，
  勾选若干条之后会浮出批量操作条（启用 / 停用 / 删除）。每张条目卡上有上移 / 下移 /
  编辑 / 复制 / 删除。未选中分区时右侧显示**全部条目**。这里也是启动台第一行槽位的
  **候选项来源**。
- **设置** — 见下表
- **关于** — 版本、项目仓库与文档链接、运行环境、配置目录 / 配置文件 / 图标库的快捷入口、
  第三方组件与许可证

### 设置

| 分组 | 内容 |
| --- | --- |
| 常规 | 开机自动启动、启动时最小化、系统托盘图标、小窗置顶 |
| 外观 | 主题模式、强调色、**窗口材质**（增强云母 / 云母 / 不透明）、**小窗亚克力**、动画效果 |
| 启动台 | 小窗的**行为**（内容在「启动台」页调）：跳到启动台设置、刷新磁盘信息 |
| 热键 | 全局热键录制（含恢复默认） |
| 高级 | 自动提权、提权前确认、日志级别、配置管理（目录 / 文件 / 导入 / 导出）、图标库目录、以管理员重启、恢复默认 |
| 关于 | 跳到「关于」页 |

### 托盘与热键

托盘菜单：`显示 / 隐藏 Rin Launcher`、`启动台`、`档案`、`设置`、`打开配置目录`、
`重新加载配置`、`退出`；左键单击托盘图标等于显示/隐藏切换。菜单里的「启动台」打开的是
**常驻小窗**，「档案」「设置」才去开完整窗口。

完整窗口右上角的关闭按钮**只收起它自己**，常驻小窗照常跑着。只有当托盘不可用、小窗也没
显示时，关闭才会真的退出程序。

全局热键默认 `Ctrl+Space`，用来显示 / 隐藏常驻小窗。热键必须**至少含一个修饰键**
（Ctrl / Alt / Shift / Win）—— 裸键会拦截系统里的正常输入，所以留空或只按一个普通键都不会注册。

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

首次运行会在配置目录生成一份带默认分区的 `config.yaml`，并在桌面右下角显示常驻小窗。

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

launcher:                             # 常驻小窗那三行，内容是「槽位」列表
  slots:                              # 行内顺序 = 数组顺序，row 决定落在哪一行
    - {kind: "action", row: 0, ref: "9f3c1a7b", label: "", icon: ""}
    - {kind: "tool", row: 1, key: "configFolder", label: "", icon: ""}
    - {kind: "usb", row: 2, label: "U 盘", icon: ""}
    - {kind: "path", row: 2, label: "D 盘", path: "D:\\", icon: ""}
  storagePath: ""                     # 第三行最左边那张固定卡片显示的目录，空串 = 用户主目录

settings:
  theme: "system"                     # system | light | dark
  accentColor: "#0078d4"
  material: "tabbed"                  # tabbed(增强云母) | mica(云母) | none(不透明)
  compactAcrylic: true                # 小窗单独走亚克力（仅 Windows）
  showTray: true
  startMinimized: false
  autoStart: false
  alwaysOnTop: true
  animationEnabled: true
  adminAutoElevate: true
  confirmAdminActions: true
  globalHotkey: "Ctrl+Space"
  compactPos: ""                      # 常驻小窗位置 "x,y"，空串 = 贴右下角
  logLevel: "INFO"                    # DEBUG | INFO | WARNING | ERROR
```

### launcher 字段

小窗的高度是算出来的（桌面可用高度的一半），三行的**内容**由 `slots` 决定 —— 每行想放几个就放几个。

| 键 | 默认值 | 作用 |
| --- | --- | --- |
| `slots` | 前 4 个条目 + 6 个内置功能 + U 盘 + 一块本机磁盘 | 槽位列表，见下 |
| `storagePath` | `""` | 第三行那张固定存储卡片显示的目录，空串回落到用户主目录；路径不存在时也回落到主目录 |

每个槽位结构一致，靠 `kind` 区分：

| 键 | 作用 |
| --- | --- |
| `kind` | `action`（引用档案条目）/ `tool`（内置功能）/ `path`（任意文件 · 文件夹 · 磁盘）/ `usb`（自动检测的可移动磁盘） |
| `row` | 落在第几行：`0` / `1` / `2` |
| `label` | 覆盖显示名，空串 = 用目标自己的名字 |
| `icon` | 覆盖图标，空串 = 用目标自己的图标 |
| `ref` | 仅 `action`：条目 id |
| `key` | 仅 `tool`：内置功能的 key |
| `path` | 仅 `path`：要打开的路径（支持 `~` 与环境变量） |

`tool` 可选的 key：

| key | 显示 | 动作 |
| --- | --- | --- |
| `launcherPage` | 启动台设置 | 完整窗口 → 启动台页 |
| `records` | 档案管理 | 完整窗口 → 档案页 |
| `settings` | 设置 | 完整窗口 → 设置页 |
| `configFolder` | 配置目录 | 打开配置文件所在目录 |
| `configFile` | 配置文件 | 直接打开 `config.yaml` |
| `reload` | 重载配置 | 重新读一遍 `config.yaml` |
| `elevate` | 提权重启 | 以管理员身份重启（仅 Windows） |
| `hide` | 隐藏小窗 | 收起常驻小窗 |
| `quit` | 退出程序 | 退出 Rin Launcher |

> `action` 槽位引用的条目被删掉或停用时，这一格会**整格消失** —— 不留空位、也不报错。
> 旧格式（只有 `apps` / `tools` 两行固定槽位、没有 `slots`）在读取时会被自动翻译成新结构：
> `apps` 里的 id 变成 `action` 槽位，`tools` 里还有对应功能的变成 `tool` 槽位，剩下的旧 key
> 丢掉，并补上一个独立的 `usb` 槽位。

### settings 字段

| 键 | 默认值 | 作用 |
| --- | --- | --- |
| `theme` | `system` | 主题模式，改动即时切换 |
| `accentColor` | `#0078d4` | 强调色，改动即时切换 |
| `material` | `tabbed` | **完整窗口**材质：`tabbed` 增强云母 / `mica` 云母 / `none` 不透明；系统不支持时退回云母（仅 Windows） |
| `compactAcrylic` | `true` | 常驻小窗走亚克力 —— 比云母更透，桌面挂件单独这么设（仅 Windows） |
| `showTray` | `true` | 是否创建托盘图标 |
| `startMinimized` | `false` | 启动时不显示常驻小窗 |
| `autoStart` | `false` | 开机自启，写 `HKCU\...\Run`（仅 Windows） |
| `alwaysOnTop` | `true` | 常驻小窗置顶；完整窗口保持普通窗口行为 |
| `globalHotkey` | `Ctrl+Space` | 全局热键，切换常驻小窗显示/隐藏 |
| `compactPos` | `""` | 常驻小窗位置，`"x,y"`；空串表示贴右下角（由「回到右下角」写回空） |
| `logLevel` | `INFO` | 日志级别，**改动需重启生效** |
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

条目、分区和启动台槽位的 `icon` 字段支持四种写法，由 `qml/components/AppIcon.qml` 统一渲染：

| 写法 | 来源 |
| --- | --- |
| `ic_fluent_folder_open_20_regular` | RinUI 内置的 Fluent System Icons 字体图标 |
| `lawnicons:generic_shell` | `assets/icons/lawnicons/` 下的 Lawnicons SVG，按主题色着色 |
| `file:<绝对路径>` | 图标库里用户自己的图标（导入的 svg / png / ico，或从程序里提取出来的） |
| 空串 | 画一个中性的占位字形 |

字体字形与图片是**互斥**的两条渲染路径：之前把 font 名和 `source` 同时写上去，透明底的
SVG 后面会透出字形，看着就是两层图标叠在一起。现在没有图片时才画字形。

### 图标选择器

条目 / 分区 / 槽位编辑器里点「从图标库中选择」打开，四个来源分页：

| 页签 | 内容 |
| --- | --- |
| 内置图标 | RinUI 自带的一百多个常用 Fluent 字体图标 |
| 随包图标 | `assets/icons/lawnicons/` 里的全部 Lawnicons，跟着主题色变 |
| 我的图标 | 图标库里的自定义图标；「添加图标」导入 svg / png / ico，或直接删掉不要的 |
| 从程序提取 | 挑一个 exe / dll / 快捷方式，向系统要它的图标，提取结果会落进图标库 |

提取走 Qt 的 `QFileIconProvider`：Windows 上它直接问系统外壳，能拿到 exe 里嵌的图标；
非 Windows 上会退化成一个通用图标，功能不至于报错消失。

图标名必须真实存在，否则会渲染成空白。可查范围：
[`RinUI/assets/fonts/FluentSystemIcons-Index.js`](RinUI/assets/fonts/FluentSystemIcons-Index.js)。

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
│   ├── effects.py               # 窗口材质：小窗亚克力 / 无焦点标志 / 增强云母
│   ├── hotkey.py                # 全局热键（pynput 监听，信号回主线程）
│   ├── tray.py                  # 系统托盘（QSystemTrayIcon + QMenu）
│   └── elevation.py             # Windows UAC 提权 / 开机启动
├── qml/
│   ├── CompactWindow.qml        # 常驻桌面右下角的小窗（启动台）
│   ├── LauncherWindow.qml       # 完整窗口（FluentWindow + NavigationView）
│   ├── pages/                   # 启动台 / 档案 / 设置 / 关于
│   ├── dialogs/                 # AppDialog 基类 + 条目 / 分区 / 槽位编辑器、图标选择器、确认框
│   ├── components/              # AppIcon / CompactRow / CompactTile / SlotListEditor /
│   │                            # IconGrid / MiniIconButton / FormRow / SettingsGroup …
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

**常驻小窗为什么不用 `FluentWindow`？**
`FluentWindow` 系（`FluentWindowBase`）在 Windows 上会主动补回 `WS_CAPTION` 并同步原生边框，
是给「带标题栏的普通窗口」用的，做成桌面挂件会多出一条系统标题栏。所以小窗的根是一个普通的
`QtQuick.Window`：`Qt.FramelessWindowHint | Qt.Tool`（工具窗口不占任务栏）+
`Qt.WindowDoesNotAcceptFocus`，窗口本身 `color: "transparent"`，卡片是里面自己画的圆角
矩形 + 投影。置顶不写死在 QML 里，跟着 `settings.alwaysOnTop` 由 `main.py` 加/减
`WindowStaysOnTopHint`，两边都写会互相打架。

**小窗的亚克力是自己上的**
小窗不是 RinUI 窗口，够不到 RinUI 那套 backdrop 机制，所以 `effects.py` 直接走 DWM：
Win11 22H2+ 用 `DWMWA_SYSTEMBACKDROP_TYPE`（亚克力 = `DWMSBT_TRANSIENTWINDOW`），21H2 退回
`DWMWA_MICA_EFFECT`，Win10 再退回 `SetWindowCompositionAttribute`。非 Windows 上全是安全空操作，
返回 `False` 之后 QML 把卡片画成接近不透明的纯色兜底，功能不受影响。无焦点则靠
`WS_EX_NOACTIVATE`：鼠标点得动，但窗口不会变成前台窗口，也不会把用户正在打字的目标挤下去。

**完整窗口的材质交给 RinUI**
「增强云母」是 RinUI backdrop 里的 `tabbed`，对应的设置就是 `settings.material`
（`tabbed` / `mica` / `none`）。系统不支持时 RinUI 会自己退回云母，不需要我们判断版本。

**小窗的 import 顺序是有讲究的**
`import QtQuick.Window` 必须排在 `import RinUI` **后面**：QML 里后导入的同名类型优先级更高，
否则 `Window` 会解析成 RinUI 的窗口包装。副作用是 QtQuick 的 `Text` 也会盖过 RinUI 的 `Text`，
所以 `CompactWindow.qml` 里的文字用 `font.pixelSize` / `color` 这些 Qt 原生属性，不写
RinUI 特有的 `typography`。

**槽位表单的下拉为什么监听 `activated` 而不是 `currentIndexChanged`**
RinUI 的 `ComboBox` 内部已经绑了 `onCurrentIndexChanged`，外部再写一个同名处理器会把它顶掉；
更重要的是，程序回填 `currentIndex`（打开编辑器时把配置里的值同步回下拉）也会触发
`currentIndexChanged`，那样「读配置」会被当成「用户改配置」再写回一次。所以
`SlotEditorDialog` 与设置页里的下拉统一写 `function onActivated(index)`：只有用户真的从
列表里选了才动状态。

**弹窗为什么不用 RinUI 的 `Dialog`（也不用 Qt 的 `Popup`）**
主窗是自绘窗口，`Popup` 的尺寸与定位会绕到 `QQC2.Overlay.overlay` 上，而这时候它是
`null` —— 实测弹窗会贴到页面左上角（`x=-291, y=-49`）、背景不绘制，并刷一屏
`Cannot read property 'width'/'height' of null`。`dialogs/AppDialog.qml` 因此干脆不用任何
窗口层特性：就是一个铺满所在页面的普通 `Item` + 居中卡片，尺寸、居中、背景全自己算，
换窗口实现也不会变。五个弹窗都继承它。

顺带一个坑：`AppDialog` 的默认内容属性会把子项交给内部的 `ColumnLayout`，所以嵌套的
图标选择器必须显式写 `parent: <弹窗根 id>`，否则它会待在布局里、铺不满整页。

**为什么密集列表里不用 RinUI 的 `ToolButton`**
它的隐式宽度跟着主题走，一排四五个就把窄列挤爆（档案页的分区列就是这么溢出的）。
`components/MiniIconButton.qml` 把尺寸固定成 28×28，宽度可预期，行内排布才稳。

**页面对象别指望 `objectName`**
RinUI 的 `NavigationView` 在推送页面时会把页面的 `objectName` 覆盖成文件名派生的名字
（`pages/LauncherSettingsPage.qml` → `LauncherSettingsPage`），所以 QML 里写的 `objectName`
拿不到；另外页面是 `Qt.createComponent` 造出来的，不在窗口的 `findChildren` 路径上，要从
内部 `StackView` 的 `currentItem` 取，而且每次切页都会销毁重建。

**两个窗口共享一个 `QQmlApplicationEngine`**
`RinUIWindow` 用的是共享引擎，而 `ThemeManager` 是挂在 `rootContext` 上的上下文属性，
后建的窗口会把它覆盖掉。小窗不是 RinUI 窗口（主题与背景效果都归完整窗口管），所以创建完小窗
之后会把 `ThemeManager` 重新钉回完整窗口那一份，否则在 Windows 上切换主题 / 背景效果会失效。

**为什么用 `FluentWindow` + `NavigationView`？**
`FluentWindowBase` 的内容区 `contentArea` 是一个普通 `Item`，不是 Layout。把页面直接挂在
窗口下并写 `Layout.fillWidth` / `Layout.fillHeight` 是**完全无效**的，页面会被算成 0×0，
表现为"窗口打开了但一片空白"。`NavigationView` 自带侧边导航和页面栈，既绕开了这个坑，
骨架也正好对上"侧边栏 + 面板"的形态。

**QML 与 Python 之间怎么通信？**
后端只有一个上下文属性 `ConfigManager`。所有读写都是它的 `@Slot`，QML 侧调
`ConfigManager.xxx()`；写成功后会发出 `configChanged`，页面据此重取数据，因此各个对话框
不需要反过来通知谁刷新。少数需要落到操作系统上的设置（热键、置顶、托盘）由
`ConfigManager` 再发一个专用信号，`main.py` 接住后应用到窗口。小窗与完整窗口之间够不到彼此，
跨窗口的请求（打开完整窗口、隐藏、退出）走小窗自己的 `openMainRequested` /
`hideRequested` / `quitRequested` 信号回到 `main.py`。

**设置页为什么有防抖？**
滑杆和输入框会连续产生改动，设置页先攒进 `pending`，再由 350ms 的定时器合并成一次
`updateSettings()`；离开页面时会强制冲刷。而且当值没有真的变化时直接跳过写盘。

## 已知限制

- **三个设置项目前只存不用**：`animationEnabled`、`adminAutoElevate`、`confirmAdminActions`
  会被写进配置、界面也能改，但还没有代码消费它们。
- **小窗高度不可调**：固定为桌面可用高度的一半，不提供缩放。三行的**内容**可以随便增删，
  但「三行」这个结构本身是定的（槽位的 `row` 只有 `0` / `1` / `2`）。
- **托盘依赖系统支持**：`QSystemTrayIcon.isSystemTrayAvailable()` 为假时不会创建托盘。
  完整窗口依旧可以关掉自己，但要重新叫出小窗就只能靠全局热键了。
- **提权、开机启动、亚克力都仅 Windows**：`elevation.py` 走的是 `ShellExecuteExW` 与注册表，
  `effects.py` 走 DWM。非 Windows 上 `run_as: admin` 的条目会**直接失败**（日志里给出一条
  warning），不会静默降级成普通启动；小窗则退回半透明纯色卡片，其余功能照常。
- **RinUI 自身的控制台告警**：`Slider.qml` 里 `Overlay.overlay` 为空时的 `TypeError`，以及
  `propertyCache` 的成员覆盖提示，都是库内部行为，不影响功能。

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
