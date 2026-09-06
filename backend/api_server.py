import http.server
import json
import logging
import os
import sys
import threading
from typing import Optional
from urllib.parse import parse_qs, urlparse

# Ensure backend directory is in sys.path
_backend_dir = os.path.dirname(os.path.abspath(__file__))
if _backend_dir not in sys.path:
    sys.path.insert(0, _backend_dir)

from collector import collect_all_system_info
from packages.manager import scan_packages, install_package, open_package, open_office_folder, get_package_icon_path, set_packages_directory, get_current_packages_directory
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
)
from activation.windows_activation import get_windows_activation_info
from activation.office_activation import get_office_activation_info
from activation.activation_tools import execute_activation_tool, set_tools_directory, get_tool_status, get_tools_directory_status
from files.checker import set_file_requirement_path, check_required_files
from hardware.battery import get_battery_info
from qc.qc_engine import evaluate_system_qc

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
    try:
        p = _get_cache_filepath()
        with open(p, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
    except Exception as e:
        logger.debug(f"Failed to save cached system info: {e}")

_cache_lock = threading.Lock()
_cached_data: Optional[dict] = _load_cached_system_info()


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
                "service": "Central System Checker Backend",
                "version": "4.1.0",
                "phase": 4,
                "api_contract_version": 2,
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
            with _cache_lock:
                if _cached_data is None or force:
                    logger.info("Collecting system, hardware, software, and driver information...")
                    _cached_data = collect_all_system_info()
                    _save_cached_system_info(_cached_data)
                data = _cached_data

            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self._send_cors_headers()
            self.end_headers()
            self.wfile.write(json.dumps(data, indent=2).encode("utf-8"))
            return

        elif path == "/api/qc/status" or path == "/api/qc":
            with _cache_lock:
                if _cached_data is None:
                    _cached_data = collect_all_system_info()
                data = _cached_data
            pkgs = scan_packages()
            qc_report = evaluate_system_qc(data, pkgs)

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
        
        if path == "/api/refresh" or path == "/api/system-info":
            logger.info("Force refresh requested via POST...")
            with _cache_lock:
                _cached_data = collect_all_system_info()
                _save_cached_system_info(_cached_data)
                data = _cached_data

            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self._send_cors_headers()
            self.end_headers()
            self.wfile.write(json.dumps(data, indent=2).encode("utf-8"))
            return

        elif path == "/api/qc/run" or path == "/api/qc/check":
            logger.info("Full system QC check requested via POST...")
            with _cache_lock:
                _cached_data = collect_all_system_info()
                _save_cached_system_info(_cached_data)
                data = _cached_data
            pkgs = scan_packages()
            qc_report = evaluate_system_qc(data, pkgs)

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
            with _cache_lock:
                _cached_data = None

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
            result = open_package(pkg_id)
            self.send_response(200 if result.get("success") else 400)
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
            with _cache_lock:
                _cached_data = None

            status_http = 200 if (result.get("success") or result.get("cancelled")) else 400
            self.send_response(status_http)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self._send_cors_headers()
            self.end_headers()
            self.wfile.write(json.dumps(result, indent=2).encode("utf-8"))
            return

        elif path == "/api/activation/windows":
            logger.info("Executing configured Windows activation tool...")
            result = execute_activation_tool("windows")
            
            # Invalidate cached system info so next fetch gets updated activation status
            with _cache_lock:
                _cached_data = None

            # 200 for completed/cancelled, 400 only for hard server errors
            status_http = 200 if (result.get("success") or result.get("cancelled")) else 400
            self.send_response(status_http)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self._send_cors_headers()
            self.end_headers()
            self.wfile.write(json.dumps(result, indent=2).encode("utf-8"))
            return

        elif path == "/api/activation/office":
            logger.info("Executing configured Office activation tool...")
            result = execute_activation_tool("office")
            
            # Invalidate cached system info so next fetch gets updated activation status
            with _cache_lock:
                _cached_data = None

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
            with _cache_lock:
                _cached_data = None

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

        elif path == "/api/packages/batch-install":
            content_len = int(self.headers.get("Content-Length", 0))
            body_raw = self.rfile.read(content_len) if content_len > 0 else b"{}"
            try:
                payload = json.loads(body_raw.decode("utf-8"))
            except Exception:
                payload = {}
            package_ids = payload.get("package_ids", None)
            custom_dir = payload.get("custom_dir", None)
            result = start_batch_install(package_ids=package_ids, custom_dir=custom_dir)
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
            result = start_intelligent_driver_install(package_ids=package_ids, custom_dir=folder_path if folder_path else None)
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
                with _cache_lock:
                    _cached_data = None
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
            with _cache_lock:
                _cached_data = None
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

    logger.info(f"Central System Checker Backend API running at http://{host}:{bound_port}/")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        logger.info("Server stopping...")
    finally:
        httpd.server_close()
