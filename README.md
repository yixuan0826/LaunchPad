# Rin Launcher

基于 **RinUI (QML)** + **Python (PySide6)** 的启动台应用，类似希沃桌面助手。

## 功能特性

- 🚀 **快速启动** - 全局热键唤起启动台
- 🎯 **多种动作类型** - 支持文件/程序、命令行、网址、键鼠模拟
- 🔐 **管理员提权** - 可单独为操作启用管理员权限，支持自动 UAC 提权
- 🎨 **RinUI Fluent Design 风格** - 现代化、圆角、阴影、动画的流畅界面
- 🌙 **主题支持** - 浅色/深色/跟随系统，支持 Windows 11 Mica/Acrylic 模糊背景
- ⚙️ **完整设置菜单** - 常规、外观、动作管理、热键、高级分类设置
- 📝 **YAML 配置** - 人类可读的配置文件，支持导入/导出/备份
- 🔧 **可视化编辑器** - 内置操作编辑器、分类编辑器、图标选择器、热键录制器

## 项目结构

```
.
├── rin_launcher/
│   ├── config_manager.py    # 配置管理（对 QML 暴露 camelCase 接口）
│   ├── action_executor.py   # 动作执行引擎
│   ├── elevation.py         # Windows UAC 提权 / 开机启动
│   └── main.py              # 入口点
├── qml/
│   ├── LauncherWindow.qml   # 主窗口
│   ├── CategorySection.qml  # 分类区域
│   ├── ActionCard.qml       # 动作卡片
│   ├── SettingsDialog.qml   # 设置对话框
│   ├── ActionEditorDialog.qml   # 动作编辑器
│   ├── CategoryEditorDialog.qml # 分类编辑器
│   ├── KeymouseStepDelegate.qml # 键鼠步骤编辑器
│   ├── IconPicker.qml       # 图标选择器（两个编辑器共用）
│   ├── ConfirmDialog.qml    # 通用确认弹窗
│   └── qmldir               # QML 模块定义
├── assets/icon.ico          # 应用图标
└── Rin-UI/                  # RinUI（git submodule，固定到 36ad74c）
```

## 依赖

- Python 3.10+
- PySide6 6.6+
- [RinUI](https://github.com/RinLit-233-shiroko/Rin-UI)（作为 submodule 放在 `Rin-UI/`）

## 安装

```bash
git clone --recurse-submodules https://github.com/yixuan0826/LaunchPad.git
cd LaunchPad

# 若已克隆但未拉取 submodule
git submodule update --init Rin-UI

pip install -r requirements.txt
```

## 运行

```bash
python -m rin_launcher.main
```

应用会自动在 `Rin-UI/`（或同级的 `Rin-UI/`）中查找 RinUI 库。

## 打包发布

```bash
pip install pyinstaller
pyinstaller build.spec
# 产物在 dist/RinLauncher.exe
```

## 配置文件

配置文件位置：`%APPDATA%\RinLauncher\config.yaml`

```yaml
version: 1
actions:
  - id: "abc123"
    name: "记事本"
    icon: "ic_fluent_file_20_regular"
    type: "file"
    target: "notepad.exe"
    arguments: ""
    working_dir: ""
    run_as: "user"
    category: "常用"
    enabled: true
    hotkey: "ctrl+n"
    tooltip: "打开记事本"
    order: 0

categories:
  - id: "cat1"
    name: "常用"
    icon: "ic_fluent_star_20_regular"
    order: 0
    expanded: true

settings:
  theme: "system"
  language: "zh_CN"
  showTray: true
  startMinimized: false
  autoStart: false
  globalHotkey: "Ctrl+Space"
  searchEngine: "https://www.bing.com/search?q={query}"
  gridColumns: 6
  itemSize: 96
  animationEnabled: true
  blurBackground: true
  accentColor: "#0078d4"
  fontFamily: "Microsoft YaHei UI"
  fontSize: 12
  adminAutoElevate: true
  confirmAdminActions: true
  logLevel: "INFO"
```

## 动作类型详解

### 1. 文件/程序 (file)
- `target`: 可执行文件路径或文件关联
- `arguments`: 启动参数
- `working_dir`: 工作目录
- `run_as`: `user` 或 `admin`

### 2. 命令行 (cmd)
- `target`: 命令 (如 `cmd.exe`, `powershell.exe`, `ping`)
- `arguments`: 命令参数
- `working_dir`: 工作目录
- `run_as`: `user` 或 `admin`

### 3. 网址 (url)
- `target`: 网址 (自动补全 https://)

### 4. 键鼠模拟 (keymouse)
- `keymouse_steps`: 步骤序列
  - 按键: `type: "key"`, `key: "ctrl+c"`, `action: "press|release|click"`, `duration: 0.1`
  - 鼠标: `type: "mouse"`, `action: "click|move|scroll"`, `x, y, dx, dy`, `button: "left|right|middle"`, `duration: 0.1`
  - 等待: `type: "wait"`, `duration: 0.5`

## 变量替换

配置中支持以下变量：
- `{appdir}` - 程序所在目录
- `{configdir}` - 配置目录
- `{homedir}` - 用户主目录
- `{tempdir}` - 临时目录
- `{desktop}` - 桌面目录
- `{documents}` - 文档目录
- `{downloads}` - 下载目录
- 环境变量: `%APPDATA%`, `%USERPROFILE%` 等

## 图标系统

使用 RinUI 内置的 Fluent System Icons，格式：`ic_fluent_<name>_20_regular`

常用图标：
- `ic_fluent_rocket_20_regular` - 火箭
- `ic_fluent_code_20_regular` - 代码
- `ic_fluent_terminal_20_regular` - 终端
- `ic_fluent_folder_20_regular` - 文件夹
- `ic_fluent_file_20_regular` - 文件
- `ic_fluent_play_20_regular` - 播放
- `ic_fluent_settings_20_regular` - 设置
- `ic_fluent_search_20_regular` - 搜索

## 许可证

GPL-3.0-or-later

## 致谢

- [RinUI](https://github.com/RinLit-233-shiroko/Rin-UI) - Fluent Design 风格 QML UI 库
- [PySide6](https://wiki.qt.io/Qt_for_Python) - Python Qt 绑定
- [Fluent Design System](https://fluent2.microsoft.design/)
- [Fluent UI System Icons](https://github.com/microsoft/fluentui-system-icons/)