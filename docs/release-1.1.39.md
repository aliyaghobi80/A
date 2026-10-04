# 1.1.39 — instant deployment options and copyable motherboard model

## Fixed

- KMS and 2X now update visually on the next Flutter frame. Each option owns a
  small GetX observer and repaint boundary, so changing it no longer rebuilds
  the full software or driver package list.
- The same isolated 2X control is used by the driver queue.
- Motherboard model values can be copied by tapping the model in simple mode,
  the main hardware page, or the detailed motherboard card. The interaction is
  keyboard-focusable, has a native pressed state, a 44-pixel minimum target,
  and gives short confirmation feedback.

## Validation

- Python unit suite: 167 passing tests.
- Flutter widget/unit suite: 49 passing tests, including a regression test that
  verifies an option checks after one frame without rebuilding its parent.
- Flutter analyzer: clean.
- Production backend, Flutter runner, portable directory, portable ZIP, and
  Inno Setup installer built successfully.
- Packaged backend health: version 1.1.39 / API contract 3; the shutdown API
  stopped the packaged service after the smoke test.
- Microsoft Defender custom scan found no threats in the installer or portable
  ZIP on this host. Authenticode remains `NotSigned`.

## Artifacts

- `dist/MarkaziSystemChecker-Setup.exe` and
  `dist/MarkaziSystemChecker-Setup-1.1.39.exe` — 40,421,543 bytes — SHA-256
  `7C78A2A3E2AD5AA3DC161BC27DFA3917CF7437A0D6565492C87416E3E0C90E9A`
- `dist/MarkaziSystemChecker-Portable-1.1.39.zip` — 49,122,166 bytes — SHA-256
  `F93BAE50A7E073845A3F375C6F2A8E7C19DE1B8DEEEDE092389F7E78C36305DA`
- `dist/MarkaziSystemChecker-1.1.39/` — 131 files, 86,258,155 bytes.
