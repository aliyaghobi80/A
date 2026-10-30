#include "flutter_window.h"

#include <chrono>
#include <optional>
#include <string>
#include <vector>

#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include "flutter/generated_plugin_registrant.h"
#include "startup_log.h"

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
bool g_is_window_fullscreen = false;

void ApplyFullScreenMode(HWND hwnd, bool fullscreen) {
  if (g_is_window_fullscreen == fullscreen) {
    return;
  }
  g_is_window_fullscreen = fullscreen;

  DWORD style = ::GetWindowLong(hwnd, GWL_STYLE);
  if (fullscreen) {
    MONITORINFO mi = {sizeof(mi)};
    HMONITOR monitor = ::MonitorFromWindow(hwnd, MONITOR_DEFAULTTOPRIMARY);
    if (::GetWindowPlacement(hwnd, &g_prev_window_placement) &&
        ::GetMonitorInfo(monitor, &mi)) {
      ::SetWindowLong(hwnd, GWL_STYLE, style & ~WS_OVERLAPPEDWINDOW);
      ::SetWindowPos(hwnd, HWND_TOP,
                     mi.rcMonitor.left, mi.rcMonitor.top,
                     mi.rcMonitor.right - mi.rcMonitor.left,
                     mi.rcMonitor.bottom - mi.rcMonitor.top,
                     SWP_NOOWNERZORDER | SWP_FRAMECHANGED);
      LogStartup("Entered native fullscreen mode");
    }
  } else {
    ::SetWindowLong(hwnd, GWL_STYLE, style | WS_OVERLAPPEDWINDOW);
    ::SetWindowPlacement(hwnd, &g_prev_window_placement);
    ::SetWindowPos(hwnd, nullptr, 0, 0, 0, 0,
                   SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER |
                   SWP_NOOWNERZORDER | SWP_FRAMECHANGED);
    LogStartup("Exited native fullscreen mode");
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
      ::SendMessage(hwnd, WM_NCLBUTTONDOWN, HTCAPTION, 0);
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
        } else if (const auto* map = std::get_if<flutter::EncodableMap>(call.arguments())) {
          auto it = map->find(flutter::EncodableValue("isFullScreen"));
          if (it != map->end() && std::holds_alternative<bool>(it->second)) {
            fullscreen = std::get<bool>(it->second);
          }
        }
      }
      ApplyFullScreenMode(hwnd, fullscreen);
      result->Success(flutter::EncodableValue(true));
    } else if (method == "isFullScreen") {
      result->Success(flutter::EncodableValue(g_is_window_fullscreen));
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
    ArmDisplayRecoveryWatchdog();
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
