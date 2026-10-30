# Markazi System Checker — Software Silent Switches & Deployment Specification

**Document Version:** 1.1.45  
**API Contract:** 5  
**Target Platform:** Windows 10 & Windows 11 (Technician Workstation Environment)

---

## 1. Overview & Architecture

Markazi System Checker provides an automated, reliable Windows technician tool for offline software deployment and sequential/parallel package installation. This document specifies the official vendor silent switches, concurrency rules, barrier definitions, GUI autopilot fallback semantics, and safety invariants governing software installation.

### Core Tenets
1. **Zero Guessed Switches Policy**: Unknown or unswitched installers never receive guessed or fabricated command-line parameters. If an installer technology is not authoritatively recognized, it receives empty arguments (`silent_args: []`) and executes under GUI autopilot as a strict serial barrier.
2. **Deterministic Tier Ordering**: Software packages are weighted and ordered deterministically from lightweight utilities to heavy suites.
3. **Barrier Isolation**: Multi-threaded concurrency (2X) is strictly limited to verified, parallel-safe standalone executables. Sensitive operations (MSI packages, system runtimes, Microsoft Office, unswitched installers) execute exclusively on Worker 1 with zero concurrency.
4. **Safety & Non-Destructive Operation**: Scanning never executes binaries; archives are deduplicated; tutorial folders (`آموزش`) are completely excluded; and process trees are terminated cleanly upon timeout using native Windows tools.

---

## 2. Installer Technologies & Standard Silent Switches

| Installer Technology | Primary Switch Pattern | Reboot Suppression | Error / Return Behavior |
|:---|:---|:---|:---|
| **Inno Setup** | `/VERYSILENT /SUPPRESSMSGBOXES /SP-` | `/NORESTART` | Exit code `0` on success. Suppresses wizard prompts and startup dialogs. |
| **NSIS (Nullsoft Scriptable Install System)** | `/S` | Parameter must be strictly uppercase `/S`. | Returns `0`. Note: NSIS requires uppercase `/S` — lowercase `/s` is ignored. |
| **WiX Toolset / Burn Engine** | `/quiet` | `/norestart` | Exit code `0` or `3010` (reboot pending). Standard Windows Installer bootstrapper. |
| **InstallShield** | `/s /v"/qn /norestart"` | `/norestart` embedded in `/v` MSI wrapper. | Passes quiet switches directly to embedded Windows Installer engine. |
| **Windows Installer (MSI / MSP)** | `msiexec.exe /i "<path>" /qn` or `/p "<path>" /qn` | `/norestart REBOOT=ReallySuppress` | Checks `Global\_MSIExecute` mutex before launch. Handles Error 1618 gracefully. |
| **Windows Update Standalone (MSU)** | `wusa.exe "<path>" /quiet` | `/norestart` | Standard Windows service update installer. |
| **AppX / MSIX / AppXBundle** | `Add-AppxPackage -LiteralPath '<path>'` | Non-rebooting | Handled via elevated non-interactive PowerShell session (`-NoProfile -NonInteractive`). |

---

## 3. Verified Software Catalog & Silent Parameters

The table below catalogs official silent installation parameters for standard technician software packages included in technician deployment repositories:

| Category | Package Name | Canonical Switch | Concurrency Mode | Watchdog Timeout |
|:---|:---|:---|:---|:---|
| **Tier 1 (Utility)** | **WinRAR** | `/s` | Parallel-Safe (2X) | 300s |
| **Tier 1 (Utility)** | **Mozilla Firefox** | `-ms` | Parallel-Safe (2X) | 300s |
| **Tier 1 (Utility)** | **VLC Media Player** | `/S` | Parallel-Safe (2X) | 300s |
| **Tier 1 (Utility)** | **KMPlayer** | `/S` | Parallel-Safe (2X) | 300s |
| **Tier 1 (Utility)** | **Free Download Manager (FDM)** | `/VERYSILENT /NORESTART /SP-` | Parallel-Safe (2X) | 300s |
| **Tier 1 (Utility)** | **Notepad++** | `/S` | Parallel-Safe (2X) | 300s |
| **Tier 1 (Utility)** | **Telegram Desktop** | `/VERYSILENT /NORESTART /SP-` | Parallel-Safe (2X) | 300s |
| **Tier 1 (Utility)** | **AnyDesk** | `--install "C:\Program Files (x86)\AnyDesk" --silent` | Parallel-Safe (2X) | 300s |
| **Tier 1 (Utility)** | **Internet Download Manager (IDM)** | `/skipdlgs` | Parallel-Safe (2X) | 300s |
| **Tier 1 (Utility)** | **7-Zip** | `/S` | Parallel-Safe (2X) | 300s |
| **Tier 2 (Runtime)** | **Visual C++ Redistributable All-in-One** | `/ai` or `/install /quiet /norestart` | Strict Barrier (Serial) | 300s |
| **Tier 2 (Runtime)** | **Microsoft .NET Desktop Runtime** | `/quiet /norestart` | Strict Barrier (Serial) | 300s |
| **Tier 2 (Runtime)** | **DirectX End-User Runtimes** | `/Q` | Strict Barrier (Serial) | 300s |
| **Tier 3 (Heavyweight)** | **Google Chrome Enterprise** | `/silent /install` | Parallel-Safe (2X) | 300s |
| **Tier 3 (Heavyweight)** | **Adobe Acrobat Reader** | `/sAll /rs /msi /norestart /quiet ALLUSERS=1 EULA_ACCEPT=YES` | Parallel-Safe (2X) | 300s |
| **Tier 4 (Office)** | **Microsoft Office 2024** | Automated via `Setup_Office 2024.cmd` with piped option `1` | Strict Barrier (Serial) | 600s |
| **System Utility** | **Windows Update Blocker (WUB)** | `/D /P` (Disable) or `/E` (Enable) | Standalone (Excluded from auto batch) | 300s |

---

## 4. Deterministic Queue Ordering & Weighting Matrix

To optimize installation throughput and minimize file lock contention, queued software packages are categorized into 4 sequential tiers:

```
[Tier 1: Utilities] ──► [Tier 2: System Runtimes] ──► [Tier 3: Heavyweight Apps] ──► [Tier 4: Office Suite]
  (WinRAR, VLC,           (VC++ All-in-One,            (Google Chrome,              (Setup_Office 2024.cmd,
   Firefox, FDM, ...)      .NET, DirectX)               Acrobat Reader, ...)         Strict Barrier, 600s)
```

1. **Tier 1: Lightweight Utilities** (Weight 10):
   - Fast execution (< 30 seconds per installer).
   - Eligible for 2X concurrency if standalone EXE with documented switches.
   - Ensures essential technician tools (e.g., WinRAR for subsequent archive extractions) are immediately operational.
2. **Tier 2: System Runtimes** (Weight 20):
   - Visual C++ All-in-One, .NET, DirectX.
   - **Invariant**: Always installed before dependent heavyweight applications to prevent missing DLL or runtime errors (`VCRUNTIME140.dll`, `MSVCP140.dll`).
   - Strict Barrier: serial execution on Worker 1.
3. **Tier 3: Heavyweight Applications** (Weight 30):
   - Google Chrome, Adobe Acrobat Reader, graphics software.
   - Significant CPU and disk footprint.
   - Eligible for 2X concurrency if parallel-safe.
4. **Tier 4: Microsoft Office 2024** (Weight 40):
   - Final barrier in the queue.
   - Extended watchdog timeout (600s).
   - Automated via allowlisted script execution.

---

## 5. Concurrency Model & Barrier Execution Invariants

In multi-threaded deployment mode (2X), tasks are distributed across two workers:

| Role | Worker | Executable Types | Invariants |
|:---|:---|:---|:---|
| **Barrier Worker** | **Worker 1** | MSI / MSP packages, System Runtimes, Office 2024, Unswitched GUI Autopilot packages, Error 1618 retry fallbacks | Executes exclusively with zero concurrency. Worker 2 must be fully drained before Worker 1 initiates a barrier. |
| **Concurrent Worker** | **Worker 2** | Verified Parallel-Safe Standalone EXEs (WinRAR, Firefox, VLC, FDM, Chrome, etc.) | Runs concurrently with Worker 1 only when Worker 1 is executing a parallel-safe task. Yields immediately when the next pending queue item is a barrier (Lookahead Barrier Brake). |

### Concurrency Invariants
- **Pre-Barrier Drain Rule**: Worker 1 halts and waits until Worker 2 has completely finished its active task before launching any barrier package.
- **Lookahead Barrier Brake**: When Worker 2 completes an item, it inspects the next pending item in the queue. If that item is classified as a barrier, Worker 2 enters an idle yield state, leaving Worker 1 to take the barrier cleanly.
- **Kernel Mutex Inspection (`Global\_MSIExecute`)**:
  - Before launching any package utilizing Windows Installer technology (`msiexec.exe`, InstallShield, WiX), the scheduler probes the `Global\_MSIExecute` mutex.
  - If the mutex is occupied, the worker waits up to 30 seconds for idle release before proceeding.
- **Error 1618 Retry Policy (`ERROR_INSTALL_ALREADY_RUNNING`)**:
  - Maximum retry attempts: 2 retries (3 total attempts).
  - Exponential backoff delays (3 seconds, then 7 seconds).
  - On retry, the package is dynamically escalated to `is_barrier = True` to enforce serial isolation and avoid concurrent mutex collisions.
  - An initial 1618 error is never recorded as an immediate installation failure.

---

## 6. Microsoft Office 2024 Deployment Policy

### Strict Script Allowlist
- **Allowed Script**: `Setup_Office 2024.cmd` (case-insensitive exact match).
- **Prohibited & Excluded Scripts**:
  - `Activator.cmd` — activation must never occur during unattended application deployment; activation is managed exclusively under official technician activation protocols.
  - `Uninstall.cmd` — destructive removal scripts are strictly prohibited from queueing.
  - `Setup_Office 2021.cmd` and older revisions — prevented from executing automatically.
- **Execution Mechanism**:
  Automated by generating a transient wrapper script in `%TEMP%` that pipes input option `1` (Install All Products):
  ```cmd
  @echo off
  cd /d "<Office_Directory>"
  (echo 1 & echo.) | "Setup_Office 2024.cmd"
  exit /b %ERRORLEVEL%
  ```
- **Watchdog Timeout**: 600 seconds (10 minutes).

### Windows 10/11 Home Deployment Restrictions
- On Windows Home editions (`get_windows_identity()["is_home"] is True`), Office deployment is completely blocked in compliance with product license policy.
- The installer automatically creates Office desktop shortcuts (`ensure_office_desktop_shortcuts()`) if Office binaries exist, without executing installation.
- A Persian explanation is returned to the user: `Windows Home اورجینال است؛ نصب Office مجاز نیست.`

---

## 7. Windows Update Blocker (WUB) & Special Tools

- **Windows Update Blocker (`Wub.exe` / `Wub_x64.exe`)**:
  - Used for deliberate, technician-controlled Windows Update service management.
  - Command switches: `/D /P` (Disable updates and protect service) or `/E` (Enable updates).
  - **Auto-Selection Policy**: Excluded from default batch queue selection (`auto_select: False`). Technicians must manually toggle WUB if desired.
- **KMS Tools & Bundles**:
  - Any folder, archive, or executable matching KMS activation tooling is excluded from the software installation queue.
  - Handled exclusively via `activation_tools.py` elevated CLI arguments (`/u /w` for Windows and `/u /o` for Office).

---

## 8. Repository Scanning, Caching & Deduplication Rules

1. **Safe Scanning**: Scanning never executes a file. Executable metadata is extracted using PE header parsing (`struct`), version resources, and digital signature checks.
2. **Adjacent Folder & Archive Deduplication**:
   - If an uncompressed folder (e.g. `Office 2024/` or `WinRAR/`) and a corresponding compressed archive (`Office 2024.rar` or `WinRAR.zip`) exist in the same directory, the scanner prioritizes the extracted directory and marks the archive as a duplicate (`is_duplicate: True`, `auto_select: False`).
   - Archive extraction in `orchestrator.py` verifies whether an adjacent folder already exists before attempting redundant decompression.
3. **Tutorial Directory Exclusion (`آموزش`)**:
   - Any directory or path containing `"آموزش"` (Farsi for "Tutorial" / "Training") is completely excluded from software discovery and activation searches.
4. **Scan Caching**:
   - In-memory cache with 3.0-second TTL (`_SCAN_CACHE_TTL_SECONDS = 3.0`) prevents excessive disk I/O and PE header re-parsing during rapid polling loops.
   - Cache is invalidated immediately upon directory change or when explicit `force_refresh=True` is provided.
5. **Process Tree Termination**:
   - Watchdog timeouts (300s default; 600s Office 2024) terminate the hung process and its entire child process tree cleanly via `taskkill.exe /F /T /PID <pid>`.
   - Inter-package delays are minimized (0.5s initial settle) to prevent artificial lag between installations.

---

## 9. Verification & State Machine Transition Table

The batch installer enforces forward-only state machine transitions for all items:

```
[pending] ──► [installing] ──┬──► [completed]  (Exit code 0/3010 or registry verified)
                             ├──► [failed]     (Non-zero exit, timeout, or blocked)
                             ├──► [skipped]    (Already installed or Home guard)
                             └──► [interrupted](Service reboot / recovery reconciliation)
                                    │
                                    └──► [pending] (Permitted ONLY for Error 1618 retry, max 2)
```

Verification occurs post-execution through:
1. Process exit code inspection (`0`, `3010`, `1638`).
2. Live Windows Registry scanning (`HKLM\Software\Microsoft\Windows\CurrentVersion\Uninstall` and `HKCU`).
3. Office click-to-run installation queries via `detect_microsoft_office()`.
