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
- Queue packages sequentially and expose every queue item's live state.
- Queue workers must clear `is_running` in a `finally` path. A dead worker must
  be detected and repaired by the status endpoint so controls never remain
  locked indefinitely.
- For a folder with several independent direct `.exe`/`.msi` installers and no
  cohesive INF package, queue every installer.
- Prefer a recognized OEM wrapper when a package is cohesive. Otherwise install
  the full INF tree with PnPUtil `/subdirs /install`.
- Extract supported archives into isolated folders and rescan their contents.
- Only run explicitly trusted driver scripts such as `InstallPackage.bat` or
  `InstallStep.txt`-documented entry points. Never execute arbitrary scripts.
- Use vendor-documented silent switches where known. Unknown installers must not
  receive guessed destructive switches.
- Never select “Restart now”. Suppress installer restarts where supported and
  show a single reminder after the queue finishes so the technician can restart
  manually.
- GUI autopilot may control only the launched installer process tree, an owned
  dialog, or a newly-created helper inside the selected package directory.
  Generic titles such as `Setup` are never ownership evidence.
- Advance only safe installer states (`Next`, license acceptance, `Install`,
  success `OK`, `Finish`, `Close`) one action at a time. Never interpret
  maintenance actions such as Uninstall/Remove/Repair as installation.
- Use bounded window messages so a hung OEM dialog cannot freeze the queue, and
  do not advance to the next package while a tracked child wizard remains open.
- Do not queue firmware, BIOS flashers, uninstallers, diagnostics, or cleanup
  utilities as ordinary drivers.

## UI and state rules

- Persian pages are RTL, but numbers, versions, serials, paths, and calculator
  inputs are explicitly LTR.
- Keep primary actions at least 44 px high and avoid duplicate actions.
- Driver selection is one source of truth in `DriverInstallController`; “select
  all” must toggle every currently scanned package on and off.
- Use stable item IDs/keys for stateful queues and poll active operations for
  real-time status instead of requiring a manual rescan.
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
