import http.server
import json
import logging
import threading
from typing import Optional

from collector import collect_all_system_info

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
        
        path = self.path.split("?")[0].rstrip("/")
        
        if path == "" or path == "/api/health":
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self._send_cors_headers()
            self.end_headers()
            resp = {
                "status": "ok",
                "service": "PC System Inspector Backend",
                "version": "1.0.0"
            }
            self.wfile.write(json.dumps(resp).encode("utf-8"))
            return

        elif path == "/api/system-info":
            # Serve fresh or cached data
            force = "refresh=true" in self.path.lower()
            with _cache_lock:
                if _cached_data is None or force:
                    logger.info("Collecting hardware information...")
                    _cached_data = collect_all_system_info()
                data = _cached_data

            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self._send_cors_headers()
            self.end_headers()
            self.wfile.write(json.dumps(data, indent=2).encode("utf-8"))
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
        path = self.path.split("?")[0].rstrip("/")
        
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

        else:
            self.send_response(404)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self._send_cors_headers()
            self.end_headers()
            resp = {"status": "error", "message": "Endpoint not found"}
            self.wfile.write(json.dumps(resp).encode("utf-8"))

    def log_message(self, format, *args):
        # Override to use Python logging instead of stderr prints
        logger.info(f"{self.address_string()} - {format % args}")

def run_server(host: str = "127.0.0.1", port: int = 18080):
    """Starts the ThreadingHTTPServer on the specified host and port."""
    server_address = (host, port)
    httpd = http.server.ThreadingHTTPServer(server_address, SystemInspectorRequestHandler)
    logger.info(f"PC System Inspector Backend API running at http://{host}:{port}/")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        logger.info("Server stopping...")
    finally:
        httpd.server_close()
