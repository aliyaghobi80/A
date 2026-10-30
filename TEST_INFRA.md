# Markazi System Checker — End-to-End (E2E) Test Infrastructure Specification

**Document Version**: 1.0 (Contract Version 5 / Application Release 1.1.45)  
**Track**: Dual Track E2E Quality Assurance (`teamwork_test_writer`)  
**Status**: Authoritative Test Infrastructure Specification  
**Governing Documents**: `ORIGINAL_REQUEST.md`, `AGENTS.md`, `CONTRACT.md`, `PROJECT.md`

---

## 1. Executive Summary & Dual Track Architecture

Markazi System Checker employs a **Dual Track Engineering Model** where the End-to-End (E2E) test infrastructure is authored, maintained, and verified independently from internal feature implementations. This model enforces an **opaque-box, contract-driven verification paradigm**: tests interact exclusively with ratified public API schemas, system state contracts, CLI interfaces, and observable UI controller behaviors.

### Core Principles
1. **Opaque-Box Independence**: Test suites do not couple to private module implementations, unexported helper functions, or internal file state. They validate behavioral contracts and external interfaces defined in `CONTRACT.md` and `PROJECT.md`.
2. **Progressive Testability & Zero Regressions**: Tests verify baseline stability and contract invariants at each milestone without premature execution of unintegrated features.
3. **Absolute Safety Guardrails**: Tests must **never** execute real installer binaries, modify Windows registry keys outside mock fixtures, alter system power settings, toggle real Windows services, invoke KMS activation, or trigger system reboots.
4. **Offline & Unmounted `H:\` Safe**: All filesystem interactions rely on hermetic synthetic fixtures, mock directory trees, and in-memory streams. Physical attachment of external technician media (`H:\`) is never required.

---

## 2. Test Hierarchy & 4-Tier Topology

The E2E test harness is organized into four distinct tiers of progressive verification:

```
┌────────────────────────────────────────────────────────────────────────┐
│                   Tier 4: Real-World Workload Scenarios                │
│  (End-to-End Technician Workflows: Full Scan → Sort → 2X Install →    │
│   Backend Restart Adoption → Diagnostics → Settings Reconciliation)   │
├────────────────────────────────────────────────────────────────────────┤
│                   Tier 3: Cross-Feature Combinations                   │
│  (Multi-Module Concurrency: 2X Install + Title Bar Drag + Diagnostics │
│   Settings Page Navigation during Active Queue + Display Recovery)     │
├────────────────────────────────────────────────────────────────────────┤
│                   Tier 2: Boundary & Corner Cases                      │
│  (Out-of-Order Revisions, Rapid Reconnects, 1618 Retry Limits,        │
│   Empty Queues, Clamped Audio Frequencies, Missing H:\ Drive)          │
├────────────────────────────────────────────────────────────────────────┤
│                   Tier 1: Feature Coverage (R1 - R6)                   │
│  (>=5 Test Cases per Feature: State Management, Title Bar, Hardware   │
│   Tests, Settings Route Fix, Software Queue Ordering, UI/UX Polish)    │
└────────────────────────────────────────────────────────────────────────┘
```

### 2.1 Tier 1: Comprehensive Feature Coverage (>=5 Cases per Feature)
- **R1: State Management Redesign**:
  1. Monotonic ascending `state_revision` generation on every state mutation.
  2. POSIX `server_time` epoch timestamp included under lock in status payloads.
  3. Stale snapshot drop (incoming payload with `state_revision < latestAppliedRevision` rejected).
  4. Adaptive non-overlapping polling cadence (active 500-800ms vs idle 3000-5000ms).
  5. Transient network drop fault tolerance (state preserved, Persian reconnection notice displayed).
  6. Strict forward state transitions (`pending` → `installing` → terminal state).
- **R2: Custom In-App Title Bar**:
  1. Window actions dispatch (minimize, maximize/restore, close).
  2. Persian RTL alignment (controls on left, branding and title on right).
  3. Windows 11 snap layout hook compatibility.
  4. Fullscreen test hiding (title bar completely removed during monitor test).
  5. Window dragging event handling without blocking child controls.
  6. Preservation of native display recovery arguments (`--display-recovery-from`).
- **R3: Component Hardware Diagnostic Tests**:
  1. Monitor Test: True OS fullscreen, pure static solid RGB colors, hidden cursor, Esc exit with geometry restoration.
  2. Keyboard Test: Responsive viewport scaling (`FittedBox`), physical keycode detection (differentiating L/R Shift/Ctrl/Alt, Numpad), hit counters.
  3. Audio Test: In-memory PCM WAV synthesis (440Hz, 1kHz, sweep, pink noise), Left/Right/Both routing, gentle volume defaults.
  4. Microphone Test: Real-time audio waveform calculation, temporary loopback recording, immediate temp file cleanup, privacy shortcut.
  5. Webcam Test: In-app live video preview, device selector, mirror toggle, snapshot capture, privacy link.
  6. Mouse Test: Sustained multi-button hold detection (Left, Middle, Right, Side 1, Side 2), double-click tracking, right-click context menu suppression.
  7. Report Deletion: Total excision of `test_report_view.dart`, `hardware_test_result.dart`, and sub-routes while keeping top QC Report button.
- **R4: App Settings Navigation Fix**:
  1. Sidebar navigation to index 7 (`SettingsPage`) opens reliably without silent dropping.
  2. Clamping expansion in `ThemeLanguageController.setNavIndex` (`index >= 0 && index <= 7`).
  3. Rejection of invalid navigation indices (< 0 or > 7).
  4. Theme mode switching and persistence from Settings.
  5. Language and accent color mutation handling.
- **R5: Application Software Installer Ordering & Optimization**:
  1. Synthetic `H:\PROGRAM\` scanning without binary execution.
  2. Adjacent folder and identical `.rar` archive deduplication (prefer folder, discard `.rar`).
  3. Package sorting by weight tiers (Tier 1 Utilities → Tier 2 Runtimes → Tier 3 Heavyweight → Tier 4 Office barrier).
  4. Office 2024 strict allowlist: execute only `Setup_Office 2024.cmd`; exclude Activator, Uninstall, and older scripts.
  5. Windows Home policy enforcement: block Office setup and deploy desktop shortcuts only.
  6. Concurrency policy: 2X parallel execution for switched EXEs; serial barrier for MSI, Office, and unswitched installers.
- **R6: General UI/UX Polish & Technician Experience**:
  1. Queue card state rendering (status badge, elapsed seconds, brand icon, expandable logs).
  2. Fixed bottom cumulative progress bar (`progress_percent`, completed count, total count).
  3. Pre-run queue preview sheet displaying execution sequence before launch.
  4. Per-item retry action for failed queue items.
  5. Persian RTL typography and minimum 44px touch targets.

### 2.2 Tier 2: Boundary, Fault Tolerance & Corner Cases
- **B-01 (Out-of-Order Frames)**: Interleaving of rapid responses (`rev 5` received before delayed `rev 4`). UI must keep `rev 5` and drop `rev 4`.
- **B-02 (Rapid Network Flapping)**: Backend connection drops and restores 5 times within 2 seconds. Queue state must remain stable.
- **B-03 (Corrupted State Files)**: Corrupted, truncated, or locked JSON state files in `%LOCALAPPDATA%`. Graceful fallback without crashing.
- **B-04 (Error 1618 Bounded Retry)**: Windows Installer busy returns code `1618`. Retries 1 and 2 roll back to `pending` with backoff; attempt 3 terminates as `failed`. No infinite loops.
- **B-05 (Missing Media / Empty Drive)**: `H:\` drive path missing or pointing to empty directory. Scan returns empty list without exception.
- **B-06 (Audio Frequency Clamping)**: Audio generator receiving 0Hz, -100Hz, or 50,000Hz clamps strictly to safe audible band (20Hz to 8,000Hz).
- **B-07 (Audio Duration Clamping)**: Generator receiving 0.0s or 100s clamps to valid interval (0.2s to 8.0s).
- **B-08 (Fullscreen Multi-Monitor Exit)**: Monitor test exited with multi-monitor / high-DPI scaling restores exact previous coordinate bounds.
- **B-09 (Zero-Length Microphone Recording)**: Loopback worker detects empty or truncated WAV file and raises controlled error instead of crashing.
- **B-10 (Mouse Multi-Button Press)**: Simultaneous 5-button press and release sequences handled cleanly.

### 2.3 Tier 3: Cross-Feature Combinations
- **C-01 (Install + Title Bar)**: Active 2X software installation running while custom title bar is dragged and window is resized.
- **C-02 (Install + Hardware Diagnostics)**: Technician runs Keyboard or Audio diagnostic test while background driver queue executes.
- **C-03 (Install + Settings)**: Technician navigates to Settings (R4) and changes theme/density while software queue is actively polling.
- **C-04 (GPU Settle + Display Recovery)**: GPU installer trigger invokes 8s settle delay while native runner watchdog monitor is armed.
- **C-05 (1618 Rollback + Parallel Worker Drain)**: Worker 2 experiences Error 1618, rolls back to serial barrier on Worker 1 while Worker 2 drains.

### 2.4 Tier 4: Real-World Workload Scenarios
- **W-01 (Full Technician Deployment Cycle)**:
  1. Synthetic `H:\PROGRAM` scan.
  2. Deduplication of extracted folder vs `.rar`.
  3. Weight sorting (WinRAR → VC++ Runtime → Chrome → Office).
  4. Launch 2X installation.
  5. Simulate backend termination mid-install.
  6. Backend restart reconciles installing items to `interrupted`.
  7. Client connects and adopts session.
  8. Technician navigates to Audio & Keyboard tests for verification.
  9. Technician adjusts settings.
- **W-02 (Hybrid Driver Deployment Cycle)**:
  1. Priority queue: Chipset (Barrier) → Intel UHD iGPU (Barrier + Settle) → NVIDIA RTX dGPU (Barrier + Settle) → LAN & Wi-Fi (2X Parallel).
  2. Mutex busy simulation during parallel phase.
  3. Advisory reboot reminder generated at completion.
- **W-03 (Windows Home Deployment Policy)**:
  1. Technician runs tool on Windows 11 Home.
  2. Software queue encounters Microsoft Office.
  3. Policy engine blocks Office installer and invokes desktop shortcut deployment.
  4. Status payload accurately records policy notice.

---

## 3. Mocking & Isolation Infrastructure

To ensure 100% compliance with safety rules, all tests utilize hermetic fixtures:

### 3.1 Process Execution Mocking
- **Python Subprocess**: `subprocess.run`, `subprocess.Popen`, and `_run_elevated_and_wait` are patched with mock runners returning synthetic exit codes (0, 1618, 3010, -2).
- **Process Tree Watchdog**: `terminate_process_tree` is mocked to verify correct arguments (`taskkill.exe /F /T /PID <pid>`) without executing real process kills.

### 3.2 Win32 & Kernel Mutex Isolation
- `Global\_MSIExecute` mutex checks (`OpenMutexW`) are intercepted via `unittest.mock.patch` to simulate busy and idle states deterministically.
- `ctypes.windll.winmm` and `winsound.PlaySound` are mocked during audio and microphone testing to eliminate physical hardware sound output and driver dependencies.

### 3.3 Filesystem & Drive Mocking
- Mock directories created using `tempfile.TemporaryDirectory()`.
- Synthetic `H:\PROGRAM\` structures contain empty `.exe`, `.cmd`, and dummy `.rar` files with valid headers.
- Queue persistence files (`driver_queue_state.json`, `software_queue_state.json`) use isolated temporary paths via environment overrides.

### 3.4 Frontend State & HTTP Isolation
- GetX controllers use mock `ApiService` instances returning simulated JSON status responses.
- Simulated network latency, dropped packets, and HTTP error codes (500, 502, timeout) are injected deterministically.

---

## 4. Test Directory Layout & File Organization

The E2E test suites reside in dedicated test directories:

```
g:\MarkaziSystem\
├── backend\
│   └── tests\
│       ├── test_*.py                    # Existing unit tests
│       └── e2e\
│           ├── __init__.py
│           ├── test_e2e_r1_state_management.py   # Tier 1: R1
│           ├── test_e2e_r2_r4_window_settings.py # Tier 1: R2 & R4
│           ├── test_e2e_r3_hardware_tests.py    # Tier 1: R3
│           ├── test_e2e_r5_software_installer.py# Tier 1: R5
│           ├── test_e2e_tier2_boundaries.py     # Tier 2: Boundaries & Corners
│           └── test_e2e_tier3_tier4_scenarios.py# Tier 3 & 4: Cross & Workloads
│
└── frontend\
    └── test\
        ├── *_test.dart                  # Existing unit/widget tests
        └── e2e\
            ├── e2e_tier1_features_test.dart      # Tier 1: Flutter UI Features
            ├── e2e_tier2_boundaries_test.dart    # Tier 2: UI Boundaries
            ├── e2e_tier3_cross_feature_test.dart # Tier 3: Cross-Feature UI
            └── e2e_tier4_real_workload_test.dart # Tier 4: Workload UI Flows
```

---

## 5. Test Execution & Verification Commands

All test suites can be executed via standard PowerShell / CLI commands:

### Backend E2E Test Suite
```powershell
# Run all backend tests including E2E
py -3 -m unittest discover -s backend/tests -p "test_*.py"

# Run exclusively E2E backend test suite
py -3 -m unittest discover -s backend/tests/e2e -p "test_*.py"
```

### Frontend E2E Test Suite
```powershell
# Run all frontend tests including E2E
cd frontend
flutter test

# Run exclusively E2E frontend test suite
cd frontend
flutter test test/e2e/
```

### Static Analysis
```powershell
cd frontend
flutter analyze
```

---

## 6. Requirement Traceability Matrix

| Requirement | Description | Backend E2E Test Suite | Frontend E2E Test Suite | Tier 2 Corner Cases |
|---|---|---|---|---|
| **R1** | State Management Redesign | `test_e2e_r1_state_management.py` | `e2e_tier1_features_test.dart` | `test_e2e_tier2_boundaries.py` (B-01, B-02, B-03) |
| **R2** | Custom In-App Title Bar | `test_e2e_r2_r4_window_settings.py` | `e2e_tier1_features_test.dart` | `test_e2e_tier2_boundaries.py` (B-08) |
| **R3** | Hardware Diagnostic Tests | `test_e2e_r3_hardware_tests.py` | `e2e_tier1_features_test.dart` | `test_e2e_tier2_boundaries.py` (B-06, B-07, B-09, B-10) |
| **R4** | App Settings Navigation Fix | `test_e2e_r2_r4_window_settings.py` | `e2e_tier1_features_test.dart` | `test_e2e_tier2_boundaries.py` (B-08) |
| **R5** | Software Installer Ordering | `test_e2e_r5_software_installer.py` | `e2e_tier1_features_test.dart` | `test_e2e_tier2_boundaries.py` (B-04, B-05) |
| **R6** | General UI/UX Polish | `test_e2e_r5_software_installer.py` | `e2e_tier1_features_test.dart` | `test_e2e_tier2_boundaries.py` (B-01) |

---

## 7. State Isolation, Flakiness Prevention & Hygiene

1. **Test Order Independence**: Each test class initializes fresh state dictionaries and tears down test threads in `setUp()` and `tearDown()`.
2. **Deterministic Time**: Clocks and epoch timestamps are controlled via mock objects or monotonic counters rather than non-deterministic `time.sleep()`.
3. **Automatic File Cleanup**: All synthetic files, temporary directories, and mock registry entries are deleted in `finally` blocks or `tempfile.TemporaryDirectory` contexts.
4. **Thread Joining**: Any worker threads spawned during queue testing must be explicitly joined or terminated before test teardown completes.
