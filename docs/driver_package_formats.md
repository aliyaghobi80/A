# Markazi System Checker — Driver Package Formats & Vendor Switch Reference

**Version**: 1.1.44  
**Date**: October 2026  
**Audience**: Systems Engineers, Core Developers, Deployment Technicians  
**Status**: Official Production Reference Specification  

---

## 1. Executive Summary & Architecture Philosophy

Markazi System Checker deploys device drivers and system hardware software across a wide variety of OEM laptops and custom desktop workstations in enterprise and retail technician environments. Because technicians operate under tight delivery deadlines, installation must be fast, accurate, and completely autonomous, without destabilizing system integrity or triggering premature reboots.

The driver deployment engine adheres to three fundamental engineering principles:
1. **Zero Guessed Switches Policy**: Command-line switches are executed if and only if they are officially documented by the vendor or verified via package metadata. Unrecognized installers receive an empty switch array (`[]`) and are routed to GUI Autopilot or strict serial execution.
2. **Strict Hardware Concurrency Isolation**: Hardware registers and kernel driver stores are never written concurrently. Barriers are strictly enforced for Chipset, Management Engine, Storage, GPU, and MSI transactions. 2X concurrency is reserved exclusively for disjoint, parallel-safe peripherals (Audio, LAN, Wi-Fi, Bluetooth, Touchpad, Card Reader, USB).
3. **Reboot Suppression & Consolidated Notification**: Automated operating system reboots (`shutdown /r`, unsuppressed installer restarts) are strictly prohibited. Exit codes indicating reboot requirements (3010, 1641) are recorded, and a single consolidated reminder is presented to the technician upon completion of the entire queue.

---

## 2. Zero Guessed Switches Policy

Guessing command-line switches (such as blindly appending `/q`, `/s`, or `/silent` to unknown executables) frequently leads to catastrophic side effects:
- Installers may interpret `/s` or `/clean` as a command to delete existing configurations or trigger an unprompted factory reset.
- Some setup wrappers treat unrecognized switches as an invocation for command-line help (`/?`), silently exiting with code `0` or `1` without installing any drivers.
- Other wrappers may drop into interactive prompt modes that hang indefinitely when run detached without a visible console.

### 2.1 Enforcement Rules
1. **Exhaustive Whitelist**: Only verified switches mapped to specific vendor signatures (file names, PE header company strings, or metadata descriptors) are permitted.
2. **Empty Switch Fallback**: If an installer executable does not match a known vendor profile, `silent_args` is explicitly set to `[]`.
3. **Barrier Designation for Unswitched Installers**: Any package with `silent_args == []` is classified as `is_barrier = True` and `is_parallel_safe = False`. It is dispatched exclusively to Worker 1, ensuring no other installations run concurrently.
4. **GUI Autopilot Handshake**: Unswitched installers invoke the GUI Autopilot subsystem, which monitors the specific launched process tree for standard confirmation dialogs (`Next`, `Install`, `Accept License`, `Finish`, `Close`).

---

## 3. Exit Code Normalization & Handling Contract

Every process execution returns an integer exit code. The scheduler normalizes these codes into uniform queue outcomes:

| Exit Code | Windows Constant / Meaning | Normalized Status | Reboot Flag | Engine Action & Policy |
|---|---|---|---|---|
| `0` | `ERROR_SUCCESS` | `completed` | Unchanged | Successful installation. Advances to the next queue item. |
| `3010` | `ERROR_SUCCESS_REBOOT_REQUIRED` | `completed` | `reboot_required = true` | Successful installation, but changes require a system restart to take effect. Reboot is suppressed; queue continues. |
| `1641` | `ERROR_SUCCESS_REBOOT_INITIATED` | `completed` | `reboot_required = true` | Installer initiated a restart sequence. The engine suppresses OS restart; queue continues. |
| `1638` | `ERROR_PRODUCT_VERSION` | `completed` | Unchanged | Another version of this product is already installed. Treated as acceptable success; queue continues. |
| `1618` | `ERROR_INSTALL_ALREADY_RUNNING` | `pending` (retry) / `failed` | Unchanged | Another installation transaction is active. Triggers the 1618 Bounded Retry Policy (Section 8.2). |
| `1602` | `ERROR_INSTALL_USEREXIT` | `failed` | Unchanged | Installation cancelled by user or technician intervention. |
| `1603` | `ERROR_INSTALL_FAILURE` | `failed` | Unchanged | Fatal Windows Installer or vendor setup error. Captured with diagnostic message. |
| `-2` | `TIMEOUT_EXPIRED` | `failed` | Unchanged | Process exceeded timeout watchdog. Entire process tree killed via `taskkill /F /T /PID`. |
| `-5` | `WORKER_DIED` | `failed` | Unchanged | Execution thread terminated abnormally. Recovered by watchdog. |
| Other | Non-zero exit code | `failed` | Unchanged | Recorded in item state and logged to diagnostic file. |

### 3.1 Single Advisory Reboot Reminder Contract
When any package in the queue returns `3010` or `1641`, or has `requires_reboot == True` in its metadata:
- The global queue property `reboot_required` transitions to `true`.
- The engine appends exactly one Persian advisory notice to `summary_message` at the completion of all queue items:
  `" — یادتان نرود پس از پایان همهٔ کارها، سیستم را دستی ری‌استارت کنید."`
- The Flutter UI displays an advisory reminder button: `"متوجه شدم؛ بعداً ری‌استارت می‌کنم"`.

---

## 4. Archive Formats, Sandbox Isolation & Security Checks

Driver repositories provided by technicians frequently contain compressed archives downloaded from OEM support portals. The scanner extracts these archives automatically prior to profiling.

### 4.1 Supported Archive Formats
- **ZIP (`.zip`)**: Handled via Python standard library `zipfile` module.
- **RAR (`.rar`)**: Handled via `UnRAR.exe`, `Rar.exe`, or `7z.exe` if detected on the host system.
- **7-Zip (`.7z`)**: Handled via `7z.exe` or `7za.exe`.
- **CAB (`.cab`)**: Handled via Windows native `expand.exe`, `extrac32.exe`, or `tar.exe`.

### 4.2 Sandbox Extraction Directory Invariant
- Archives are **never extracted in-place** into the parent directory.
- Each archive is extracted into a dedicated, isolated subdirectory named after the archive:
  `_extracted_<archive_stem>_<fingerprint>/`
- This completely prevents file collisions between driver packages sharing common filenames (such as `setup.exe` or `data1.cab`).

### 4.3 Security Invariants & Defensive Limits
1. **Recursion Depth Limit**:
   - Nested archives (e.g. a `.cab` inside a `.zip`) are extracted up to a maximum recursion depth of **3** (`MAX_RECURSION_DEPTH = 3`).
   - Beyond depth 3, extraction stops to prevent cyclic or infinitely nested archives.
2. **Zip-Slip Path Traversal Protection**:
   - For every entry within an archive, the target destination path is strictly resolved and canonicalized (`os.path.abspath`).
   - If `os.path.commonpath([dest_abs, target]) != dest_abs`, the entry attempts directory traversal outside the sandbox (e.g. `../../Windows/System32`).
   - The operation is immediately aborted, raising a security violation.
3. **Archive Bomb Defenses**:
   - Total uncompressed size limit: **10 GB** (`MAX_UNCOMPRESSED_BYTES = 10 * 1024 * 1024 * 1024`).
   - Maximum compression ratio: **100:1** (`MAX_COMPRESSION_RATIO = 100.0`).
   - Maximum file count per archive: **25,000 files** (`MAX_ARCHIVE_FILE_COUNT = 25000`).
4. **Extended Windows Long-Path Handling**:
   - Deep nested folder structures frequently exceed the legacy Windows 260-character `MAX_PATH` limit.
   - For any path exceeding 240 characters, the scanner automatically prepends the Windows NT extended-length prefix `\\?\` (or `\\?\UNC\` for network shares).

### 4.4 Exclusion Filters
The inspector scans directory contents and explicitly filters out non-driver utilities, ensuring they are never queued:
- **Firmware & BIOS Flashers**: `flash.bat`, `flash.exe`, `fpt.exe`, `afudos.exe`, `afuwin.exe`, `insydeflash.exe`, `hpflash.exe`, `amifldrv.sys`, `biosflash.exe`, `fwupdate.exe`, `meupdate.exe`.
- **Diagnostics**: `SupportAssist`, `LenovoDiagnostics`, `DellCommandUpdate`, `pc-doctor`, `hwdiagnostic`, `diags`.
- **Cleanup Utilities**: `DDU` (Display Driver Uninstaller), `AMDCleanupUtility`, `drivercleaner`.
- **Uninstallers**: `unins000.exe`, `unins001.exe`, `uninstall.exe`.

---

## 5. OEM Vendor Package Specifications

### 5.1 ASUS (ASUSTeK Computer Inc.)
- **Primary Wrappers**: `AsusSetup.exe`, `Setup.exe`.
- **Metadata Discovery**: ASUS packages typically contain an `InstallStep.txt` or `InstallStep.bat.txt` file outlining the exact invocation sequence and parameters.
- **Official Switches**:
  - `AsusSetup.exe`: `["-s", "-norestart"]`
- **Behavioral Notes**:
  - `AsusSetup.exe` acts as an orchestration wrapper around vendor sub-installers.
  - When `AsusSetup.exe` is present in the root of an ASUS package, it takes absolute precedence over internal sub-installers.
  - Installs silently and exits with code `0` or `3010`.

### 5.2 Lenovo (Lenovo Group Ltd.)
- **Primary Wrappers**: Standalone SoftPaq executables named `[a-z0-9]+us\d+\.exe` (e.g. `n2wud08w.exe`, `r0yuj14w.exe`), Inno Setup wrappers, or unpacked `Setup.exe`.
- **Official Switches**:
  - SoftPaq EXE: `["/VERYSILENT", "/NORESTART", "/SUPPRESSMSGBOXES"]`
  - Unpacked Setup: `["/s", "/norestart"]`
- **Behavioral Notes**:
  - Lenovo SoftPaqs frequently default to unpacking mode unless the silent deployment flags are supplied.
  - The combination of `/VERYSILENT` and `/NORESTART` ensures completely headless deployment.

### 5.3 HP (HP Inc. / Hewlett-Packard)
- **Primary Wrappers**: SoftPaq executables matching pattern `sp\d{4,7}\.exe` (e.g. `sp142850.exe`), `Setup.exe`, `Install.cmd`.
- **Metadata Discovery**: HP packages contain a `.cva` descriptor file (Control Variable File) containing INI-style sections:
  - `[Software Title]` -> Package display title
  - `[Install]` / `SilentInstall` -> Exact command-line and switches designated by HP engineers
- **Official Switches**:
  - Standalone SoftPaq: `["/s", "-s"]`
  - Unpacked HP Setup: `["/s", "/norestart"]`
- **Behavioral Notes**:
  - The package inspector automatically parses `.cva` files to extract the official `SilentInstall` command line before resorting to default switch evaluation.

### 5.4 Dell (Dell Technologies)
- **Primary Wrappers**: Dell Update Package (DUP) executables matching `*win64.exe` or `*dell*.exe` (e.g. `Audio_Realtek_WIN64_6.0.9239.1_A01.exe`).
- **Official Switches**:
  - DUP Executable: `["/s"]`
  - Forced update switch (where needed): `["/s", "/f"]`
- **Behavioral Notes**:
  - Dell DUP packages return code `0` for success and `3010` for success with reboot pending.
  - DUP wrappers automatically unpack their internal payloads into a temporary sandbox and invoke the respective driver installer.

### 5.5 Acer (Acer Inc.)
- **Primary Wrappers**: `Setup.exe`, `Install.bat`, direct INF collections.
- **Official Switches**:
  - `Setup.exe`: `["/s", "/norestart"]`
- **Behavioral Notes**:
  - Acer driver bundles often contain OEM wrappers around Intel or Realtek drivers.
  - If a wrapper is absent, the engine falls back to PnPUtil INF batch installation.

### 5.6 MSI (Micro-Star International)
- **Primary Wrappers**: `Setup.exe`, `Install.bat`, `SilentInstall.bat`.
- **Official Switches**:
  - `Setup.exe`: `["/s", "/norestart"]`
  - Silent script: Executed as a strict barrier with hidden window.

### 5.7 Gigabyte (Gigabyte Technology)
- **Primary Wrappers**: `Setup.exe`, `Install.exe`, `Run.exe`.
- **Official Switches**:
  - `Setup.exe` / `Install.exe`: `["/s", "/norestart"]`
- **Behavioral Notes**:
  - Gigabyte driver packs often include utility launchers. The engine excludes utility executables and targets the direct driver installer.

### 5.8 Samsung (Samsung Electronics)
- **Primary Wrappers**: `Setup.exe`, Samsung Update driver bundles.
- **Official Switches**:
  - `Setup.exe`: `["/s", "/norestart"]`

### 5.9 Toshiba / Dynabook
- **Primary Wrappers**: `Setup.exe`, Dynabook driver packages.
- **Official Switches**:
  - `Setup.exe`: `["/s", "/norestart"]`

### 5.10 Huawei (Huawei Technologies)
- **Primary Wrappers**: MateBook Driver packs, `Setup.exe`, `Install.exe`.
- **Official Switches**:
  - `Setup.exe`: `["/s", "/norestart"]`

---

## 6. Hardware Component Specifications

### 6.1 Intel Corporation
- **Hardware Vendor ID**: `VEN_8086`
- **Components & Switches**:
  1. **Intel Chipset Device Software**:
     - Entry point: `SetupChipset.exe`.
     - Silent switches: `["-s", "-norestart"]`.
     - Concurrency: Strict Barrier (Priority 1).
  2. **Intel Management Engine (MEI) / Serial IO**:
     - Entry point: `SetupME.exe`, `SetupSerialIO.exe`.
     - Silent switches: `["-s", "-norestart"]`.
     - Concurrency: Strict Barrier (Priority 2).
  3. **Intel Rapid Storage Technology (RST)**:
     - Entry point: `SetupRST.exe`.
     - Silent switches: `["-s", "-norestart"]`.
     - Concurrency: Strict Barrier (Priority 3).
  4. **Intel Graphics (UHD, Iris Xe, Intel Arc)**:
     - Modern entry point (11th Gen+, Arc): `Installer.exe`, `gfx_win*.exe`.
     - Modern switches: `["--overwrite", "-s"]`.
     - Legacy entry point: `igxpin.exe`.
     - Legacy switches: `["-s", "-norestart"]`.
     - Concurrency: Strict Barrier (Priority 4/5) + Mandatory 5-8s Display Settle Delay.
  5. **Intel Wi-Fi & Bluetooth**:
     - Entry point: `Setup.exe` or `dpinst.exe`.
     - Silent switches: `["/s", "/norestart"]` or `["/q", "/se", "/sa", "/sw"]`.
     - Concurrency: Parallel-Safe (2X Eligible).

### 6.2 Realtek Semiconductor Corp.
- **Hardware Vendor ID**: `VEN_10EC`
- **Components & Switches**:
  1. **Realtek High Definition Audio**:
     - Entry point: `setup.exe` (Realtek InstallShield / Custom Setup).
     - Silent switches: `["-s", "-norestart"]`.
     - Concurrency: Parallel-Safe (2X Eligible).
  2. **Realtek PCIe GbE / 2.5GbE LAN**:
     - Entry point: `setup.exe`, `Install_Win10.exe`, `Install_Win11.exe`.
     - Silent switches: `["/s", "/norestart"]`.
     - Concurrency: Parallel-Safe (2X Eligible).
  3. **Realtek RTS5139/RTS5229 Card Reader**:
     - Entry point: `setup.exe`.
     - Silent switches: `["/s", "/norestart"]`.
     - Concurrency: Parallel-Safe (2X Eligible).
  4. **Realtek Wireless (RTL8821CE, RTL8822CE, RTL8852BE)**:
     - Entry point: `setup.exe`.
     - Silent switches: `["/s", "/norestart"]`.
     - Concurrency: Parallel-Safe (2X Eligible).

### 6.3 NVIDIA Corporation
- **Hardware Vendor ID**: `VEN_10DE`
- **Components & Switches**:
  - **GeForce Game Ready, Studio, Quadro, RTX Drivers**:
    - Package types: Self-extracting setup (`*international-dch-whql.exe`) or extracted `setup.exe`.
    - Silent switches: `["-s", "-noreboot"]`.
    - Concurrency: Strict Barrier (Priority 5) + Mandatory 5-8s Display Settle Delay.
    - Timeout Watchdog: 600 seconds.

### 6.4 AMD (Advanced Micro Devices, Inc.)
- **Hardware Vendor ID**: `VEN_1002`
- **Components & Switches**:
  1. **AMD Radeon Software / Adrenalin Edition**:
     - Package types: `amd-software*.exe`, `Setup.exe`.
     - Silent switches: `["-INSTALL", "-OUTPUT", "screen", "-NORESTART"]`.
     - Concurrency: Strict Barrier (Priority 4/5) + Mandatory 5-8s Display Settle Delay.
     - **Unified Adrenalin Deduplication**: If an AMD APU (iGPU) and discrete AMD Radeon GPU share the same installer package, the engine executes the installer once and marks both hardware entries resolved.
  2. **AMD Chipset Drivers**:
     - Entry point: `Setup.exe`.
     - Silent switches: `["-s", "-norestart"]`.
     - Concurrency: Strict Barrier (Priority 1).

### 6.5 Qualcomm Inc.
- **Hardware Vendor ID**: `VEN_17CB` / `VEN_168C` (Atheros)
- **Components & Switches**:
  - Wi-Fi 6E/7 and Bluetooth controllers:
    - Entry points: `Setup.exe` (`["/s", "/norestart"]`) or PnPUtil direct INF deployment.
    - Concurrency: Parallel-Safe (2X Eligible).

### 6.6 MediaTek Inc.
- **Hardware Vendor ID**: `VEN_14C3`
- **Components & Switches**:
  - Wi-Fi (MT7921, MT7922, MT7902) & Bluetooth:
    - Entry points: `Install.exe`, `Setup.exe` (`["/s", "/norestart"]`) or PnPUtil direct INF deployment.
    - Concurrency: Parallel-Safe (2X Eligible).

### 6.7 Broadcom Inc.
- **Hardware Vendor ID**: `VEN_14E4`
- **Components & Switches**:
  - NetXtreme Gigabit Ethernet, Wi-Fi, Bluetooth:
    - Entry points: `Setup.exe` (`["/s", "/norestart"]`) or direct INF deployment via PnPUtil.
    - Concurrency: Parallel-Safe (2X Eligible).

### 6.8 Synaptics & ELAN Microelectronics
- **Hardware Vendor IDs**: `SYN`, `ELAN`, `ACPI\VEN_SYN*`, `ACPI\VEN_ELAN*`
- **Components & Switches**:
  - Precision Touchpad, TrackPoint, Fingerprint Readers:
    - Entry points: `Setup.exe` (`["/s", "/norestart"]`) or PnPUtil direct INF tree deployment.
    - Concurrency: Parallel-Safe (2X Eligible).

### 6.9 Goodix Technology
- **Hardware Vendor IDs**: `VEN_27C6`, `ACPI\GDIX*`
- **Components & Switches**:
  - Fingerprint sensors:
    - Entry points: `Setup.exe` (`["/s", "/norestart"]`) or direct INF deployment.
    - Concurrency: Parallel-Safe (2X Eligible).

---

## 7. Windows Driver Store (PnPUtil) INF Deployment

When an OEM driver package contains raw INF driver files without a recognized setup executable wrapper, the engine utilizes the official Windows Driver Store command-line utility `PnPUtil.exe`:

### 7.1 PnPUtil Invocation Command
```powershell
pnputil.exe /add-driver "<inf_path>" /install
```
For directories containing recursive driver structures with multiple INF files:
```powershell
pnputil.exe /add-driver "<root_directory>\*.inf" /subdirs /install
```

### 7.2 Safety Invariants for PnPUtil
- **Strict Barrier Classification**: All PnPUtil invocations modify the Windows Driver Store (`C:\Windows\System32\DriverStore`) and kernel driver binding tables. Therefore, PnPUtil installations are strictly classified as `is_barrier = True` and execute exclusively on Worker 1.
- **Exit Code Mapping**:
  - `0`: Driver installed successfully.
  - `3010`: Driver installed successfully, reboot required (sets `reboot_required = true`).
  - `259` (`ERROR_NO_MORE_ITEMS`): Driver already up-to-date or better driver already present (mapped to `completed`).

---

## 8. Windows Installer (MSI) & Concurrency Mutex Management

### 8.1 Kernel Mutex `Global\_MSIExecute`
The Windows Installer service (`msiexec.exe`) enforces single-instance execution at the operating system kernel level using the named mutex `Global\_MSIExecute`. Launching two concurrent MSI installations simultaneously causes the second instance to terminate immediately with error code `1618` (`ERROR_INSTALL_ALREADY_RUNNING`).

To prevent collisions:
1. All MSI packages (`install_method == "msiexec"`) and executables that unpack MSI payloads are designated as **Strict Barriers**.
2. The scheduler checks the state of `Global\_MSIExecute` via `OpenMutexW` prior to dispatching any installer that may use MSI.
3. If the mutex is occupied, the worker pauses and polls until the mutex is released.

### 8.2 Error 1618 Bounded Retry Policy
If an executable unexpectedly triggers an internal MSI payload and exits with `1618`:
1. The scheduler intercepts the `1618` code before reporting state to the UI.
2. If `retry_count < 2`:
   - Increments `retry_count`.
   - Converts the package to a strict barrier: `is_barrier = True`, `is_parallel_safe = False`.
   - Sets status to `pending` with explanatory message: `"Windows Installer در حال استفاده است؛ تلاش مجدد..."`.
   - Waits with exponential backoff:
     - Retry 1: 3.0 seconds + wait for `Global\_MSIExecute` release.
     - Retry 2: 7.0 seconds + wait for `Global\_MSIExecute` release.
   - Pushes the package to the head of the queue for exclusive execution on Worker 1.
3. If `retry_count >= 2`:
   - Marks the package as `failed` with a Persian error explanation, completely preventing infinite execution loops.

---

## 9. GUI Autopilot Safety & Bounded Interaction

For legacy or proprietary driver packages that do not provide silent switches, the system includes a background GUI Autopilot module:

### 9.1 Boundaries & Guardrails
- **Process Tree Binding**: Autopilot controls **only** windows owned directly by the launched installer PID or its spawned children. It never interacts with arbitrary windows on the desktop.
- **Window Title Safeguards**: Generic titles like `Setup` or `Install` are never considered sufficient proof of ownership unless the window handle belongs to the tracked process tree.
- **Safe State Transitions Only**:
  - Permitted actions: Clicking `Next` (`بعدی`), `Accept` (`پذیرش قوانین`), `Install` (`نصب`), `Finish` (`پایان`), `Close` (`بستن`), `OK` (`تایید`).
  - **Prohibited actions**: Any button labelled `Uninstall`, `Remove`, `Repair`, `Modify`, `Restart Now`, or `Reboot` is strictly ignored.
- **Non-blocking Window Messages**: Autopilot uses asynchronous message posting (`PostMessage`) or bounded timeouts (`SendMessageTimeout`) to ensure a hung dialog cannot freeze the queue thread.
