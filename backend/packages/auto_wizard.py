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
    "agree to the terms",
    "موافقم",
    "قوانین را می‌پذیرم",
    "پذیرش قوانین",
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

        title = _get_window_text(hwnd).lower()
        if not title:
            return False

        # If title matches software keyword
        if any(k in title for k in self.target_title_keywords):
            return True

        # Generic installer windows
        generic_installer_titles = [
            "setup", "installer", "installation", "wizard", "language", "نصب",
            "select setup language", "installer language", "intel", "graphics", "driver"
        ]
        if any(g in title for g in generic_installer_titles):
            return True

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
            user32.SendMessageW(hwnd, BM_SETCHECK, target, 0)
            user32.SendMessageW(hwnd, BM_CLICK, 0, 0)
            return True
        return False

    def process_window(self, hwnd: int) -> bool:
        children = self._get_child_windows(hwnd)
        if not children:
            return False

        handled = False

        # 1. First pass: Handle Checkboxes and Radio Buttons (License agreement, Reboot options)
        for c_hwnd, c_text, c_cls in children:
            c_text_lower = c_text.lower()
            if not user32.IsWindowEnabled(c_hwnd):
                continue

            # Accept license agreements
            if any(k in c_text_lower for k in _ACCEPT_CHECKBOX_KEYWORDS):
                if not any(k in c_text_lower for k in ["do not", "don't", "عدم"]):
                    if self._check_control(c_hwnd, True):
                        logger.info(f"[AutoPilot] Checked agreement: '{c_text}'")
                        handled = True

            # Reboot later option
            if any(k in c_text_lower for k in _REBOOT_LATER_KEYWORDS):
                if self._check_control(c_hwnd, True):
                    logger.info(f"[AutoPilot] Selected Reboot Later: '{c_text}'")
                    handled = True

            # Uncheck Reboot now option if present
            if any(k in c_text_lower for k in _REBOOT_NOW_KEYWORDS):
                if not any(k in c_text_lower for k in _REBOOT_LATER_KEYWORDS):
                    self._check_control(c_hwnd, False)

        # 2. Second pass: Find and click the best affirmative button
        # Button candidates in priority order: Finish/Close/Done > Install > I Agree > Next > OK
        clickable_buttons: List[Tuple[int, str, int]] = []

        for c_hwnd, c_text, c_cls in children:
            if not user32.IsWindowEnabled(c_hwnd):
                continue
            if "button" not in c_cls.lower():
                continue

            c_text_lower = c_text.lower().replace("&", "").strip()
            if not c_text_lower:
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
