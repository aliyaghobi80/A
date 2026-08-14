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
from packages.manager import scan_packages, install_package, open_package, get_package_icon_path

logger = logging.getLogger(__name__)

# In-memory cached result
_cache_lock = threading.Lock()
_cached_data: Optional[dict] = None

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
                "version": "2.2.0",
                "phase": 2
            }
            self.wfile.write(json.dumps(resp).encode("utf-8"))
            return

        elif path == "/api/system-info":
            # Serve fresh or cached data
            force = "refresh" in query_params and query_params["refresh"][0].lower() == "true"
            with _cache_lock:
                if _cached_data is None or force:
                    logger.info("Collecting system, hardware, software, and driver information...")
                    _cached_data = collect_all_system_info()
                data = _cached_data

            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self._send_cors_headers()
            self.end_headers()
            self.wfile.write(json.dumps(data, indent=2).encode("utf-8"))
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
                data = _cached_data

            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self._send_cors_headers()
            self.end_headers()
            self.wfile.write(json.dumps(data, indent=2).encode("utf-8"))
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

        else:
            self.send_response(404)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self._send_cors_headers()
            self.end_headers()
            resp = {"status": "error", "message": "Endpoint not found"}
            self.wfile.write(json.dumps(resp).encode("utf-8"))

    def log_message(self, format, *args):
        logger.info(f"{self.address_string()} - {format % args}")

def run_server(host: str = "127.0.0.1", port: int = 18080):
    """Starts the ThreadingHTTPServer on the specified host and port."""
    server_address = (host, port)
    httpd = http.server.ThreadingHTTPServer(server_address, SystemInspectorRequestHandler)
    logger.info(f"Central System Checker Backend API running at http://{host}:{port}/")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        logger.info("Server stopping...")
    finally:
        httpd.server_close()
