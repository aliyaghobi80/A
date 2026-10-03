#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>

#include <atomic>
#include <memory>
#include <thread>

#include "win32_window.h"

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  void ArmDisplayRecoveryWatchdog();
  void StartDisplayRecoveryWatchdog();
  void StopDisplayRecoveryWatchdog();
  void RelaunchAfterDisplayReset();

  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;

  // GPU installers can invalidate ANGLE's D3D device. If a forced frame is not
  // produced after Windows announces a display reset, restart only the UI; the
  // detached backend and its sequential install queue are adopted by the new
  // process and continue uninterrupted.
  std::atomic<bool> first_frame_rendered_{false};
  std::atomic<bool> display_recovery_pending_{false};
  std::atomic<bool> recovery_relaunch_started_{false};
  std::atomic<unsigned long long> display_recovery_deadline_ms_{0};
  std::atomic<unsigned long long> display_generation_{0};
  std::atomic<bool> recovery_watchdog_stop_{false};
  // Win32Window can destroy/recreate a temporary HWND while the Flutter host
  // is being initialized. Only WM_CLOSE marks an actual user/app exit.
  std::atomic<bool> close_requested_{false};
  std::thread recovery_watchdog_thread_;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
