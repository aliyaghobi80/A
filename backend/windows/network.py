import logging
import os
import re
import socket
import subprocess
from typing import List, Dict, Any

from utils.powershell import run_powershell_json, get_hidden_subprocess_kwargs
from utils.formatters import clean_string

logger = logging.getLogger(__name__)



def _parse_ipconfig_all() -> List[Dict[str, Any]]:
    """
    Parses `ipconfig /all` output natively.
    Runs in ~20ms compared to 2,500ms PowerShell Get-NetAdapter.
    """
    adapters: List[Dict[str, Any]] = []
    try:
        proc = subprocess.run(
            ["ipconfig", "/all"],
            capture_output=True,
            text=True,
            timeout=4,
            **get_hidden_subprocess_kwargs()
        )
        out = proc.stdout or ""
        if not out.strip():
            return []

        cur_adapter: Dict[str, Any] = {}

        for raw_line in out.splitlines():
            line = raw_line.rstrip()
            if not line:
                continue

            # Section header matching e.g. "Ethernet adapter Ethernet:" or "Wireless LAN adapter Wi-Fi:"
            m_header = re.match(r'^(?:[A-Za-z0-9\s()._-]+ adapter)\s+(.+):$', line)
            if m_header:
                if cur_adapter and cur_adapter.get("name"):
                    adapters.append(cur_adapter)
                cur_adapter = {
                    "name": clean_string(m_header.group(1).strip()),
                    "description": "Not available",
                    "mac_address": "Not available",
                    "ipv4_address": "Not available",
                    "status": "Disconnected",
                    "link_speed": "Not available",
                    "is_connected": False,
                }
                continue

            if not cur_adapter:
                continue

            line_clean = line.strip()
            if ":" not in line_clean:
                continue

            key, val = [p.strip() for p in line_clean.split(":", 1)]
            key_lower = key.lower()

            if "description" in key_lower:
                cur_adapter["description"] = clean_string(val)
                # Infer link speed from description if available
                desc_lower = val.lower()
                if "gigabit" in desc_lower or "gbe" in desc_lower or "1000m" in desc_lower:
                    cur_adapter["link_speed"] = "1 Gbps"
                elif "2.5g" in desc_lower or "2500m" in desc_lower:
                    cur_adapter["link_speed"] = "2.5 Gbps"
                elif "10g" in desc_lower:
                    cur_adapter["link_speed"] = "10 Gbps"
                elif "fast ethernet" in desc_lower or "100m" in desc_lower:
                    cur_adapter["link_speed"] = "100 Mbps"
                elif "802.11ax" in desc_lower or "wi-fi 6" in desc_lower:
                    cur_adapter["link_speed"] = "Wi-Fi 6"
                elif "802.11ac" in desc_lower or "wi-fi 5" in desc_lower:
                    cur_adapter["link_speed"] = "Wi-Fi 5"
                elif "802.11n" in desc_lower or "wi-fi 4" in desc_lower:
                    cur_adapter["link_speed"] = "Wi-Fi 4"
            elif "physical address" in key_lower:
                cur_adapter["mac_address"] = clean_string(val)
            elif "media state" in key_lower and "disconnected" in val.lower():
                cur_adapter["status"] = "Disconnected"
                cur_adapter["is_connected"] = False
            elif "ipv4 address" in key_lower:
                # Strip (Preferred) or (Tentative) annotations
                ip = re.sub(r'\(.*?\)', '', val).strip()
                if ip:
                    cur_adapter["ipv4_address"] = ip
                    if not ip.startswith("169.254"):
                        cur_adapter["status"] = "Up"
                        cur_adapter["is_connected"] = True

        if cur_adapter and cur_adapter.get("name"):
            adapters.append(cur_adapter)

    except Exception as e:
        logger.debug(f"ipconfig /all parser error: {e}")

    return adapters


def _get_network_info_powershell() -> List[Dict[str, Any]]:
    """PowerShell fallback method using Get-NetAdapter."""
    adapters_result: List[Dict[str, Any]] = []
    try:
        script = """
        $adapters = Get-NetAdapter | Select-Object Name, InterfaceDescription, MacAddress, Status, LinkSpeed, ifIndex
        $ips = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Select-Object InterfaceIndex, IPAddress
        $res = @()
        foreach ($a in $adapters) {
            $matched = @($ips | Where-Object { $_.InterfaceIndex -eq $a.ifIndex } | ForEach-Object { $_.IPAddress })
            $res += [PSCustomObject]@{
                Name = $a.Name
                Description = $a.InterfaceDescription
                MacAddress = $a.MacAddress
                Status = $a.Status
                LinkSpeed = $a.LinkSpeed
                IPv4 = ($matched -join ', ')
            }
        }
        $res | ConvertTo-Json
        """
        data = run_powershell_json(script, timeout=6)
        
        if isinstance(data, dict):
            raw_adapters = [data]
        elif isinstance(data, list):
            raw_adapters = data
        else:
            raw_adapters = []

        for raw in raw_adapters:
            if not isinstance(raw, dict):
                continue
                
            name = clean_string(raw.get("Name"))
            desc = clean_string(raw.get("Description"))
            mac = clean_string(raw.get("MacAddress"))
            status = clean_string(raw.get("Status"), default="Disconnected")
            link_speed = clean_string(raw.get("LinkSpeed"))
            ipv4 = clean_string(raw.get("IPv4"))
            
            is_up = status.lower() in ("up", "connected", "active") or (ipv4 != "Not available" and not ipv4.startswith("169.254"))

            adapters_result.append({
                "name": name,
                "description": desc,
                "mac_address": mac,
                "ipv4_address": ipv4,
                "status": status,
                "link_speed": link_speed,
                "is_connected": is_up
            })
    except Exception as e:
        logger.error(f"Error querying network adapters via PowerShell: {e}")

    return adapters_result


def get_network_info() -> List[Dict[str, Any]]:
    """
    Detects all installed network adapters, their connection status, MAC, and IPv4 addresses.
    Uses ultra-fast native ipconfig parsing first (~20ms), with PowerShell as fallback.
    """
    # 1. Ultra-fast native ipconfig /all
    adapters_result = _parse_ipconfig_all()

    # 2. Fallback to PowerShell if ipconfig returned no adapters
    if not adapters_result:
        adapters_result = _get_network_info_powershell()

    # 3. Last-resort fallback to standard socket query
    if not adapters_result:
        try:
            hostname = socket.gethostname()
            local_ip = socket.gethostbyname(hostname)
        except Exception:
            local_ip = "Not available"

        adapters_result.append({
            "name": "Ethernet / Wi-Fi",
            "description": "Default Network Adapter",
            "mac_address": "Not available",
            "ipv4_address": local_ip,
            "status": "Up" if local_ip != "Not available" else "Disconnected",
            "link_speed": "Not available",
            "is_connected": local_ip != "Not available"
        })

    # Sort adapters so connected / Up adapters appear first
    adapters_result.sort(key=lambda x: (not x["is_connected"], x["name"]))

    return adapters_result

