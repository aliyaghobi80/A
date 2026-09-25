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
- Splash progress reflects backend readiness and initial-data loading. Do not
  add a fixed minimum delay; only expose retry after genuine repeated failure.
- Check narrow desktop layouts as well as the normal technician workstation
  size. Prefer `Wrap`/`LayoutBuilder` over fixed-width rows.

## Release version

Keep these values synchronized: `frontend/pubspec.yaml`,
`backend/api_server.py`, `installer/setup.iss`, and `build_production.py`.
Production artifacts belong in `dist/` and must include the installer, portable
directory, and versioned ZIP.
