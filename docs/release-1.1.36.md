# 1.1.36 — opt-in deployment and lifecycle hardening

## Behavior

- Automatic KMS stage is unchecked by default. Both queue construction and the
  worker enforce explicit opt-in; Home remains blocked. Direct manual activation
  is a separate explicit action. API contract 3 prevents reuse of older backends
  that would ignore the new activation option.
- Software and driver pages offer 2X for the next queue. Modes are immutable
  during a running queue and restored from backend status during UI recovery.
- 2X is an upper bound. `config/parallel_installers.json` deliberately ships
  empty: no production OEM package has been tested for safe overlap. Existing
  packages therefore remain sequential even with 2X selected. Do not describe
  this release as universally supporting simultaneous driver installation.
- Reviewed profiles use an exact executable SHA-256 key and a value such as
  `{"reviewed": true, "kind": "software", "resources": ["vendor.product"]}`.
  Driver profiles use kind `driver`. Review must cover nested processes, shared
  prerequisites, Windows Installer, no-restart behavior and autopilot ownership.
  A changed binary needs a new review. GPU/chipset/storage/MEI, INF/MSI/scripts
  and orchestration stages remain exclusive regardless of profiles.
- A global gate prevents conflicting queued software/driver operations from
  overlapping; one failing lane is joined with the other before queue cleanup.
  Manual external installers are outside this scheduler's control.
- GPU display-reset verification is delayed until after Windows/Flutter handle
  the reset. Old frame callbacks cannot acknowledge a newer display generation;
  repeated events no longer postpone the recovery deadline indefinitely.
- Exit targets the adopted backend PID and its descendants, not generic image
  names. Native committed window destruction signals an exit event even if Dart
  cannot complete its shutdown callback. UI destruction is bounded. A renderer
  recovery does not signal close, retaining the backend adoption window.
- The bounded-close watchdog is armed only by a real `WM_CLOSE`. Flutter's
  temporary native-window teardown during startup cannot close the application
  eight seconds after launch.
- Close after installers finish; forced close can interrupt a vendor installer.
  Elevated or detached third-party processes are not guaranteed killable.

## Antivirus and distribution

No Defender exclusions, protection disabling, obfuscation or detection bypass
is added. Existing extraction-free packaging is retained. Third-party activation
tools are not bundled by this change and may independently be detected.
There is no guarantee of acceptance by every antivirus. This release is not
claimed to have a trusted publisher signature or a clean antivirus verdict.
For public distribution, acquire a trusted code-signing certificate, sign the
owned binaries and installer consistently, and submit genuine false positives
to the relevant vendor. Do not treat all warnings as false positives.

References:
- https://learn.microsoft.com/en-us/defender-xdr/developer-faq
- https://www.microsoft.com/en-us/wdsi/filesubmission
- https://learn.microsoft.com/en-us/windows/win32/msi/initialization-errors

## Validation limits

Tests use mocked installers and synthetic files, never real installation,
activation, power changes or reboot. Native release compilation does not prove
recovery on every graphics adapter. Repeat GPU replacement and shutdown tests
on a dedicated test laptop before customer deployment.

## Completed checks

- Python unit suite: 165 passing tests.
- Flutter widget/unit suite: 46 passing tests. Real service launch is disabled
  under FLUTTER_TEST; state-changing installer runners remain mocked.
- Flutter analyzer: clean.
- Windows native/Flutter release and Python one-directory bundle compiled.
- Packaged backend smoke test: health 1.1.36 / contract 3, verified adopted PID,
  native close event successfully stopped the service within the 8-second bound.
- Final packaged portable remained running for 10 seconds (past the former 8-second
  false-shutdown point); its exact UI/backend test process tree was then removed
  and verified absent.
- No code-signing certificate was available in CurrentUser/My. No claim of
  trusted signing or antivirus certification is made.
- Microsoft Defender local scan (current host/signatures) returned no threats
  for the installer and portable ZIP. This is a point-in-time result, not a
  guarantee for every security product or future definition update.
- Authenticode status is `NotSigned`. A trusted publisher certificate remains
  required to improve identity and SmartScreen reputation for distribution.
- ZIP inspection found one expected root, 130 entries and no activation CMD,
  KMS directory or runtime log.

## Artifacts

- `dist/MarkaziSystemChecker-Setup.exe` — 40,488,997 bytes — SHA-256
  `FB5BB553C04F1B35068001A7B682913E96AE11F3DAD26AF7687F46FAA612B478`
- `dist/MarkaziSystemChecker-Setup-1.1.36.exe` — versioned copy with the same
  size and SHA-256 as the installer above.
- `dist/MarkaziSystemChecker-Portable-1.1.36.zip` — 49,213,797 bytes — SHA-256
  `24958EC3A3EFAC2865593797DD5A94DD0D45B0790B59C447A48ED817B7FDEDDF`
- `dist/MarkaziSystemChecker-1.1.36/` — 132 files, 86,521,562 bytes.
