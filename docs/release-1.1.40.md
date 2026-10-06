# 1.1.40 — Home activation continuity and copyable device identity

## Fixed

- Official Windows activation detection no longer excludes digital Home
  licenses that do not expose a partial product key in WMI.
- A recent positive result from an official Windows licensing source is kept
  for five minutes, so a transient WMI or `slmgr` timeout cannot immediately
  disable the desktop-icon action.
- Device settings also reconciles its lightweight status with the latest
  positive activation snapshot already held by the UI. Windows 10/11 Home
  therefore keeps the This PC, Control Panel and Recycle Bin action available
  when the original Windows license has been confirmed.
- The exact device model and System SKU are now single-click copy targets in
  the global header, simple mode, full hardware view and Windows details card.
  Copy targets use native pressed feedback, semantic labels and a minimum
  44-pixel interaction height.

## Validation

- Python unit suite: 169 passing tests.
- Flutter widget/unit suite: 50 passing tests.
- Flutter analyzer: clean.
- Regression coverage includes a licensed Windows 11 Home snapshot combined
  with a transient negative device-status response.
- Production backend, Flutter runner, portable directory, ZIP and installer
  built successfully.
- Packaged backend health: version 1.1.40 / API contract 3.
- Microsoft Defender custom scan found no threats in the installer or portable
  ZIP on this host. Authenticode remains `NotSigned`.

## Artifacts

- `dist/MarkaziSystemChecker-Setup.exe` and
  `dist/MarkaziSystemChecker-Setup-1.1.40.exe` — 40,214,793 bytes — SHA-256
  `150E9DC670395F5543BBD516DFF35B3FA41A824E51BCEBD56F4BDDF11BFCD73C`
- `dist/MarkaziSystemChecker-Portable-1.1.40.zip` — 48,822,708 bytes — SHA-256
  `E90850165B1B90373AE639ADE2FCF28B21FCBF22F7AC7FBEC1C8C6E159FF17A0`
- `dist/MarkaziSystemChecker-1.1.40/` — 131 files, 85,488,517 bytes.
