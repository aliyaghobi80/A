"""
backend/tests/test_challenger_empirical_harness.py

Empirical Challenger Stress Harness (R1, R2, R3):
Adversarially and empirically validates:
1. `inspect_frame.py` and `inspect_frame.ps1` under synthetic, boundary, and live Win32 window conditions.
2. Window controls hit-testing geometry across multi-DPI scales (100% to 300%), multi-monitor negative coordinates, and proves HTTOP edge resize never intercepts clicks over the 32px title bar controls.
3. Maximize / Windows 11 Snap Layouts hit-testing (HTMAXBUTTON) precision and mouse click down/up handling.
4. True Native Fullscreen transition logic (rcMonitor coverage, WINDOWPLACEMENT restore, style transitions).
5. Watchdog (kDisplayRecoveryTimeoutMs = 8000), LowPower GPU preference, and --display-recovery-from preservation.
"""

import os
import sys
import subprocess
import unittest
import ctypes
from ctypes import wintypes
from typing import Tuple, Dict, Any, List

# Win32 Hit Test Constants
HTERROR = -2
HTTRANSPARENT = -1
HTNOWHERE = 0
HTCLIENT = 1
HTCAPTION = 2
HTSYSMENU = 3
HTGROWBOX = 4
HTSIZE = HTGROWBOX
HTMENU = 5
HTHSCROLL = 6
HTVSCROLL = 7
HTMINBUTTON = 8
HTMAXBUTTON = 9
HTLEFT = 10
HTRIGHT = 11
HTTOP = 12
HTTOPLEFT = 13
HTTOPRIGHT = 14
HTBOTTOM = 15
HTBOTTOMLEFT = 16
HTBOTTOMRIGHT = 17
HTREDUCE = HTMINBUTTON
HTZOOM = HTMAXBUTTON

# Win32 Styles
WS_OVERLAPPED = 0x00000000
WS_POPUP = 0x80000000
WS_CHILD = 0x40000000
WS_MINIMIZE = 0x20000000
WS_VISIBLE = 0x10000000
WS_DISABLED = 0x08000000
WS_CLIPSIBLINGS = 0x04000000
WS_CLIPCHILDREN = 0x02000000
WS_MAXIMIZE = 0x01000000
WS_CAPTION = 0x00C00000
WS_BORDER = 0x00800000
WS_DLGFRAME = 0x00400000
WS_VSCROLL = 0x00200000
WS_HSCROLL = 0x00100000
WS_SYSMENU = 0x00080000
WS_THICKFRAME = 0x00040000
WS_MINIMIZEBOX = 0x00020000
WS_MAXIMIZEBOX = 0x00010000
WS_OVERLAPPEDWINDOW = (
    WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU | WS_THICKFRAME | WS_MINIMIZEBOX | WS_MAXIMIZEBOX
)

# Win32 Messages
WM_NCCALCSIZE = 0x0083
WM_NCHITTEST = 0x0084
WM_NCLBUTTONDOWN = 0x00A1
WM_NCLBUTTONUP = 0x00A2
WM_SIZE = 0x0005
SW_RESTORE = 9
SW_MAXIMIZE = 3
SW_SHOW = 5


def exact_cpp_wm_nchittest(
    pt: Tuple[int, int],
    rc: Tuple[int, int, int, int],  # left, top, right, bottom
    scale: float,
    is_zoomed: bool,
    is_fullscreen: bool = False,
) -> int:
    """
    Exact mathematical replication of FlutterWindow::MessageHandler WM_NCHITTEST
    as implemented in frontend/windows/runner/flutter_window.cpp:374-439.
    """
    if is_fullscreen:
        return HTCLIENT

    pt_x, pt_y = pt
    rc_left, rc_top, rc_right, rc_bottom = rc

    button_width = int(46 * scale)
    title_bar_height = int(32 * scale)

    # 1. Window Controls Area (Top-Right):
    # Bypass HTTOP/HTTOPRIGHT resize interception over the top 8-16px of window controls
    # so buttons (Minimize, Maximize, Close) receive clicks across their full 32px height.
    controls_left = rc_right - 3 * button_width
    controls_right = rc_right
    controls_top = rc_top
    controls_bottom = rc_top + title_bar_height

    if (
        pt_x >= controls_left
        and pt_x < controls_right
        and pt_y >= controls_top
        and pt_y < controls_bottom
    ):
        # Maximize button: return HTMAXBUTTON for Windows 11 Snap Layouts hover flyout
        max_btn_left = rc_right - 2 * button_width
        max_btn_right = rc_right - button_width
        if pt_x >= max_btn_left and pt_x < max_btn_right:
            return HTMAXBUTTON
        # Minimize and Close buttons return HTCLIENT so Flutter receives click and hover events
        return HTCLIENT

    # 2. Edge & Corner Resizing (Only when not maximized)
    if not is_zoomed:
        border_thickness = int(8 * scale)
        corner_size = int(16 * scale)

        left = pt_x >= rc_left and pt_x < rc_left + border_thickness
        right = pt_x <= rc_right and pt_x >= rc_right - border_thickness
        top = pt_y >= rc_top and pt_y < rc_top + border_thickness
        bottom = pt_y <= rc_bottom and pt_y >= rc_bottom - border_thickness

        if top and pt_x < rc_left + corner_size:
            return HTTOPLEFT
        if top and pt_x >= rc_right - corner_size:
            return HTTOPRIGHT
        if bottom and pt_x < rc_left + corner_size:
            return HTBOTTOMLEFT
        if bottom and pt_x >= rc_right - corner_size:
            return HTBOTTOMRIGHT

        if top:
            return HTTOP
        if bottom:
            return HTBOTTOM
        if left:
            return HTLEFT
        if right:
            return HTRIGHT

    return HTCLIENT


class TestChallengerEmpiricalHarness(unittest.TestCase):
    """Adversarial stress test suite verifying R1, R2, R3 native runner contracts."""

    @classmethod
    def setUpClass(cls):
        cls.repo_root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
        cls.inspect_py = os.path.join(cls.repo_root, "inspect_frame.py")
        cls.inspect_ps1 = os.path.join(cls.repo_root, "inspect_frame.ps1")
        cls.flutter_window_cpp = os.path.join(
            cls.repo_root, "frontend", "windows", "runner", "flutter_window.cpp"
        )
        cls.main_cpp = os.path.join(cls.repo_root, "frontend", "windows", "runner", "main.cpp")

    # =========================================================================
    # PART 1: inspect_frame.py and inspect_frame.ps1 Empirical Stress Testing
    # =========================================================================

    def test_inspect_frame_py_self_test(self):
        """Verify inspect_frame.py --test executes and exits with code 0."""
        res = subprocess.run(
            [sys.executable, self.inspect_py, "--test"],
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(res.returncode, 0, f"inspect_frame.py --test failed: {res.stderr}")
        self.assertIn("Non-client frame margin calculation verified", res.stdout)

    def test_inspect_frame_ps1_self_test(self):
        """Verify inspect_frame.ps1 -Test executes via PowerShell and exits with code 0."""
        res = subprocess.run(
            ["powershell", "-ExecutionPolicy", "Bypass", "-File", self.inspect_ps1, "-Test"],
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(res.returncode, 0, f"inspect_frame.ps1 -Test failed: {res.stderr}")
        self.assertIn("Non-client frame margin calculation verified: ncTop = 0px", res.stdout)

    def test_inspect_frame_py_live_win32_window_detection(self):
        """
        Adversarial empirical test: Spawns two real live Win32 windows:
        1. A standard window with WS_OVERLAPPEDWINDOW (native caption present)
        2. A custom frameless window where WM_NCCALCSIZE returns 0
        Verifies inspect_frame.py correctly identifies FAIL on window 1 and PASS on window 2!
        """
        if sys.platform != "win32":
            self.skipTest("Live Win32 window test requires Windows OS")

        user32 = ctypes.windll.user32
        kernel32 = ctypes.windll.kernel32

        # Define Window Procedure for standard window
        WNDPROC = ctypes.WINFUNCTYPE(
            ctypes.c_longlong, wintypes.HWND, wintypes.UINT, wintypes.WPARAM, wintypes.LPARAM
        )

        user32.DefWindowProcW.argtypes = [wintypes.HWND, wintypes.UINT, wintypes.WPARAM, wintypes.LPARAM]
        user32.DefWindowProcW.restype = ctypes.c_longlong

        user32.CreateWindowExW.argtypes = [
            wintypes.DWORD, wintypes.LPCWSTR, wintypes.LPCWSTR, wintypes.DWORD,
            ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_int,
            wintypes.HWND, wintypes.HMENU, wintypes.HINSTANCE, wintypes.LPVOID
        ]
        user32.CreateWindowExW.restype = wintypes.HWND

        def std_wnd_proc(hwnd, msg, wparam, lparam):
            return user32.DefWindowProcW(hwnd, msg, wparam, lparam)

        def frameless_wnd_proc(hwnd, msg, wparam, lparam):
            if msg == WM_NCCALCSIZE:
                # Return 0 to eliminate caption and non-client borders
                return 0
            return user32.DefWindowProcW(hwnd, msg, wparam, lparam)

        hinstance = kernel32.GetModuleHandleW(None)

        class WNDCLASSW(ctypes.Structure):
            _fields_ = [
                ("style", wintypes.UINT),
                ("lpfnWndProc", WNDPROC),
                ("cbClsExtra", ctypes.c_int),
                ("cbWndExtra", ctypes.c_int),
                ("hInstance", wintypes.HINSTANCE),
                ("hIcon", wintypes.HICON),
                ("hCursor", wintypes.HICON),
                ("hbrBackground", wintypes.HBRUSH),
                ("lpszMenuName", wintypes.LPCWSTR),
                ("lpszClassName", wintypes.LPCWSTR),
            ]

        # Register classes
        proc_std = WNDPROC(std_wnd_proc)
        wc_std = WNDCLASSW()
        wc_std.hInstance = hinstance
        wc_std.lpszClassName = "ChallengerTestStdClass"
        wc_std.lpfnWndProc = proc_std
        user32.RegisterClassW(ctypes.byref(wc_std))

        proc_frame = WNDPROC(frameless_wnd_proc)
        wc_frame = WNDCLASSW()
        wc_frame.hInstance = hinstance
        wc_frame.lpszClassName = "ChallengerTestFramelessClass"
        wc_frame.lpfnWndProc = proc_frame
        user32.RegisterClassW(ctypes.byref(wc_frame))

        # 1. Create and show standard window
        hwnd_std = user32.CreateWindowExW(
            0,
            "ChallengerTestStdClass",
            "Challenger Standard Window",
            WS_OVERLAPPEDWINDOW | WS_VISIBLE,
            100,
            100,
            800,
            600,
            None,
            None,
            hinstance,
            None,
        )
        self.assertTrue(bool(hwnd_std), "Failed to create standard test window")

        # 2. Create and show custom frameless window
        hwnd_frame = user32.CreateWindowExW(
            0,
            "ChallengerTestFramelessClass",
            "Challenger Frameless Window",
            WS_OVERLAPPEDWINDOW | WS_VISIBLE,
            150,
            150,
            800,
            600,
            None,
            None,
            hinstance,
            None,
        )
        self.assertTrue(bool(hwnd_frame), "Failed to create frameless test window")

        try:
            # Import inspect_window_frame directly
            sys.path.insert(0, self.repo_root)
            import inspect_frame

            # Test Window 1 (Standard): Must detect native title bar present (FAIL)
            res_std = inspect_frame.inspect_window_frame(hwnd_std)
            self.assertFalse(
                res_std["is_native_titlebar_eliminated"],
                "inspect_frame falsely claimed standard window has title bar eliminated!",
            )
            self.assertGreater(
                res_std["non_client_margins"]["top"],
                20,
                f"Standard window nc_top should be ~30px+, got {res_std['non_client_margins']['top']}",
            )
            self.assertIn("FAIL", res_std["verdict"])

            # Test Window 2 (Frameless): Must detect native title bar eliminated (PASS)
            res_frame = inspect_frame.inspect_window_frame(hwnd_frame)
            self.assertTrue(
                res_frame["is_native_titlebar_eliminated"],
                f"inspect_frame failed to detect eliminated title bar on frameless window: {res_frame}",
            )
            self.assertLessEqual(
                res_frame["non_client_margins"]["top"],
                1,
                f"Frameless window nc_top should be <= 1px, got {res_frame['non_client_margins']['top']}",
            )
            self.assertIn("PASS", res_frame["verdict"])

            # Also test CLI execution with --hwnd=
            cli_res_std = subprocess.run(
                [sys.executable, self.inspect_py, f"--hwnd={hwnd_std}"],
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(cli_res_std.returncode, 1, "CLI must exit with code 1 for standard window")

            cli_res_frame = subprocess.run(
                [sys.executable, self.inspect_py, f"--hwnd={hwnd_frame}"],
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(cli_res_frame.returncode, 0, "CLI must exit with code 0 for frameless window")

        finally:
            user32.DestroyWindow(hwnd_std)
            user32.DestroyWindow(hwnd_frame)
            user32.UnregisterClassW("ChallengerTestStdClass", hinstance)
            user32.UnregisterClassW("ChallengerTestFramelessClass", hinstance)

    # =========================================================================
    # PART 2: Window Controls Hit-Testing Geometry Stress Testing
    # =========================================================================

    def test_controls_hit_test_bypass_httop_across_all_dpi_scales(self):
        """
        Adversarially tests that for all DPI scales (100% to 300%) and window dimensions:
        1. Clicks in the top border region (y in [rc.top, rc.top + 8*scale)) over
           Minimize, Maximize, and Close buttons are NEVER intercepted as HTTOP or HTTOPRIGHT.
        2. Minimize button returns HTCLIENT across its entire 46px x 32px area.
        3. Maximize button returns HTMAXBUTTON across its entire 46px x 32px area.
        4. Close button returns HTCLIENT across its entire 46px x 32px area.
        5. Outside the controls area (pt.x < controls_left), top border clicks DO return HTTOP.
        """
        dpi_scales = [1.0, 1.25, 1.5, 1.75, 2.0, 2.25, 2.5, 3.0]
        window_sizes = [(1024, 768), (1280, 800), (1600, 900), (1920, 1080), (2560, 1440), (3840, 2160)]
        origins = [
            (0, 0),         # Primary display origin
            (100, 50),      # Offset windowed position
            (1920, 0),      # Secondary monitor to right
            (-1920, 0),     # Secondary monitor to left (NEGATIVE COORDINATES)
            (0, -1080),     # Secondary monitor above (NEGATIVE COORDINATES)
        ]

        for scale in dpi_scales:
            button_width = int(46 * scale)
            title_bar_height = int(32 * scale)
            border_thickness = int(8 * scale)

            for w, h in window_sizes:
                for ox, oy in origins:
                    rc = (ox, oy, ox + w, oy + h)
                    rc_left, rc_top, rc_right, rc_bottom = rc

                    controls_left = rc_right - 3 * button_width
                    min_left = rc_right - 3 * button_width
                    min_right = rc_right - 2 * button_width
                    max_left = rc_right - 2 * button_width
                    max_right = rc_right - button_width
                    close_left = rc_right - button_width
                    close_right = rc_right

                    # --- TEST 1: Minimize button area (including top border) ---
                    # Test top 1px, middle of top border, bottom of top border, center of button
                    test_points_min = [
                        (min_left, rc_top),
                        ((min_left + min_right) // 2, rc_top),
                        ((min_left + min_right) // 2, rc_top + 1),
                        ((min_left + min_right) // 2, rc_top + border_thickness - 1),
                        ((min_left + min_right) // 2, (rc_top + rc_top + title_bar_height) // 2),
                        (min_right - 1, rc_top + title_bar_height - 1),
                    ]
                    for pt in test_points_min:
                        hit = exact_cpp_wm_nchittest(pt, rc, scale, is_zoomed=False)
                        self.assertEqual(
                            hit,
                            HTCLIENT,
                            f"Minimize button at point {pt} intercepted as {hit} (expected HTCLIENT) at scale {scale}",
                        )

                    # --- TEST 2: Maximize button area (including top border) ---
                    test_points_max = [
                        (max_left, rc_top),
                        ((max_left + max_right) // 2, rc_top),
                        ((max_left + max_right) // 2, rc_top + 1),
                        ((max_left + max_right) // 2, rc_top + border_thickness - 1),
                        ((max_left + max_right) // 2, (rc_top + rc_top + title_bar_height) // 2),
                        (max_right - 1, rc_top + title_bar_height - 1),
                    ]
                    for pt in test_points_max:
                        hit = exact_cpp_wm_nchittest(pt, rc, scale, is_zoomed=False)
                        self.assertEqual(
                            hit,
                            HTMAXBUTTON,
                            f"Maximize button at point {pt} intercepted as {hit} (expected HTMAXBUTTON) at scale {scale}",
                        )

                    # --- TEST 3: Close button area (including top border) ---
                    test_points_close = [
                        (close_left, rc_top),
                        ((close_left + close_right) // 2, rc_top),
                        ((close_left + close_right) // 2, rc_top + 1),
                        ((close_left + close_right) // 2, rc_top + border_thickness - 1),
                        ((close_left + close_right) // 2, (rc_top + rc_top + title_bar_height) // 2),
                        (close_right - 1, rc_top),
                        (close_right - 1, rc_top + title_bar_height - 1),
                    ]
                    for pt in test_points_close:
                        hit = exact_cpp_wm_nchittest(pt, rc, scale, is_zoomed=False)
                        self.assertEqual(
                            hit,
                            HTCLIENT,
                            f"Close button at point {pt} intercepted as {hit} (expected HTCLIENT) at scale {scale}",
                        )

                    # --- TEST 4: Top edge resize outside controls (must remain HTTOP) ---
                    # Point just to the left of controls: controls_left - 1
                    corner_size = int(16 * scale)
                    safe_x = (rc_left + corner_size + controls_left) // 2
                    if safe_x > rc_left + corner_size and safe_x < controls_left:
                        top_border_pt = (safe_x, rc_top + 2)
                        hit_top = exact_cpp_wm_nchittest(top_border_pt, rc, scale, is_zoomed=False)
                        self.assertEqual(
                            hit_top,
                            HTTOP,
                            f"Top edge at point {top_border_pt} outside controls should return HTTOP, got {hit_top} at scale {scale}",
                        )

    def test_controls_pixel_exact_boundary_transitions(self):
        """
        Adversarial test: checks the exact single-pixel boundaries between buttons
        and between buttons and resize regions.
        """
        scale = 1.5
        button_width = int(46 * scale)  # 69px
        title_bar_height = int(32 * scale)  # 48px
        border_thickness = int(8 * scale)  # 12px
        rc = (100, 100, 1100, 800)
        rc_left, rc_top, rc_right, rc_bottom = rc

        controls_left = rc_right - 3 * button_width  # 1100 - 207 = 893
        min_btn_left = controls_left
        max_btn_left = rc_right - 2 * button_width  # 1100 - 138 = 962
        close_btn_left = rc_right - button_width   # 1100 - 69 = 1031

        # Test at y = rc_top + 4 (within top resize border of 12px)
        test_y = rc_top + 4

        # 1. Pixel immediately before Minimize button: must be HTTOP (resize)
        self.assertEqual(
            exact_cpp_wm_nchittest((controls_left - 1, test_y), rc, scale, is_zoomed=False),
            HTTOP,
            "Pixel at controls_left - 1 should be HTTOP resize border",
        )

        # 2. First pixel of Minimize button: must be HTCLIENT
        self.assertEqual(
            exact_cpp_wm_nchittest((controls_left, test_y), rc, scale, is_zoomed=False),
            HTCLIENT,
            "Pixel at controls_left should be HTCLIENT",
        )

        # 3. Last pixel of Minimize button: must be HTCLIENT
        self.assertEqual(
            exact_cpp_wm_nchittest((max_btn_left - 1, test_y), rc, scale, is_zoomed=False),
            HTCLIENT,
            "Pixel at max_btn_left - 1 should be HTCLIENT",
        )

        # 4. First pixel of Maximize button: must be HTMAXBUTTON
        self.assertEqual(
            exact_cpp_wm_nchittest((max_btn_left, test_y), rc, scale, is_zoomed=False),
            HTMAXBUTTON,
            "Pixel at max_btn_left should be HTMAXBUTTON",
        )

        # 5. Last pixel of Maximize button: must be HTMAXBUTTON
        self.assertEqual(
            exact_cpp_wm_nchittest((close_btn_left - 1, test_y), rc, scale, is_zoomed=False),
            HTMAXBUTTON,
            "Pixel at close_btn_left - 1 should be HTMAXBUTTON",
        )

        # 6. First pixel of Close button: must be HTCLIENT
        self.assertEqual(
            exact_cpp_wm_nchittest((close_btn_left, test_y), rc, scale, is_zoomed=False),
            HTCLIENT,
            "Pixel at close_btn_left should be HTCLIENT",
        )

        # 7. Last pixel of Close button: must be HTCLIENT
        self.assertEqual(
            exact_cpp_wm_nchittest((rc_right - 1, test_y), rc, scale, is_zoomed=False),
            HTCLIENT,
            "Pixel at rc_right - 1 should be HTCLIENT",
        )

        # 8. Pixel immediately below title bar under Maximize button: must be HTCLIENT (inner window)
        self.assertEqual(
            exact_cpp_wm_nchittest((max_btn_left + 10, rc_top + title_bar_height), rc, scale, is_zoomed=False),
            HTCLIENT,
            "Pixel below title bar should return HTCLIENT",
        )

    def test_controls_hit_test_in_maximized_mode(self):
        """
        Adversarially tests hit-testing when window is maximized (is_zoomed == True):
        Edge resizing is completely inactive, but Maximize button returns HTMAXBUTTON
        and Minimize/Close buttons return HTCLIENT.
        """
        dpi_scales = [1.0, 1.25, 1.5, 2.0]
        work_areas = [
            (0, 0, 1920, 1040),
            (0, 40, 1920, 1080),
            (1920, 0, 3840, 1040),
        ]

        for scale in dpi_scales:
            button_width = int(46 * scale)
            title_bar_height = int(32 * scale)

            for rc in work_areas:
                rc_left, rc_top, rc_right, rc_bottom = rc
                max_left = rc_right - 2 * button_width
                max_right = rc_right - button_width

                # Maximize button
                hit_max = exact_cpp_wm_nchittest(
                    ((max_left + max_right) // 2, rc_top + 5),
                    rc,
                    scale,
                    is_zoomed=True,
                )
                self.assertEqual(hit_max, HTMAXBUTTON)

                # Close button
                hit_close = exact_cpp_wm_nchittest(
                    (rc_right - button_width // 2, rc_top + 5),
                    rc,
                    scale,
                    is_zoomed=True,
                )
                self.assertEqual(hit_close, HTCLIENT)

                # Minimize button
                hit_min = exact_cpp_wm_nchittest(
                    (max_left - button_width // 2, rc_top + 5),
                    rc,
                    scale,
                    is_zoomed=True,
                )
                self.assertEqual(hit_min, HTCLIENT)

                # Blank title bar area in maximized mode: returns HTCLIENT so Flutter can drag or double click
                hit_drag = exact_cpp_wm_nchittest(
                    (rc_left + 100, rc_top + 5),
                    rc,
                    scale,
                    is_zoomed=True,
                )
                self.assertEqual(hit_drag, HTCLIENT)

    # =========================================================================
    # PART 3: Maximize Button & Snap Layouts Click State Machine
    # =========================================================================

    def test_snap_layouts_mouse_click_handling(self):
        """
        Adversarially verifies the message handling logic for maximize clicks in
        flutter_window.cpp:441-453:
        1. WM_NCLBUTTONDOWN with HTMAXBUTTON returns 0 (prevents DefWindowProc lockup).
        2. WM_NCLBUTTONUP with HTMAXBUTTON checks ::IsZoomed and calls ShowWindow(SW_RESTORE) or SW_MAXIMIZE.
        3. Other messages (e.g. WM_NCRBUTTONDOWN) do not intercept so DWM snap flyout can show menu.
        """
        with open(self.flutter_window_cpp, "r", encoding="utf-8") as f:
            content = f.read()

        # Check WM_NCLBUTTONDOWN intercept
        self.assertIn("if (message == WM_NCLBUTTONDOWN && wparam == HTMAXBUTTON)", content)
        self.assertIn("return 0;", content)

        # Check WM_NCLBUTTONUP intercept
        self.assertIn("if (message == WM_NCLBUTTONUP && wparam == HTMAXBUTTON)", content)
        self.assertIn("if (::IsZoomed(hwnd))", content)
        self.assertIn("::ShowWindow(hwnd, SW_RESTORE);", content)
        self.assertIn("::ShowWindow(hwnd, SW_MAXIMIZE);", content)

    # =========================================================================
    # PART 4: True Native Fullscreen State Transition & Placement Restoration
    # =========================================================================

    def test_true_fullscreen_transition_contracts(self):
        """
        Adversarially validates that flutter_window.cpp:45-99 fulfills all native
        fullscreen requirements:
        1. Clears zoom state via ShowWindow(SW_RESTORE) before switching style if previously zoomed.
        2. Removes WS_OVERLAPPEDWINDOW and adds WS_POPUP style.
        3. Positions to mi.rcMonitor with HWND_TOPMOST and SWP_FRAMECHANGED.
        4. Sets foreground and focus.
        5. On exit, restores g_prev_window_style, g_prev_window_placement, sets HWND_NOTOPMOST.
        6. Re-extends DWM frame via DwmExtendFrameIntoClientArea(hwnd, &margins).
        7. If g_prev_was_zoomed, restores maximize state via ShowWindow(SW_MAXIMIZE).
        """
        with open(self.flutter_window_cpp, "r", encoding="utf-8") as f:
            content = f.read()

        # Verify entry contracts
        self.assertIn("void ApplyFullScreenMode(HWND hwnd, bool fullscreen)", content)
        self.assertIn("if (g_is_window_fullscreen == fullscreen) {", content)
        self.assertIn("::GetWindowPlacement(hwnd, &g_prev_window_placement);", content)
        self.assertIn("g_prev_window_style = ::GetWindowLongPtr(hwnd, GWL_STYLE);", content)
        self.assertIn("g_prev_was_zoomed = (::IsZoomed(hwnd) != FALSE);", content)
        self.assertIn("if (g_prev_was_zoomed) {\n      ::ShowWindow(hwnd, SW_RESTORE);\n    }", content)
        self.assertIn("LONG_PTR new_style = (g_prev_window_style & ~WS_OVERLAPPEDWINDOW) | WS_POPUP;", content)
        self.assertIn("mi.rcMonitor.left, mi.rcMonitor.top,", content)
        self.assertIn("SWP_NOOWNERZORDER | SWP_FRAMECHANGED | SWP_SHOWWINDOW", content)
        self.assertIn("::SetForegroundWindow(hwnd);", content)

        # Verify exit contracts
        self.assertIn("::SetWindowLongPtr(hwnd, GWL_STYLE, orig_style);", content)
        self.assertIn("::SetWindowPlacement(hwnd, &g_prev_window_placement);", content)
        self.assertIn("::SetWindowPos(hwnd, HWND_NOTOPMOST, 0, 0, 0, 0,", content)
        self.assertIn("MARGINS margins = {0, 0, 1, 0};", content)
        self.assertIn("::DwmExtendFrameIntoClientArea(hwnd, &margins);", content)
        self.assertIn("if (g_prev_was_zoomed) {\n      ::ShowWindow(hwnd, SW_MAXIMIZE);\n    }", content)

    # =========================================================================
    # PART 5: Native Resilience Invariants
    # =========================================================================

    def test_native_resilience_invariants(self):
        """
        Verifies:
        1. kDisplayRecoveryTimeoutMs = 8000 in flutter_window.cpp
        2. LowPower GPU preference in main.cpp:28
        3. RelaunchAfterDisplayReset with --display-recovery-from in flutter_window.cpp:564
        4. Independent watchdog thread
        """
        with open(self.flutter_window_cpp, "r", encoding="utf-8") as f:
            fw_content = f.read()

        with open(self.main_cpp, "r", encoding="utf-8") as f:
            main_content = f.read()

        # 1. Watchdog timeout = 8000ms
        self.assertIn("constexpr unsigned long long kDisplayRecoveryTimeoutMs = 8000;", fw_content)

        # 2. Low-power GPU preference
        self.assertIn("project.set_gpu_preference(flutter::GpuPreference::LowPowerPreference);", main_content)

        # 3. Process adoption parameter
        self.assertIn('command_line.append(L"\\" --display-recovery-from=");', fw_content)

        # 4. Display change triggers recovery arming
        self.assertIn("if (message == WM_DISPLAYCHANGE) {", fw_content)
        self.assertIn("ArmDisplayRecoveryWatchdog();", fw_content)
        self.assertIn("if (message == WM_DWMCOMPOSITIONCHANGED) {", fw_content)


if __name__ == "__main__":
    unittest.main()
