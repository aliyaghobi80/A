# Central System Checker (مرکزی سیستم چکر) - Phase 2 (Automatic EXE Software Scanner)

A high-performance Windows desktop application built with **Flutter** (Frontend UI/UX) and **Python** (Hardware, OS, Driver & Executable Software Discovery Engine) designed for rapid hardware verification, invoice audits, driver health inspections, and software package installation.

---

## 🌟 Key Features

### 1. Automatic Recursive EXE Software Scanner
- **No `package.json` required**: Drop any `.exe` or `.EXE` installer into the configured package directory, and the application discovers it automatically.
- **Recursive Subdirectory Scanning**:
  ```text
  Packages/
  ├── ChromeSetup.exe
  ├── WinRAR.exe
  ├── Apps/
  │   └── Browsers/
  │       └── ChromeSetup.exe
  ├── Tools/
  │   └── vlc.exe
  └── Utilities/
      └── 7Zip.EXE
  ```
- **Metadata Extraction from Windows Binaries**:
  - Automatically extracts `ProductName`, `FileDescription`, `CompanyName` (Publisher), `ProductVersion`, and `OriginalFilename` using Win32 VersionInfo APIs.
  - Automatically cleans filenames to human-readable names when metadata is absent.
- **Application Icon Extraction**:
  - Automatically extracts embedded application icons from `.exe` binaries into high-resolution PNG data URIs.
- **Configurable Software Root (`config/software_directory.json`)**:
  ```json
  {
    "packageRoot": "Packages",
    "description": "Relative or absolute directory path to scan for installable software .exe files"
  }
  ```
- **Clear Missing Directory Handling**:
  - If the configured directory is not found on disk, the UI displays a clear message:
    - Persian: `پوشه نرم‌افزارها پیدا نشد.`
    - English: `Software directory not found.`
- **Safe Installation Engine**:
  - Scanning NEVER executes files.
  - Clicking **[ Install ]** (`[ نصب ]`) displays a confirmation dialog, safely launches the user-selected installer with directory containment, waits for completion, and automatically refreshes installation status.

### 2. Simple Mode UI/UX (5–10s Paper Invoice Comparison)
- **Prominent Hardware Values**:
  - 22–26pt high-contrast typography for **CPU**, **RAM**, **GPU**, **Motherboard**, **Storage**, and **Windows**.
- **Top Quick Status Summary**:
  - **System Status**: `● Ready` (`● آماده`) / `● Needs Attention` (`● نیاز به بررسی`).
  - **Drivers**: `X / Y Important Drivers OK` (`X از Y درایور مهم سالم`).
  - **Software**: `X / Y Installed` (`X از Y نصب شده`).
  - **Files**: `X / Y Present` (`X از Y موجود است`).
- **1-Click Copy Summary**:
  - "Copy Specifications" / "کپی خلاصه مشخصات" exports all hardware, software, driver, and file checks to the clipboard.

### 3. Important Hardware Driver Checker
- **Critical Device Coverage**:
  - **Graphics / GPU**: NVIDIA, AMD, Intel display controllers.
  - **Audio Controller**: High Definition Audio / Realtek controllers.
  - **Ethernet**: Physical PCIe GbE / Gigabit network adapters.
  - **Wi-Fi**: Wireless LAN adapters.
  - **Bluetooth**: Bluetooth controllers (gracefully reports `Not Present` / `وجود ندارد` without penalizing systems lacking physical Bluetooth hardware).
  - **Chipset & System Devices**: Detects missing drivers (Code 28), startup failures (Code 10), and hardware issues.

### 4. Required Files and Folders Checker
- Configuration-driven check via [`config/file_requirements.json`](file:///g:/MarkaziSystem/config/file_requirements.json).

### 5. Bilingual Support (English & Persian) with Native RTL
- **English**: LTR layout, clear technical terminology.
- **Persian (فارسی)**: Native RTL layout with technical terminology:
  - Software: **نرم‌افزارها**
  - Scan: **اسکن**
  - Install: **نصب**
  - Installed: **نصب شده**
  - Not Installed: **نصب نشده**
  - Unknown: **نامشخص**
  - Present: **موجود است**
  - Missing: **موجود نیست**
  - Ready: **آماده**
  - Needs Attention: **نیاز به بررسی**
  - Driver OK: **سالم**
  - Driver Problem: **خطای درایور**
  - Not Present: **وجود ندارد**
  - System Status: **وضعیت سیستم**

### 6. Minimum Window Size Protection
- Enforces an appropriate minimum desktop window size ($1100 \times 700$ px with DPI scaling) via `WM_GETMINMAXINFO`.

---

## 🏗️ Architecture

```
MarkaziSystem/
├── Packages/                        # Configured Software Packages Directory
│   ├── Apps/Browsers/               # Nested folders discovered automatically
│   ├── Tools/
│   └── Utilities/
│
├── config/
│   ├── software_directory.json      # Configurable packages root path
│   ├── software_requirements.json   # Configurable list of required software
│   └── file_requirements.json       # Configurable list of required files/folders
│
├── frontend/                        # Flutter Desktop Application (Windows)
│   ├── lib/
│   │   ├── main.dart                # App Entry & State
│   │   ├── l10n/                    # Localization System (EN & FA)
│   │   ├── models/                  # SystemInfo, DriverItem, SoftwarePackage
│   │   ├── services/                # ApiService (system-info, packages, install)
│   │   ├── theme/                   # Dark/Light Themes + Persian Typography
│   │   └── widgets/
│   │       ├── simple_mode_view.dart # 5-10s Invoice Dashboard & Quick Status
│   │       ├── advanced_mode_view.dart # Detailed Diagnostics Grid
│   │       ├── summary_hero_bar.dart # Overview Metric Chips
│   │       └── cards/               # Hardware, Software, Driver, & Package Cards
│   │           ├── driver_card.dart
│   │           ├── packages_card.dart
│   │           ├── software_card.dart
│   │           └── files_card.dart
│   └── test/                        # Automated Unit & Widget Tests
│
├── backend/                         # Modular Python Engine
│   ├── main.py                      # CLI & Server Runner (Host: 127.0.0.1:18080)
│   ├── server.py                    # Multi-threaded HTTP Server
│   ├── collector.py                 # Concurrent Task Orchestrator
│   ├── drivers/                     # Windows PnP Driver Checker
│   │   └── checker.py
│   ├── packages/                    # Recursive EXE Scanner & Installer Engine
│   │   └── manager.py
│   ├── software/                    # Software Collectors
│   ├── files/                       # File/Folder Presence Checker
│   └── hardware/                    # CPU, RAM, GPU, Storage, Motherboard, BIOS
│
├── run_demo.bat                     # Windows Batch 1-Click Launcher
├── run_demo.ps1                     # Windows PowerShell 1-Click Launcher
└── README.md                        # Project Documentation
```

---

## 🚀 How to Run

### Option 1: 1-Click Launch (Recommended)
Double-click or run:
```cmd
run_demo.bat
```
*(or run `.\run_demo.ps1` in PowerShell)*

### Option 2: Running from Source

#### Step 1: Start Backend
```powershell
python backend/main.py
```

#### Step 2: Run Flutter Desktop App
```powershell
cd frontend
flutter run -d windows
```

---

## 🧪 Testing & Validation

```powershell
cd frontend
flutter test
flutter analyze
```
