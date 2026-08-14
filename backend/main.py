import argparse
import json
import logging
import os
import sys

# Ensure backend root is in sys.path
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
if BASE_DIR not in sys.path:
    sys.path.insert(0, BASE_DIR)

from collector import collect_all_system_info
from server import run_server

DEFAULT_PORT = 18080

def setup_logging(verbose: bool = False):
    level = logging.DEBUG if verbose else logging.INFO
    logging.basicConfig(
        level=level,
        format="[%(asctime)s] [%(levelname)s] %(name)s: %(message)s",
        datefmt="%H:%M:%S"
    )

def main():
    parser = argparse.ArgumentParser(description="Central System Checker - Windows Hardware Detection Backend")
    parser.add_argument("--host", default="127.0.0.1", help="Host interface to bind (default: 127.0.0.1)")
    parser.add_argument("--port", type=int, default=DEFAULT_PORT, help=f"Port to bind (default: {DEFAULT_PORT})")
    parser.add_argument("--test", action="store_true", help="Run system inspection once, print JSON to stdout, and exit")
    parser.add_argument("--save", type=str, help="Save system inspection output to specified JSON file and exit")
    parser.add_argument("--verbose", action="store_true", help="Enable debug logging")

    args = parser.parse_args()
    setup_logging(args.verbose)

    if args.test:
        print("[*] Inspecting Windows Hardware & System...")
        data = collect_all_system_info()
        print(json.dumps(data, indent=2))
        return 0

    if args.save:
        data = collect_all_system_info()
        with open(args.save, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2)
        print(f"[+] Saved system information to {args.save}")
        return 0

    print(f"==================================================")
    print(f" Central System Checker - Local Backend Service   ")
    print(f" Running at: http://{args.host}:{args.port}/        ")
    print(f"==================================================")
    
    run_server(host=args.host, port=args.port)
    return 0

if __name__ == "__main__":
    sys.exit(main())
