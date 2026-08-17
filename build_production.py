# build_production.py
"""
Complete Automated Production Packaging and Deployment Script for Markazi System Checker.
1. Freezes Python backend with PyInstaller (backend_server.exe).
2. Builds Flutter Windows Release binary (MarkaziSystemChecker.exe).
3. Stages portable directory (dist/MarkaziSystemChecker).
4. Creates portable zip archive (dist/MarkaziSystemChecker-Portable-1.0.0.zip).
5. Compiles Inno Setup Windows installer (dist/MarkaziSystemChecker-Setup-1.0.0.exe).
"""

import os
import sys
import shutil
import zipfile
import subprocess

ROOT_DIR = os.path.dirname(os.path.abspath(__file__))
DIST_DIR = os.path.join(ROOT_DIR, "dist")
STAGE_DIR = os.path.join(DIST_DIR, "MarkaziSystemChecker")
FLUTTER_RELEASE_DIR = os.path.join(ROOT_DIR, r"frontend\build\windows\x64\runner\Release")
ISCC_CANDIDATES = [
    r"C:\Users\aymix\AppData\Local\Programs\Inno Setup 6\ISCC.exe",
    r"C:\Program Files (x86)\Inno Setup 6\ISCC.exe",
    r"C:\Program Files\Inno Setup 6\ISCC.exe",
    os.path.expandvars(r"%LOCALAPPDATA%\Programs\Inno Setup 6\ISCC.exe"),
]

def find_iscc() -> str:
    for p in ISCC_CANDIDATES:
        if os.path.isfile(p):
            return p
    # Check PATH
    iscc_path = shutil.which("ISCC.exe") or shutil.which("iscc")
    if iscc_path:
        return iscc_path
    raise FileNotFoundError("Inno Setup Compiler (ISCC.exe) not found on this system.")

def step_freeze_backend():
    print("==================================================")
    print("[1/5] Freezing Python Backend with PyInstaller...")
    print("==================================================")
    sys.path.insert(0, os.path.join(ROOT_DIR, "backend"))
    from backend.build_backend import build_backend
    exe_path = build_backend()
    return exe_path

def step_sync_release_folder(backend_exe: str):
    print("==================================================")
    print("[2/5] Synchronizing Assets into Flutter Release...")
    print("==================================================")
    os.makedirs(FLUTTER_RELEASE_DIR, exist_ok=True)

    # 1. Copy backend_server.exe
    dest_backend_dir = os.path.join(FLUTTER_RELEASE_DIR, "backend")
    os.makedirs(dest_backend_dir, exist_ok=True)
    shutil.copy2(backend_exe, os.path.join(dest_backend_dir, "backend_server.exe"))
    shutil.copy2(backend_exe, os.path.join(FLUTTER_RELEASE_DIR, "backend_server.exe"))

    # 2. Copy config, Tools, Packages
    for folder in ["config", "Tools", "Packages"]:
        src = os.path.join(ROOT_DIR, folder)
        dst = os.path.join(FLUTTER_RELEASE_DIR, folder)
        if os.path.exists(src):
            if os.path.exists(dst):
                shutil.rmtree(dst)
            shutil.copytree(src, dst)
            print(f" * Copied {folder} -> {dst}")

    # 3. Create logs and data folders
    os.makedirs(os.path.join(FLUTTER_RELEASE_DIR, "logs"), exist_ok=True)
    os.makedirs(os.path.join(FLUTTER_RELEASE_DIR, "data"), exist_ok=True)

def step_stage_portable_bundle():
    print("==================================================")
    print("[3/5] Creating Staged Portable Distribution...")
    print("==================================================")
    if os.path.exists(STAGE_DIR):
        shutil.rmtree(STAGE_DIR)
    shutil.copytree(FLUTTER_RELEASE_DIR, STAGE_DIR)
    print(f"[OK] Staged portable directory at: {STAGE_DIR}")

def step_create_portable_zip():
    print("==================================================")
    print("[4/5] Creating Portable ZIP Archive...")
    print("==================================================")
    zip_path = os.path.join(DIST_DIR, "MarkaziSystemChecker-Portable-1.0.0.zip")
    if os.path.exists(zip_path):
        os.remove(zip_path)

    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as zf:
        for root, _, files in os.walk(STAGE_DIR):
            for file in files:
                abs_file = os.path.join(root, file)
                rel_file = os.path.relpath(abs_file, os.path.dirname(STAGE_DIR))
                zf.write(abs_file, rel_file)

    size_mb = os.path.getsize(zip_path) / (1024 * 1024)
    print(f"[OK] Portable ZIP created: {zip_path} ({size_mb:.2f} MB)")

def step_compile_installer():
    print("==================================================")
    print("[5/5] Compiling Inno Setup Windows Installer...")
    print("==================================================")
    iscc = find_iscc()
    iss_file = os.path.join(ROOT_DIR, "installer", "setup.iss")
    cmd = [iscc, iss_file]
    print(f"[*] Running: {iscc} {iss_file}")
    res = subprocess.run(cmd, cwd=os.path.dirname(iss_file))
    if res.returncode != 0:
        raise RuntimeError(f"Inno Setup compilation failed with code {res.returncode}")

    installer_path = os.path.join(DIST_DIR, "MarkaziSystemChecker-Setup.exe")
    if not os.path.isfile(installer_path):
        # Fallback check
        installer_path = os.path.join(DIST_DIR, "MarkaziSystemChecker-Setup-1.0.0.exe")
        if not os.path.isfile(installer_path):
            raise FileNotFoundError(f"Expected installer at {installer_path}, but not found.")

    # Also keep a copy as MarkaziSystemChecker-Setup-1.0.0.exe if possible
    versioned_path = os.path.join(DIST_DIR, "MarkaziSystemChecker-Setup-1.0.0.exe")
    try:
        if installer_path != versioned_path:
            shutil.copy2(installer_path, versioned_path)
    except Exception:
        pass

    size_mb = os.path.getsize(installer_path) / (1024 * 1024)
    print(f"[OK] Windows Installer generated: {installer_path} ({size_mb:.2f} MB)")

def main():
    os.makedirs(DIST_DIR, exist_ok=True)
    backend_exe = step_freeze_backend()
    step_sync_release_folder(backend_exe)
    step_stage_portable_bundle()
    step_create_portable_zip()
    step_compile_installer()

    print("\n==================================================")
    print("  PRODUCTION BUILD COMPLETED SUCCESSFULLY!")
    print(f"  Installer: dist/MarkaziSystemChecker-Setup.exe")
    print(f"  Portable:  dist/MarkaziSystemChecker-Portable-1.0.0.zip")
    print("==================================================\n")

if __name__ == "__main__":
    main()
