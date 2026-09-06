import argparse
import json
import logging
import os
import sys

# Ensure UTF-8 output encoding on all Windows machines
try:
    if hasattr(sys.stdout, 'reconfigure'):
        sys.stdout.reconfigure(encoding='utf-8', errors='replace')
    if hasattr(sys.stderr, 'reconfigure'):
        sys.stderr.reconfigure(encoding='utf-8', errors='replace')
except Exception:
    pass

# Ensure backend root, internal dir, and PyInstaller bundle directories are in sys.path
if getattr(sys, 'frozen', False):
    bundle_dir = getattr(sys, '_MEIPASS', os.path.dirname(os.path.abspath(sys.executable)))
    internal_dir = os.path.join(bundle_dir, '_internal')
    for p in [internal_dir, os.path.join(internal_dir, 'backend'), bundle_dir, os.path.join(bundle_dir, 'backend')]:
        if os.path.isdir(p) and p not in sys.path:
            sys.path.insert(0, p)
    BASE_DIR = bundle_dir
else:
    BASE_DIR = os.path.dirname(os.path.abspath(__file__))
    if BASE_DIR not in sys.path:
        sys.path.insert(0, BASE_DIR)

try:
    from api_server import run_server
    from collector import collect_all_system_info
except (ImportError, ModuleNotFoundError):
    from backend.api_server import run_server
    from backend.collector import collect_all_system_info

DEFAULT_PORT = 18088


def setup_logging(verbose: bool = False):
    level = logging.DEBUG if verbose else logging.INFO
    # Store logs in logs/ inside application root or BASE_DIR
    app_root = BASE_DIR
    if getattr(sys, 'frozen', False):
        exe_dir = os.path.dirname(os.path.abspath(sys.executable))
        app_root = os.path.dirname(exe_dir) if os.path.basename(exe_dir).lower() == "backend" else exe_dir
    else:
        curr = os.path.abspath(os.path.dirname(os.path.dirname(__file__)))
        if os.path.isdir(os.path.join(curr, "config")):
            app_root = curr

    logs_dir = os.path.join(app_root, "logs")
    try:
        os.makedirs(logs_dir, exist_ok=True)
        log_file = os.path.join(logs_dir, "server.log")
    except Exception:
        log_file = os.path.join(BASE_DIR, "service.log")

    handlers = []
    try:
        handlers.append(logging.FileHandler(log_file, encoding="utf-8"))
    except Exception:
        pass
    if sys.stdout is not None:
        handlers.append(logging.StreamHandler(sys.stdout))

    logging.basicConfig(
        level=level,
        format="[%(asctime)s] [%(levelname)s] %(name)s: %(message)s",
        datefmt="%H:%M:%S",
        handlers=handlers if handlers else None
    )


def start_parent_watchdog(parent_pid: int = None):
    """Monitors the parent process (Flutter frontend).
    If the parent process exits or crashes, this backend terminates immediately."""
    import threading
    if parent_pid is None or parent_pid <= 0:
        try:
            parent_pid = os.getppid()
        except Exception:
            return
    if parent_pid <= 1:
        return

    def _watch():
        import ctypes
        import time
        SYNCHRONIZE = 0x00100000
        INFINITE = 0xFFFFFFFF
        try:
            handle = ctypes.windll.kernel32.OpenProcess(SYNCHRONIZE, False, int(parent_pid))
            if handle:
                ctypes.windll.kernel32.WaitForSingleObject(handle, INFINITE)
                ctypes.windll.kernel32.CloseHandle(handle)
                os._exit(0)
        except Exception:
            pass

        while True:
            time.sleep(1.5)
            try:
                h = ctypes.windll.kernel32.OpenProcess(0x0400, False, int(parent_pid))
                if not h:
                    os._exit(0)
                ctypes.windll.kernel32.CloseHandle(h)
            except Exception:
                os._exit(0)

    t = threading.Thread(target=_watch, daemon=True, name="ParentProcessWatchdog")
    t.start()


def main():
    parser = argparse.ArgumentParser(description="Central System Checker - Windows Hardware Detection Backend")
    parser.add_argument("--host", default="127.0.0.1", help="Host interface to bind (default: 127.0.0.1)")
    parser.add_argument("--port", type=int, default=DEFAULT_PORT, help=f"Port to bind (default: {DEFAULT_PORT})")
    parser.add_argument("--parent-pid", type=int, default=None, help="Parent process PID to monitor for automatic termination")
    parser.add_argument("--test", action="store_true", help="Run system inspection once, print JSON to stdout, and exit")
    parser.add_argument("--save", type=str, help="Save system inspection output to specified JSON file and exit")
    parser.add_argument("--verbose", action="store_true", help="Enable debug logging")

    args = parser.parse_args()
    setup_logging(args.verbose)

    if args.test:
        try:
            print("[*] Inspecting Windows Hardware & System...")
            data = collect_all_system_info()
            print(json.dumps(data, indent=2))
        except Exception:
            pass
        return 0

    if args.save:
        data = collect_all_system_info()
        with open(args.save, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2)
        try:
            print(f"[+] Saved system information to {args.save}")
        except Exception:
            pass
        return 0

    # Start watchdog to guarantee backend kills itself when frontend exits
    start_parent_watchdog(args.parent_pid)

    try:
        logging.info(f"Central System Checker Local Backend Service starting at http://{args.host}:{args.port}/")
    except Exception:
        pass

    run_server(host=args.host, port=args.port)
    return 0


if __name__ == "__main__":
    sys.exit(main())
