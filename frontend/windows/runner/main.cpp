#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"
#include "startup_log.h"
#include <bitsdojo_window_windows/bitsdojo_window_plugin.h>

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  LogStartup("Starting Markazi System Checker");
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");
  // Prefer the integrated/low-power adapter on hybrid laptops. A dedicated
  // NVIDIA/AMD driver installer can reset its adapter mid-install; keeping the
  // technician UI on the integrated adapter prevents the renderer from being
  // taken down with it. Flutter automatically falls back when only one adapter
  // is available.
  project.set_gpu_preference(flutter::GpuPreference::LowPowerPreference);
  LogStartup("Low-power GPU preference enabled for driver-install resilience");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  // Configure bitsdojo_window to take over the native frame and hide
  // the window until the Flutter first frame is ready. This must be
  // called before window.Create().
  bitsdojo_window_configure(BDW_CUSTOM_FRAME | BDW_HIDE_ON_STARTUP);

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 780);
  if (!window.Create(L"Markazi System Checker", origin, size)) {
    LogStartup("Native window creation failed");
    MessageBoxW(nullptr, L"Unable to initialize the application window.\n"
        L"Check the graphics driver and the startup.log in\n"
        L"%LOCALAPPDATA%\\MarkaziSystemChecker\\logs.",
        L"Markazi System Checker", MB_OK | MB_ICONERROR);
    ::CoUninitialize();
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
