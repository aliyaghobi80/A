# 1.1.37 — selection, deployment coordination and navigation cleanup

## Behavior

- The Calculations destination and implementation were removed from the
  application. The settings page is now the last valid sidebar destination.
- Software and driver selection remain controller-owned GetX state. Stable item
  keys are used for both lists, and select-all toggles the entire current scan
  on and off without a page-local copy of the selection.
- 2X remains available on both deployment pages, but is deliberately bounded:
  only exact SHA-256 profiles marked reviewed with disjoint resources may share
  the two lanes. GPU, chipset, storage, MEI, MSI, INF/script, orchestration and
  unknown packages remain barriers and run sequentially.
- `config/parallel_installers.json` is still empty because no production OEM
  binary has completed the required dedicated-machine concurrency review.
  Selecting 2X therefore does not make current arbitrary packages overlap.
- Before every queued launch, the scheduler checks Windows Installer's global
  `_MSIExecute` mutex. An external MSI transaction makes the queue wait instead
  of competing with it. Exit code 1618 also triggers one bounded wait and retry.
- A manually launched arbitrary EXE has no universal Windows transaction mutex.
  The app never controls its window, but conflict-free overlap cannot be
  guaranteed; the UI tells technicians to run external EXE installers after the
  queue.
- The existing full-exit path is retained: explicit exit terminates the owned
  backend/process tree, while native `WM_CLOSE` signals the packaged backend and
  uses a bounded renderer-safe fallback. Processes are targeted by ownership,
  never by a broad executable-name kill.

## Validation

- Python unit suite: 167 passing tests.
- Flutter widget/unit suite: 46 passing tests.
- Flutter analyzer: clean.
- Select-all benchmark fixtures toggled 5,000 software IDs and 1,000 driver IDs
  on and off synchronously in under 500 ms on this build host.
- Packaged backend smoke test: health 1.1.37 / API contract 3; the native close
  event stopped the process with exit code 0 within the 10-second bound.
- Microsoft Defender custom scans of the installer and portable ZIP returned no
  new detections on this host. This is a point-in-time result, not a guarantee
  for other antivirus engines or future signatures.
- Authenticode status remains `NotSigned`; trusted publisher signing is still
  required for publisher identity and better SmartScreen reputation.

## Artifacts

- `dist/MarkaziSystemChecker-Setup.exe` — 40,422,673 bytes — SHA-256
  `1193F22BF4B47C0EB73518810638DF7BFC3B22DFECE1530DA16E6F8FB5CBCF70`
- `dist/MarkaziSystemChecker-Setup-1.1.37.exe` — versioned copy with the same
  size and SHA-256 as the installer above.
- `dist/MarkaziSystemChecker-Portable-1.1.37.zip` — 49,122,025 bytes — SHA-256
  `EFCB994DE47DF5EA0315C54930FC059673F6EE6B329A998E2D5C1A293069789D`
- `dist/MarkaziSystemChecker-1.1.37/` — 131 files, 86,260,728 bytes.
