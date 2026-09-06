# backend/drivers/deduplicator.py
"""
Driver Package Deduplication & Fingerprinting Engine.
Prevents duplicate installations by computing canonical package fingerprints:
- Canonical Path & Normalized Names
- Driver Category & Target Hardware IDs
- Driver Version comparison
- SHA-256 Hash of primary installer or INF
Filters redundant duplicates and retains the best / newest candidate.
"""

import hashlib
import os
import re
from typing import Dict, Any, List, Tuple
from .hardware_matcher import _compare_driver_versions

logger = logging = __import__("logging").getLogger(__name__)


def generate_package_fingerprint(pkg: Dict[str, Any]) -> str:
    """
    Computes a composite fingerprint representing the unique identity of a driver package:
    category + sorted top hardware IDs + driver version + provider.
    """
    category = str(pkg.get("category", "other")).lower()
    version = str(pkg.get("driver_version", "")).strip()
    provider = str(pkg.get("provider", "")).strip().lower()

    hw_ids = pkg.get("hardware_ids", [])
    if isinstance(hw_ids, list):
        sorted_hw = sorted(h.upper() for h in hw_ids if len(h) > 8)[:10]
    else:
        sorted_hw = []

    raw_seed = f"{category}|{provider}|{version}|{';'.join(sorted_hw)}"
    if not sorted_hw and not version:
        # Fallback to normalized relative path if metadata is sparse
        raw_seed = f"{category}|{pkg.get('relative_path', '')}"

    return hashlib.sha256(raw_seed.encode("utf-8")).hexdigest()[:20]


def deduplicate_driver_packages(packages: List[Dict[str, Any]]) -> Tuple[List[Dict[str, Any]], List[Dict[str, Any]]]:
    """
    Groups packages by their functional target identity (category + target hardware or normalized name).
    When duplicates are found, chooses the optimal candidate:
    1. Higher driver version
    2. Extracted folder over ZIP archive
    3. More complete Hardware IDs
    Returns: (unique_packages, filtered_duplicates)
    """
    groups: Dict[str, List[Dict[str, Any]]] = {}

    for p in packages:
        # Compute group key
        cat = p.get("category", "other")
        hw_ids = p.get("hardware_ids", [])
        if hw_ids and len(hw_ids) > 0:
            # Group by category + primary hardware vendor/device
            primary_hw = sorted(hw_ids)[0]
            # Strip minor subsystem suffix to group same device
            m = re.match(r"(PCI\\VEN_[0-9A-Fa-f]{4}&DEV_[0-9A-Fa-f]{4}|USB\\VID_[0-9A-Fa-f]{4}&PID_[0-9A-Fa-f]{4})", primary_hw)
            if m:
                grp_key = f"{cat}:{m.group(1).upper()}"
            else:
                grp_key = f"{cat}:{primary_hw[:20]}"
        else:
            # Group by normalized name
            norm_name = re.sub(r"[\W_]+", "", p.get("display_name", "")).lower()
            grp_key = f"{cat}:{norm_name}"

        if grp_key not in groups:
            groups[grp_key] = []
        groups[grp_key].append(p)

    unique_list = []
    duplicates_list = []

    for grp_key, pkg_list in groups.items():
        if len(pkg_list) == 1:
            pkg_list[0]["is_duplicate"] = False
            unique_list.append(pkg_list[0])
            continue

        # Sort candidates to find the best:
        # 1. Higher version
        # 2. Extracted folder > zip archive
        # 3. Valid auto install supported
        def _candidate_score(cand: Dict[str, Any]):
            v = cand.get("driver_version", "")
            is_folder = 1 if cand.get("package_type") == "folder" else 0
            hw_count = len(cand.get("hardware_ids", []))
            return (is_folder, hw_count)

        # Sort by version first
        best = pkg_list[0]
        for candidate in pkg_list[1:]:
            v_cmp = _compare_driver_versions(
                candidate.get("driver_version", ""),
                best.get("driver_version", "")
            )
            if v_cmp > 0:
                best = candidate
            elif v_cmp == 0:
                if _candidate_score(candidate) > _candidate_score(best):
                    best = candidate

        best["is_duplicate"] = False
        unique_list.append(best)

        for other in pkg_list:
            if other is not best:
                other["is_duplicate"] = True
                other["duplicate_of"] = best.get("package_id")
                duplicates_list.append(other)

    return unique_list, duplicates_list
