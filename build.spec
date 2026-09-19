# -*- mode: python ; coding: utf-8 -*-

import sys
from pathlib import Path

# Project root
ROOT = Path.cwd()
SRC = ROOT / "src"

# Determine Python path
PYTHON_PATH = Path(sys.executable).parent

block_cipher = None

a = Analysis(
    ['src/rin_launcher/main.py'],
    pathex=[str(SRC)],
    binaries=[],
    datas=[
        (str(SRC / "rin_launcher" / "resources"), "rin_launcher/resources"),
    ],
    hiddenimports=[
        'PySide6.QtCore',
        'PySide6.QtGui',
        'PySide6.QtWidgets',
        'PySide6.QtSvg',
        'yaml',
        'psutil',
        'pynput',
        'dotenv',
        'watchdog',
        'darkdetect',
        'qtawesome',
        'ctypes.wintypes',
    ],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[
        'tkinter',
        'matplotlib',
        'numpy',
        'pandas',
        'scipy',
        'PIL',
        'cv2',
        'requests',
        'urllib3',
    ],
    win_no_prefer_redirects=False,
    win_private_assemblies=False,
    cipher=block_cipher,
    noarchive=False,
)

pyz = PYZ(a.pure, a.zipped_data, cipher=block_cipher)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.zipfiles,
    a.datas,
    [],
    name='RinLauncher',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    upx_exclude=[],
    runtime_tmpdir=None,
    console=False,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
    icon=str(ROOT / 'resources' / 'icon.ico') if (ROOT / 'resources' / 'icon.ico').exists() else None,
)

# Windows-specific: add manifest for admin elevation
if sys.platform == 'win32':
    import xml.etree.ElementTree as ET
    
    manifest_content = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<assembly xmlns="urn:schemas-microsoft-com:asm.v1" manifestVersion="1.0">
  <assemblyIdentity version="1.0.0.0" name="RinLauncher" processorArchitecture="*" />
  <description>Rin Launcher - A launcher application similar to Seewo Desktop Assistant</description>
  <trustInfo xmlns="urn:schemas-microsoft-com:asm.v3">
    <security>
      <requestedPrivileges>
        <requestedExecutionLevel level="asInvoker" uiAccess="false" />
      </requestedPrivileges>
    </security>
  </trustInfo>
  <compatibility xmlns="urn:schemas-microsoft-com:compatibility.v1">
    <application>
      <supportedOS Id="{e2011457-1546-43c5-a5fe-008deee3d3f0}"/>  <!-- Windows 10 -->
      <supportedOS Id="{8e0f7a12-bfb3-4fe8-b9a5-48fd50a15a9a}"/>  <!-- Windows 11 -->
    </application>
  </compatibility>
  <application xmlns="urn:schemas-microsoft-com:asm.v3">
    <windowsSettings>
      <dpiAware xmlns="http://schemas.microsoft.com/SMI/2005/WindowsSettings">True/PM</dpiAware>
      <dpiAwareness xmlns="http://schemas.microsoft.com/SMI/2016/WindowsSettings">PerMonitorV2</dpiAwareness>
    </windowsSettings>
  </application>
</assembly>'''
    
    manifest_path = ROOT / 'resources' / 'app.manifest'
    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    manifest_path.write_text(manifest_content, encoding='utf-8')
    
    # Note: To use admin manifest, change level="asInvoker" to level="requireAdministrator"
    # But we'll use asInvoker and handle admin elevation programmatically