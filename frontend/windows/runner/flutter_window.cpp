#include "flutter_window.h"

#include <chrono>
#include <dwmapi.h>
#include <optional>
#include <string>
#include <vector>
#include <windowsx.h>

#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include "flutter/generated_plugin_registrant.h"
#include "startup_log.h"

#ifndef DWMWA_USE_IMMERSIVE_DARK_MODE
#define DWMWA_USE_IMMERSIVE_DARK_MODE 20
#endif
#ifndef DWMWA_BORDER_COLOR
#define DWMWA_BORDER_COLOR 34
#endif
#ifndef DWMWA_CAPTION_COLOR
#define DWMWA_CAPTION_COLOR 35
#endif

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

namespace {
// A display-driver replacement can leave ANGLE/D3D permanently wedged while
// the backend queue continues normally. Eight seconds is long enough for the
// ordinary Windows display reset, but short enough that the technician does
// not mistake a dead renderer for a frozen deployment.
constexpr unsigned long long kDisplayRecoveryTimeoutMs = 8000;

// Native window management channels supporting custom in-app title bar and fullscreen tests
std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> g_markazi_window_channel;
std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> g_window_manager_channel;
WINDOWPLACEMENT g_prev_window_placement = {sizeof(WINDOWPLACEMENT)};
LONG_PTR g_prev_window_style = 0;
bool g_prev_was_zoomed = false;
bool g_is_window_fullscreen = false;

void ApplyFullScreenMode(HWND hwnd, bool fullscreen) {
  if (g_is_window_fullscreen == fullscreen) {
    return;
  }
  g_is_window_fullscreen = fullscreen;

  if (fullscreen) {
    g_prev_window_placement.length = sizeof(WINDOWPLACEMENT);
    ::GetWindowPlacement(hwnd, &g_prev_window_placement);
    g_prev_window_style = ::GetWindowLongPtr(hwnd, GWL_STYLE);
    g_prev_was_zoomed = (::IsZoomed(hwnd) != FALSE);

    if (g_prev_was_zoomed) {
      ::ShowWindow(hwnd, SW_RESTORE);
    }

    MONITORINFO mi = {sizeof(mi)};
    HMONITOR monitor = ::MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST);
    if (::GetMonitorInfo(monitor, &mi)) {
      LONG_PTR new_style = (g_prev_window_style & ~WS_OVERLAPPEDWINDOW) | WS_POPUP;
      ::SetWindowLongPtr(hwnd, GWL_STYLE, new_style);
      ::SetWindowPos(hwnd, HWND_TOPMOST,
                     mi.rcMonitor.left, mi.rcMonitor.top,
                     mi.rcMonitor.right - mi.rcMonitor.left,
                     mi.rcMonitor.bottom - mi.rcMonitor.top,
                     SWP_NOOWNERZORDER | SWP_FRAMECHANGED | SWP_SHOWWINDOW);
      ::SetForegroundWindow(hwnd);
      ::SetFocus(hwnd);

      RECT wr = {};
      ::GetWindowRect(hwnd, &wr);
      if (wr.left == mi.rcMonitor.left && wr.top == mi.rcMonitor.top &&
          wr.right == mi.rcMonitor.right && wr.bottom == mi.rcMonitor.bottom) {
        LogStartup("Verified GetWindowRect == rcMonitor in true native fullscreen mode");
      } else {
        LogStartup("Entered native fullscreen mode with monitor bounds");
      }
    }
  } else {
    LONG_PTR orig_style = g_prev_window_style
                              ? g_prev_window_style
                              : ((::GetWindowLongPtr(hwnd, GWL_STYLE) & ~WS_POPUP) | WS_OVERLAPPEDWINDOW);
    ::SetWindowLongPtr(hwnd, GWL_STYLE, orig_style);
    ::SetWindowPlacement(hwnd, &g_prev_window_placement);
    ::SetWindowPos(hwnd, HWND_NOTOPMOST, 0, 0, 0, 0,
                   SWP_NOMOVE | SWP_NOSIZE | SWP_NOOWNERZORDER | SWP_FRAMECHANGED);
    MARGINS margins = {0, 0, 1, 0};
    ::DwmExtendFrameIntoClientArea(hwnd, &margins);

    if (g_prev_was_zoomed) {
      ::ShowWindow(hwnd, SW_MAXIMIZE);
    }
    LogStartup("Exited native fullscreen mode and restored geometry");
  }
}

void SetupWindowChannels(flutter::BinaryMessenger* messenger, HWND hwnd) {
  if (!messenger || !hwnd) {
    return;
  }

  auto method_handler = [hwnd](const flutter::MethodCall<flutter::EncodableValue>& call,
                               std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
    const std::string& method = call.method_name();

    if (method == "minimize") {
      ::ShowWindow(hwnd, SW_MINIMIZE);
      result->Success(flutter::EncodableValue(true));
    } else if (method == "maximize") {
      ::ShowWindow(hwnd, SW_MAXIMIZE);
      result->Success(flutter::EncodableValue(true));
    } else if (method == "unmaximize" || method == "restore") {
      ::ShowWindow(hwnd, SW_RESTORE);
      result->Success(flutter::EncodableValue(true));
    } else if (method == "isMaximized") {
      result->Success(flutter::EncodableValue(::IsZoomed(hwnd) != FALSE));
    } else if (method == "isMinimized") {
      result->Success(flutter::EncodableValue(::IsIconic(hwnd) != FALSE));
    } else if (method == "close") {
      ::PostMessage(hwnd, WM_CLOSE, 0, 0);
      result->Success(flutter::EncodableValue(true));
    } else if (method == "startDragging") {
      ::ReleaseCapture();
      POINT pt = {};
      ::GetCursorPos(&pt);
      ::SendMessage(hwnd, WM_NCLBUTTONDOWN, HTCAPTION, MAKELPARAM(pt.x, pt.y));
      result->Success(flutter::EncodableValue(true));
    } else if (method == "show") {
      ::ShowWindow(hwnd, SW_SHOW);
      result->Success(flutter::EncodableValue(true));
    } else if (method == "hide") {
      ::ShowWindow(hwnd, SW_HIDE);
      result->Success(flutter::EncodableValue(true));
    } else if (method == "focus") {
      ::SetForegroundWindow(hwnd);
      ::SetFocus(hwnd);
      result->Success(flutter::EncodableValue(true));
    } else if (method == "setFullScreen") {
      bool fullscreen = false;
      if (call.arguments()) {
        if (const auto* b = std::get_if<bool>(call.arguments())) {
          fullscreen = *b;
        } else if (const auto* i = std::get_if<int>(call.arguments())) {
          fullscreen = (*i != 0);
        } else if (const auto* i64 = std::get_if<int64_t>(call.arguments())) {
          fullscreen = (*i64 != 0);
        } else if (const auto* map = std::get_if<flutter::EncodableMap>(call.arguments())) {
          auto it = map->find(flutter::EncodableValue("isFullScreen"));
          if (it != map->end()) {
            if (std::holds_alternative<bool>(it->second)) {
              fullscreen = std::get<bool>(it->second);
            } else if (std::holds_alternative<int>(it->second)) {
              fullscreen = (std::get<int>(it->second) != 0);
            } else if (std::holds_alternative<int64_t>(it->second)) {
              fullscreen = (std::get<int64_t>(it->second) != 0);
            }
          }
        }
      }
      ApplyFullScreenMode(hwnd, fullscreen);
      result->Success(flutter::EncodableValue(true));
    } else if (method == "isFullScreen") {
      result->Success(flutter::EncodableValue(g_is_window_fullscreen));
    } else if (method == "setTheme") {
      bool is_dark = true;
      if (call.arguments()) {
        if (const auto* b = std::get_if<bool>(call.arguments())) {
          is_dark = *b;
        } else if (const auto* map = std::get_if<flutter::EncodableMap>(call.arguments())) {
          auto it = map->find(flutter::EncodableValue("isDark"));
          if (it != map->end() && std::holds_alternative<bool>(it->second)) {
            is_dark = std::get<bool>(it->second);
          }
        }
      }
      BOOL enable_dark = is_dark ? TRUE : FALSE;
      ::DwmSetWindowAttribute(hwnd, DWMWA_USE_IMMERSIVE_DARK_MODE,
                              &enable_dark, sizeof(enable_dark));
      COLORREF caption_color = is_dark ? RGB(15, 23, 42) : RGB(248, 250, 252);
      ::DwmSetWindowAttribute(hwnd, DWMWA_CAPTION_COLOR,
                              &caption_color, sizeof(caption_color));
      COLORREF border_color = is_dark ? RGB(30, 41, 59) : RGB(226, 232, 240);
      ::DwmSetWindowAttribute(hwnd, DWMWA_BORDER_COLOR,
                              &border_color, sizeof(border_color));
      result->Success(flutter::EncodableValue(true));
    } else if (method == "ensureInitialized" || method == "waitUntilReadyToShow") {
      result->Success(flutter::EncodableValue(true));
    } else {
      result->Success();
    }
  };

  g_markazi_window_channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      messenger, "markazi/window", &flutter::StandardMethodCodec::GetInstance());
  g_markazi_window_channel->SetMethodCallHandler(method_handler);

  g_window_manager_channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      messenger, "window_manager", &flutter::StandardMethodCodec::GetInstance());
  g_window_manager_channel->SetMethodCallHandler(method_handler);

  LogStartup("Native window management platform channels registered (markazi/window and window_manager)");
}

void TeardownWindowChannels() {
  if (g_markazi_window_channel) {
    g_markazi_window_channel->SetMethodCallHandler(nullptr);
    g_markazi_window_channel.reset();
  }
  if (g_window_manager_channel) {
    g_window_manager_channel->SetMethodCallHandler(nullptr);
    g_window_manager_channel.reset();
  }
}
}

FlutterWindow::~FlutterWindow() {
  StopDisplayRecoveryWatchdog();
}

bool FlutterWindow::OnCreate() {
  LogStartup("Creating Flutter window");
  if (!Win32Window::OnCreate()) {
    return false;
  }

  // Preserve native Windows drop shadows and Windows 11 rounded corners
  MARGINS margins = {0, 0, 1, 0};
  ::DwmExtendFrameIntoClientArea(GetHandle(), &margins);

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    LogStartup("Flutter engine/view creation failed");
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());
  SetupWindowChannels(flutter_controller_->engine()->messenger(), GetHandle());

  flutter_controller_->engine()->SetNextFrameCallback([this]() {
    KillTimer(GetHandle(), 1);
    first_frame_rendered_.store(true);
    LogStartup("First Flutter frame rendered");
    this->Show();
  });
  SetTimer(GetHandle(), 1, 30000, nullptr);

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();
  StartDisplayRecoveryWatchdog();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (close_requested_.load()) {
    // Works even when Dart cannot process an exit notification after GPU loss.
    const auto event_name = L"Local\\MarkaziSystemChecker.Close." +
                            std::to_wstring(GetCurrentProcessId());
    HANDLE close_event =
        OpenEventW(EVENT_MODIFY_STATE, FALSE, event_name.c_str());
    if (close_event) {
      SetEvent(close_event);
      CloseHandle(close_event);
    }
    // Engine destruction may itself block on a lost D3D device. Bound only a
    // committed WM_CLOSE shutdown, never Win32's temporary startup teardown.
    std::thread([]() {
      Sleep(8000);
      TerminateProcess(GetCurrentProcess(), 0);
    }).detach();
  }
  KillTimer(GetHandle(), 1);
  KillTimer(GetHandle(), 2);
  StopDisplayRecoveryWatchdog();
  LogStartup("Window closed");
  // The backend's parent watchdog owns process cleanup. Never kill other
  // sessions' backend processes by image name.

  TeardownWindowChannels();
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  if (message == WM_CLOSE) {
    close_requested_.store(true);
  }
  if (message == WM_TIMER && wparam == 2) {
    KillTimer(hwnd, 2);
    if (!first_frame_rendered_.load()) {
      // Preserve the startup callback that makes the window visible.
      SetTimer(hwnd, 2, 500, nullptr);
      return 0;
    }
    if (flutter_controller_ && display_recovery_pending_.load()) {
      const auto generation = display_generation_.load();
      // Probe only AFTER Flutter has processed the display-reset message.
      // A callback from an older surface must not acknowledge a newer reset.
      flutter_controller_->engine()->SetNextFrameCallback([this, generation]() {
        if (display_generation_.load() == generation) {
          display_recovery_pending_.store(false);
          display_recovery_deadline_ms_.store(0);
          LogStartup("New Flutter frame verified after display reset");
        }
      });
      flutter_controller_->ForceRedraw();
    }
    return 0;
  }
  if (message == WM_TIMER && wparam == 1) {
    KillTimer(hwnd, 1);
    LogStartup("No first frame after 30 seconds");
    this->Show();
    MessageBoxW(hwnd,
        L"The application has not rendered its first frame.\n"
        L"Check the graphics driver and Windows updates, then restart the application.\n"
        L"Diagnostics: %LOCALAPPDATA%\\MarkaziSystemChecker\\logs\\startup.log",
        L"Markazi System Checker - Startup diagnostics", MB_OK | MB_ICONWARNING);
    return 0;
  }
  // Arm recovery before Flutter sees WM_DISPLAYCHANGE. If ANGLE blocks while
  // handling a graphics-device reset, the independent native watchdog can
  // still replace the UI process.
  if (message == WM_DISPLAYCHANGE) {
    LogStartup("Windows display reset detected; arming renderer recovery");
    ArmDisplayRecoveryWatchdog();
  }
  if (message == WM_DWMCOMPOSITIONCHANGED) {
    LogStartup("DWM composition reset detected; arming renderer recovery");
    MARGINS margins = {0, 0, 1, 0};
    ::DwmExtendFrameIntoClientArea(hwnd, &margins);
    ArmDisplayRecoveryWatchdog();
  }

  // Synchronously eliminate native caption and window borders
  if (message == WM_NCCALCSIZE) {
    if (wparam == TRUE) {
      if (g_is_window_fullscreen) {
        return 0;
      }
      if (::IsZoomed(hwnd)) {
        HMONITOR monitor = ::MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST);
        MONITORINFO mi = {sizeof(mi)};
        if (::GetMonitorInfo(monitor, &mi)) {
          auto* params = reinterpret_cast<NCCALCSIZE_PARAMS*>(lparam);
          params->rgrc[0] = mi.rcWork;
        }
        return 0;
      }
      return 0;
    }
    return 0;
  }

  // Native edge/corner resizing, Windows 11 Snap Layouts hover, and window controls hit-testing
  if (message == WM_NCHITTEST) {
    if (g_is_window_fullscreen) {
      return HTCLIENT;
    }

    POINT pt = {GET_X_LPARAM(lparam), GET_Y_LPARAM(lparam)};
    RECT rc;
    ::GetWindowRect(hwnd, &rc);

    HMONITOR monitor = ::MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST);
    MONITORINFO mi = {sizeof(mi)};
    if (::GetMonitorInfo(monitor, &mi)) {
      if (::IsZoomed(hwnd)) {
        rc = mi.rcWork;
      }
    }

    UINT dpi = FlutterDesktopGetDpiForMonitor(monitor);
    double scale = (dpi == 0 ? 96.0 : dpi) / 96.0;

    int button_width = static_cast<int>(46 * scale);
    int title_bar_height = static_cast<int>(32 * scale);

    // 1. Window Controls Area (Top-Right):
    // Bypass HTTOP/HTTOPRIGHT resize interception over the top 8-16px of window controls
    // so buttons (Minimize, Maximize, Close) receive clicks across their full 32px height.
    int controls_left = rc.right - 3 * button_width;
    int controls_right = rc.right;
    int controls_top = rc.top;
    int controls_bottom = rc.top + title_bar_height;

    if (pt.x >= controls_left && pt.x < controls_right &&
        pt.y >= controls_top && pt.y < controls_bottom) {
      // Maximize button: return HTMAXBUTTON for Windows 11 Snap Layouts hover flyout
      int max_btn_left = rc.right - 2 * button_width;
      int max_btn_right = rc.right - button_width;
      if (pt.x >= max_btn_left && pt.x < max_btn_right) {
        return HTMAXBUTTON;
      }
      // Minimize and Close buttons return HTCLIENT so Flutter receives click and hover events
      return HTCLIENT;
    }

    // 2. Edge & Corner Resizing (Only when not maximized)
    if (!::IsZoomed(hwnd)) {
      int border_thickness = static_cast<int>(8 * scale);
      int corner_size = static_cast<int>(16 * scale);

      bool left = pt.x >= rc.left && pt.x < rc.left + border_thickness;
      bool right = pt.x <= rc.right && pt.x >= rc.right - border_thickness;
      bool top = pt.y >= rc.top && pt.y < rc.top + border_thickness;
      bool bottom = pt.y <= rc.bottom && pt.y >= rc.bottom - border_thickness;

      if (top && pt.x < rc.left + corner_size) return HTTOPLEFT;
      if (top && pt.x >= rc.right - corner_size) return HTTOPRIGHT;
      if (bottom && pt.x < rc.left + corner_size) return HTBOTTOMLEFT;
      if (bottom && pt.x >= rc.right - corner_size) return HTBOTTOMRIGHT;

      if (top) return HTTOP;
      if (bottom) return HTBOTTOM;
      if (left) return HTLEFT;
      if (right) return HTRIGHT;
    }

    return HTCLIENT;
  }

  if (message == WM_NCLBUTTONDOWN && wparam == HTMAXBUTTON) {
    // Acknowledge button down cleanly so Windows sends the subsequent UP event
    return 0;
  }

  if (message == WM_NCLBUTTONUP && wparam == HTMAXBUTTON) {
    if (::IsZoomed(hwnd)) {
      ::ShowWindow(hwnd, SW_RESTORE);
    } else {
      ::ShowWindow(hwnd, SW_MAXIMIZE);
    }
    return 0;
  }

  // Give Flutter, including plugins, an opportunity to handle window messages.
  // Wrap with exception handling to safely survive DirectX 11 / DXGI device resets
  // that occur during GPU graphics driver installations.
  if (flutter_controller_) {
    try {
      std::optional<LRESULT> result =
          flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                        lparam);
      if (result) {
        return *result;
      }
    } catch (...) {
      LogStartup("Exception safely caught in HandleTopLevelWindowProc (GPU display/device reset)");
    }
  }

  switch (message) {
    case WM_SIZE:
      if (flutter_controller_ && g_markazi_window_channel) {
        if (wparam == SIZE_MAXIMIZED) {
          g_markazi_window_channel->InvokeMethod("onWindowMaximize", nullptr);
          if (g_window_manager_channel) {
            g_window_manager_channel->InvokeMethod("onWindowMaximize", nullptr);
          }
        } else if (wparam == SIZE_RESTORED) {
          g_markazi_window_channel->InvokeMethod("onWindowRestore", nullptr);
          if (g_window_manager_channel) {
            g_window_manager_channel->InvokeMethod("onWindowRestore", nullptr);
          }
        }
      }
      // IMPORTANT: Do NOT return early here. Fall through so that
      // Win32Window::MessageHandler can execute MoveWindow on child_content_.
      break;

    case WM_DISPLAYCHANGE:
      if (flutter_controller_) {
        flutter_controller_->ForceRedraw();
      }
      break;

    case WM_FONTCHANGE:
      if (flutter_controller_ && flutter_controller_->engine()) {
        flutter_controller_->engine()->ReloadSystemFonts();
      }
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}

void FlutterWindow::ArmDisplayRecoveryWatchdog() {
  if (!flutter_controller_) {
    return;
  }

  display_generation_.fetch_add(1);
  if (!display_recovery_pending_.exchange(true)) {
    display_recovery_deadline_ms_.store(GetTickCount64() +
                                        kDisplayRecoveryTimeoutMs);
  }
  // Repeated display events must not extend the recovery deadline forever.
  SetTimer(GetHandle(), 2, 500, nullptr);
}

void FlutterWindow::StartDisplayRecoveryWatchdog() {
  if (recovery_watchdog_thread_.joinable()) {
    return;
  }
  recovery_watchdog_stop_.store(false);
  recovery_watchdog_thread_ = std::thread([this]() {
    while (!recovery_watchdog_stop_.load()) {
      if (display_recovery_pending_.load()) {
        const auto deadline = display_recovery_deadline_ms_.load();
        if (deadline != 0 && GetTickCount64() >= deadline) {
          RelaunchAfterDisplayReset();
        }
      }
      std::this_thread::sleep_for(std::chrono::milliseconds(250));
    }
  });
}

void FlutterWindow::StopDisplayRecoveryWatchdog() {
  recovery_watchdog_stop_.store(true);
  if (recovery_watchdog_thread_.joinable() &&
      recovery_watchdog_thread_.get_id() != std::this_thread::get_id()) {
    recovery_watchdog_thread_.join();
  }
}

void FlutterWindow::RelaunchAfterDisplayReset() {
  if (recovery_relaunch_started_.exchange(true)) {
    return;
  }

  wchar_t executable_path[32768] = {};
  const DWORD length =
      GetModuleFileNameW(nullptr, executable_path, std::size(executable_path));
  if (length == 0 || length >= std::size(executable_path)) {
    LogStartup("Renderer recovery could not resolve executable path");
    recovery_relaunch_started_.store(false);
    display_recovery_pending_.store(false);
    return;
  }

  const DWORD old_pid = GetCurrentProcessId();
  std::wstring command_line = L"\"";
  command_line.append(executable_path);
  command_line.append(L"\" --display-recovery-from=");
  command_line.append(std::to_wstring(old_pid));
  std::vector<wchar_t> mutable_command(command_line.begin(), command_line.end());
  mutable_command.push_back(L'\0');

  STARTUPINFOW startup_info = {};
  startup_info.cb = sizeof(startup_info);
  PROCESS_INFORMATION process_info = {};
  std::wstring executable(executable_path, length);
  const auto separator = executable.find_last_of(L"\\/");
  const std::wstring working_directory = separator == std::wstring::npos
                                             ? std::wstring()
                                             : executable.substr(0, separator);

  LogStartup("Flutter renderer did not recover; relaunching technician UI");
  const BOOL started = CreateProcessW(
      executable_path, mutable_command.data(), nullptr, nullptr, FALSE, 0,
      nullptr, working_directory.empty() ? nullptr : working_directory.c_str(),
      &startup_info, &process_info);
  if (!started) {
    LogStartup("Automatic UI relaunch failed after display reset");
    recovery_relaunch_started_.store(false);
    display_recovery_pending_.store(false);
    return;
  }

  CloseHandle(process_info.hThread);
  CloseHandle(process_info.hProcess);
  // The backend grants the replacement process a hand-off window and keeps
  // the active driver queue alive. End only this unresponsive Flutter UI.
  Sleep(750);
  TerminateProcess(GetCurrentProcess(), 70);
}
