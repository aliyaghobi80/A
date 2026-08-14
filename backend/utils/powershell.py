import subprocess
import json
import logging
from typing import Any, Optional

logger = logging.getLogger(__name__)

def run_powershell_json(script: str, timeout: int = 15) -> Optional[Any]:
    """
    Executes a PowerShell script and parses the resulting JSON output safely.
    Uses -NoProfile and -NonInteractive to maximize performance and avoid profile interference.
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
            timeout=timeout
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
