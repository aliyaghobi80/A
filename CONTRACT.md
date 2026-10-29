# Markazi System Checker — Interface Contract & Technical Specifications

**Contract Version**: 4  
**Target Application Version**: 1.1.44 (Build 1.1.44+45)  
**Status**: Official Specification (Ratified by System Contract Architect)  
**Scope**: Backend API Server, Driver Engine, Concurrency Scheduler, Package Profiler, Hardware Matcher, Native Graphics Recovery, and Flutter Frontend.

---

## 1. Version Alignment Contract

All four release descriptors across the repository must remain strictly synchronized to the values below:

| Target File | Variable / Key | Target Value | Verification Check |
|---|---|---|---|
| `backend/api_server.py` | `APP_VERSION` & `/api/health` `version` | `"1.1.44"` | `GET /api/health` returns `"version": "1.1.44"` |
| `backend/api_server.py` | `/api/health` `api_contract_version` | `4` | `GET /api/health` returns `"api_contract_version": 4` |
| `frontend/pubspec.yaml` | `version` | `1.1.44+45` | `flutter pub get` & `flutter test` |
| `installer/setup.iss` | `#define MyAppVersion` | `"1.1.44"` | Inno Setup compile output |
| `build_production.py` | `APP_VERSION` | `"1.1.44"` | `py build_production.py --help` / build logs |

---

## 2. Driver Package Profiling Schema & Data Models

Every inspected driver package must produce a normalized `DriverPackage` dictionary conforming to the schema below. This schema is populated by `backend/drivers/package_inspector.py` without executing any binaries.

### 2.1 Complete JSON Schema for `DriverPackage`

```json
{
  "package_id": "drv_pkg_a1b2c3d4e5f60718",
  "display_name": "Realtek High Definition Audio Driver",
  "category": "audio",
  "category_fa": "کارت صدا و مالتی‌مدیا",
  "category_order": 9,
  "package_type": "folder",
  "source_path": "C:\\Drivers\\Realtek_Audio",
  "relative_path": "Realtek_Audio",
  "installer_file": "setup.exe",
  "installer_path": "C:\\Drivers\\Realtek_Audio\\setup.exe",
  "install_method": "setup_exe",
  "silent_args": ["-s", "-norestart"],
  "is_barrier": false,
  "is_parallel_safe": true,
  "resource_tag": "audio",
  "timeout_seconds": 300,
  "requires_reboot": false,
  "hardware_ids": [
    "HDAUDIO\\FUNC_01&VEN_10EC&DEV_0256",
    "HDAUDIO\\FUNC_01&VEN_10EC&DEV_0256&SUBSYS_10431234"
  ],
  "driver_version": "6.0.9239.1",
  "driver_date": "2024-03-15",
  "provider": "Realtek Semiconductor Corp.",
  "is_valid": true,
  "match": {
    "is_matched": true,
    "confidence": "HIGH",
    "status": "needs_install",
    "recommendation": "recommended"
  }
}
```

### 2.2 Field Definitions & Constraints

| Field | Type | Description | Mandatory Constraints |
|---|---|---|---|
| `package_id` | `string` | Deterministic 16-character SHA-256 hex string prefixed with `drv_pkg_`. | Stable across scans and UI refreshes. |
| `display_name` | `string` | User-friendly Persian/English component title. | Never empty. |
| `category` | `string` | Canonical category key. | Must be one of the 13 defined categories. |
| `category_fa` | `string` | Persian localized category label. | Displayed in UI cards. |
| `category_order` | `integer` | Numerical sorting weight for installation sequence. | 1 (highest priority) to 14 (lowest priority). |
| `package_type` | `string` | Physical packaging structure. | `"folder"`, `"archive"`, `"standalone_exe"`, `"standalone_msi"`, `"inf_only"`. |
| `source_path` | `string` | Absolute Windows file system path to root of package. | Must exist on disk. |
| `relative_path` | `string` | Path relative to root of scanned drivers directory. | Used for display & logging. |
| `installer_file` | `string` | Target entry-point filename (e.g. `setup.exe`, `AsusSetup.exe`). | Statically validated. |
| `installer_path` | `string` | Absolute path to target installer executable/script. | Statically validated. |
| `install_method` | `string` | Execution dispatcher route. | `"setup_exe"`, `"asus_setup"`, `"msiexec"`, `"pnputil"`, `"inf_pnputil"`, `"script"`, `"interactive"`. |
| `silent_args` | `list[string]` | Official unattended command-line flags. | **Zero guessed switches**. Empty `[]` if unknown. |
| `is_barrier` | `boolean` | Concurrency barrier flag. | `true` forces exclusive execution on Worker 1. |
| `is_parallel_safe` | `boolean` | 2X concurrency eligibility flag. | `true` permits parallel execution on Worker 2. |
| `resource_tag` | `string` | Hardware resource isolation tag. | Prevents resource collisions (e.g. `"audio"`, `"lan"`). |
| `timeout_seconds` | `integer` | Process watchdog timeout. | Default 300s; GPU 600s; Chipset 420s. |
| `requires_reboot` | `boolean` | Indicates whether package inherently demands restart. | Propagates to post-queue reminder. |
| `hardware_ids` | `list[string]` | List of extracted or matched PnP Hardware/Compatible IDs. | Normalized uppercase strings. |
| `driver_version` | `string` | Extracted package driver version string. | E.g. `"6.0.9239.1"` or empty string. |
| `driver_date` | `string` | Extracted INF driver date (`YYYY-MM-DD`). | ISO 8601 string or empty string. |
| `provider` | `string` | Vendor or publisher name from INF / PE header. | E.g. `"Realtek"`, `"Intel"`. |
| `match` | `object` | Hardware matcher assessment. | Contains `is_matched`, `confidence`, `status`, `recommendation`. |

---

## 3. Barrier vs Parallel-Safe Classification & Rules

To guarantee system stability, hardware registers are never written concurrently by competing installers.

### 3.1 Strict Barriers (`is_barrier: true`, `is_parallel_safe: false`)

A barrier package must **always** execute exclusively on **Worker 1**. Before a barrier executes, any running parallel worker must be **drained**. While a barrier is running, no other worker may claim or execute any package.

The following packages are strictly classified as Barriers:
1. **Core Platform & Chipset**:
   - `category in ("chipset", "system_mei", "storage")`
   - Intel Chipset Device Software, Intel Management Engine (MEI), Intel Rapid Storage Technology (RST), AMD Chipset Drivers.
2. **Graphics Drivers (GPU)**:
   - `category == "gpu"`
   - Discrete and integrated graphics installers (NVIDIA, AMD Radeon, Intel Graphics).
3. **Windows Installer (MSI Packages)**:
   - `install_method == "msiexec"` or any executable wrapper that unpacks/invokes `msiexec.exe`.
4. **PnPUtil INF Batches**:
   - `install_method in ("pnputil", "inf_pnputil")` (kernel driver store manipulation).
5. **Vendor Batch Scripts**:
   - `install_method == "script"` (`InstallPackage.bat`, `setup.bat`).
6. **System Runtimes & Frameworks**:
   - Visual C++ Redistributable, .NET Framework, DirectX Runtimes.
7. **Unknown or Unswitched Installers**:
   - Packages where `silent_args` is empty `[]` and require GUI Autopilot or interactive wizard confirmation.
8. **Re-scheduled 1618 Retry Packages**:
   - Any package retrying after an initial `1618` (`ERROR_INSTALL_ALREADY_RUNNING`) exit code.

### 3.2 Parallel-Safe Packages (`is_barrier: false`, `is_parallel_safe: true`)

Parallel-safe packages are eligible for concurrent execution on **Worker 2** only when **2X mode** is active (`double_speed == true`). In **1X mode**, all packages run serially on Worker 1.

A package is classified as Parallel-Safe **if and only if** all the following criteria are met:
1. `category in ("audio", "lan", "wifi", "bluetooth", "touchpad", "card_reader", "usb", "other")`.
2. `install_method in ("setup_exe", "asus_setup")`.
3. Verified, vendor-documented silent switches with reboot suppression are present in `silent_args`.
4. It does not invoke `msiexec.exe` or hold `Global\_MSIExecute`.
5. It does not collide with the `resource_tag` of an already active parallel package.

### 3.3 Drainage & Lookahead Barrier Invariants

1. **Pre-Barrier Drain Rule**: When Worker 1 dequeues a Barrier package, it checks if Worker 2 is currently active. If Worker 2 is active, Worker 1 must enter a blocking wait (`Condition.wait()`) until Worker 2 completes and releases its slot. Only when `active_workers == 0` does Worker 1 begin executing the Barrier.
2. **Lookahead Barrier Brake**: When Worker 2 completes an item and requests another task from the scheduler, the scheduler inspects the next pending item in the queue. If the next pending item is a Barrier, Worker 2 **must not** claim any subsequent item, even if parallel-safe items exist further down the queue. Worker 2 yields immediately so that Worker 1 can claim the Barrier without unnecessary delay.

---

## 4. Installation Ordering Contract

Queue items are strictly sorted by `category_order` before execution begins:

| Order | Category Key | Category Description | Concurrency Classification |
|---|---|---|---|
| **1** | `chipset` | Intel/AMD Core Chipset & Platform | **Strict Barrier** (Serial) |
| **2** | `system_mei` | Management Engine Interface / Serial IO | **Strict Barrier** (Serial) |
| **3** | `storage` | Rapid Storage Technology (RST) / NVMe | **Strict Barrier** (Serial) |
| **4** | `gpu` (iGPU) | Integrated Graphics (AMD APU or Intel UHD/Iris) | **Strict Barrier** (Serial + Display Settle) |
| **5** | `gpu` (dGPU) | Discrete Graphics (NVIDIA, AMD Radeon, Intel Arc) | **Strict Barrier** (Serial + Display Settle) |
| **6** | `lan` | Ethernet Controller | **Parallel-Safe** (2X Eligible) |
| **7** | `wifi` | Wireless WLAN Controller | **Parallel-Safe** (2X Eligible) |
| **8** | `bluetooth` | Bluetooth Adapter | **Parallel-Safe** (2X Eligible) |
| **9** | `audio` | High Definition Audio & Codecs | **Parallel-Safe** (2X Eligible) |
| **10** | `touchpad` | Precision Touchpad / Pointing Device | **Parallel-Safe** (2X Eligible) |
| **11** | `card_reader` | SD/PCIe Card Reader | **Parallel-Safe** (2X Eligible) |
| **12** | `camera` | Web Camera / IR Sensor | **Parallel-Safe** (2X Eligible) |
| **13** | `usb` | USB 3.x / Thunderbolt Drivers | **Parallel-Safe** (2X Eligible) |
| **14** | `other` | Hotkey utilities, OEM helper software | **Parallel-Safe** or Barrier if unswitched |

---

## 5. Windows Installer Mutex & Error 1618 Retry Policy

### 5.1 Mutex Synchronization (`Global\_MSIExecute`)

The Windows Installer service creates and holds the kernel mutex `Global\_MSIExecute` during any active installation transaction:
- The scheduler checks `Global\_MSIExecute` prior to launching any package known to invoke MSI technology.
- Check implementation: `OpenMutexW(SYNCHRONIZE | 0x0001, False, "Global\\_MSIExecute")`.
- If the handle is non-zero, Windows Installer is currently busy.

### 5.2 Error 1618 Bounded Retry & Serial Fallback Policy

When any installer process exits with code `1618` (`ERROR_INSTALL_ALREADY_RUNNING`):

```
Installer returns 1618
         │
         ▼
  retry_count < 2? ────► NO ───► Mark item as FAILED with Persian explanation
         │
        YES
         │
         ▼
Increment retry_count (+1)
Set status = "pending"
Set is_barrier = True  (FORCED SERIAL FALLBACK)
Set message = "Windows Installer در حال استفاده است؛ تلاش مجدد {N} از ۲..."
         │
         ▼
Exponential Backoff Delay:
- Retry 1: Wait 3.0s + poll wait_for_windows_installer_idle()
- Retry 2: Wait 7.0s + poll wait_for_windows_installer_idle()
         │
         ▼
Re-queue to head of queue
Execute exclusively on Worker 1 after Worker 2 drains
```

- **Maximum Retries**: Strictly capped at **2 retries** (maximum 3 total execution attempts).
- **Infinite Loop Prevention**: Under no circumstances may an item retry more than twice.
- **Immediate Failure Elimination**: An initial exit code of 1618 must **never** be recorded as an immediate installation failure in the UI.

---

## 6. Exit Code Normalization & Reboot Suppression Contract

All installer processes return an exit code that must be mapped to normalized queue item outcomes:

| Exit Code | Constant / Meaning | Normalized Status | Reboot Flag | Action Taken |
|---|---|---|---|---|
| `0` | `ERROR_SUCCESS` | `completed` | Unchanged | Mark successful. Advance queue. |
| `3010` | `ERROR_SUCCESS_REBOOT_REQUIRED` | `completed` | Set `reboot_required = true` | Mark successful. Suppress reboot. Queue continues. |
| `1641` | `ERROR_SUCCESS_REBOOT_INITIATED` | `completed` | Set `reboot_required = true` | Mark successful. Suppress reboot. Queue continues. |
| `1638` | `ERROR_PRODUCT_VERSION` | `completed` | Unchanged | Another version already installed. Acceptable success. |
| `1618` | `ERROR_INSTALL_ALREADY_RUNNING` | `pending` (retry) or `failed` | Unchanged | Trigger 1618 Retry Policy (Section 5.2). |
| `1602` | `ERROR_INSTALL_USEREXIT` | `failed` | Unchanged | Mark cancelled by technician. |
| `1603` | `ERROR_INSTALL_FAILURE` | `failed` | Unchanged | Record fatal MSI/Setup failure reason. |
| `-2` | `TIMEOUT_EXPIRED` | `failed` | Unchanged | Watchdog killed process tree. Record timeout failure. |
| `-5` | `WORKER_DIED` | `failed` | Unchanged | Recovered by dead worker watchdog. |
| Other | Non-zero exit code | `failed` | Unchanged | Record exit code in item state. |

### 6.1 Single Advisory Reboot Reminder

- Automated operating system restarts (`shutdown /r`, installer automatic reboots) are **strictly prohibited**.
- If any package completes with exit code `3010` or `1641`, the global queue flag `reboot_required` is set to `true`.
- When the entire driver queue finishes, the backend appends exactly one advisory Persian message to `summary_message`:
  `" — یادتان نرود پس از پایان همهٔ کارها، سیستم را دستی ری‌استارت کنید."`
- The Flutter UI displays an advisory dialog offering: `"متوجه شدم؛ بعداً ری‌استارت می‌کنم"`.

---

## 7. Process Tree Termination & Timeout Watchdog Contract

When an installer process hangs or exceeds `timeout_seconds`:

### 7.1 Specification for `terminate_process_tree`

```python
def terminate_process_tree(pid: int) -> bool:
    """
    Forcefully terminates a process and all of its spawned child processes.
    Uses Windows native taskkill.exe with /F (force) and /T (tree).
    """
    if not pid or pid <= 0:
        return False
    try:
        cmd = ["taskkill.exe", "/F", "/T", "/PID", str(pid)]
        CREATE_NO_WINDOW = 0x08000000
        res = subprocess.run(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            creationflags=CREATE_NO_WINDOW,
            timeout=10,
        )
        return res.returncode == 0
    except Exception as e:
        logger.error(f"Failed to terminate process tree for PID {pid}: {e}")
        return False
```

- When `subprocess.TimeoutExpired` occurs in `_run_elevated_and_wait` or scheduler worker:
  1. Capture the process PID.
  2. Invoke `terminate_process_tree(pid)`.
  3. Return exit code `-2`.
  4. Record failure reason: `"زمان مجاز نصب به پایان رسید و فرآیند متوقف شد (Timeout)."`

---

## 8. GPU Vendor Installation Subsystem Contract

Graphics driver deployment must handle hardware topology (hybrid graphics, APUs + dGPUs) safely.

### 8.1 Common Interface: `GpuVendorInstaller`

Located in `backend/drivers/gpu_installers.py`:

```python
from abc import ABC, abstractmethod
from typing import Dict, Any

class GpuVendorInstaller(ABC):
    @abstractmethod
    def can_handle(self, package: Dict[str, Any]) -> bool:
        """Determines if this vendor installer matches the package."""
        pass

    @abstractmethod
    def install(self, package: Dict[str, Any], timeout_seconds: int = 600) -> Dict[str, Any]:
        """
        Executes the unattended GPU installation.
        Returns Dict with keys: success (bool), exit_code (int), message (str), reboot (bool).
        """
        pass

    @abstractmethod
    def get_vendor_name(self) -> str:
        """Returns vendor display name ('NVIDIA', 'AMD', 'Intel')."""
        pass
```

### 8.2 Vendor Specific Implementations

1. **`NvidiaGpuInstaller`**:
   - Matches: `VEN_10DE` or package filename matching `*geforce*`, `*whql*.exe`, `*quadro*`.
   - Silent switches: `["-s", "-noreboot"]`.
   - Timeout: 600 seconds.
2. **`AmdGpuInstaller`**:
   - Matches: `VEN_1002` or package filename matching `*adrenalin*`, `*radeon*`, `amd-software*.exe`.
   - Silent switches: `["-INSTALL", "-OUTPUT", "screen", "-NORESTART"]`.
   - Timeout: 600 seconds.
   - **Unified Adrenalin Deduplication**: If an AMD APU (iGPU) and AMD Radeon (dGPU) share the identical hardware package, the installer executes once and maps completion to both devices.
3. **`IntelGpuInstaller`**:
   - Matches: `VEN_8086` (Display controller class) or `Installer.exe`, `igxpin.exe`, `gfx_win*.exe`.
   - Modern Switch (Intel Arc / 11th Gen+): `["--overwrite", "-s"]`.
   - Legacy Switch: `["-s", "-norestart"]`.
   - Timeout: 480 seconds.

### 8.3 GPU Execution Rules & Display Settle Delay

1. **Topological Order**:
   - iGPU (Integrated Processor Graphics) **must always be installed before** dGPU (Discrete Dedicated Graphics).
   - Global vendor priority: `AMD` → `Intel` → `NVIDIA`.
2. **Mandatory Display Settle Delay**:
   - Windows Display Driver Model (WDDM) resets the display adapter during graphics driver replacement, temporarily interrupting DXGI swap chains.
   - After any GPU installer completes (success or failure), the scheduler must execute a non-blocking delay of **5 to 8 seconds** (default: 8s) before starting any subsequent package or initiating a hardware scan.

---

## 9. Atomic State Persistence Contract

To guarantee that a graphics reset, UI crash, or process termination does not corrupt queue state, all state changes must be written atomically to disk:

- **State File Path**:  
  `%LOCALAPPDATA%\MarkaziSystemChecker\driver_queue_state.json`  
  (Fallback: `%APPDATA%\MarkaziSystemChecker\driver_queue_state.json` or `C:\ProgramData\MarkaziSystemChecker\driver_queue_state.json`).
- **Atomic Replacement Protocol**:
  ```python
  def persist_queue_state_atomic(state_dict: dict, file_path: str) -> None:
      temp_path = f"{file_path}.tmp"
      os.makedirs(os.path.dirname(file_path), exist_ok=True)
      with open(temp_path, "w", encoding="utf-8") as f:
          json.dump(state_dict, f, ensure_ascii=False, indent=2)
          f.flush()
          os.fsync(f.fileno())
      os.replace(temp_path, file_path)
  ```
- **Backend Adoption Handshake**:
  - If the Flutter UI crashes and relaunches, it connects to `/api/drivers/queue/status`.
  - The backend serves the active state directly from memory, verified against the atomic snapshot on disk.

---

## 10. Queue Status API Schema (`/api/drivers/queue/status` & `/api/drivers/batch-status`)

Both endpoints serve identical JSON structures. Contract Version 4 adds `active_items` while maintaining backward compatibility with `current_package` and `current_index`.

### 10.1 Complete Response JSON Schema

```json
{
  "status": "ok",
  "is_running": true,
  "cancelled": false,
  "mode": "2X",
  "double_speed": true,
  "worker_count": 2,
  "active_workers": 2,
  "total": 6,
  "completed": 2,
  "failed": 0,
  "skipped": 0,
  "current_index": 2,
  "current_package": "Realtek Audio Driver",
  "current_file": "Realtek Audio Driver",
  "progress_percent": 33.3,
  "start_time": 1729000080.0,
  "end_time": null,
  "reboot_required": false,
  "summary_message": "در حال نصب موازی ۲ درایور...",
  "resolved_devices_count": 0,
  "last_update_time": 1729000112.8,
  "worker_alive": true,
  "fatal_error": "",
  "active_items": [
    {
      "package_id": "drv_pkg_a1b2c3d4",
      "display_name": "Realtek Audio Driver",
      "category": "audio",
      "worker_id": 1,
      "status": "installing",
      "start_time": 1729000100.5,
      "elapsed_seconds": 12.3,
      "retry_count": 0
    },
    {
      "package_id": "drv_pkg_e5f60718",
      "display_name": "Intel Wi-Fi Driver",
      "category": "wifi",
      "worker_id": 2,
      "status": "installing",
      "start_time": 1729000104.2,
      "elapsed_seconds": 8.6,
      "retry_count": 0
    }
  ],
  "items": [
    {
      "package_id": "drv_pkg_1111",
      "display_name": "Intel Chipset Device Software",
      "category": "chipset",
      "category_fa": "چیپست و مدیریت پلتفرم",
      "installer_file": "SetupChipset.exe",
      "status": "completed",
      "worker_id": null,
      "message": "نصاب درایور با موفقیت اجرا و نصب شد.",
      "failure_reason": null,
      "exit_code": 0,
      "retry_count": 0
    },
    {
      "package_id": "drv_pkg_a1b2c3d4",
      "display_name": "Realtek Audio Driver",
      "category": "audio",
      "category_fa": "کارت صدا و مالتی‌مدیا",
      "installer_file": "setup.exe",
      "status": "installing",
      "worker_id": 1,
      "message": "در حال نصب...",
      "failure_reason": null,
      "exit_code": null,
      "retry_count": 0
    },
    {
      "package_id": "drv_pkg_e5f60718",
      "display_name": "Intel Wi-Fi Driver",
      "category": "wifi",
      "category_fa": "شبکه بی‌سیم (Wi-Fi)",
      "installer_file": "Setup.exe",
      "status": "installing",
      "worker_id": 2,
      "message": "در حال نصب...",
      "failure_reason": null,
      "exit_code": null,
      "retry_count": 0
    },
    {
      "package_id": "drv_pkg_2222",
      "display_name": "NVIDIA Graphics Driver",
      "category": "gpu",
      "category_fa": "کارت گرافیک",
      "installer_file": "setup.exe",
      "status": "pending",
      "worker_id": null,
      "message": "",
      "failure_reason": null,
      "exit_code": null,
      "retry_count": 0
    }
  ]
}
```

### 10.2 Field Validation Rules

- `active_items`: Array of 0, 1, or 2 items currently executing.
  - When queue is running in 1X mode: Contains at most 1 item (`worker_id: 1`).
  - When queue is running in 2X mode: Contains up to 2 items (`worker_id: 1` and `worker_id: 2`).
  - When queue is draining or waiting for barrier: Contains 0 or 1 item.
- `current_package` / `current_file`:
  - When 1 item is active: String matching `active_items[0].display_name`.
  - When 2 items are active: Concatenated string: `"{Item 1} • {Item 2}"` for backward compatibility with older UI widgets.
- `items`: All items in queue order. An item's status transitions:
  `pending` → `installing` → (`completed` | `failed` | `skipped`).

---

## 11. Frontend UI Specifications

### 11.1 GPU Flashing Warning Banner

In `frontend/lib/widgets/pages/driver_install_page.dart` (and `driver_card.dart`):
- **Display Condition**: Visible if and only if:
  `batchStatus.isRunning && batchStatus.items.any((item) => item.status == 'installing' && item.category.toLowerCase() == 'gpu')`
- **Exact Persian Text**:  
  `«ممکن است صفحه چند ثانیه چشمک بزند؛ برنامه ادامه می‌دهد»`
- **UI Presentation**:
  - Container with amber background (`Colors.amber.shade900.withOpacity(0.2)`), amber border, and info/tv icon.
  - Directionality: RTL layout for Persian message.

### 11.2 Dual Active Items Display in 2X Mode

- **Header Text in Queue Progress Panel**:
  - Single active item: `"در حال نصب: {Item} ({done} از {total})"`
  - Two active items: `"در حال نصب (۲ مورد همزمان): {Item 1} • {Item 2} ({done} از {total})"`
- **Active Progress Slots**:
  - Render two distinct progress chips/cards side by side when 2 items are installing.
  - Each chip displays the worker tag (`خط ۱` and `خط ۲`), the package display name, elapsed seconds, and an animated spinner.
- **Widget Key Invariant**:
  - All cards, tiles, and chips must explicitly specify `ValueKey('driver-queue-${item.packageId}')` to avoid Flutter widget recycling or flickering during parallel state transitions.

---

## 12. Application Batch Installer Compatibility

The software batch installer (`backend/packages/batch_installer.py`) extends this exact same scheduler specification:
1. `double_speed == true` enables up to 2 concurrent standalone EXE installations.
2. MSI installers, packages invoking `msiexec`, and runtimes (DirectX, VC++) are designated strict barriers.
3. Mutex inspection on `Global\_MSIExecute` and error 1618 retry policy apply identically to software packages.
