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
- Driver selection is one source of truth in `DriverInstallController`; “select
  all” must toggle every currently scanned package on and off.
- Use stable item IDs/keys for stateful queues and poll active operations for
  real-time status instead of requiring a manual rescan.
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

Keep these values synchronized: `frontend/pubspec.yaml`,
`backend/api_server.py`, `installer/setup.iss`, and `build_production.py`.
Production artifacts belong in `dist/` and must include the installer, portable
directory, and versioned ZIP.
