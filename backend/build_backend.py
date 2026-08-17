# backend/build_backend.py
"""
Builds the standalone, frozen Python backend executable (backend_server.exe)
using PyInstaller. Guarantees 100% zero external runtime dependencies on destination machines.
"""

import os
import sys
import shutil
import subprocess

def build_backend(output_dir: str = None):
    backend_dir = os.path.dirname(os.path.abspath(__file__))
    root_dir = os.path.dirname(backend_dir)
    main_py = os.path.join(backend_dir, "main.py")

    if output_dir is None:
        output_dir = os.path.join(root_dir, "build_backend_out")

    os.makedirs(output_dir, exist_ok=True)
    dist_path = os.path.join(output_dir, "dist")
    work_path = os.path.join(output_dir, "build")

    hidden_imports = [
        "PIL",
        "PIL.Image",
        "PIL.PngImagePlugin",
        "ctypes",
        "ctypes.wintypes",
        "winreg",
        "http.server",
        "urllib.parse",
        "threading",
        "concurrent.futures",
        "json",
        "subprocess",
        "logging",
        "datetime",
        "collector",
        "server",
        "qc.qc_engine",
        "hardware.cpu",
        "hardware.ram",
        "hardware.gpu",
        "hardware.motherboard",
        "hardware.storage",
        "hardware.bios",
        "hardware.battery",
        "windows.system",
        "windows.network",
        "windows.proxy",
        "software.detector",
        "software.registry",
        "software.office",
        "files.checker",
        "drivers.checker",
        "drivers.recommendations",
        "activation.windows_activation",
        "activation.office_activation",
        "activation.activation_tools",
        "packages.manager",
    ]

    cmd = [
        sys.executable,
        "-m", "PyInstaller",
        "--name=backend_server",
        "--onefile",
        "--noconsole",
        "--clean",
        f"--paths={backend_dir}",
        f"--distpath={dist_path}",
        f"--workpath={work_path}",
        f"--specpath={output_dir}",
    ]

    ico_path = os.path.join(root_dir, "installer", "app_icon.ico")
    if os.path.exists(ico_path):
        cmd.append(f"--icon={ico_path}")

    for imp in hidden_imports:
        cmd.extend(["--hidden-import", imp])

    cmd.append(main_py)

    print("[*] Running PyInstaller command:")
    print(" ".join(cmd))

    res = subprocess.run(cmd, cwd=backend_dir)
    if res.returncode != 0:
        raise RuntimeError(f"PyInstaller build failed with exit code {res.returncode}")

    exe_path = os.path.join(dist_path, "backend_server.exe")
    if not os.path.exists(exe_path):
        raise FileNotFoundError(f"Expected backend_server.exe at {exe_path}, but not found.")

    print(f"[OK] Backend successfully packaged into standalone binary: {exe_path} ({os.path.getsize(exe_path)} bytes)")
    return exe_path

if __name__ == "__main__":
    build_backend()
