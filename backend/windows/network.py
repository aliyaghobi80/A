import logging
import socket
from typing import List, Dict, Any

from utils.powershell import run_powershell_json
from utils.formatters import clean_string

logger = logging.getLogger(__name__)

def get_network_info() -> List[Dict[str, Any]]:
    """
    Detects all installed network adapters, their connection status, MAC, and IPv4 addresses.
    Returns a list of adapter objects:
        name: str
        description: str
        mac_address: str
        ipv4_address: str
        status: str ('Up', 'Disconnected', 'Disabled')
        link_speed: str
        is_connected: bool
    """
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
        data = run_powershell_json(script)
        
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
        logger.error(f"Error querying network adapters: {e}")

    # Fallback if no adapter found
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
