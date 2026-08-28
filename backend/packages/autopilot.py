# backend/packages/autopilot.py
"""
Autonomous GUI Installer Auto-Pilot for Windows.
Automatically interacts with installer wizard dialogs (Inno Setup, NSIS, InstallShield,
MSI, custom dialogs, SFX extractors) by finding and clicking 'Next', 'I Agree', 'Install',
'Finish', 'OK', 'Close', and selecting 'Restart later' radio buttons.
Runs in a background thread during package and driver installations to ensure 100%
autonomous, hands-free execution ("کاملا خودران").
"""

import ctypes
import ctypes.wintypes
import logging
import threading
import time
from typing import List, Optional, Set

logger = logging.getLogger("markazi_autopilot")

# Win32 Constants
user32 = ctypes.windll.user32
kernel32 = ctypes.windll.kernel32

WNDENUMPROC = ctypes.WINFUNCTYPE(ctypes.c_bool, ctypes.wintypes.HWND, ctypes.wintypes.LPARAM)

BM_CLICK = 0x00F5
BM_GETCHECK = 0x00F0
BM_SETCHECK = 0x00F1
BST_CHECKED = 1
BST_UNCHECKED = 0

WM_COMMAND = 0x0111
WM_GETTEXT = 0x000D
WM_GETTEXTLENGTH = 0x000E
WM_LBUTTONDOWN = 0x0201
WM_LBUTTONUP = 0x0202
WM_KEYDOWN = 0x0100
WM_KEYUP = 0x0101
VK_RETURN = 0x0D
VK_SPACE = 0x20

GWL_STYLE = -16
BS_RADIOBUTTON = 0x00000004
BS_AUTORADIOBUTTON = 0x00000009
BS_CHECKBOX = 0x00000002
BS_AUTOCHECKBOX = 0x00000003

# Keywords to match next/proceed buttons
_PROCEED_BUTTON_KEYWORDS = [
    "next", "next >", "> next", "next > >",
    "بعدی", "> بعدی", "بعدي", "مرحله بعد",
    "install", "نصب", "شروع نصب",
    "i agree", "agree", "موافقم", "accept", "پذیرش",
    "continue", "ادامه",
    "finish", "پایان", "خروج", "بستن", "close", "done",
    "ok", "تایید", "تأیید", "قبول",
    "yes", "بلی", "بله",
    "extract", "استخراج",
]

# Keywords to reject / avoid clicking
_NEGATIVE_BUTTON_KEYWORDS = [
    "cancel", "انصراف", "لغو", "خروج از نصب",
    "back", "بازگشت", "< back", "< قبلی",
    "abort", "ignore", "retry",
    "uninstall", "remove",
]

# Keywords for 'Restart later' options
_RESTART_LATER_KEYWORDS = [
    "restart later", "restart computer later", "manually restart", "restart manually",
    "no, i will restart", "no, i will restart the computer later", "i will restart later",
    "بعدا ریستارت", "بعداً ری‌استارت", "بعدا ری‌استارت", "بعداً راه‌اندازی مجدد",
    "بعدا سیستم را ریستارت", "بعداً سیستم را ری‌استارت",
]

# Keywords for 'Launch / Run app now' checkboxes to uncheck
_UNCHECK_LAUNCH_KEYWORDS = [
    "launch", "run", "open", "start",
    "اجرا", "باز کردن", "اجرای برنامه",
]

# Keywords for 'I accept terms' radio buttons to check
_ACCEPT_TERMS_KEYWORDS = [
    "i accept", "i agree", "accept the agreement", "accept the terms",
    "موافقم", "قوانین را می پذیرم", "پذیرش توافقنامه",
]


def _get_window_text(hwnd: int) -> str:
    """Safely retrieves window or control text."""
    try:
        length = user32.SendMessageW(hwnd, WM_GETTEXTLENGTH, 0, 0)
        if length > 0:
            buffer = ctypes.create_unicode_buffer(length + 1)
            user32.SendMessageW(hwnd, WM_GETTEXT, length + 1, buffer)
            return buffer.value.strip()
    except Exception:
        pass
    return ""


def _get_class_name(hwnd: int) -> str:
    """Safely retrieves window class name."""
    try:
        buffer = ctypes.create_unicode_buffer(256)
        user32.GetClassNameW(hwnd, buffer, 256)
        return buffer.value.strip()
    except Exception:
        return ""


def _get_window_pid(hwnd: int) -> int:
    """Retrieves process ID for a given window handle."""
    pid = ctypes.wintypes.DWORD()
    user32.GetWindowThreadProcessId(hwnd, ctypes.byref(pid))
    return pid.value


class InstallerAutopilot:
    """
    Background worker that monitors GUI installer windows and automatically
    progresses through wizard pages.
    """

    def __init__(self, target_pid: Optional[int] = None, target_name: str = "", timeout: float = 300.0):
        self.target_pid = target_pid
        self.target_name = target_name.lower()
        self.timeout = timeout
        self.stop_event = threading.Event()
        self.thread: Optional[threading.Thread] = None
        self.clicked_history: Set[str] = set()
        self.last_click_time = 0.0

    def start(self):
        """Starts the autopilot watcher thread."""
        self.stop_event.clear()
        self.thread = threading.Thread(target=self._run_loop, daemon=True, name="InstallerAutopilot")
        self.thread.start()
        logger.info(f"[AutoPilot] Started watcher for PID={self.target_pid} name='{self.target_name}'")

    def stop(self):
        """Stops the autopilot watcher."""
        self.stop_event.set()
        if self.thread and self.thread.is_alive():
            self.thread.join(timeout=1.0)
        logger.info("[AutoPilot] Stopped watcher")

    def _run_loop(self):
        start_t = time.time()
        while not self.stop_event.is_set():
            if time.time() - start_t > self.timeout:
                logger.info("[AutoPilot] Timeout reached, stopping watcher")
                break

            try:
                self._inspect_and_act()
            except Exception as e:
                logger.debug(f"[AutoPilot] Error in loop: {e}")

            time.sleep(0.35)

    def _inspect_and_act(self):
        """Finds active installer windows and clicks appropriate buttons."""
        top_windows: List[int] = []

        def enum_win_proc(hwnd, _lparam):
            if user32.IsWindowVisible(hwnd):
                top_windows.append(hwnd)
            return True

        user32.EnumWindows(WNDENUMPROC(enum_win_proc), 0)

        for hwnd in top_windows:
            if self.stop_event.is_set():
                break

            win_title = _get_window_text(hwnd)
            win_class = _get_class_name(hwnd)
            win_pid = _get_window_pid(hwnd)

            # Check if this window belongs to our target process or matches installer keywords
            is_match = False
            if self.target_pid and win_pid == self.target_pid:
                is_match = True
            elif self.target_name and self.target_name in win_title.lower():
                is_match = True
            elif any(kw in win_title.lower() for kw in ["setup", "install", "wizard", "نصب", "inno setup", "nullsoft"]):
                is_match = True

            if not is_match or not win_title:
                continue

            # Inspect child controls inside this installer window
            self._handle_wizard_window(hwnd, win_title)

    def _handle_wizard_window(self, hwnd: int, win_title: str):
        child_controls: List[int] = []

        def enum_child_proc(h_child, _lparam):
            if user32.IsWindowVisible(h_child) and user32.IsWindowEnabled(h_child):
                child_controls.append(h_child)
            return True

        user32.EnumChildWindows(hwnd, WNDENUMPROC(enum_child_proc), 0)

        proceed_buttons: List[int] = []

        for h_ctrl in child_controls:
            c_class = _get_class_name(h_ctrl).lower()
            c_text = _get_window_text(h_ctrl).replace("&", "").strip().lower()

            if not c_text:
                continue

            # 1. Check if it is a Radio button or Checkbox
            if "button" in c_class:
                # Handle "I accept..." terms
                if any(kw in c_text for kw in _ACCEPT_TERMS_KEYWORDS):
                    try:
                        user32.SendMessageW(h_ctrl, BM_CLICK, 0, 0)
                        user32.SendMessageW(h_ctrl, BM_SETCHECK, BST_CHECKED, 0)
                        logger.info(f"[AutoPilot] Selected 'I Accept' on '{win_title}'")
                    except Exception:
                        pass

                # Handle "Restart Later"
                if any(kw in c_text for kw in _RESTART_LATER_KEYWORDS):
                    try:
                        user32.SendMessageW(h_ctrl, BM_CLICK, 0, 0)
                        user32.SendMessageW(h_ctrl, BM_SETCHECK, BST_CHECKED, 0)
                        logger.info(f"[AutoPilot] Selected 'Restart Later' on '{win_title}'")
                    except Exception:
                        pass

                # Handle "Launch / Run now" checkboxes -> uncheck
                if any(kw in c_text for kw in _UNCHECK_LAUNCH_KEYWORDS):
                    try:
                        user32.SendMessageW(h_ctrl, BM_SETCHECK, BST_UNCHECKED, 0)
                    except Exception:
                        pass

                # Check if it is a proceed button (Next, Install, Finish, etc.)
                if any(c_text == kw or c_text.startswith(kw) for kw in _PROCEED_BUTTON_KEYWORDS):
                    if not any(neg in c_text for neg in _NEGATIVE_BUTTON_KEYWORDS):
                        proceed_buttons.append(h_ctrl)

        # Click the best proceed button
        if proceed_buttons:
            # Throttle clicks to 1 per 600ms so wizards have time to change state
            now = time.time()
            if now - self.last_click_time < 0.6:
                return

            btn = proceed_buttons[0]
            btn_text = _get_window_text(btn).replace("&", "").strip()

            try:
                # Send standard Win32 button click
                user32.SendMessageW(btn, BM_CLICK, 0, 0)
                # Send mouse down/up as secondary guarantee
                user32.SendMessageW(btn, WM_LBUTTONDOWN, 1, 0)
                user32.SendMessageW(btn, WM_LBUTTONUP, 0, 0)

                self.last_click_time = now
                logger.info(f"[AutoPilot] ✓ Automatically clicked '{btn_text}' on '{win_title}'")
            except Exception as e:
                logger.debug(f"[AutoPilot] Click failed: {e}")
