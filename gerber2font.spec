# -*- mode: python ; coding: utf-8 -*-

from pathlib import Path
from PyInstaller.utils.hooks import collect_dynamic_libs, collect_submodules

project_root = Path.cwd()

shapely_hiddenimports = collect_submodules("shapely")
shapely_binaries = collect_dynamic_libs("shapely")
fonttools_hiddenimports = collect_submodules("fontTools")

a = Analysis(
    ["gerber2font.py"],
    pathex=[str(project_root)],
    binaries=shapely_binaries,
    datas=[
        (str(project_root / "README.md"), "."),
        (str(project_root / "LICENSE"), "."),
    ],
    hiddenimports=shapely_hiddenimports + fonttools_hiddenimports,
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[],
    noarchive=False,
)

pyz = PYZ(a.pure)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.datas,
    [],
    name="gerber2font",
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=False,
    console=True,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
    version=None,
    icon=str(project_root / "app.ico") if (project_root / "app.ico").exists() else None,
    onefile=True,
)
