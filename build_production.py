# build_production.py
"""
Complete Automated Production Packaging and Deployment Script for Markazi System Checker.
1. Terminates any running backend/frontend instances to avoid file locks.
2. Freezes Python backend as a PyInstaller one-directory bundle.
3. Builds Flutter Windows Release binary (MarkaziSystemChecker.exe).
4. Synchronizes assets, validated Packages, config, and Visual C++ runtime DLLs.
5. Stages portable directory (dist/MarkaziSystemChecker).
6. Creates the versioned portable zip archive.
7. Compiles Inno Setup Windows installer (dist/MarkaziSystemChecker-Setup.exe).
"""

import os
import sys
import shutil
import zipfile
import subprocess
import urllib.request

APP_VERSION = "1.1.34"
ROOT_DIR = os.path.dirname(os.path.abspath(__file__))
BACKEND_DIR = os.path.join(ROOT_DIR, "backend")
if BACKEND_DIR not in sys.path:
    sys.path.insert(0, BACKEND_DIR)

DIST_DIR = os.path.join(ROOT_DIR, "dist")
STAGE_DIR = os.path.join(DIST_DIR, f"MarkaziSystemChecker-{APP_VERSION}")
FRONTEND_DIR = os.path.join(ROOT_DIR, "frontend")
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

def step_kill_running_processes():
    print("==================================================")
    print("[0/6] Ensuring No Conflicting Processes Are Running...")
    print("==================================================")
    for port in [18088, 18080, 18089]:
        try:
            req = urllib.request.Request(f"http://127.0.0.1:{port}/api/shutdown", method="GET")
            with urllib.request.urlopen(req, timeout=1) as resp:
                pass
        except Exception:
            pass

    # Force kill any lingering instances
    for proc_name in ["backend_server.exe", "MarkaziSystemChecker.exe", "markazi_system_checker.exe"]:
        try:
            subprocess.run(["taskkill", "/F", "/IM", proc_name], capture_output=True)
        except Exception:
            pass

def step_freeze_backend():
    print("==================================================")
    print("[1/6] Freezing Python Backend with PyInstaller...")
    print("==================================================")
    sys.path.insert(0, os.path.join(ROOT_DIR, "backend"))
    from backend.build_backend import build_backend
    exe_path = build_backend()
    return exe_path

def step_build_flutter():
    print("==================================================")
    print("[2/6] Building Flutter Windows Release...")
    print("==================================================")
    flutter_bin = shutil.which("flutter.bat") or shutil.which("flutter") or "flutter"
    flutter_cmd = f'"{flutter_bin}" build windows --release --no-pub'
    print(f"[*] Running: {flutter_cmd} in {FRONTEND_DIR}")
    res = subprocess.run(flutter_cmd, cwd=FRONTEND_DIR, shell=True)
    if res.returncode != 0:
        raise RuntimeError(f"Flutter build failed with return code {res.returncode}")
    print("[OK] Flutter Windows Release compiled successfully.")


def _copy_validated_packages(src: str, dst: str) -> None:
    """Copies package media while excluding blocked installers and scripts."""
    backend_dir = os.path.join(ROOT_DIR, "backend")
    if backend_dir not in sys.path:
        sys.path.insert(0, backend_dir)
    from packages.manager import SUPPORTED_PACKAGE_EXTENSIONS, scan_packages

    scan = scan_packages(src)
    packages = scan.get("packages", [])
    valid_installers = {
        str(item.get("relative_path") or "").replace("\\", "/").lower()
        for item in packages
        if item.get("is_valid")
    }
    blocked = [item for item in packages if not item.get("is_valid")]
    executable_scripts = {".bat", ".cmd", ".ps1", ".vbs", ".js", ".jse", ".wsf", ".wsh", ".hta", ".scr", ".com", ".cpl"}

    if os.path.isdir(dst):
        shutil.rmtree(dst)
    os.makedirs(dst, exist_ok=True)

    copied_installers = 0
    skipped_scripts = 0
    for current_root, directories, files in os.walk(src):
        rel_root = os.path.relpath(current_root, src)
        target_root = dst if rel_root == "." else os.path.join(dst, rel_root)
        os.makedirs(target_root, exist_ok=True)
        for directory in directories:
            os.makedirs(os.path.join(target_root, directory), exist_ok=True)
        for filename in files:
            source_file = os.path.join(current_root, filename)
            relative_path = os.path.relpath(source_file, src).replace("\\", "/")
            extension = os.path.splitext(filename)[1].lower()
            if extension in executable_scripts:
                skipped_scripts += 1
                continue
            if extension in SUPPORTED_PACKAGE_EXTENSIONS:
                if relative_path.lower() not in valid_installers:
                    continue
                copied_installers += 1
            shutil.copy2(source_file, os.path.join(target_root, filename))

    print(f" * Included {copied_installers} validated installer(s).")
    if blocked:
        print(f" * Excluded {len(blocked)} blocked installer(s):")
        for item in blocked:
            print(f"   - {item.get('relative_path')}: {item.get('validation_code')}")
    if skipped_scripts:
        print(f" * Excluded {skipped_scripts} executable script(s) from Packages.")

def step_sync_release_folder(backend_exe: str):
    print("==================================================")
    print("[3/6] Synchronizing Assets into Flutter Release...")
    print("==================================================")
    os.makedirs(FLUTTER_RELEASE_DIR, exist_ok=True)

    stale_tools_dir = os.path.join(FLUTTER_RELEASE_DIR, "Tools")
    if os.path.isdir(stale_tools_dir):
        shutil.rmtree(stale_tools_dir)

    # 1. Copy the complete one-directory backend bundle. Native libraries stay
    # beside the launcher and are never unpacked into the user's Temp folder.
    dest_backend_dir = os.path.join(FLUTTER_RELEASE_DIR, "backend")
    backend_bundle_dir = os.path.dirname(os.path.abspath(backend_exe))
    if not os.path.isfile(os.path.join(backend_bundle_dir, "backend_server.exe")):
        raise FileNotFoundError(f"Invalid backend bundle: {backend_bundle_dir}")
    if os.path.isdir(dest_backend_dir):
        shutil.rmtree(dest_backend_dir)
    shutil.copytree(backend_bundle_dir, dest_backend_dir)

    # Remove the obsolete one-file launcher from earlier releases. The UI
    # always resolves backend/backend_server.exe first.
    stale_root_backend = os.path.join(FLUTTER_RELEASE_DIR, "backend_server.exe")
    if os.path.isfile(stale_root_backend):
        os.remove(stale_root_backend)
    print(f" * Copied extraction-free backend bundle -> {dest_backend_dir}")

    # 2. Copy configuration and offline software packages. Third-party
    # activation scripts are intentionally excluded from release artifacts.
    config_src = os.path.join(ROOT_DIR, "config")
    config_dst = os.path.join(FLUTTER_RELEASE_DIR, "config")
    if os.path.exists(config_src):
        if os.path.exists(config_dst):
            shutil.rmtree(config_dst)
        shutil.copytree(config_src, config_dst)
        print(f" * Copied config -> {config_dst}")

    packages_src = os.path.join(ROOT_DIR, "Packages")
    packages_dst = os.path.join(FLUTTER_RELEASE_DIR, "Packages")
    if os.path.exists(packages_src):
        _copy_validated_packages(packages_src, packages_dst)
        print(f" * Copied validated Packages -> {packages_dst}")

    # 2.2 Ensure assets (especially Parts) are copied into flutter_assets
    src_assets = os.path.join(FRONTEND_DIR, "assets")
    dst_assets = os.path.join(FLUTTER_RELEASE_DIR, "data", "flutter_assets", "assets")
    if os.path.exists(src_assets):
        os.makedirs(dst_assets, exist_ok=True)
        for item in os.listdir(src_assets):
            s_item = os.path.join(src_assets, item)
            d_item = os.path.join(dst_assets, item)
            if os.path.isdir(s_item):
                shutil.copytree(s_item, d_item, dirs_exist_ok=True)
            else:
                shutil.copy2(s_item, d_item)
        print(f" * Verified assets synchronized -> {dst_assets}")

    # 2.5 Bundle Visual C++ Runtime & Universal C Runtime DLLs for fresh & legacy Windows compatibility
    system32 = os.path.join(os.environ.get("SystemRoot", "C:\\Windows"), "System32")
    vc_dlls = [
        "vcruntime140.dll",
        "vcruntime140_1.dll",
        "msvcp140.dll",
        "msvcp140_1.dll",
        "msvcp140_2.dll",
        "msvcp140_atomic_wait.dll",
        "msvcp140_codecvt_ids.dll",
        "vcomp140.dll",
    ]
    for dll in vc_dlls:
        src_dll = os.path.join(system32, dll)
        if os.path.isfile(src_dll):
            shutil.copy2(src_dll, os.path.join(FLUTTER_RELEASE_DIR, dll))
            shutil.copy2(src_dll, os.path.join(dest_backend_dir, dll))

    # OS DLLs must come from the target Windows installation, not this build PC.
    # Remove stale copies left by previous builds in these two exact build dirs.
    for directory in (FLUTTER_RELEASE_DIR, dest_backend_dir):
        for name in ("ucrtbase.dll", "d3dcompiler_47.dll"):
            stale = os.path.join(directory, name)
            if os.path.isfile(stale):
                os.remove(stale)
    print(" * Bundled VC runtime DLLs; target Windows supplies OS components.")

    # 3. Create clean logs folder without lingering log files
    logs_dir = os.path.join(FLUTTER_RELEASE_DIR, "logs")
    os.makedirs(logs_dir, exist_ok=True)
    for lf in os.listdir(logs_dir):
        try:
            os.remove(os.path.join(logs_dir, lf))
        except Exception:
            pass

def step_stage_portable_bundle():
    print("==================================================")
    print("[4/6] Creating Staged Portable Distribution...")
    print("==================================================")
    resolved_stage = os.path.abspath(STAGE_DIR)
    resolved_dist = os.path.abspath(DIST_DIR)
    if os.path.commonpath([resolved_stage, resolved_dist]) != resolved_dist or resolved_stage == resolved_dist:
        raise RuntimeError(f"Unsafe staging directory: {resolved_stage}")
    if os.path.isdir(resolved_stage):
        shutil.rmtree(resolved_stage)
    os.makedirs(resolved_stage, exist_ok=True)
    shutil.copytree(FLUTTER_RELEASE_DIR, STAGE_DIR, dirs_exist_ok=True)
    print(f"[OK] Staged portable directory at: {STAGE_DIR}")

def step_create_portable_zip():
    print("==================================================")
    print("[5/6] Creating Portable ZIP Archive...")
    print("==================================================")
    zip_path = os.path.join(DIST_DIR, f"MarkaziSystemChecker-Portable-{APP_VERSION}.zip")
    if os.path.exists(zip_path):
        os.remove(zip_path)

    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as zf:
        for root, _, files in os.walk(STAGE_DIR):
            for file in files:
                # Exclude runtime log files from the template archive to prevent lock conflicts
                if file.endswith(".log"):
                    continue
                abs_file = os.path.join(root, file)
                rel_file = os.path.relpath(abs_file, os.path.dirname(STAGE_DIR))
                zf.write(abs_file, rel_file)

    size_mb = os.path.getsize(zip_path) / (1024 * 1024)
    print(f"[OK] Portable ZIP created: {zip_path} ({size_mb:.2f} MB)")

def step_compile_installer():
    print("==================================================")
    print("[6/6] Compiling Inno Setup Windows Installer...")
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
        installer_path = os.path.join(DIST_DIR, f"MarkaziSystemChecker-Setup-{APP_VERSION}.exe")
        if not os.path.isfile(installer_path):
            raise FileNotFoundError(f"Expected installer at {installer_path}, but not found.")

    versioned_path = os.path.join(DIST_DIR, f"MarkaziSystemChecker-Setup-{APP_VERSION}.exe")
    try:
        if installer_path != versioned_path:
            shutil.copy2(installer_path, versioned_path)
    except Exception:
        pass

    size_mb = os.path.getsize(installer_path) / (1024 * 1024)
    print(f"[OK] Windows Installer generated: {installer_path} ({size_mb:.2f} MB)")

def main():
    os.makedirs(DIST_DIR, exist_ok=True)
    step_kill_running_processes()
    backend_exe = step_freeze_backend()
    step_build_flutter()
    step_sync_release_folder(backend_exe)
    step_stage_portable_bundle()
    step_create_portable_zip()
    step_compile_installer()

    print("\n==================================================")
    print("  PRODUCTION BUILD COMPLETED SUCCESSFULLY!")
    print(f"  Installer: dist/MarkaziSystemChecker-Setup.exe")
    print(f"  Portable:  dist/MarkaziSystemChecker-Portable-{APP_VERSION}.zip")
    print("==================================================\n")

if __name__ == "__main__":
    main()
