# 1.1.38 — stable deployment options and GPU renderer recovery

## Fixed

- Idle four-second queue polling no longer clears the technician's KMS choice.
  Backend deployment options are adopted only while a queue is actually
  running; one-shot activation consent is cleared after that observed queue
  finishes.
- Deployment preference reconciliation was extracted from the large software
  controller into `DeploymentPreferences`, with a regression test covering
  idle refresh, active queue adoption and queue completion.
- KMS and 2X helper text is compact while preserving the native disabled state
  for Windows Home and active queues.
- Display-driver recovery now also watches DWM composition resets. If Flutter
  cannot produce a new frame after a GPU/display reset, the native runner
  replaces only the UI after eight seconds. The replacement adopts the existing
  backend session, so the active driver queue continues.

## H:\\PROGRAM audit

- Read-only scan found 9 valid visible packages and no duplicate package rows.
- The matching RAR copies are correctly ignored when extracted folders exist.
- The x64 Windows Update Blocker variant is selected on this 64-bit host.
- The KMS directory is intentionally treated as an opt-in orchestration source,
  not as an ordinary software row. No executable or script was launched during
  the audit.

## Validation

- Python unit suite: 167 passing tests.
- Flutter widget/unit suite: 47 passing tests.
- Flutter analyzer: clean.
- Windows release runner compiled successfully with the native recovery change.
- Packaged backend health: version 1.1.38 / API contract 3. Native close event
  stopped it with exit code 0.
- Microsoft Defender custom scan found no new detections for the installer or
  portable ZIP on this host. Authenticode remains `NotSigned`.

## Artifacts

- `dist/MarkaziSystemChecker-Setup.exe` — 40,421,733 bytes — SHA-256
  `388EEC181F13D9CAA12351AB521F643EB489E00F94B17C6235662D0ECC40B48A`
- `dist/MarkaziSystemChecker-Setup-1.1.38.exe` — versioned installer copy.
- `dist/MarkaziSystemChecker-Portable-1.1.38.zip` — 49,121,488 bytes — SHA-256
  `6EE4FF3130F3E6730BE2F3333A1866F118B3F4040C8D3790C3CD8C018B3FF292`
- `dist/MarkaziSystemChecker-1.1.38/` — 131 files, 86,258,042 bytes.
