# Rin Launcher

类似希沃桌面助手的启动台应用，基于 Python + PySide6 (Qt) 构建，采用 Rin UI 风格设计。

## 功能特性

- 🚀 **快速启动** - 全局热键 (默认 `Ctrl+Space`) 唤起启动台
- 🎯 **多种动作类型** - 支持文件/程序、命令行、网址、键鼠模拟
- 🔐 **管理员提权** - 可单独为操作启用管理员权限，支持自动 UAC 提权
- 🎨 **Rin UI 风格** - 现代化、圆角、阴影、动画的流畅界面
- 🌙 **主题支持** - 浅色/深色/跟随系统，支持 Windows 11 Mica/Acrylic 模糊背景
- ⚙️ **完整设置菜单** - 常规、外观、动作管理、热键、高级分类设置
- 📝 **YAML 配置** - 人类可读的配置文件，支持导入/导出/备份
- 🔧 **可视化编辑器** - 内置操作编辑器、分类编辑器、图标选择器、热键录制器
- 📦 **便携打包** - PyInstaller 单文件打包，支持 Windows 11

## 系统要求

- Windows 10/11 (x64)
- Python 3.10+ (开发时)
- 无需安装 Python 即可运行打包版本

## 快速开始

### 开发环境

```bash
# 克隆仓库
git clone <repository-url>
cd rin-launcher

# 创建虚拟环境
python -m venv venv
venv\Scripts\activate  # Windows

# 安装依赖
pip install -r requirements.txt

# 运行
python -m rin_launcher
```

### 打包发布

```bash
# 安装打包依赖
pip install pyinstaller

# 打包
pyinstaller build.spec

# 产物在 dist/RinLauncher.exe
```

## 配置文件

配置文件位置：`%APPDATA%\RinLauncher\config.yaml`

```yaml
version: 1
settings:
  theme: "system"        # system, light, dark
  language: "zh_CN"
  show_tray: true
  start_minimized: false
  auto_start: false
  global_hotkey: "ctrl+space"
  search_engine: "https://www.bing.com/search?q={query}"
  grid_columns: 6
  item_size: 96
  animation_enabled: true
  blur_background: true
  accent_color: "#0078d4"
  font_family: "Microsoft YaHei UI"
  font_size: 12
  admin_auto_elevate: true
  confirm_admin_actions: true
  log_level: "INFO"

categories:
  - id: "abc123"
    name: "常用"
    icon: "fa5s.star"
    order: 0
    expanded: true

actions:
  - id: "xyz789"
    name: "记事本"
    icon: "fa5s.file-alt"
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

使用 [Font Awesome 5](https://fontawesome.com/v5/search) 图标，格式：`fa5s.icon-name` (Solid) 或 `fa5b.icon-name` (Brands)

常用图标：
- `fa5s.rocket` - 火箭
- `fa5s.code` - 代码
- `fa5s.terminal` - 终端
- `fa5s.folder` - 文件夹
- `fa5s.file` - 文件
- `fa5s.play` - 播放
- `fa5s.cog` - 设置
- `fa5s.search` - 搜索

## 开发指南

### 项目结构
```
src/rin_launcher/
├── core/           # 核心模型和配置管理
│   ├── models.py   # 数据模型
│   └── config_manager.py  # YAML 配置管理
├── ui/             # 界面组件
│   ├── theme.py    # 主题系统
│   ├── components.py  # 基础组件
│   ├── launcher_window.py  # 主窗口
│   ├── settings_dialog.py  # 设置对话框
│   ├── action_editor.py    # 动作编辑器
│   └── category_editor.py  # 分类编辑器
├── actions/        # 动作执行引擎
│   └── executor.py
├── utils/          # 工具函数
└── main.py         # 入口点
```

### 添加新动作类型
1. 在 `core/models.py` 的 `ActionType` 枚举中添加
2. 在 `actions/executor.py` 的 `execute` 方法中添加处理逻辑
3. 在 `ui/action_editor.py` 中添加编辑界面

## 许可证

GPL-3.0-or-later - 详见 [LICENSE](LICENSE)

## 贡献

欢迎提交 Issue 和 Pull Request！

## 致谢

- [PySide6](https://wiki.qt.io/Qt_for_Python) - Python Qt 绑定
- [qtawesome](https://github.com/spyder-ide/qtawesome) - Font Awesome 图标
- [darkdetect](https://github.com/albertosottile/darkdetect) - 系统主题检测
- [pynput](https://github.com/moses-palmer/pynput) - 键鼠监听与模拟