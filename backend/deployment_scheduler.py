"""Bounded deployment lanes with conservative, cross-queue resource exclusion.

2X is a maximum, never a promise that arbitrary OEM installers can overlap.
Only locally reviewed, hash-pinned profiles may opt into parallel execution.
Unknown packages, orchestrator stages and core driver changes are exclusive.
"""
from concurrent.futures import ThreadPoolExecutor
from contextlib import contextmanager
import hashlib
import json
from pathlib import Path
import threading
import sys


POLICY_FILE = ((Path(sys.executable).resolve().parent.parent if getattr(sys, "frozen", False)
                else Path(__file__).resolve().parent.parent) / "config" / "parallel_installers.json")
_condition = threading.Condition()
_active = []


def approved_resources(item, *, driver=False, root=None):
    if item.get("orchestrator_action"):
        return None
    if driver and (item.get("category") in {"gpu", "chipset", "storage", "system_mei"}
                   or item.get("install_method") in {"msiexec", "pnputil", "inf_pnputil", "script"}):
        return None
    path = (item.get("installer_path") or item.get("installer_file") or
            item.get("relative_path") or item.get("filename"))
    if not path:
        return None
    path = Path(path)
    if not path.is_absolute() and root:
        path = Path(root) / path
    if path.suffix.lower() != ".exe":
        return None
    try:
        profiles = json.loads(POLICY_FILE.read_text(encoding="utf-8"))
        if not profiles:
            return None
        digest = hashlib.sha256()
        with path.open("rb") as stream:
            for chunk in iter(lambda: stream.read(1024 * 1024), b""):
                digest.update(chunk)
        profile = profiles.get(digest.hexdigest(), {})
        resources = profile.get("resources")
        if (profile.get("kind") != ("driver" if driver else "software") or
                profile.get("reviewed") is not True or not isinstance(resources, list) or
                not resources or not all(isinstance(x, str) and x.strip() for x in resources)):
            return None
        return frozenset(resources)
    except (OSError, ValueError, TypeError, AttributeError):
        return None


@contextmanager
def deployment_slot(resources):
    """An exclusive job blocks both software and driver lanes in this backend."""
    token = object()
    with _condition:
        _condition.wait_for(lambda: not _active or (
            resources is not None and len(_active) < 2 and
            all(existing is not None and not (existing & resources)
                for _, existing in _active)))
        _active.append((token, resources))
    try:
        yield
    finally:
        with _condition:
            _active[:] = [(key, value) for key, value in _active if key is not token]
            _condition.notify_all()


def run_deployment(items, run_one, *, double_speed=False, resources_for=lambda item: None):
    """Preserve barriers/order; join both jobs before the next pair or stage."""
    def execute(index, item, resources):
        with deployment_slot(resources):
            run_one(index, item)

    index = 0
    with ThreadPoolExecutor(max_workers=2, thread_name_prefix="Deployment") as pool:
        while index < len(items):
            resource = resources_for(items[index]) if double_speed else None
            next_resource = (resources_for(items[index + 1])
                             if double_speed and resource and index + 1 < len(items) else None)
            if resource and next_resource and not (resource & next_resource):
                futures = [pool.submit(execute, i, items[i], r) for i, r in
                           ((index, resource), (index + 1, next_resource))]
                # Executor's context waits even if one job raises: never unlock
                # queue controls while the second installer is still running.
                for future in futures:
                    future.result()
                index += 2
            else:
                execute(index, items[index], resource)
                index += 1
