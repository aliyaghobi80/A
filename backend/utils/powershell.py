import subprocess
import json
import logging
import os
from typing import Any, Optional

logger = logging.getLogger(__name__)

# Standard Windows flag to hide console window completely
CREATE_NO_WINDOW = 0x08000000


def get_hidden_subprocess_kwargs():
    """
    Returns subprocess kwargs to completely suppress command prompt / PowerShell console popups on Windows.
    Uses CREATE_NO_WINDOW flag and SW_HIDE startupinfo while preserving stdout/stderr capture.
    """
    kwargs = {}
    if os.name == 'nt':
        kwargs['creationflags'] = CREATE_NO_WINDOW
        startupinfo = subprocess.STARTUPINFO()
        startupinfo.dwFlags |= subprocess.STARTF_USESHOWWINDOW
        startupinfo.wShowWindow = subprocess.SW_HIDE
        kwargs['startupinfo'] = startupinfo
        kwargs['stdin'] = subprocess.DEVNULL
    return kwargs


def run_powershell_json(script: str, timeout: int = 15) -> Optional[Any]:
    """
    Executes a PowerShell script silently with no console window and parses the resulting JSON output safely.
    Uses -NoProfile, -NonInteractive, and CREATE_NO_WINDOW.
    """
    try:
        cmd = [
            "powershell.exe",
            "-NoProfile",
            "-NonInteractive",
            "-ExecutionPolicy", "Bypass",
            "-Command",
            script
        ]
        proc = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=timeout,
            **get_hidden_subprocess_kwargs()
        )
        if proc.returncode != 0:
            if proc.stderr:
                logger.warning(f"PowerShell command returned code {proc.returncode}: {proc.stderr.strip()}")
            return None
        
        raw_output = proc.stdout.strip()
        if not raw_output:
            return None
            
        return json.loads(raw_output)
    except subprocess.TimeoutExpired:
        logger.error(f"PowerShell command timed out after {timeout}s")
        return None
    except json.JSONDecodeError as e:
        logger.warning(f"Failed to parse JSON from PowerShell output: {e}")
        return None
    except Exception as e:
        logger.error(f"Unexpected error running PowerShell: {e}")
        return None
