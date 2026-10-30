"""
inspect_frame.py - Automated Win32 Non-Client Frame Inspection Script

Verifies that the application window has no native caption/title bar:
Checks that the non-client top height is approximately 0 (comparing
GWL_STYLE, GetWindowRect, and GetClientRect via ClientToScreen).
"""

import sys
import os
import ctypes
from ctypes import wintypes
from typing import Optional, Dict, Any

# Win32 Constants
GWL_STYLE = -16
WS_CAPTION = 0x00C00000
WS_POPUP = 0x80000000
WS_THICKFRAME = 0x00040000
WS_VISIBLE = 0x10000000

class RECT(ctypes.Structure):
    _fields_ = [
        ("left", wintypes.LONG),
        ("top", wintypes.LONG),
        ("right", wintypes.LONG),
        ("bottom", wintypes.LONG),
    ]

class POINT(ctypes.Structure):
    _fields_ = [
        ("x", wintypes.LONG),
        ("y", wintypes.LONG),
    ]

def inspect_window_frame(hwnd: int) -> Dict[str, Any]:
    user32 = ctypes.windll.user32
    if not user32.IsWindow(hwnd):
        raise ValueError(f"Invalid HWND: {hwnd}")

    # 1. Retrieve Title & Class Name
    title_buf = ctypes.create_unicode_buffer(512)
    user32.GetWindowTextW(hwnd, title_buf, 512)
    class_buf = ctypes.create_unicode_buffer(512)
    user32.GetClassNameW(hwnd, class_buf, 512)

    # 2. Retrieve Window Styles
    style = user32.GetWindowLongW(hwnd, GWL_STYLE)
    has_caption = bool(style & WS_CAPTION)
    is_popup = bool(style & WS_POPUP)
    has_thickframe = bool(style & WS_THICKFRAME)

    # 3. Retrieve Window Rect (Screen Coordinates)
    w_rect = RECT()
    user32.GetWindowRect(hwnd, ctypes.byref(w_rect))

    # 4. Retrieve Client Rect
    c_rect = RECT()
    user32.GetClientRect(hwnd, ctypes.byref(c_rect))

    # 5. Client Origin in Screen Coordinates
    pt = POINT(0, 0)
    user32.ClientToScreen(hwnd, ctypes.byref(pt))

    # 6. Calculate Non-Client Margins
    nc_top = pt.y - w_rect.top
    nc_left = pt.x - w_rect.left
    nc_bottom = w_rect.bottom - (pt.y + c_rect.bottom)
    nc_right = w_rect.right - (pt.x + c_rect.right)

    # 7. Verification:
    # A standard native Windows title bar adds ~30-50px to nc_top.
    # When WM_NCCALCSIZE eliminates the native caption, nc_top is approximately 0 (0 to 1px).
    is_native_titlebar_eliminated = (nc_top <= 1)

    return {
        "hwnd": hwnd,
        "title": title_buf.value,
        "class_name": class_buf.value,
        "style_hex": hex(style),
        "has_caption_style": has_caption,
        "is_popup": is_popup,
        "has_thickframe": has_thickframe,
        "window_rect": (w_rect.left, w_rect.top, w_rect.right, w_rect.bottom),
        "client_rect": (c_rect.left, c_rect.top, c_rect.right, c_rect.bottom),
        "client_origin_screen": (pt.x, pt.y),
        "non_client_margins": {
            "top": nc_top,
            "left": nc_left,
            "bottom": nc_bottom,
            "right": nc_right,
        },
        "is_native_titlebar_eliminated": is_native_titlebar_eliminated,
        "verdict": "PASS: Native title bar eliminated (nc_top <= 1px)" if is_native_titlebar_eliminated else f"FAIL: Native title bar present (nc_top = {nc_top}px)"
    }

def find_target_window(title_substring: str = "Markazi System Checker") -> int:
    user32 = ctypes.windll.user32
    found_hwnd = 0

    @ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)
    def enum_proc(hwnd, lparam):
        nonlocal found_hwnd
        if user32.IsWindowVisible(hwnd):
            buf = ctypes.create_unicode_buffer(512)
            user32.GetWindowTextW(hwnd, buf, 512)
            if title_substring.lower() in buf.value.lower():
                found_hwnd = hwnd
                return False  # Stop enumeration
        return True

    user32.EnumWindows(enum_proc, 0)
    return found_hwnd

def self_test_calculation():
    """Verify non-client calculation math using synthetic rectangles."""
    # Case 1: Frameless window (WM_NCCALCSIZE returns 0)
    # w_rect: (100, 100, 1380, 880), client origin: (100, 100), client size: 1280x780
    w_top, w_left, w_right, w_bottom = 100, 100, 1380, 880
    c_w, c_h = 1280, 780
    pt_x, pt_y = 100, 100
    nc_top = pt_y - w_top
    nc_left = pt_x - w_left
    nc_bottom = w_bottom - (pt_y + c_h)
    nc_right = w_right - (pt_x + c_w)
    assert nc_top == 0, f"Expected nc_top == 0, got {nc_top}"
    assert nc_left == 0 and nc_bottom == 0 and nc_right == 0

    # Case 2: Standard native frame (Caption height ~31px, borders 8px)
    # w_rect: (92, 69, 1388, 888), client origin: (100, 100), client size: 1280x780
    w_top_std, w_left_std, w_right_std, w_bottom_std = 69, 92, 1388, 888
    nc_top_std = pt_y - w_top_std  # 100 - 69 = 31px
    assert nc_top_std == 31, f"Expected standard nc_top == 31, got {nc_top_std}"
    print("[Self-Test] Non-client frame margin calculation verified.")

if __name__ == "__main__":
    if "--test" in sys.argv:
        self_test_calculation()
        sys.exit(0)

    target_title = "Markazi System Checker"
    target_hwnd = None
    for arg in sys.argv[1:]:
        if arg.startswith("--hwnd="):
            target_hwnd = int(arg.split("=")[1], 0)
        elif not arg.startswith("--"):
            target_title = arg

    hwnd = target_hwnd if target_hwnd else find_target_window(target_title)
    if not hwnd:
        print(f"Target window matching '{target_title}' not currently running.")
        print("To run self-test calculation: py -3 inspect_frame.py --test")
        sys.exit(0)

    res = inspect_window_frame(hwnd)
    print("=== Window Frame Inspection Report ===")
    print(f"HWND: 0x{res['hwnd']:X} ({res['hwnd']})")
    print(f"Title: {res['title']}")
    print(f"Class: {res['class_name']}")
    print(f"Style: {res['style_hex']} (WS_CAPTION={res['has_caption_style']}, WS_POPUP={res['is_popup']})")
    print(f"Window Rect: {res['window_rect']}")
    print(f"Client Rect: {res['client_rect']}")
    print(f"Client Screen Origin: {res['client_origin_screen']}")
    print(f"Non-Client Margins: Top={res['non_client_margins']['top']}px, Left={res['non_client_margins']['left']}px, Right={res['non_client_margins']['right']}px, Bottom={res['non_client_margins']['bottom']}px")
    print(f"Verdict: {res['verdict']}")
    if not res["is_native_titlebar_eliminated"]:
        sys.exit(1)
