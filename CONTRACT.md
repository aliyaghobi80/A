# Markazi System Checker — Interface Contract & Technical Specifications

**Contract Version**: 5  
**Target Application Version**: 1.1.45 (Build 1.1.45+46)  
**Status**: Official Specification (Ratified by System Contract Architect)  
**Scope**: Backend API Server, Driver Engine, Software Batch Deployment, Concurrency Scheduler, Package Profiler, Hardware Diagnostic Subsystems, Custom Window Frame, State Management Service, and Flutter Frontend.

---

## 1. Release Descriptors & Version Alignment Contract

All four release descriptors across the repository must remain strictly synchronized to the values below:

| Target File | Variable / Key | Target Value | Verification Check |
|---|---|---|---|
| `backend/api_server.py` | `APP_VERSION` & `/api/health` `version` | `"1.1.45"` | `GET /api/health` returns `"version": "1.1.45"` |
| `backend/api_server.py` | `/api/health` `api_contract_version` | `5` | `GET /api/health` returns `"api_contract_version": 5` |
| `backend/api_server.py` | `/api/health` `phase` | `5` | `GET /api/health` returns `"phase": 5` |
| `frontend/pubspec.yaml` | `version` | `1.1.45+46` | `flutter pub get` & `flutter test` |
| `installer/setup.iss` | `#define MyAppVersion` | `"1.1.45"` | Inno Setup compile check |
| `build_production.py` | `APP_VERSION` | `"1.1.45"` | `py build_production.py --help` / build logs |

> **Ownership Rule**: Modification of these 4 release descriptor files is exclusively owned by the Integrator Agent during Phase 7 / Milestone G integration.

---

## 2. Status Polling Schema & Monotonic Sequence Model

### 2.1 Monotonic Sequence Contract

Both Driver Queue Status and Software Batch Status endpoints must provide monotonic ordering primitives to prevent UI flickering, out-of-order race conditions, and status reversion:

1. **`state_revision`** (`integer`, mandatory, `>= 1`):
   - Initialized to `1` when a queue session is created or restored.
   - Strictly incremented by at least `+1` on **every internal state mutation**:
     - Queue initialization, start, pause, resume, cancellation, or completion.
     - Item state transition (`pending` → `installing` → `completed` / `failed` / `skipped` / `interrupted`).
     - Worker assignment or release.
     - Error 1618 retry re-queueing.
     - Dead worker recovery.
     - Progress percent update or elapsed time tick.
     - Reconciled state update upon backend startup.
   - The value is strictly monotonic and never decrements or rolls back during the lifetime of a queue session.
2. **`server_time`** (`float`, mandatory):
   - High-resolution POSIX epoch timestamp (`time.time()`).
   - Captured under lock at the exact instant the status response snapshot is constructed.
3. **`api_contract_version`** (`integer`, mandatory):
   - Set to `5`.

### 2.2 Endpoint Routing Alignment

The backend HTTP server (`backend/api_server.py`) must route the following canonical and aliased paths:
- **Driver Queue Status**:
  - `GET /api/drivers/queue/status` (Canonical)
  - `GET /api/drivers/batch-status` (Backward-compatible alias)
  - `GET /api/drivers/install/status` (Forward-compatible alias)
- **Software Batch Status**:
  - `GET /api/packages/batch-status` (Canonical)
  - `GET /api/software/install/status` (Forward-compatible alias)

### 2.3 Driver Queue Status Schema (`GET /api/drivers/queue/status`)

```json
{
  "api_contract_version": 5,
  "state_revision": 42,
  "server_time": 1729000150.125,
  "status": "ok",
  "is_running": true,
  "cancelled": false,
  "mode": "2X",
  "double_speed": true,
  "worker_count": 2,
  "active_workers": 2,
  "total": 6,
  "completed": 2,
  "failed": 0,
  "skipped": 0,
  "interrupted": 0,
  "current_index": 2,
  "current_package": "Realtek Audio Driver • Intel Wi-Fi Driver",
  "current_file": "Realtek Audio Driver • Intel Wi-Fi Driver",
  "progress_percent": 33.3,
  "start_time": 1729000080.0,
  "end_time": null,
  "reboot_required": false,
  "summary_message": "در حال نصب موازی ۲ درایور...",
  "resolved_devices_count": 0,
  "last_update_time": 1729000112.8,
  "worker_alive": true,
  "fatal_error": "",
  "active_items": [
    {
      "package_id": "drv_pkg_a1b2c3d4",
      "display_name": "Realtek High Definition Audio Driver",
      "category": "audio",
      "worker_id": 1,
      "status": "installing",
      "start_time": 1729000100.5,
      "elapsed_seconds": 12.3,
      "retry_count": 0
    },
    {
      "package_id": "drv_pkg_e5f60718",
      "display_name": "Intel Wi-Fi 6 AX201 Driver",
      "category": "wifi",
      "worker_id": 2,
      "status": "installing",
      "start_time": 1729000104.2,
      "elapsed_seconds": 8.6,
      "retry_count": 0
    }
  ],
  "items": [
    {
      "package_id": "drv_pkg_1111",
      "display_name": "Intel Chipset Device Software",
      "category": "chipset",
      "category_fa": "چیپست و مدیریت پلتفرم",
      "installer_file": "SetupChipset.exe",
      "status": "completed",
      "worker_id": null,
      "message": "نصاب درایور با موفقیت اجرا و نصب شد.",
      "failure_reason": null,
      "exit_code": 0,
      "retry_count": 0,
      "elapsed_seconds": 18.2
    },
    {
      "package_id": "drv_pkg_a1b2c3d4",
      "display_name": "Realtek High Definition Audio Driver",
      "category": "audio",
      "category_fa": "کارت صدا و مالتی‌مدیا",
      "installer_file": "setup.exe",
      "status": "installing",
      "worker_id": 1,
      "message": "در حال نصب...",
      "failure_reason": null,
      "exit_code": null,
      "retry_count": 0,
      "elapsed_seconds": 12.3
    },
    {
      "package_id": "drv_pkg_e5f60718",
      "display_name": "Intel Wi-Fi 6 AX201 Driver",
      "category": "wifi",
      "category_fa": "شبکه بی‌سیم (Wi-Fi)",
      "installer_file": "Setup.exe",
      "status": "installing",
      "worker_id": 2,
      "message": "در حال نصب...",
      "failure_reason": null,
      "exit_code": null,
      "retry_count": 0,
      "elapsed_seconds": 8.6
    },
    {
      "package_id": "drv_pkg_2222",
      "display_name": "NVIDIA Graphics Driver",
      "category": "gpu",
      "category_fa": "کارت گرافیک",
      "installer_file": "setup.exe",
      "status": "pending",
      "worker_id": null,
      "message": "",
      "failure_reason": null,
      "exit_code": null,
      "retry_count": 0,
      "elapsed_seconds": 0.0
    }
  ]
}
```

### 2.4 Software Batch Status Schema (`GET /api/packages/batch-status`)

```json
{
  "api_contract_version": 5,
  "state_revision": 19,
  "server_time": 1729000155.450,
  "is_running": true,
  "cancelled": false,
  "total": 5,
  "completed": 2,
  "failed": 0,
  "skipped": 0,
  "interrupted": 0,
  "reboot_required": false,
  "current_item_name": "Google Chrome",
  "current_item_index": 2,
  "progress_percent": 40.0,
  "start_time": 1729000120.0,
  "end_time": null,
  "summary_message": "در حال نصب نرم‌افزار ۲ از ۵: Google Chrome",
  "items": [
    {
      "id": "pkg_winrar_x64",
      "name": "WinRAR 7.01",
      "status": "completed",
      "progress_percent": 100.0,
      "is_barrier": false,
      "stage": "done",
      "error_message": null,
      "exit_code": 0,
      "retry_count": 0,
      "elapsed_seconds": 4.1
    },
    {
      "id": "pkg_vlc_media_player",
      "name": "VLC Media Player 3.0.21",
      "status": "completed",
      "progress_percent": 100.0,
      "is_barrier": false,
      "stage": "done",
      "error_message": null,
      "exit_code": 0,
      "retry_count": 0,
      "elapsed_seconds": 11.5
    },
    {
      "id": "pkg_chrome_standalone",
      "name": "Google Chrome",
      "status": "installing",
      "progress_percent": 50.0,
      "is_barrier": false,
      "stage": "installing",
      "error_message": null,
      "exit_code": null,
      "retry_count": 0,
      "elapsed_seconds": 15.2
    },
    {
      "id": "pkg_vcredist_bundle",
      "name": "Visual C++ All-in-One",
      "status": "pending",
      "progress_percent": 0.0,
      "is_barrier": true,
      "stage": "waiting",
      "error_message": null,
      "exit_code": null,
      "retry_count": 0,
      "elapsed_seconds": 0.0
    },
    {
      "id": "pkg_office_2024",
      "name": "Microsoft Office 2024 Pro Plus",
      "status": "pending",
      "progress_percent": 0.0,
      "is_barrier": true,
      "stage": "waiting",
      "error_message": null,
      "exit_code": null,
      "retry_count": 0,
      "elapsed_seconds": 0.0
    }
  ]
}
```

### 2.5 Item State Transition Machine

All queue items (driver and software) adhere strictly to the forward state machine:

```
                  ┌──────────────┐
                  │   pending    │
                  └──────┬───────┘
                         │
                         ▼
                  ┌──────────────┐
       ┌─────────►│  installing  ├──────────┐
       │          └──────┬───────┘          │
       │                 │                  │
(Error 1618 retry        │                  │
 capped at 2)            ▼                  │ (Backend shutdown / crash)
       │          ┌──────────────┐          │
       └──────────┤ 1618 Retry   │          ▼
                  └──────────────┘   ┌──────────────┐
                         │           │ interrupted  │
                         ▼           └──────────────┘
            ┌────────────────────────────┐
            │ Terminal States:           │
            │  - completed               │
            │  - failed                  │
            │  - skipped                 │
            └────────────────────────────┘
```

#### State Machine Invariants:
1. **Forward Only**: Allowed transitions:
   - `pending` → `installing`
   - `installing` → `completed`
   - `installing` → `failed`
   - `installing` → `skipped`
   - `installing` → `interrupted` (upon service restart)
   - `pending` → `skipped` (user cancellation before execution)
   - `pending` → `interrupted` (service shutdown before item execution)
2. **Error 1618 Exception**: The backward transition `installing` → `pending` is permitted **exclusively** when an installer exits with error `1618` (`ERROR_INSTALL_ALREADY_RUNNING`), capped at maximum 2 retries. On rollback, `is_barrier` is forced to `true`.
3. **Terminal Invariance**: Once an item reaches `completed`, `failed`, `skipped`, or `interrupted`, its status is immutable for that queue run. Any payload attempting to transition an item out of a terminal state must be rejected and logged as an error.

### 2.6 Interrupted Status Model & Startup Reconciliation

When the backend service restarts or crashes mid-installation:
- Items marked `installing` or unexecuted `pending` items in a persisted active session must **never** resume execution automatically.
- The startup recovery routine parses the persisted state file.
- Every item with `status == "installing"` is transitioned to `status = "interrupted"` with message:
  `"فرآیند نصب به دلیل بسته شدن یا راه‌اندازی مجدد سرویس متوقف شد."`
- The queue's `is_running` flag is set to `false`.
- The `interrupted` counter is populated.
- `state_revision` is incremented.

---

## 3. InstallStateService Model & Reactive Lifecycle Contract

### 3.1 Architecture Overview

A single permanent singleton service `InstallStateService` registered via `Get.put(InstallStateService(), permanent: true)` in `main.dart`:
- Acts as the **sole source of truth** for all driver and software deployment states in Flutter.
- Eliminates page-level polling timers (`_pollTimer`, `_batchPollTimer`, `_periodicSyncTimer`).
- Manages an adaptive non-overlapping loop that queries backend status.
- Discards out-of-order responses using monotonic `state_revision`.
- Retains last valid state across transient network drops and displays a non-intrusive reconnection banner.

### 3.2 State Service Observables & Properties

```dart
class InstallStateService extends GetxService {
  // Observables
  final Rx<DriverBatchStatus> driverStatus = DriverBatchStatus.empty().obs;
  final Rx<BatchInstallStatus> softwareStatus = BatchInstallStatus.empty().obs;
  final RxBool isDriverRunning = false.obs;
  final RxBool isSoftwareRunning = false.obs;
  final RxBool isDisconnected = false.obs;
  final RxString disconnectionMessage = ''.obs;

  // Monotonic Revision Trackers
  int _latestDriverRevision = 0;
  int _latestSoftwareRevision = 0;

  // Polling Management
  bool _isPollingActive = false;
  static const Duration _activeInterval = Duration(milliseconds: 600);
  static const Duration _idleInterval = Duration(milliseconds: 4000);
}
```

### 3.3 Out-of-Order Stale Response Guard

Upon receiving an HTTP status response:
```dart
void applyDriverStatus(Map<String, dynamic> json) {
  final int incomingRevision = json['state_revision'] ?? 0;
  if (incomingRevision < _latestDriverRevision) {
    logger.w('Dropped stale driver status frame: incoming $incomingRevision < latest $_latestDriverRevision');
    return; // DISCARD STALE FRAME
  }
  _latestDriverRevision = incomingRevision;
  isDisconnected.value = false;
  // Apply state update reactively
}
```

### 3.4 Adaptive Non-Overlapping Polling Loop

- Operates as a single async loop awaiting the in-flight request before scheduling the next tick via `Future.delayed`.
- **Active Interval**: 500ms – 800ms when `isDriverRunning.value || isSoftwareRunning.value`.
- **Idle Interval**: 3000ms – 5000ms when all queues are idle.
- If a network request times out or throws `SocketException`, `ClientException`, or 5xx:
  - Do NOT reset `driverStatus` or `softwareStatus`.
  - Set `isDisconnected.value = true`.
  - Floating reconnection banner is displayed: `«اتصال به سرویس قطع شد؛ در حال تلاش مجدد»`.
  - Polling continues attempting reconnection with idle backoff.
  - Upon successful reconnection, `isDisconnected.value = false`, and state is smoothly reconciled.

### 3.5 Granular Obx Rebuilding & Stable Keys

- Screens and cards must avoid wrapping entire pages in monolithic `Obx`.
- Only leaf state widgets (status badges, progress bars, time elapsed, log drawers) use targeted `Obx`.
- Every card must specify an explicit stable key:
  - Driver cards: `ValueKey('driver-queue-${item.packageId}')`
  - Software cards: `ValueKey('software-item-${item.id}')`

---

## 4. Atomic State Persistence & Startup Reconciliation Contract

### 4.1 Persistence File Specifications

State files are located in Windows application data directories:
- **Driver Queue State**: `%LOCALAPPDATA%\MarkaziSystemChecker\driver_queue_state.json`
- **Software Batch State**: `%LOCALAPPDATA%\MarkaziSystemChecker\software_queue_state.json`
- Fallback paths: `%APPDATA%\MarkaziSystemChecker\` or `C:\ProgramData\MarkaziSystemChecker\`.

### 4.2 Atomic Replacement Protocol

To guarantee crash resilience and prevent file corruption during power cuts or GPU display resets:
```python
def persist_state_atomic(state_dict: dict, file_path: str) -> None:
    temp_path = f"{file_path}.tmp"
    os.makedirs(os.path.dirname(file_path), exist_ok=True)
    with open(temp_path, "w", encoding="utf-8") as f:
        json.dump(state_dict, f, ensure_ascii=False, indent=2)
        f.flush()
        os.fsync(f.fileno())
    os.replace(temp_path, file_path)
```

### 4.3 Startup Reconciliation Protocol

Upon module initialization (`queue_manager.py` and `batch_installer.py`):
1. Check if the persistence file exists.
2. Read and parse JSON.
3. If `is_running == true`:
   - Reconcile any item with `status == "installing"` or `status == "pending"` to `status = "interrupted"`.
   - Set `is_running = false`, `cancelled = true`.
   - Set `summary_message = "فرآیند قبلی به دلیل بسته شدن ناگهانی سرویس متوقف شد."`.
   - Increment `state_revision += 1`.
   - Persist reconciled state atomically back to disk.
4. If `is_running == false`:
   - Keep completed/failed state available in memory for UI adoption upon launch.

---

## 5. Custom In-App Title Bar & Native Windows Runner Contract

### 5.1 Package Evaluation & Selection: `window_manager`

| Criteria | `bitsdojo_window` | `window_manager` (Ratified) |
|---|---|---|
| **pub.dev Status** | Discontinued / Unmaintained (>2 years) | Actively maintained, Flutter Favorite candidate |
| **Flutter 3.x Support** | Broken build on modern Flutter Windows C++ engine | Full support for Flutter 3.12+ through 3.24+ |
| **Native C++ Hooking** | Replaces Win32 `wWinMain` creation & message loop | Clean platform channel; leaves `flutter_window.cpp` intact |
| **Display Recovery Watchdog**| Breaks custom watchdog and frame verification | **100% compatible**; watchdog timer remains unharmed |
| **Windows 11 Snap Layouts** | Buggy / non-functional caption button hits | Native `WM_NCHITTEST` snap layout menu on Maximize hover |
| **Fullscreen Mode** | Requires manual Win32 style bits stripping | Clean `setFullScreen(true/false)` API |

### 5.2 Native Runner Invariants (Owned Exclusively by Native Agent)

The following native capabilities in `frontend/windows/runner/` must remain strictly preserved:
1. **Low-Power GPU Preference (`main.cpp`)**:
   ```cpp
   project.set_gpu_preference(flutter::GpuPreference::LowPowerPreference);
   ```
   Ensures Flutter renders on the integrated GPU (iGPU) on hybrid laptops, surviving dedicated GPU driver resets.
2. **Display Recovery Watchdog (`flutter_window.cpp`)**:
   - `StartDisplayRecoveryWatchdog()`, `ArmDisplayRecoveryWatchdog()`, `kDisplayRecoveryTimeoutMs = 8000`.
   - If rendering hangs for > 8 seconds following a WDDM display reset, the watchdog relaunches the UI:
     `MarkaziSystemChecker.exe --display-recovery-from=<old_pid>`.
   - The replacement UI process adopts the active backend session without interrupting running installer queues.

### 5.3 Custom Title Bar UI Invariants

- Positioned at the very top of `DashboardScreen` / `Scaffold`.
- Height: 36px – 40px.
- RTL Alignment:
  - **Right**: Application Logo and Persian Title (`سامانه بررسی و نصب مرکزی`).
  - **Center**: Window dragging region (`DragToMoveArea` or `window_manager.startDragging()`).
  - **Left**: Minimize (`_`), Maximize/Restore (`□`), and Close (`✕`) buttons.
- Close button hover turns red (`#E81123`).
- Double-clicking title bar toggles maximize / restore.
- **Fullscreen Hiding Invariant**: When Monitor Test enters fullscreen, the Custom Title Bar must be completely hidden (`visibility: false` or unmounted).

---

## 6. Modernized Hardware Diagnostic Tests Contracts

### 6.1 Monitor & Pixel Test
- **True Game Fullscreen**: Calls `window_manager.setFullScreen(true)`, completely covering Windows Taskbar and Title Bar.
- **Pure Static Solids**: Displays only pure solid colors:
  - Black (`#000000`)
  - White (`#FFFFFF`)
  - Pure Red (`#FF0000`)
  - Pure Green (`#00FF00`)
  - Pure Blue (`#0000FF`)
  - Optional secondary: Cyan (`#00FFFF`), Magenta (`#FF00FF`), Yellow (`#FFFF00`).
- **Zero Artifacts**: Zero animations (`duration: Duration.zero`), zero gradients, zero shadows, zero text/overlays while in fullscreen test mode.
- **Cursor Hidden**: `MouseRegion(cursor: SystemMouseCursors.none)`.
- **Pre-Test Instructions**: Guidance shown exclusively on hub card before entering fullscreen.
- **Navigation**:
  - Next Color: `→` (`arrowRight`), `↑` (`arrowUp`), Space, Left Mouse Click.
  - Previous Color: `←` (`arrowLeft`), `↓` (`arrowDown`), Right Mouse Click.
  - Exit: `Esc` (`escape`).
- **Restoration Invariant**: On Esc, calls `setFullScreen(false)`, restoring exact previous window bounds, state, and DPI scaling across multi-monitor setups.

### 6.2 Keyboard Test
- **Responsive Layout**: Wrapped in `LayoutBuilder` / `FittedBox` scaling dynamically to viewport width without horizontal overflow.
- **Physical Keycode Detection**: Uses `event.physicalKey` (`PhysicalKeyboardKey`) to distinguish:
  - `shiftLeft` vs `shiftRight`
  - `controlLeft` vs `controlRight`
  - `altLeft` vs `altRight`
  - Dedicated Numpad keys (`numpad0`-`numpad9`, `numpadAdd`, `numpadEnter`, etc.)
  - System keys: `metaLeft`, `contextMenu`, `printScreen`, `pause`, `scrollLock`.
- **OS-Intercepted Keys Guidance**: Informative Persian note explaining keys captured by Windows (`Win`, `Ctrl+Alt+Del`, `Alt+Tab`).
- **Hit Counters**: Real-time counter for each key, total keystroke counter, and a "پاک‌سازی / Reset" button.

### 6.3 Audio & Headphones Test
- **In-Memory Synthesized WAV**: Uses Python backend standard library (`math`, `struct`, `wave`, `io`, `winsound`) to generate:
  - 440 Hz standard concert pitch sine tone.
  - 1000 Hz (1 kHz) reference test tone.
  - 40 Hz to 120 Hz bass frequency sweep.
  - Pink noise (1/f filter approximation).
- Standalone: Zero external audio files or copyright media.
- Channel Routing: Buttons for `Left Only`, `Right Only`, and `Both Channels`.
- Safe Default Volume: Default 20% (0.2), slider range 1% to 60%.
- Windows mute warning badge and output device selector.

### 6.4 Microphone Test
- **Real-Time Level Meter**: Visual waveform / amplitude meter showing live mic input.
- **Temporary Loopback Test**: Record button, Stop button, Play/Pause, Progress bar, and Re-record.
- **Storage Hygiene**: Recorded WAV files saved strictly to `%TEMP%\markazi_mic_*.wav` and deleted immediately upon exiting the test or closing the app.
- **Privacy Detection**: Detects Windows microphone privacy blocks and provides direct URI shortcut to `ms-settings:privacy-microphone`.

### 6.5 Webcam Test
- **In-App Live Video**: Direct live camera preview in Flutter using `camera_windows` (eliminating external `microsoft.windows.camera:` launch).
- **Controls**: Device selector dropdown, mirror toggle, resolution picker, and temporary snapshot capture.
- **Privacy Detection**: Handles camera permission blocks with direct link to `ms-settings:privacy-webcam`.

### 6.6 Mouse Test
- **Button Hold Detection**: Listens to pointer down/up events to reflect sustained hold for Left, Middle, Right, Side 1 (Back), Side 2 (Forward).
- **Draggable Mouse Visual**: Canvas indicator tracking cursor position.
- **Double-Click Detection**: Detects double-clicks (< 300ms interval) with visual counter.
- **Scroll Tracking**: Directional scroll velocity and distance meter.
- **Context Menu Suppression**: Blocks Win32 right-click context menu within test area.

### 6.7 Complete Deletion of "Report & Health Card" Subtest
- **Files Deleted**:
  - `frontend/lib/widgets/hardware_tests/test_report_view.dart`
  - `frontend/lib/models/hardware_test_result.dart`
- **Controller & UI Cleanup**:
  - `HardwareTestController`: Remove `activeSubTest == 'report'`, `testResults`, `recordResult()`, `clearResults()`, `getFormattedReport()`.
  - `HardwareTestsPage`: Remove `case 'report': return const TestReportView()`.
  - `app_sidebar.dart`: Remove `report` sub-item under Hardware Tests accordion.
  - `test_hub_view.dart`: Remove `کارنامه و گزارش تست‌ها` card.
  - All test views: Remove "ثبت سلامت در کارنامه" and "ثبت ایراد" buttons.
- **QC Decoupling**: Keep top `گزارش QC` button (`qcCtrl.runFullCheck(context)` in `GlobalAppHeader`) and `qc_controller.dart` intact.

---

## 7. App Settings Navigation Fix Contract

### 7.1 Root Cause & Invariant Fix
- In `frontend/lib/controllers/theme_language_controller.dart`:
  ```dart
  // Previous bug:
  void setNavIndex(int index) {
    if (index >= 0 && index <= 6) { // BUG: Rejected SettingsPage (index 7)
      activeNavIndex.value = index;
    }
  }
  ```
- **Contract Ratification**:
  ```dart
  void setNavIndex(int index) {
    if (index >= 0 && index <= 7) {
      activeNavIndex.value = index;
    }
  }
  ```
- `DashboardScreen` in `frontend/lib/main.dart` maps index 7 to `SettingsPage`.
- Automated widget test must verify clicking "تنظیمات برنامه" in sidebar switches `activeNavIndex` to 7 and renders `SettingsPage`.

---

## 8. Software Scanner, Queue Ordering & Optimization Contract

### 8.1 Scanner Safety & Synthetic Fixtures
- Scans `H:\PROGRAM\` or configured custom directory.
- Read-only: Zero executable binaries launched during scan.
- Test environments without `H:\` mounted use synthetic directory trees (`tempfile.mkdtemp()`).

### 8.2 Adjacent Folder vs Archive (.rar) Deduplication
When scanning `H:\PROGRAM\`:
- If an extracted folder `X\` and an adjacent archive `X.rar` (or `.zip`, `.7z`) exist in the same directory:
  - The extracted folder `X\` is preferred.
  - The archive `X.rar` is excluded from the scanned package list.
  - Redundant decompression is completely avoided.

### 8.3 Weight-Based Installation Queue Ordering

Software packages in `backend/packages/batch_installer.py` must be sorted strictly by package weight and dependency tiers:

| Tier | Priority Tier | Included Software Packages | Concurrency & Barrier Classification |
|---|---|---|---|
| **Tier 1** | **Lightweight Utilities** | WinRAR, Mozilla Firefox, VLC Media Player, KMPlayer, Free Download Manager (FDM) | Parallel-Safe (2X eligible if switched) |
| **Tier 2** | **System Runtimes** | Visual C++ Redistributable All-in-One, .NET Framework, DirectX Runtimes | **Strict Barrier** (Serial, Worker 1) |
| **Tier 3** | **Heavyweight Applications** | Google Chrome, Adobe Acrobat Reader, Large productivity tools | Parallel-Safe or Barrier depending on switches |
| **Tier 4** | **Office Suite (Final Barrier)** | `Setup_Office 2024.cmd` | **Strict Barrier** (Serial, Worker 1, 600s watchdog) |

> **Dependency Rule**: Tier 2 (System Runtimes) must **always** install prior to any dependent application in Tier 3 or 4.

### 8.4 Microsoft Office Allowlist & Home Guard
- **Strict Allowlist**: Exclusively queue `Setup_Office 2024.cmd`.
- **Excluded**: `Activator.cmd`, `Uninstall.cmd`, and older setup scripts (`Setup_Office 2021.cmd`, etc.) are strictly excluded from automatic queueing.
- **Windows Home Guard**: If running on Windows 10/11 Home, Office deployment is completely disabled; only desktop shortcuts are deployed.

### 8.5 KMS v6 & Directory Exclusion
- **KMS v6**: Managed strictly under activation rules (`activation_tools.py`), never as a software package.
- **Windows Update Blocker (WUB)**: Excluded from automatic batch selection.
- **Tutorial Directory Exclusion**: Any folder containing `"آموزش"` is ignored during scanning.

### 8.6 Concurrency & Silent Switches
- 2X concurrency applies exclusively to verified parallel-safe standalone EXEs with documented silent switches.
- MSI packages, Office, runtimes, and unswitched installers execute as strict serial barriers on Worker 1.
- Zero guessed switches: unswitched installers execute via GUI autopilot as barriers.

---

## 9. Driver Deployment Engine & Scheduler Specifications

### 9.1 Priority Tiers (9 Tiers)
1. **Chipset / Platform** (`chipset`): Intel/AMD Core Chipset & Platform (Strict Barrier, Serial).
2. **Management Engine / System** (`system_mei`): MEI / Serial IO / DPTF (Strict Barrier, Serial).
3. **Storage Controller** (`storage`): RST / NVMe / SATA RAID (Strict Barrier, Serial).
4. **Integrated GPU (iGPU)** (`gpu`): Intel UHD/Iris or AMD APU graphics (Strict Barrier, Serial + Settle Delay).
5. **Discrete GPU (dGPU)** (`gpu`): NVIDIA GeForce/RTX, AMD Radeon, Intel Arc (Strict Barrier, Serial + Settle Delay).
   - Topological Order: iGPU always installs before dGPU. Vendor order: AMD → Intel → NVIDIA.
   - Adrenalin Deduplication: Unified APU+dGPU installer runs once and maps completion to both.
   - Display Settle Delay: 5 to 8 seconds delay after GPU install before starting next package.
6. **Parallel-Safe Devices** (2X Concurrent):
   - Wired LAN (`lan`), Wi-Fi (`wifi`), Bluetooth (`bluetooth`), Audio (`audio`), Touchpad (`touchpad`), Card Reader (`card_reader`), Camera (`camera`), USB (`usb`).
7. **Utility & Hotkeys** (`other`): Parallel-Safe if switched, Barrier if unswitched.

### 9.2 Pre-Barrier Drain & Lookahead Brake
- **Pre-Barrier Drain**: Worker 1 waits for Worker 2 to drain before launching a Barrier.
- **Lookahead Barrier Brake**: When Worker 2 finishes an item, it inspects the next pending item; if the next item is a Barrier, Worker 2 yields immediately.

### 9.3 Windows Installer Mutex & Error 1618 Retry Policy
- Mutex check: `Global\_MSIExecute`.
- Error 1618: Bounded retry capped at 2 retries (3 total attempts). Backoff (3s, 7s), wait for mutex idle, forced serial fallback (`is_barrier = True`). Never recorded as immediate failure.

### 9.4 Process Tree Termination
- Watchdog timeout (300s default, 420s chipset, 600s GPU) killed cleanly via `taskkill.exe /F /T /PID`.

---

## 10. General UI/UX Polish & Technician Experience Contract

### 10.1 Rich Queue Cards
- Brand icon from `brand_icons.py` / assets.
- Live status chip (`در انتظار`, `در حال نصب`, `نصب شد`, `خطا`, `رد شد`, `متوقف شد`).
- Active elapsed timer (`XXs`).
- Expandable execution log drawer displaying stdout/stderr.
- Per-item retry button for failed items.

### 10.2 Fixed Bottom Cumulative Progress Bar
- Fixed bottom container on installation pages:
  - Overall percentage (`progress_percent`).
  - Item count (`تکمیل شده: X از Y`).
  - Elapsed time.
  - Concurrency mode indicator (`1X متوالی` / `2X موازی`).

### 10.3 Pre-Run Queue Preview Sheet
- Modal sheet showing the exact sequence of packages sorted by weight/priority before technician clicks "شروع نصب".
- Filter and search bar.
- Visual barrier indicators (Serial Barrier vs 2X Parallel).
- Touch target minimum: 44px. RTL layout with LTR numbers/paths.
