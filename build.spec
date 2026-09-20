# -*- mode: python ; coding: utf-8 -*-
"""PyInstaller build script — run with ``pyinstaller build.spec``."""

from pathlib import Path

ROOT = Path(SPECPATH)
ICON = ROOT / "assets" / "icon.ico"

a = Analysis(
    [str(ROOT / "rin_launcher" / "main.py")],
    pathex=[str(ROOT)],
    binaries=[],
    datas=[
        (str(ROOT / "qml"), "qml"),
        # RinUI 是内联的普通目录，QML/字体/主题都不是 Python 模块，必须显式带上。
        (str(ROOT / "RinUI"), "RinUI"),
        # QML 里用相对路径引用 Lawnicons，图标与 icon.ico 都在 assets 下。
        (str(ROOT / "assets"), "assets"),
    ],
    # PyInstaller's PySide6 hook already pulls in the Qt modules, so only the
    # plain-Python dependencies have to be listed here.
    hiddenimports=["yaml", "pynput", "watchdog", "ctypes.wintypes"],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=["tkinter", "matplotlib", "numpy", "pandas", "scipy", "PIL", "cv2"],
    noarchive=False,
)

pyz = PYZ(a.pure)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.datas,
    [],
    name="RinLauncher",
    debug=False,
    strip=False,
    upx=True,
    console=False,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
    icon=str(ICON) if ICON.exists() else None,
)
