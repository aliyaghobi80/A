# backend/server.py
"""Compatibility forwarder to api_server.py"""
from api_server import (
    SystemInspectorRequestHandler,
    run_server,
    collect_all_system_info,
)

__all__ = [
    "SystemInspectorRequestHandler",
    "run_server",
    "collect_all_system_info",
]
