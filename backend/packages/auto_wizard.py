# backend/packages/auto_wizard.py
"""
Intelligent Automated Installer Wizard Clicker (Win32 API via ctypes).
Automatically navigates installer GUI steps:
- Clicks "OK" on Language selection dialogs
- Clicks "Next >" / "Continue"
- Accepts License Agreements ("I Agree", "I accept the agreement" radio/checkbox)
- Clicks "Install"
- Selects "Restart later" on reboot prompts
- Clicks "Finish" / "Close" when done
"""

import os
import sys
import time
import ctypes
import logging
import threading
from ctypes import wintypes
from typing import List, Set, Dict, Optional, Tuple

logger = logging.getLogger(__name__)

user32 = ctypes.windll.user32
kernel32 = ctypes.windll.kernel32

# HWND/WPARAM/LPARAM are pointer-sized on 64-bit Windows.
user32.SendMessageW.argtypes = [wintypes.HWND, wintypes.UINT, wintypes.WPARAM, wintypes.LPARAM]
user32.SendMessageW.restype = ctypes.c_ssize_t
user32.IsWindowVisible.argtypes = [wintypes.HWND]
user32.IsWindowEnabled.argtypes = [wintypes.HWND]
user32.GetWindowTextLengthW.argtypes = [wintypes.HWND]
user32.GetWindowTextW.argtypes = [wintypes.HWND, wintypes.LPWSTR, ctypes.c_int]
user32.GetClassNameW.argtypes = [wintypes.HWND, wintypes.LPWSTR, ctypes.c_int]
user32.GetWindowThreadProcessId.argtypes = [wintypes.HWND, ctypes.POINTER(wintypes.DWORD)]
user32.GetWindowLongPtrW.argtypes = [wintypes.HWND, ctypes.c_int]
user32.GetWindowLongPtrW.restype = ctypes.c_ssize_t

# Win32 Constants
BM_CLICK = 0x00F5
BM_GETCHECK = 0x00F0
BM_SETCHECK = 0x00F1
BST_UNCHECKED = 0x0000
BST_CHECKED = 0x0001
BST_INDETERMINATE = 0x0002

WM_COMMAND = 0x0111
WM_CLOSE = 0x0010
BN_CLICKED = 0
GWL_STYLE = -16
BS_TYPEMASK = 0x0000000F
_CHECKABLE_BUTTON_TYPES = {2, 3, 4, 5, 6, 9}
CB_GETCOUNT = 0x0146
CB_SETCURSEL = 0x014E

# Target Button Labels (Priority order: Finish/Close/Done > Install > I Agree > Next > OK)
_AFFIRMATIVE_BUTTONS = [
    "finish",
    "پایان",
    "close",
    "بستن",
    "done",
    "begin installation",
    "begin install",
    "begin",
    "start installation",
    "start install",
    "start",
    "express install",
    "install",
    "نصب",
    "شروع نصب",
    "نصب را شروع کنید",
    "i agree",
    "agree",
    "موافقم",
    "i accept",
    "accept",
    "next >",
    "next",
    "بعدی >",
    "بعدی",
    "continue",
    "ادامه",
    "ok",
    "تایید",
]

_NEVER_CLICK_BUTTONS = [
    "cancel",
    "لغو",
    "انصراف",
    "no",
    "خیر",
    "decline",
    "back",
    "< back",
    "قبلی",
    "< قبلی",
    "do not accept",
    "don't accept",
]

_ACCEPT_CHECKBOX_KEYWORDS = [
    "i accept",
    "i agree",
    "accept the agreement",
    "accept the terms",
    "accept the license",
    "read and accept the license terms",
    "agree to the terms",
    "read and agree",
    "have read and agree",
    "terms of the license agreement",
    "accept all terms",
    "yes, i agree",
    "license agreement and privacy policy",
    "eula",
    "موافقم",
    "قوانین را می‌پذیرم",
    "پذیرش قوانین",
]

_LICENSE_PAGE_KEYWORDS = [
    "license agreement",
    "software license terms",
    "licence agreement",
    "end user license",
    "terms and conditions",
    "terms of use",
    "eula",
    "توافقنامه مجوز",
    "شرایط استفاده",
    "قوانین و مقررات",
]

_REBOOT_LATER_KEYWORDS = [
    "restart later",
    "reboot later",
    "i will restart",
    "restart the computer later",
    "no, i will restart",
    "بعدا ری استارت",
    "بعداً راه‌اندازی",
    "بعداً",
]

_REBOOT_NOW_KEYWORDS = [
    "restart now",
    "reboot now",
    "اکنون ری‌استارت",
    "راه‌اندازی مجدد",
]


def _get_window_text(hwnd: int) -> str:
    length = user32.GetWindowTextLengthW(hwnd)
    if length > 0:
        buff = ctypes.create_unicode_buffer(length + 1)
        user32.GetWindowTextW(hwnd, buff, length + 1)
        return buff.value.strip()
    return ""


def _get_class_name(hwnd: int) -> str:
    buff = ctypes.create_unicode_buffer(256)
    user32.GetClassNameW(hwnd, buff, 256)
    return buff.value.strip()


def _get_process_id_for_window(hwnd: int) -> int:
    pid = wintypes.DWORD()
    user32.GetWindowThreadProcessId(hwnd, ctypes.byref(pid))
    return pid.value


def _process_parents() -> Dict[int, int]:
    """Take a read-only process snapshot, including detached installer children."""
    class Entry(ctypes.Structure):
        _fields_ = [("size", wintypes.DWORD), ("usage", wintypes.DWORD),
                    ("pid", wintypes.DWORD), ("heap", ctypes.c_size_t),
                    ("module", wintypes.DWORD), ("threads", wintypes.DWORD),
                    ("parent", wintypes.DWORD), ("priority", wintypes.LONG),
                    ("flags", wintypes.DWORD), ("exe", wintypes.WCHAR * 260)]
    kernel32.CreateToolhelp32Snapshot.argtypes = [wintypes.DWORD, wintypes.DWORD]
    kernel32.CreateToolhelp32Snapshot.restype = wintypes.HANDLE
    kernel32.Process32FirstW.argtypes = [wintypes.HANDLE, wintypes.LPVOID]
    kernel32.Process32NextW.argtypes = [wintypes.HANDLE, wintypes.LPVOID]
    kernel32.CloseHandle.argtypes = [wintypes.HANDLE]
    handle = kernel32.CreateToolhelp32Snapshot(2, 0)
    if handle in (None, ctypes.c_void_p(-1).value):
        return {}
    parents = {}
    try:
        entry = Entry()
        entry.size = ctypes.sizeof(entry)
        ok = kernel32.Process32FirstW(handle, ctypes.byref(entry))
        while ok:
            parents[entry.pid] = entry.parent
            ok = kernel32.Process32NextW(handle, ctypes.byref(entry))
        return parents
    finally:
        kernel32.CloseHandle(handle)


def _is_installer_process(pid: int) -> bool:
    """Do not wait forever for a player/browser launched by the finished wizard."""
    kernel32.OpenProcess.argtypes = [wintypes.DWORD, wintypes.BOOL, wintypes.DWORD]
    kernel32.OpenProcess.restype = wintypes.HANDLE
    kernel32.QueryFullProcessImageNameW.argtypes = [wintypes.HANDLE, wintypes.DWORD,
                                                  wintypes.LPWSTR, ctypes.POINTER(wintypes.DWORD)]
    handle = kernel32.OpenProcess(0x1000, False, pid)
    if not handle:
        return True
    try:
        path = ctypes.create_unicode_buffer(32768)
        size = wintypes.DWORD(len(path))
        if not kernel32.QueryFullProcessImageNameW(handle, 0, path, ctypes.byref(size)):
            return True
        name = os.path.basename(path.value).lower()
        if any(word in name for word in ('setup', 'install', 'redist', 'msiexec', 'dpinst')):
            return True
        normalized = os.path.normcase(path.value)
        for variable in ('ProgramFiles', 'ProgramFiles(x86)'):
            root = os.environ.get(variable)
            if root and normalized.startswith(os.path.normcase(root) + os.sep):
                return False
        return True
    finally:
        kernel32.CloseHandle(handle)


class InstallerAutoPilot:
    """
    Monitors and automatically navigates installer windows for a given target process or window title.
    """

    def __init__(self, target_pids: Optional[Set[int]] = None, target_title_keywords: Optional[List[str]] = None, timeout_seconds: int = 180):
        self.target_pids = set(target_pids) if target_pids else set()
        self.target_title_keywords = [k.lower() for k in (target_title_keywords or []) if k]
        self.timeout_seconds = timeout_seconds
        self._stop_event = threading.Event()
        self._action_count = 0
        self._last_clicked_time: Dict[int, float] = {}

    def add_pid(self, pid: int):
        if pid > 0:
            self.target_pids.add(pid)

    def stop(self):
        self._stop_event.set()

    def _refresh_child_pids(self):
        parents = _process_parents()
        known = set(self.target_pids)
        while True:
            children = {pid for pid, parent in parents.items() if parent in known}
            expanded = known | children
            if expanded == known:
                break
            known = expanded
        self.target_pids.update(known)

    def wait_for_children(self, timeout_seconds: float) -> bool:
        deadline = time.monotonic() + max(0, timeout_seconds)
        while not self._stop_event.is_set():
            self._refresh_child_pids()
            live = _process_parents()
            if not any(_is_installer_process(pid) for pid in self.target_pids.intersection(live)):
                return True
            if time.monotonic() >= deadline:
                return False
            self._stop_event.wait(0.4)
        return False

    def run_in_background(self) -> threading.Thread:
        thread = threading.Thread(target=self._run_loop, daemon=True, name="InstallerAutoPilot")
        thread.start()
        return thread

    def _is_relevant_window(self, hwnd: int) -> bool:
        if not user32.IsWindowVisible(hwnd):
            return False

        w_pid = _get_process_id_for_window(hwnd)
        if self.target_pids and w_pid in self.target_pids:
            return True

        # Never interact with another installer's or application's window.
        # A title is not ownership evidence.
        return False

    def _get_child_windows(self, parent_hwnd: int) -> List[Tuple[int, str, str]]:
        children: List[Tuple[int, str, str]] = []

        def enum_child(hwnd, _):
            if user32.IsWindowVisible(hwnd):
                text = _get_window_text(hwnd)
                cls = _get_class_name(hwnd)
                children.append((hwnd, text, cls))
            return True

        WNDENUMPROC = ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)
        user32.EnumChildWindows(parent_hwnd, WNDENUMPROC(enum_child), 0)
        return children

    def _click_button(self, hwnd: int, text: str) -> bool:
        now = time.time()
        last = self._last_clicked_time.get(hwnd, 0)
        # Avoid clicking the exact same control faster than once every 800ms
        if now - last < 0.8:
            return False

        if not user32.IsWindowEnabled(hwnd):
            return False

        logger.info(f"[AutoPilot] Clicking button HWND {hwnd}: '{text}'")
        user32.SendMessageW(hwnd, BM_CLICK, 0, 0)
        self._last_clicked_time[hwnd] = now
        self._action_count += 1
        return True

    def _check_control(self, hwnd: int, check: bool = True) -> bool:
        current = user32.SendMessageW(hwnd, BM_GETCHECK, 0, 0)
        target = BST_CHECKED if check else BST_UNCHECKED
        if current != target:
            user32.SendMessageW(hwnd, BM_CLICK, 0, 0)
            return user32.SendMessageW(hwnd, BM_GETCHECK, 0, 0) == target
        return False

    @staticmethod
    def _is_checkable_control(hwnd: int, class_name: str) -> bool:
        cls = class_name.lower()
        if any(token in cls for token in ("checkbox", "radiobutton", "newradiobutton", "newcheckbox")):
            return True
        if "button" not in cls:
            return False
        try:
            style = int(user32.GetWindowLongPtrW(hwnd, GWL_STYLE))
            return (style & BS_TYPEMASK) in _CHECKABLE_BUTTON_TYPES
        except Exception:
            return False

    def process_window(self, hwnd: int) -> bool:
        children = self._get_child_windows(hwnd)
        if not children:
            return False

        texts = " ".join(text.lower().replace("&", "") for _, text, _ in children)
        license_page = any(keyword in texts for keyword in _LICENSE_PAGE_KEYWORDS)
        reboot_dialog = any(word in texts for word in (
            "restart", "reboot", "ری‌استارت", "ری استارت",
            "راه‌اندازی مجدد", "راه اندازی مجدد"))
        reboot_later_selected = False
        if reboot_dialog:
            later_controls = [
                (control, text, cls) for control, text, cls in children
                if any(word in text.lower() for word in _REBOOT_LATER_KEYWORDS)
                and user32.IsWindowEnabled(control)
            ]
            # Never press Finish/OK on a reboot dialog until an explicit
            # "restart later" choice exists and has been selected.
            if not later_controls:
                return False
            for control, text, cls in later_controls:
                if user32.SendMessageW(control, BM_GETCHECK, 0, 0) == BST_CHECKED:
                    reboot_later_selected = True
                    break
                if self._click_button(control, text):
                    logger.info(f"[AutoPilot] Selected Reboot Later: '{text}'")
                    return True

        handled = False

        # 1. First pass: Handle Checkboxes and Radio Buttons (License agreement, Reboot options)
        for c_hwnd, c_text, c_cls in children:
            c_text_lower = c_text.lower().replace("&", "").strip()
            if not user32.IsWindowEnabled(c_hwnd):
                continue

            # Accept license agreements
            if any(k in c_text_lower for k in _ACCEPT_CHECKBOX_KEYWORDS):
                if not any(k in c_text_lower for k in ["do not", "don't", "عدم"]):
                    if self._check_control(c_hwnd, True):
                        logger.info(f"[AutoPilot] Checked agreement: '{c_text}'")
                        handled = True

            # Reboot later option outside a recognized reboot page
            if not reboot_dialog and any(k in c_text_lower for k in _REBOOT_LATER_KEYWORDS):
                if self._check_control(c_hwnd, True):
                    logger.info(f"[AutoPilot] Selected Reboot Later: '{c_text}'")
                    handled = True

        # Some OEM wrappers expose the agreement text as a separate Static
        # control and leave the actual checkbox/radio label empty. Select it
        # only when the whole page is clearly a license page and there is a
        # single unambiguous enabled checkable control.
        if license_page and not handled:
            unlabeled_checkables = [
                (control, text, cls)
                for control, text, cls in children
                if user32.IsWindowEnabled(control)
                and self._is_checkable_control(control, cls)
                and not any(neg in text.lower() for neg in _NEVER_CLICK_BUTTONS)
            ]
            positive = [
                item for item in unlabeled_checkables
                if any(k in item[1].lower() for k in _ACCEPT_CHECKBOX_KEYWORDS)
            ]
            candidates = positive or ([unlabeled_checkables[0]] if len(unlabeled_checkables) == 1 else [])
            if candidates and self._check_control(candidates[0][0], True):
                logger.info("[AutoPilot] Checked agreement control on detected license page")
                handled = True

        # 2. Second pass: Find and click the best affirmative button
        # Button candidates in priority order: Finish/Close/Done > Install > I Agree > Next > OK
        clickable_buttons: List[Tuple[int, str, int]] = []

        for c_hwnd, c_text, c_cls in children:
            if not user32.IsWindowEnabled(c_hwnd):
                continue
            if "button" not in c_cls.lower():
                continue

            # Radio buttons and checkboxes must never enter the push-button
            # pass: clicking an already accepted checkbox here toggled it off
            # in some Lenovo/ASUS installers before Next was pressed.
            if self._is_checkable_control(c_hwnd, c_cls):
                continue

            c_text_lower = c_text.lower().replace("&", "").strip()
            if not c_text_lower:
                continue
            if any(k in c_text_lower for k in _REBOOT_NOW_KEYWORDS):
                continue
            if reboot_dialog and any(k in c_text_lower for k in _REBOOT_LATER_KEYWORDS):
                continue

            # Never click cancel / back
            if any(c_text_lower == neg or neg in c_text_lower for neg in _NEVER_CLICK_BUTTONS):
                continue

            # Check priority match
            for priority, aff in enumerate(_AFFIRMATIVE_BUTTONS):
                if c_text_lower == aff or c_text_lower.startswith(aff) or aff in c_text_lower:
                    clickable_buttons.append((c_hwnd, c_text, priority))
                    break

        if clickable_buttons:
            # Sort by priority (lowest index in _AFFIRMATIVE_BUTTONS is highest priority)
            clickable_buttons.sort(key=lambda x: x[2])
            best_btn, btn_text, _ = clickable_buttons[0]
            if self._click_button(best_btn, btn_text):
                handled = True

        return handled

    def _run_loop(self):
        start_time = time.time()
        logger.info(f"[AutoPilot] Started installer auto-pilot for PIDs {self.target_pids} and keywords {self.target_title_keywords}")

        while not self._stop_event.is_set():
            if time.time() - start_time > self.timeout_seconds:
                logger.info("[AutoPilot] Timeout reached, stopping auto-pilot.")
                break

            # Find all matching top-level windows
            self._refresh_child_pids()
            matching_windows = []

            def enum_proc(hwnd, _):
                if self._is_relevant_window(hwnd):
                    matching_windows.append(hwnd)
                return True

            WNDENUMPROC = ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)
            user32.EnumWindows(WNDENUMPROC(enum_proc), 0)

            for hwnd in matching_windows:
                try:
                    self.process_window(hwnd)
                except Exception as e:
                    logger.debug(f"[AutoPilot] Error processing window {hwnd}: {e}")

            time.sleep(0.4)

        logger.info(f"[AutoPilot] Finished with {self._action_count} actions taken.")
