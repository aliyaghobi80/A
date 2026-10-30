# Markazi System Checker — Engineering Guide

## Product goal

Markazi System Checker is a Windows technician tool for hardware verification,
invoice/QC checks, offline software deployment, and sequential driver
installation. The UI is Flutter/GetX and the local Windows service is Python.

## Repository map

- `frontend/`: Flutter Windows UI, controllers, services, and widget tests.
- `backend/`: hardware collectors, software/driver scanners, installers, and API.
- `config/`: technician-selectable package and requirement configuration.
- `installer/`: Inno Setup definition.
- `docs/`: release validation notes and operational documentation.
- `build_production.py`: builds the backend, Flutter release, portable folder,
  portable ZIP, and installer.

## Required checks

Run these before a release:

```powershell
py -3 -m unittest discover -s backend/tests -p "test_*.py"
cd frontend
flutter analyze
flutter test
```

Tests must never install a real driver/application, change power settings,
disable Windows services, activate Windows/Office, or restart the computer.
Use fixtures and mocked process runners for every state-changing workflow.

## Driver deployment rules

- Scanning never executes a file.
- Treat the selected driver directory as the repository for the current device,
  but show matching information as guidance rather than silently dropping OEM
  components.
- Queue packages sequentially by default (1X) and expose every queue item's live state.
- In 2X mode, non-sensitive standalone EXE installers (audio, LAN, Wi-Fi, bluetooth,
  touchpad, card reader, etc.) run up to 2 concurrently using the deployment worker pool.
- MSI installers always run serially, one by one.
- Strict Barrier definitions: packages marked as barriers execute exclusively on Worker 1
  with zero concurrency. Strict barriers include:
  - MSI packages (`msiexec.exe`) and executable wrappers that invoke `msiexec`.
  - Graphics drivers (GPU: Intel, AMD, NVIDIA).
  - Core platform, Chipset, MEI, Serial IO, Storage/RST, and DPTF.
  - System runtimes (Visual C++, .NET Framework, DirectX).
  - Packages inherently requiring reboot.
  - Unknown or unswitched installers requiring interactive wizard confirmation.
- Pre-barrier drain rule & lookahead barrier brake:
  - Before Worker 1 launches a barrier, Worker 2 must drain and finish any active task.
  - When Worker 2 finishes an item, it inspects the next pending item; if the next item
    is a barrier, Worker 2 yields immediately so Worker 1 can execute the barrier without delay.
- Windows kernel mutex inspection:
  - The scheduler checks the `Global\_MSIExecute` mutex prior to launching any package
    invoking Windows Installer technology. If busy, the worker waits for idle release.
- Error 1618 retry policy (`ERROR_INSTALL_ALREADY_RUNNING`):
  - Bounded retry capped at maximum 2 retries (3 total attempts).
  - Uses exponential backoff (e.g. 3s, 7s) and waits for `Global\_MSIExecute` to become idle.
  - Enforces serial fallback (`is_barrier = True`) on retry to avoid subsequent mutex collisions.
  - An initial 1618 error must never be recorded as an immediate failure or cause an infinite loop.
- Queue workers must clear `is_running` in a `finally` path. A dead worker must
  be detected and repaired by the status endpoint so controls never remain
  locked indefinitely.
- Process tree termination:
  - Any installer that hangs or exceeds its watchdog timeout (300s default; 420s chipset; 600s GPU)
    is terminated cleanly along with its entire process tree using native `taskkill.exe /F /T /PID`.
- For a folder with several independent direct `.exe`/`.msi` installers and no
  cohesive INF package, queue every installer.
- Prefer a recognized OEM wrapper when a package is cohesive. Otherwise install
  the full INF tree with PnPUtil `/subdirs /install`.
- Extract supported archives (.zip, .rar, .7z, .cab) into isolated folders up to recursion
  depth 3 with zip-slip, archive bomb, and long-path protections, and rescan their contents.
- Only run explicitly trusted driver scripts such as `InstallPackage.bat` or
  `InstallStep.txt`-documented entry points. Never execute arbitrary scripts.
- Use vendor-documented silent switches where known. Unknown installers must not
  receive guessed destructive switches (zero guessed switches policy; empty `[]` silent_args).
- Never select “Restart now”. Suppress installer restarts where supported and
  show a single reminder after the queue finishes so the technician can restart
  manually.
- GUI autopilot:
  - Window focus independent; controls only the launched installer process tree, an owned
    dialog, or a newly-created helper inside the selected package directory. Generic titles
    such as `Setup` are never ownership evidence.
  - Advance only safe installer states (`Next`, license acceptance, `Install`,
    success `OK`, `Finish`, `Close`) one action at a time. Never interpret
    maintenance actions such as Uninstall/Remove/Repair as installation.
  - Use bounded window messages so a hung OEM dialog cannot freeze the queue, and
    do not advance to the next package while a tracked child wizard remains open.
- Do not queue firmware, BIOS flashers, uninstallers, diagnostics, or cleanup
  utilities as ordinary drivers.

## Driver installation ordering

Queue items are strictly sorted by priority before execution:
1. **Chipset / Platform** (`chipset`): Intel/AMD Core Chipset & Platform (Strict Barrier, Serial).
2. **Management Engine / System** (`system_mei`): Management Engine Interface / Serial IO / DPTF (Strict Barrier, Serial).
3. **Storage Controller** (`storage`): Rapid Storage Technology (RST) / NVMe / SATA RAID (Strict Barrier, Serial).
4. **Integrated GPU (iGPU)** (`gpu`): Intel UHD/Iris or AMD APU graphics (Strict Barrier, Serial).
5. **Discrete GPU (dGPU)** (`gpu`): NVIDIA GeForce/RTX/Quadro, AMD Radeon, or Intel Arc (Strict Barrier, Serial).
   - *GPU Topological & Vendor Priority*: iGPU always installs before dGPU. Vendor order: AMD → Intel → NVIDIA.
   - *Adrenalin Deduplication*: Unified APU+dGPU installer installs once and maps completion to both devices.
   - *Display Settle Delay*: A non-blocking delay of 5 to 8 seconds is enforced after GPU installations to allow the WDDM display reset to settle before starting the next package.
6. **Parallel-Safe Devices** (Eligible for 2X concurrent execution):
   - Wired LAN / Ethernet (`lan`)
   - Wireless Network (`wifi`)
   - Bluetooth Adapter (`bluetooth`)
   - Audio / Sound Card (`audio`)
   - Touchpad & Input (`touchpad`)
   - Card Reader (`card_reader`)
   - Camera & Webcams (`camera`)
   - USB 3.x / Thunderbolt (`usb`)
7. **Utility & Hotkeys** (`other`): OEM helper software, hotkey utilities (Parallel-Safe if switched, Barrier if unswitched).

## Software deployment rules

- Software scanning never executes a file. Scanning supports synthetic/mock
  fixtures for `H:\PROGRAM\` in automated test environments where `H:\` is not mounted.
- Deduplicate adjacent folder and `.rar` archive with identical names (prefer
  the extracted folder, prevent redundant archive extraction).
- Sort software installation queue strictly by package weight (lightweight utilities
  first: WinRAR, Firefox, VLC, KMPlayer, FDM before Chrome, Acrobat Reader, and Office).
- System runtimes (Visual C++ Redistributables, .NET Framework, DirectX) must
  always be installed before any dependent applications.
- Enforce strict allowlist for Microsoft Office: execute only `Setup_Office 2024.cmd`
  as a strict barrier with extended watchdog (600s). Exclude `Activator.cmd`,
  `Uninstall.cmd`, and older setup scripts (`Setup_Office 2021.cmd`, etc.) from automatic queueing.
- Windows 10/11 Home deployment restrictions: Office installation is disabled on Home;
  deploy desktop shortcuts only and keep policy reason visible.
- Manage KMS v6 strictly under activation rules (`activation_tools.py`), never as
  an ordinary software queue item.
- Exclude Windows Update Blocker (WUB) from automatic batch selection.
- Ignore directories or paths containing `"آموزش"` during package scanning.
- Zero guessed switches policy: unswitched installers run via GUI autopilot as
  strict barriers with empty `[]` `silent_args`.
- Apply 2X concurrency exclusively to verified parallel-safe standalone EXEs; enforce
  serial barrier execution on Worker 1 for MSI, Office, runtimes, and unswitched installers.
- Cache scan results and minimize inter-package delays unless child processes are running.

## Teamwork rules

- **Single file ownership**: Each file has exactly one owning subagent. No two agents may edit the same file concurrently.
- **Contract before coding**: Modules communicate exclusively through ratified contracts (`CONTRACT.md`), defining schemas, endpoints, concurrency invariants, and state models before implementation.
- **Staged integration sequence**: Strictly adhere to the integration flow:
  1. Milestone A: Contract & Architecture Ratification
  2. Milestones B, C, E (Parallel): Scanner/Profiler, Scheduler/GPU Subsystem, Native Graphics Recovery
  3. Milestone D: Flutter UI & Progress Panels
  4. Milestone F: Comprehensive Mocked Test Suite
  5. Milestone G: Documentation & Release Packaging
- **Zero regressions**: All existing tests must pass after every integration step without regression.

## UI and state rules

- Persian pages are RTL, but numbers, versions, serials, paths, and calculator
  inputs are explicitly LTR.
- Keep primary actions at least 44 px high and avoid duplicate actions.
- Single permanent singleton `InstallStateService` (`Get.put(..., permanent: true)`):
  Acts as the sole source of truth for software and driver queue state across all pages.
  Individual pages consume state reactively and do not manage polling lifecycles.
- Monotonic revisioning and timestamp ordering: Backend status endpoints must provide
  monotonic integer `state_revision` and POSIX `server_time`. UI drops any status
  payload where `state_revision` is strictly lower than the latest applied revision.
- Adaptive non-overlapping polling: Replaces fixed overlapping interval timers with
  a single active polling loop (500ms–800ms during active installations; 3000ms–5000ms when idle).
- Network resilience: Preserve last valid queue state across network/HTTP errors or
  timeouts, displaying a non-intrusive Persian reconnection notice
  («اتصال به سرویس قطع شد؛ در حال تلاش مجدد») without blanking or resetting item cards.
- Strict item state machine: Forward-only transitions (`pending` → `installing` →
  `completed` / `failed` / `skipped` / `interrupted`). Rollback to `pending` is permitted
  exclusively for Error 1618 retry (capped at 2 retries).
- Atomic persistence: Driver queue state (`driver_queue_state.json`) and software batch
  state (`software_queue_state.json`) are persisted atomically to `%LOCALAPPDATA%\MarkaziSystemChecker\`.
- Interrupted task reconciliation: Backend startup reconciles any unfinalized `installing`
  items to `interrupted` without automatic re-execution.
- Granular UI updates: Use immutable models, stable widget keys (`ValueKey`), and
  granular `Obx` rebuilding only modified fields.
- App settings navigation: Expand `ThemeLanguageController.setNavIndex` clamp to
  `index >= 0 && index <= 7` so the SettingsPage opens reliably from the sidebar.
- Driver selection is one source of truth in `DriverInstallController`; “select
  all” must toggle every currently scanned package on and off.
- The backend owns `system_info_cache.json`; the Flutter UI uses separately
  named cache files. Persist JSON with serialized/atomic replacement so startup
  scans, force refreshes, and renderer recovery cannot corrupt or overwrite a
  newer snapshot.
- Prefer Flutter's low-power graphics adapter on hybrid systems so installing a
  dedicated GPU driver does not invalidate the UI renderer. After a Windows
  display reset, the native runner must verify that a new frame is produced and
  recover only the UI process when necessary; never restart Windows.
- A replacement UI process must adopt the existing backend session during
  graphics recovery so an active sequential driver queue is not lost.
- Do not run a full hardware scan after every queue item. Update lightweight
  progress in real time, then refresh hardware once after the queue and allow a
  longer display-settle interval when a GPU package was involved.
- Splash progress reflects backend readiness and initial-data loading. Do not
  add a fixed minimum delay; only expose retry after genuine repeated failure.
- Check narrow desktop layouts as well as the normal technician workstation
  size. Prefer `Wrap`/`LayoutBuilder` over fixed-width rows.

## Custom in-app title bar rules

- Integrate custom title bar using `window_manager` on pub.dev.
- Embed controls (minimize, maximize/restore, close) directly into Flutter UI matching
  dark/light themes and RTL alignment (logo and title on the right, controls on the left).
- Support window dragging, double-click to maximize/restore, hover states (red close hover),
  and native Windows 11 snap layouts.
- Completely hide the title bar in fullscreen test modes.
- Preserve native runner display recovery watchdog (`kDisplayRecoveryTimeoutMs = 8000`),
  low-power GPU preference, and `--display-recovery-from` in `main.cpp` and `flutter_window.cpp`.

## Hardware diagnostic tests rules

- **Monitor & Pixel Test**: True fullscreen covering entire screen including taskbar
  and title bar (game-style fullscreen via `window_manager.setFullScreen(true)`); pure static
  solid colors (Black, White, Red, Green, Blue, secondary) with zero animations, gradients,
  shadows, or overlays during test; hide mouse cursor; show instructions only prior to
  entering fullscreen; navigate with arrow keys (`→`, `↑` for next; `←`, `↓` for prev) and
  `Esc` to exit and restore exact previous window geometry, state, and DPI across multi-monitor setups.
- **Keyboard Test**: Responsive key layout using `LayoutBuilder` / `FittedBox` scaled to
  viewport width; physical keycode detection via `PhysicalKeyboardKey` (differentiating
  Left/Right Shift/Ctrl/Alt, Numpad, Win, Menu, PrtSc, Pause); graceful handling and technician
  guidance for OS-intercepted keys; maintain key hit counter and reset button.
- **Audio & Headphones Test**: Synthesize standalone in-memory WAV tones (440Hz, 1kHz, sweep,
  pink noise) without external files or copyright dependencies; Left, Right, Both channel buttons;
  safe default volume (20%) with volume slider; audio output device selection and mute warning.
- **Microphone Test**: Real-time waveform/level meter, loopback recording controls (record,
  stop, playback, progress, re-record); save recordings strictly to temporary storage (`%TEMP%`)
  with automatic cleanup on exit; detect Windows privacy restrictions and provide direct link
  to `ms-settings:privacy-microphone`.
- **Webcam Test**: In-app live video preview via `camera_windows`, eliminating external
  Windows Camera app launch; device selector, mirror toggle, resolution picker, and temporary
  snapshot capture; link to `ms-settings:privacy-webcam`.
- **Mouse Test**: Detect and visually reflect button hold for Left, Middle, Right, and Side
  buttons until release; draggable mouse indicator; double-click detection (< 300ms);
  scroll tracking; cursor movement tracking; suppress context menu on right click.
- **Removed Report & Health Card Subtest**: Completely delete the unused "Health Card & Hardware Report"
  page, menu item, route, controller, and associated export/print/PDF/CSV code; decouple and
  preserve the top QC Report button.

## Activation and storage rules

- Combine independent official Windows licensing signals. A positive Licensed
  result from one source must not be overwritten by a stale negative result
  from another source.
- License status is live data: refresh it through `/api/activation/status`
  instead of waiting for a full hardware rescan.
- Windows 10/11 Home follows the product's original-Windows policy: activation
  and Office deployment actions are disabled and the reason stays visible.
- For the technician-provided KMS v6 bundle on non-Home Windows, prefer its
  documented elevated unattended arguments (`/u /w` for Windows and `/u /o`
  for Office) over redirected menu input. Verify success through official
  license probes, not the script exit code, and remove only the generated
  activation log after verification.
- Batch activation requires explicit `include_activation: true`, defaults off,
  and is rechecked by the worker. Home still forbids it even with opt-in.
  API contract 3 is required so an old backend cannot ignore this opt-out.
- Desktop icons may only be enabled after consolidated Windows activation has
  been confirmed.
- Removable USB media is never listed as an internal disk. Internal capacity
  usage is derived from volumes mapped to the same physical disk.
- Safe eject validates that the requested drive is currently removable, waits
  for the mount point to disappear, and reports failure instead of claiming a
  successful eject while the drive remains mounted.

## Release version

Keep these values synchronized: `frontend/pubspec.yaml` (`1.1.45+46`),
`backend/api_server.py` (`1.1.45`, API Contract `5`), `installer/setup.iss` (`1.1.45`),
and `build_production.py` (`1.1.45`). Production artifacts belong in `dist/` and must
include the installer, portable directory, and versioned ZIP.
