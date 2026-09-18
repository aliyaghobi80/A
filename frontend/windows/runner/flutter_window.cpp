#include "flutter_window.h"

#include <optional>

#include "flutter/generated_plugin_registrant.h"
#include "startup_log.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

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

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    KillTimer(GetHandle(), 1);
    LogStartup("First Flutter frame rendered");
    this->Show();
  });
  SetTimer(GetHandle(), 1, 30000, nullptr);

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  KillTimer(GetHandle(), 1);
  LogStartup("Window closed");
  // The backend's parent watchdog owns process cleanup. Never kill other
  // sessions' backend processes by image name.

  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
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
