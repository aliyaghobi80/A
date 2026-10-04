import http.server
import json
import logging
import os
import sys
import threading
from typing import Optional
from urllib.parse import parse_qs, urlparse

# Ensure UTF-8 output encoding on all Windows machines
try:
    if hasattr(sys.stdout, 'reconfigure'):
        sys.stdout.reconfigure(encoding='utf-8', errors='replace')
    if hasattr(sys.stderr, 'reconfigure'):
        sys.stderr.reconfigure(encoding='utf-8', errors='replace')
except Exception:
    pass

# Ensure backend directory is in sys.path
_backend_dir = os.path.dirname(os.path.abspath(__file__))
if _backend_dir not in sys.path:
    sys.path.insert(0, _backend_dir)

from collector import collect_all_system_info
from packages.manager import scan_packages, install_package, open_package, open_office_folder, get_package_icon_path, set_packages_directory, get_current_packages_directory, pin_package_to_taskbar, set_windows_update_state
from windows.device_settings import get_device_settings_status, pin_windows_security, set_sleep_never, disable_all_startup_apps, disable_windows10_background_apps
from packages.office_shortcuts import ensure_office_desktop_shortcuts
from packages.batch_installer import start_batch_install, get_batch_status, cancel_batch_install
from drivers.driver_installer import (
    scan_driver_folder,
    start_batch_driver_install,
    get_driver_batch_status,
    cancel_driver_batch_install,
    intelligent_scan_drivers,
    start_intelligent_driver_install,
    get_driver_directory_config,
    set_driver_directory_config,
    load_driver_history,
    launch_interactive_driver_installer,
    open_driver_package_folder,
)
from activation.windows_activation import get_windows_activation_info
from activation.office_activation import get_office_activation_info
from activation.activation_tools import set_tools_directory, get_tool_status, get_tools_directory_status
from files.checker import set_file_requirement_path, check_required_files
from hardware.battery import get_battery_info
from hardware.storage import get_connected_usb_drives, safe_eject_drive
from qc.qc_engine import evaluate_system_qc
from windows.power_settings import set_laptop_power_modes
from session_watchdog import adopt_parent_process, get_parent_processes, get_parent_session

logger = logging.getLogger(__name__)

# Persistent system information cache
def _get_cache_filepath() -> str:
    appdata = os.environ.get("APPDATA") or os.environ.get("LOCALAPPDATA")
    if appdata:
        d = os.path.join(appdata, "CentralSystemChecker")
        try:
            os.makedirs(d, exist_ok=True)
            return os.path.join(d, "system_info_cache.json")
        except Exception:
            pass
    return os.path.join(_backend_dir, "system_cache.json")

def _load_cached_system_info() -> Optional[dict]:
    try:
        p = _get_cache_filepath()
        if os.path.isfile(p):
            with open(p, "r", encoding="utf-8") as f:
                data = json.load(f)
                if isinstance(data, dict) and data.get("status") == "success":
                    logger.info(f"Loaded persistent system cache from {p}")
                    return data
    except Exception as e:
        logger.debug(f"Failed to load cached system info: {e}")
    return None

def _save_cached_system_info(data: dict):
    temp_path = ""
    try:
        p = _get_cache_filepath()
        temp_path = f"{p}.{os.getpid()}.{threading.get_ident()}.tmp"
        with open(temp_path, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
            f.flush()
            os.fsync(f.fileno())
        os.replace(temp_path, p)
    except Exception as e:
        logger.debug(f"Failed to save cached system info: {e}")
    finally:
        if temp_path and os.path.exists(temp_path):
            try:
                os.remove(temp_path)
            except OSError:
                pass

_cache_lock = threading.Lock()
_cached_data: Optional[dict] = _load_cached_system_info()
_cache_generation = 0


def _refresh_system_cache(*, force: bool, reason: str) -> dict:
    """Collect without holding the cache lock and reject stale scan results.

    ``ThreadingHTTPServer`` can receive a manual refresh while the startup scan
    is still running.  A generation token prevents the older startup result
    from overwriting the newer technician-requested snapshot.
    """
    global _cached_data, _cache_generation
    with _cache_lock:
        if _cached_data is not None and not force:
            return _cached_data
        _cache_generation += 1
        generation = _cache_generation

    logger.info("Collecting system information (%s, generation %s)...", reason, generation)
    fresh = collect_all_system_info()

    with _cache_lock:
        if generation == _cache_generation:
            _cached_data = fresh
            _save_cached_system_info(fresh)
            return fresh

        logger.info(
            "Discarded stale system scan generation %s; current generation is %s.",
            generation,
            _cache_generation,
        )
        return _cached_data if _cached_data is not None else fresh


def _invalidate_system_cache() -> None:
    """Invalidate cached hardware data and supersede every in-flight scan."""
    global _cached_data, _cache_generation
    with _cache_lock:
        _cache_generation += 1
        _cached_data = None


def _trigger_background_scan():
    """Refreshes hardware and system info in background on startup to replace stale disk cache."""
    try:
        _refresh_system_cache(force=True, reason="startup")
        logger.info("Background system scan completed; hardware cache is now fresh.")
    except Exception as e:
        logger.error(f"Error in background system scan: {e}")


threading.Thread(target=_trigger_background_scan, daemon=True).start()


class SystemInspectorRequestHandler(http.server.BaseHTTPRequestHandler):
    
    def _send_cors_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization")

    def do_OPTIONS(self):
        self.send_response(204)
        self._send_cors_headers()
        self.end_headers()

    def do_GET(self):
        global _cached_data
        
        parsed = urlparse(self.path)
        path = parsed.path.rstrip("/")
        query_params = parse_qs(parsed.query)
        
        if path == "" or path == "/api/health":
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self._send_cors_headers()
            self.end_headers()
            resp = {
                "status": "ok",
                "service": "Markazi System Checker Backend",
                "version": "1.1.38",
                "phase": 4,
                "api_contract_version": 3,
            }
            self.wfile.write(json.dumps(resp).encode("utf-8"))
            return

        elif path == "/api/shutdown":
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self._send_cors_headers()
            self.end_headers()
            resp = {"status": "ok", "message": "Server shutting down..."}
            self.wfile.write(json.dumps(resp).encode("utf-8"))
            def _delayed_exit():
                import time
                time.sleep(0.3)
                os._exit(0)
            threading.Thread(target=_delayed_exit, daemon=True).start()
            return

        elif path == "/api/system-info" or path == "/api/refresh":
            # Serve fresh or cached data
            force = ("refresh" in query_params and query_params["refresh"][0].lower() == "true") or path == "/api/refresh"
            data = _refresh_system_cache(
                force=force,
                reason="GET force refresh" if force else "GET cache miss",
            )

            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self._send_cors_headers()
            self.end_headers()
            self.wfile.write(json.dumps(data, indent=2).encode("utf-8"))
            return

        elif path == "/api/qc/status" or path == "/api/qc":
            data = _refresh_system_cache(force=False, reason="QC cache miss")
            pkgs = scan_packages()
            qc_report = evaluate_system_qc(data, pkgs, get_device_settings_status())

            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self._send_cors_headers()
            self.end_headers()
            self.wfile.write(json.dumps(qc_report, indent=2).encode("utf-8"))
            return

        elif path == "/api/packages":
            custom_dir = query_params.get("dir", [None])[0]
            logger.info("Scanning software packages...")
            packages_data = scan_packages(custom_dir)

            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self._send_cors_headers()
            self.end_headers()
            self.wfile.write(json.dumps(packages_data, indent=2).encode("utf-8"))
            return

        elif path == "/api/device-settings/status":
            result = get_device_settings_status()
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self._send_cors_headers()
            self.end_headers()
            self.wfile.write(json.dumps(result, indent=2).encode("utf-8"))
            return

        elif path == "/api/packages/icon":
            pkg_id = query_params.get("id", [""])[0]
            icon_path = get_package_icon_path(pkg_id)
            if icon_path and os.path.isfile(icon_path):
                ext = os.path.splitext(icon_path)[1].lower()
                mime = "image/x-icon" if ext == ".ico" else "image/png" if ext == ".png" else "application/octet-stream"
                try:
                    with open(icon_path, "rb") as f:
                        content = f.read()
                    self.send_response(200)
                    self.send_header("Content-Type", mime)
                    self.send_header("Content-Length", str(len(content)))
                    self._send_cors_headers()
                    self.end_headers()
                    self.wfile.write(content)
                    return
                except Exception as e:
                    logger.error(f"Error serving icon: {e}")

            self.send_response(404)
            self._send_cors_headers()
            self.end_headers()
            return

        elif path == "/api/tools" or path == "/api/tools/status":
            logger.info("Querying activation tools directory status...")
            tools_status = get_tools_directory_status()
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self._send_cors_headers()
            self.end_headers()
            self.wfile.write(json.dumps(tools_status, indent=2).encode("utf-8"))
            return

        elif path == "/api/activation/status":
            logger.info("Querying Windows & Office activation status...")
            win_act = get_windows_activation_info()
            off_act = get_office_activation_info()
            resp = {
                "status": "success",
                "windows": win_act,
                "office": off_act
            }
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self._send_cors_headers()
            self.end_headers()
            self.wfile.write(json.dumps(resp, indent=2).encode("utf-8"))
            return

        elif path == "/api/proxy":
            logger.info("Querying manual proxy status...")
            from windows.proxy import get_proxy_info
            proxy_info = get_proxy_info()
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self._send_cors_headers()
            self.end_headers()
            self.wfile.write(json.dumps(proxy_info, indent=2).encode("utf-8"))
            return

        elif path == "/api/battery" or path == "/api/battery/test":
            logger.info("Querying battery health & power status...")
            bat_info = get_battery_info()
            resp = {
                "status": "success",
                "battery": bat_info
            }
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self._send_cors_headers()
            self.end_headers()
            self.wfile.write(json.dumps(resp, indent=2).encode("utf-8"))
            return

        elif path == "/api/reboot" or path == "/api/reboot/status":
            logger.info("Querying pending reboot status...")
            from windows.reboot import check_pending_reboot
            reboot_info = check_pending_reboot()
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self._send_cors_headers()
            self.end_headers()
            self.wfile.write(json.dumps(reboot_info, indent=2).encode("utf-8"))
            return

        elif path == "/api/system/usb-drives":
            logger.debug("Scanning connected USB flash drives...")
            drives = get_connected_usb_drives()
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self._send_cors_headers()
            self.end_headers()
            self.wfile.write(json.dumps({"status": "success", "usb_drives": drives}, indent=2).encode("utf-8"))
            return

        elif path == "/api/system/storage":
            from hardware.storage import get_storage_info
            logger.debug("Scanning physical storage drives...")
            storage_data = get_storage_info()
            with _cache_lock:
                if _cached_data and isinstance(_cached_data.get("storage"), list):
                    _cached_data["storage"] = storage_data
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self._send_cors_headers()
            self.end_headers()
            self.wfile.write(json.dumps({"status": "success", "storage": storage_data}, indent=2).encode("utf-8"))
            return

        elif path == "/api/packages/batch-status":
            resp = get_batch_status()
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self._send_cors_headers()
            self.end_headers()
            self.wfile.write(json.dumps(resp, indent=2).encode("utf-8"))
            return

        elif path in ("/api/drivers/batch-status", "/api/drivers/queue/status"):
            resp = get_driver_batch_status()
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self._send_cors_headers()
            self.end_headers()
            self.wfile.write(json.dumps(resp, indent=2).encode("utf-8"))
            return

        elif path in ("/api/drivers/config", "/api/drivers/directory"):
            resp = get_driver_directory_config()
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self._send_cors_headers()
            self.end_headers()
            self.wfile.write(json.dumps(resp, indent=2).encode("utf-8"))
            return

        elif path == "/api/drivers/history":
            resp = load_driver_history()
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self._send_cors_headers()
            self.end_headers()
            self.wfile.write(json.dumps(resp, indent=2).encode("utf-8"))
            return

        else:
            self.send_response(404)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self._send_cors_headers()
            self.end_headers()
            resp = {"status": "error", "message": "Endpoint not found"}
            self.wfile.write(json.dumps(resp).encode("utf-8"))

    def do_POST(self):
        global _cached_data
        parsed = urlparse(self.path)
        path = parsed.path.rstrip("/")
        
        if path == "/api/session/attach":
            content_len = int(self.headers.get("Content-Length", 0))
            body_raw = self.rfile.read(content_len) if content_len > 0 else b"{}"
            try:
                payload = json.loads(body_raw.decode("utf-8"))
            except Exception:
                payload = {}
            success = adopt_parent_process(payload.get("parent_pid"))
            parent_pid, generation = get_parent_session()
            result = {
                "success": success,
                "parent_pid": parent_pid,
                "backend_pid": os.getpid(),
                "parent_pids": get_parent_processes(),
                "generation": generation,
                "message": "Frontend session attached." if success else "Invalid frontend process.",
            }
            self.send_response(200 if success else 400)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self._send_cors_headers()
            self.end_headers()
            self.wfile.write(json.dumps(result).encode("utf-8"))
            return

        if path == "/api/refresh" or path == "/api/system-info":
            logger.info("Force refresh requested via POST...")
            data = _refresh_system_cache(force=True, reason="POST force refresh")

            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self._send_cors_headers()
            self.end_headers()
            self.wfile.write(json.dumps(data, indent=2).encode("utf-8"))
            return

        elif path == "/api/qc/run" or path == "/api/qc/check":
            logger.info("Full system QC check requested via POST...")
            data = _refresh_system_cache(force=True, reason="QC run")
            pkgs = scan_packages()
            qc_report = evaluate_system_qc(data, pkgs, get_device_settings_status())

            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self._send_cors_headers()
            self.end_headers()
            self.wfile.write(json.dumps(qc_report, indent=2).encode("utf-8"))
            return

        elif path == "/api/battery/test" or path == "/api/battery":
            logger.info("Battery health test requested via POST...")
            bat_info = get_battery_info()
            resp = {
                "status": "success",
                "battery": bat_info
            }
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self._send_cors_headers()
            self.end_headers()
            self.wfile.write(json.dumps(resp, indent=2).encode("utf-8"))
            return

        elif path == "/api/packages/scan":
            logger.info("Package rescan requested via POST...")
            data = scan_packages()
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self._send_cors_headers()
            self.end_headers()
            self.wfile.write(json.dumps(data, indent=2).encode("utf-8"))
            return

        elif path == "/api/packages/install":
            content_len = int(self.headers.get("Content-Length", 0))
            body_raw = self.rfile.read(content_len) if content_len > 0 else b"{}"
            try:
                payload = json.loads(body_raw.decode("utf-8"))
            except Exception:
                payload = {}

            pkg_id = (
                payload.get("package_id")
                or payload.get("id")
                or payload.get("relative_path")
                or payload.get("filename")
                or ""
            )
            if not pkg_id:
                self.send_response(400)
                self.send_header("Content-Type", "application/json; charset=utf-8")
                self._send_cors_headers()
                self.end_headers()
                resp = {"success": False, "message": "Missing 'package_id' or 'relative_path' in request body."}
                self.wfile.write(json.dumps(resp).encode("utf-8"))
                return

            logger.info(f"Triggering package installation for: {pkg_id}")
            result = install_package(pkg_id)

            # Invalidate cached system info so next fetch gets updated install status
            _invalidate_system_cache()

            self.send_response(200 if result.get("success") else 400)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self._send_cors_headers()
            self.end_headers()
            self.wfile.write(json.dumps(result, indent=2).encode("utf-8"))
            return

        elif path == "/api/packages/open":
            content_len = int(self.headers.get("Content-Length", 0))
            body_raw = self.rfile.read(content_len) if content_len > 0 else b"{}"
            try:
                payload = json.loads(body_raw.decode("utf-8"))
            except Exception:
                payload = {}

            pkg_id = (
                payload.get("package_id")
                or payload.get("id")
                or payload.get("relative_path")
                or payload.get("filename")
                or payload.get("name")
                or ""
            )
            if not pkg_id:
                self.send_response(400)
                self.send_header("Content-Type", "application/json; charset=utf-8")
                self._send_cors_headers()
                self.end_headers()
                resp = {"success": False, "message": "Missing 'package_id' in request body."}
                self.wfile.write(json.dumps(resp).encode("utf-8"))
                return

            logger.info(f"Opening installed package: {pkg_id}")
            result = open_package(
                pkg_id,
                confirm_home_update_block=bool(payload.get("confirm_home_update_block", False)),
            )
            self.send_response(200 if (result.get("success") or result.get("requires_confirmation")) else 400)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self._send_cors_headers()
            self.end_headers()
            self.wfile.write(json.dumps(result, indent=2).encode("utf-8"))
            return

        elif path == "/api/packages/pin-taskbar":
            content_len = int(self.headers.get("Content-Length", 0))
            body_raw = self.rfile.read(content_len) if content_len > 0 else b"{}"
            try:
                payload = json.loads(body_raw.decode("utf-8"))
            except Exception:
                payload = {}
            pkg_id = payload.get("package_id") or payload.get("relative_path") or payload.get("id") or ""
            result = pin_package_to_taskbar(pkg_id) if pkg_id else {
                "success": False,
                "message": "شناسه برنامه ارسال نشده است.",
            }
            self.send_response(200 if result.get("success") else 400)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self._send_cors_headers()
            self.end_headers()
            self.wfile.write(json.dumps(result, indent=2).encode("utf-8"))
            return

        elif path == "/api/packages/windows-update":
            content_len = int(self.headers.get("Content-Length", 0))
            body_raw = self.rfile.read(content_len) if content_len > 0 else b"{}"
            try:
                payload = json.loads(body_raw.decode("utf-8"))
            except Exception:
                payload = {}
            pkg_id = payload.get("package_id") or payload.get("relative_path") or payload.get("id") or ""
            enable = payload.get("enable")
            if not pkg_id or not isinstance(enable, bool):
                result = {"success": False, "message": "شناسه برنامه یا وضعیت موردنظر معتبر نیست."}
            else:
                result = set_windows_update_state(
                    pkg_id,
                    enable=enable,
                    confirm_home_update_block=bool(payload.get("confirm_home_update_block", False)),
                )
            self.send_response(200 if (result.get("success") or result.get("requires_confirmation")) else 400)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self._send_cors_headers()
            self.end_headers()
            self.wfile.write(json.dumps(result, indent=2).encode("utf-8"))
            return

        elif path in ("/api/device-settings/pin-windows-security", "/api/device-settings/desktop-icons", "/api/device-settings/tehran-timezone"):
            from windows.desktop_time import show_desktop_icons, set_tehran_automatic_timezone
            if path.endswith('desktop-icons'):
                result = show_desktop_icons()
            elif path.endswith('tehran-timezone'):
                result = set_tehran_automatic_timezone()
            else:
                result = pin_windows_security()
            self.send_response(200 if result.get("success") else 400)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self._send_cors_headers()
            self.end_headers()
            self.wfile.write(json.dumps(result, indent=2).encode("utf-8"))
            return

        elif path == "/api/device-settings/sleep-never":
            result = set_sleep_never()
            self.send_response(200 if result.get("success") else 400)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self._send_cors_headers()
            self.end_headers()
            self.wfile.write(json.dumps(result, indent=2).encode("utf-8"))
            return

        elif path == "/api/device-settings/laptop-power-modes":
            from windows.device_settings import has_battery
            result = set_laptop_power_modes() if has_battery() else {"success": False, "message": "این گزینه مخصوص دستگاه دارای باتری است."}
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self._send_cors_headers()
            self.end_headers()
            self.wfile.write(json.dumps(result).encode("utf-8"))
            return

        elif path == "/api/device-settings/disable-startup-apps":
            result = disable_all_startup_apps()
            self.send_response(200 if (result.get("success") or result.get("cancelled")) else 400)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self._send_cors_headers()
            self.end_headers()
            self.wfile.write(json.dumps(result, indent=2).encode("utf-8"))
            return

        elif path == "/api/device-settings/disable-background-apps":
            result = disable_windows10_background_apps()
            self.send_response(200 if (result.get("success") or result.get("unsupported")) else 400)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self._send_cors_headers()
            self.end_headers()
            self.wfile.write(json.dumps(result, indent=2).encode("utf-8"))
            return

        elif path == "/api/device-settings/apply-all":
            try:
                from packages.orchestrator import apply_desktop_icons, apply_essential_device_settings
                logger.info("Applying all essential device settings and desktop icons...")
                icons_res = apply_desktop_icons()
                settings_res = apply_essential_device_settings()
                any_ok = icons_res.get("success", False) or settings_res.get("success", False)
                all_ok = icons_res.get("success", False) and settings_res.get("all_success", False)
                msg = "تمام تنظیمات مهم دستگاه و آیکن‌های دسکتاپ با موفقیت اعمال شدند." if all_ok else "تنظیمات مهم دستگاه (خاموشی صفحه، Sleep و...) با موفقیت اعمال شدند."
                resp = {
                    "success": any_ok,
                    "all_ok": all_ok,
                    "desktop_icons": icons_res,
                    "settings": settings_res,
                    "message": msg,
                }
            except Exception as e:
                logger.error(f"Error applying all settings: {e}", exc_info=True)
                resp = {"success": False, "message": f"خطا در اعمال تنظیمات: {e}"}
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self._send_cors_headers()
            self.end_headers()
            self.wfile.write(json.dumps(resp, indent=2).encode("utf-8"))
            return

        elif path == "/api/packages/office-shortcuts":
            result = ensure_office_desktop_shortcuts()
            self.send_response(200 if result.get("created") else 400)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self._send_cors_headers()
            self.end_headers()
            self.wfile.write(json.dumps(result, indent=2).encode("utf-8"))
            return

        elif path in ("/api/packages/open-office", "/api/packages/open-office-folder"):
            content_len = int(self.headers.get("Content-Length", 0))
            body_raw = self.rfile.read(content_len) if content_len > 0 else b"{}"
            try:
                payload = json.loads(body_raw.decode("utf-8"))
            except Exception:
                payload = {}

            custom_dir = payload.get("directory") or payload.get("custom_dir")
            logger.info(f"Opening office folder for directory: {custom_dir}")
            result = open_office_folder(custom_dir)
            self.send_response(200 if result.get("success") else 400)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self._send_cors_headers()
            self.end_headers()
            self.wfile.write(json.dumps(result, indent=2).encode("utf-8"))
            return

        elif path == "/api/packages/uninstall":
            content_len = int(self.headers.get("Content-Length", 0))
            body_raw = self.rfile.read(content_len) if content_len > 0 else b"{}"
            try:
                payload = json.loads(body_raw.decode("utf-8"))
            except Exception:
                payload = {}

            pkg_id = (
                payload.get("package_id")
                or payload.get("id")
                or payload.get("relative_path")
                or payload.get("filename")
                or payload.get("name")
                or ""
            )
            if not pkg_id:
                self.send_response(400)
                self.send_header("Content-Type", "application/json; charset=utf-8")
                self._send_cors_headers()
                self.end_headers()
                resp = {"success": False, "message": "Missing 'package_id' in request body."}
                self.wfile.write(json.dumps(resp).encode("utf-8"))
                return

            logger.info(f"Uninstalling package: {pkg_id}")
            from packages.manager import uninstall_package
            result = uninstall_package(pkg_id)

            # Invalidate cached system info
            _invalidate_system_cache()

            status_http = 200 if (result.get("success") or result.get("cancelled")) else 400
            self.send_response(status_http)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self._send_cors_headers()
            self.end_headers()
            self.wfile.write(json.dumps(result, indent=2).encode("utf-8"))
            return

        elif path == "/api/activation/windows":
            logger.info("Executing configured Windows activation tool...")
            from activation.verification import verify_activation_result
            from windows.device_settings import get_windows_identity
            identity = get_windows_identity()
            if identity.get('is_home'):
                result = {
                    'success': False,
                    'skipped': True,
                    'blocked': True,
                    'home_guard': True,
                    'windows': identity,
                    'message': f"{identity.get('label') or 'Windows Home'} اورجینال است؛ ابزار فعال‌سازی اجرا نشد.",
                }
            else:
                from packages.orchestrator import activate_windows_from_packages
                result = verify_activation_result(
                    'windows',
                    activate_windows_from_packages(
                        get_current_packages_directory(),
                        timeout_seconds=300,
                    ),
                )
            
            # Invalidate cached system info so next fetch gets updated activation status
            _invalidate_system_cache()

            # 200 for completed/cancelled, 400 only for hard server errors
            status_http = 200 if (result.get("success") or result.get("cancelled")) else 400
            self.send_response(status_http)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self._send_cors_headers()
            self.end_headers()
            self.wfile.write(json.dumps(result, indent=2).encode("utf-8"))
            return

        elif path == "/api/activation/office":
            logger.info("Preparing KMS bundle and executing owned OFFICE.cmd...")
            from packages.orchestrator import activate_office_from_packages

            result = activate_office_from_packages(
                get_current_packages_directory(),
                timeout_seconds=300,
            )
            
            # Invalidate cached system info so next fetch gets updated activation status
            _invalidate_system_cache()

            status_http = 200 if (result.get("success") or result.get("cancelled")) else 400
            self.send_response(status_http)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self._send_cors_headers()
            self.end_headers()
            self.wfile.write(json.dumps(result, indent=2).encode("utf-8"))
            return

        elif path == "/api/proxy/disable":
            logger.info("Disabling Windows manual proxy...")
            from windows.proxy import disable_proxy
            result = disable_proxy()

            # Invalidate cached system info so next fetch gets updated proxy status
            _invalidate_system_cache()

            self.send_response(200 if result.get("success") else 400)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self._send_cors_headers()
            self.end_headers()
            self.wfile.write(json.dumps(result, indent=2).encode("utf-8"))
            return

        elif path == "/api/reboot/restart":
            content_len = int(self.headers.get("Content-Length", 0))
            body_raw = self.rfile.read(content_len) if content_len > 0 else b"{}"
            try:
                payload = json.loads(body_raw.decode("utf-8"))
            except Exception:
                payload = {}
            delay = int(payload.get("delay_seconds", 3))
            reason = str(payload.get("reason", "Markazi System QC - اعمال تغییرات و درایورها"))
            from windows.reboot import execute_system_restart
            result = execute_system_restart(delay_seconds=delay, reason_msg=reason)
            self.send_response(200 if result.get("success") else 400)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self._send_cors_headers()
            self.end_headers()
            self.wfile.write(json.dumps(result, indent=2).encode("utf-8"))
            return

        elif path == "/api/reboot/cancel":
            from windows.reboot import cancel_system_restart
            result = cancel_system_restart()
            self.send_response(200 if result.get("success") else 400)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self._send_cors_headers()
            self.end_headers()
            self.wfile.write(json.dumps(result, indent=2).encode("utf-8"))
            return

        elif path == "/api/system/eject-drive":
            content_len = int(self.headers.get("Content-Length", 0))
            body_raw = self.rfile.read(content_len) if content_len > 0 else b"{}"
            try:
                payload = json.loads(body_raw.decode("utf-8"))
            except Exception:
                payload = {}
            drive_letter = str(payload.get("drive_letter") or "").strip()
            logger.info(f"Safely ejecting drive {drive_letter}...")
            result = safe_eject_drive(drive_letter)
            _invalidate_system_cache()
            self.send_response(200 if result.get("success") else 400)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self._send_cors_headers()
            self.end_headers()
            self.wfile.write(json.dumps(result, indent=2, ensure_ascii=False).encode("utf-8"))
            return

        elif path == "/api/packages/batch-install":
            content_len = int(self.headers.get("Content-Length", 0))
            body_raw = self.rfile.read(content_len) if content_len > 0 else b"{}"
            try:
                payload = json.loads(body_raw.decode("utf-8"))
            except Exception:
                payload = {}
            package_ids = payload.get("package_ids", None)
            custom_dir = payload.get("custom_dir", None)
            include_system_setup = payload.get("include_system_setup", None)
            result = start_batch_install(
                package_ids=package_ids,
                custom_dir=custom_dir,
                include_system_setup=include_system_setup,
                include_activation=payload.get("include_activation") is True,
                double_speed=payload.get("double_speed") is True,
            )
            self.send_response(200 if result.get("success") else 400)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self._send_cors_headers()
            self.end_headers()
            self.wfile.write(json.dumps(result, indent=2).encode("utf-8"))
            return

        elif path == "/api/packages/batch-cancel":
            result = cancel_batch_install()
            self.send_response(200 if result.get("success") else 400)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self._send_cors_headers()
            self.end_headers()
            self.wfile.write(json.dumps(result, indent=2).encode("utf-8"))
            return

        elif path in ("/api/drivers/scan", "/api/drivers/scan-folder"):
            content_len = int(self.headers.get("Content-Length", 0))
            body_raw = self.rfile.read(content_len) if content_len > 0 else b"{}"
            try:
                payload = json.loads(body_raw.decode("utf-8"))
            except Exception:
                payload = {}
            folder_path = (payload.get("folder_path") or payload.get("directory") or "").strip()
            result = intelligent_scan_drivers(custom_dir=folder_path if folder_path else None)
            self.send_response(200 if result.get("success") else 400)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self._send_cors_headers()
            self.end_headers()
            self.wfile.write(json.dumps(result, indent=2).encode("utf-8"))
            return

        elif path in ("/api/drivers/queue/install", "/api/drivers/batch-install"):
            content_len = int(self.headers.get("Content-Length", 0))
            body_raw = self.rfile.read(content_len) if content_len > 0 else b"{}"
            try:
                payload = json.loads(body_raw.decode("utf-8"))
            except Exception:
                payload = {}
            folder_path = (payload.get("folder_path") or payload.get("directory") or "").strip()
            package_ids = payload.get("package_ids", None)
            resume = payload.get("resume", False)
            result = start_intelligent_driver_install(package_ids=package_ids, custom_dir=folder_path if folder_path else None, resume=resume, double_speed=payload.get("double_speed") is True)
            self.send_response(200 if result.get("success") else 400)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self._send_cors_headers()
            self.end_headers()
            self.wfile.write(json.dumps(result, indent=2).encode("utf-8"))
            return

        elif path in ("/api/drivers/queue/cancel", "/api/drivers/batch-cancel"):
            result = cancel_driver_batch_install()
            self.send_response(200 if result.get("success") else 400)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self._send_cors_headers()
            self.end_headers()
            self.wfile.write(json.dumps(result, indent=2).encode("utf-8"))
            return

        elif path == "/api/drivers/install-interactive":
            content_len = int(self.headers.get("Content-Length", 0))
            body_raw = self.rfile.read(content_len) if content_len > 0 else b"{}"
            try:
                payload = json.loads(body_raw.decode("utf-8"))
            except Exception:
                payload = {}
            package_id = payload.get("package_id", "")
            folder_path = payload.get("folder_path", None)
            result = launch_interactive_driver_installer(package_id, custom_dir=folder_path)
            self.send_response(200 if result.get("success") else 400)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self._send_cors_headers()
            self.end_headers()
            self.wfile.write(json.dumps(result, indent=2).encode("utf-8"))
            return

        elif path == "/api/drivers/open-folder":
            content_len = int(self.headers.get("Content-Length", 0))
            body_raw = self.rfile.read(content_len) if content_len > 0 else b"{}"
            try:
                payload = json.loads(body_raw.decode("utf-8"))
            except Exception:
                payload = {}
            package_id = payload.get("package_id", "")
            folder_path = payload.get("folder_path", None)
            result = open_driver_package_folder(package_id, custom_dir=folder_path)
            self.send_response(200 if result.get("success") else 400)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self._send_cors_headers()
            self.end_headers()
            self.wfile.write(json.dumps(result, indent=2).encode("utf-8"))
            return

        elif path in ("/api/drivers/config", "/api/drivers/directory"):
            content_len = int(self.headers.get("Content-Length", 0))
            body_raw = self.rfile.read(content_len) if content_len > 0 else b"{}"
            try:
                payload = json.loads(body_raw.decode("utf-8"))
            except Exception:
                payload = {}
            new_path = (payload.get("folder_path") or payload.get("directory") or "").strip()
            result = set_driver_directory_config(new_path)
            self.send_response(200 if result.get("success") else 400)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self._send_cors_headers()
            self.end_headers()
            self.wfile.write(json.dumps(result, indent=2).encode("utf-8"))
            return

        elif path == "/api/packages/directory":
            content_len = int(self.headers.get("Content-Length", 0))
            body_raw = self.rfile.read(content_len) if content_len > 0 else b"{}"
            try:
                payload = json.loads(body_raw.decode("utf-8"))
            except Exception:
                payload = {}

            custom_dir = payload.get("directory", "").strip()
            if not custom_dir:
                self.send_response(400)
                self.send_header("Content-Type", "application/json; charset=utf-8")
                self._send_cors_headers()
                self.end_headers()
                resp = {"success": False, "message": "Missing 'directory' in request body."}
                self.wfile.write(json.dumps(resp).encode("utf-8"))
                return

            res = set_packages_directory(custom_dir)
            if res.get("success"):
                pkgs_data = scan_packages(custom_dir)
                res["packages_data"] = pkgs_data
                self.send_response(200)
            else:
                self.send_response(400)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self._send_cors_headers()
            self.end_headers()
            self.wfile.write(json.dumps(res, indent=2).encode("utf-8"))
            return

        elif path == "/api/tools/directory":
            content_len = int(self.headers.get("Content-Length", 0))
            body_raw = self.rfile.read(content_len) if content_len > 0 else b"{}"
            try:
                payload = json.loads(body_raw.decode("utf-8"))
            except Exception:
                payload = {}

            custom_dir = payload.get("directory", "").strip()
            if not custom_dir:
                self.send_response(400)
                self.send_header("Content-Type", "application/json; charset=utf-8")
                self._send_cors_headers()
                self.end_headers()
                resp = {"success": False, "message": "Missing 'directory' in request body."}
                self.wfile.write(json.dumps(resp).encode("utf-8"))
                return

            res = set_tools_directory(custom_dir)
            if res.get("success"):
                _invalidate_system_cache()
                res["windows_tool_status"] = get_tool_status("windows")
                res["office_tool_status"] = get_tool_status("office")
                self.send_response(200)
            else:
                self.send_response(400)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self._send_cors_headers()
            self.end_headers()
            self.wfile.write(json.dumps(res, indent=2).encode("utf-8"))
            return

        elif path == "/api/files/directory":
            content_len = int(self.headers.get("Content-Length", 0))
            body_raw = self.rfile.read(content_len) if content_len > 0 else b"{}"
            try:
                payload = json.loads(body_raw.decode("utf-8"))
            except Exception:
                payload = {}

            req_id = payload.get("id", "training_folder").strip()
            new_path = payload.get("path", "").strip()
            if not new_path:
                self.send_response(400)
                self.send_header("Content-Type", "application/json; charset=utf-8")
                self._send_cors_headers()
                self.end_headers()
                resp = {"success": False, "message": "Missing 'path' in request body."}
                self.wfile.write(json.dumps(resp).encode("utf-8"))
                return

            res = set_file_requirement_path(req_id, new_path)
            _invalidate_system_cache()
            res["files_status"] = check_required_files()
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self._send_cors_headers()
            self.end_headers()
            self.wfile.write(json.dumps(res, indent=2).encode("utf-8"))
            return

        elif path == "/api/shutdown":
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self._send_cors_headers()
            self.end_headers()
            resp = {"status": "ok", "message": "Server shutting down..."}
            self.wfile.write(json.dumps(resp).encode("utf-8"))
            def _delayed_exit():
                import time
                time.sleep(0.3)
                os._exit(0)
            threading.Thread(target=_delayed_exit, daemon=True).start()
            return

        else:
            self.send_response(404)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self._send_cors_headers()
            self.end_headers()
            resp = {"status": "error", "message": "Endpoint not found"}
            self.wfile.write(json.dumps(resp).encode("utf-8"))

    def log_message(self, format, *args):
        logger.info(f"{self.address_string()} - {format % args}")

def run_server(host: str = "127.0.0.1", port: int = 18088):
    """Starts the ThreadingHTTPServer on the specified host and port with automatic fallback ports."""
    candidate_ports = [port, 18088, 18080, 18089, 18090, 18091]
    # Remove duplicates preserving order
    seen_ports = set()
    ports_to_try = [p for p in candidate_ports if not (p in seen_ports or seen_ports.add(p))]

    httpd = None
    bound_port = None

    for candidate in ports_to_try:
        try:
            server_address = (host, candidate)
            httpd = http.server.ThreadingHTTPServer(server_address, SystemInspectorRequestHandler)
            bound_port = candidate
            break
        except OSError as e:
            logger.warning(f"Could not bind to port {candidate}: {e}. Trying next port...")

    if not httpd or bound_port is None:
        logger.critical(f"FATAL: Failed to bind to any candidate port in {ports_to_try}.")
        sys.exit(1)

    logger.info(f"Markazi System Checker Backend API running at http://{host}:{bound_port}/")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        logger.info("Server stopping...")
    finally:
        httpd.server_close()
