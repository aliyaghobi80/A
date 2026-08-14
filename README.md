# Central System Checker (مرکزی سیستم چکر) - Phase 2 Refined

A modern Windows desktop application built with **Flutter** (Frontend UI/UX) and **Python** (Modular Hardware, OS, Software, Driver & Package Engine) designed for fast, accurate hardware verification, invoice audits, driver health inspections, and software package management.

---

## 🌟 Key Features (Phase 1 & Phase 2 Refined)

### 1. Simple Mode UI/UX (5–10s Paper Invoice Comparison)
- **Prominent Hardware Values**:
  - High-contrast, large (22–26pt) main values for **CPU**, **RAM**, **GPU**, **Motherboard**, **Storage**, and **Windows**.
  - Immediate visual clarity for non-technical retail staff comparing physical PC specs against purchase invoices.
- **Top Quick Status Summary**:
  - **System Status**: `● Ready` (`● آماده`) / `● Needs Attention` (`● نیاز به بررسی`).
  - **Drivers**: `X / Y Important Drivers OK` (`X از Y درایور مهم سالم`).
  - **Software**: `X / Y Installed` (`X از Y نصب شده`).
  - **Files**: `X / Y Present` (`X از Y موجود است`).
- **1-Click Copy Summary**:
  - "Copy Specifications" / "کپی خلاصه مشخصات" formats all specs cleanly to clipboard.

### 2. Important Hardware Driver Checker
- **Critical Device Coverage**:
  - **Graphics / GPU**: NVIDIA, AMD, Intel display controllers.
  - **Audio Controller**: High Definition Audio / Realtek controllers.
  - **Ethernet**: Physical PCIe GbE / Gigabit network adapters.
  - **Wi-Fi**: Wireless LAN adapters.
  - **Bluetooth**: Bluetooth controllers (gracefully reports `Not Present` / `وجود ندارد` without penalizing systems lacking physical Bluetooth hardware).
  - **Chipset & System Devices**: Detects missing drivers (Code 28), startup failures (Code 10), and hardware issues.

### 3. Software Package System & Manifests
- **Structured Package System**:
  ```
  Packages/
  ├── Chrome/
  │   ├── package.json
  │   ├── installer.exe
  │   └── app.ico
  ├── WinRAR/
  │   ├── package.json
  │   ├── installer.exe
  │   └── app.ico
  ├── VLC/
  │   ├── package.json
  │   ├── installer.exe
  │   └── app.ico
  └── ...
  ```
- **Package Manifest Schema (`package.json`)**:
  ```json
  {
    "id": "vlc",
    "name": "VLC Media Player",
    "version": "3.0.21",
    "publisher": "VideoLAN",
    "installer": "installer.exe",
    "icon": "app.ico",
    "silentArguments": "/S",
    "detectionId": "vlc"
  }
  ```
- **Security & Integrity**:
  - Validates manifest schema and verifies installer exists directly inside the package folder.
  - Blocks path traversal (e.g. `../` or arbitrary root executables).
  - Dedicated **"Scan Packages"** button rescans the Packages directory on-demand.
  - Safe **[ Install ]** button with confirmation dialog, enabled only for valid, uninstalled packages.

### 4. Required Files and Folders Checker
- Configuration-driven check via [`config/file_requirements.json`](file:///g:/MarkaziSystem/config/file_requirements.json) (`Training Folder`, `Desktop Tools`, `System Hosts File`).

### 5. Bilingual Support (English & Persian) with Native RTL
- **English**: LTR layout, clear technical terminology.
- **Persian (فارسی)**: Native RTL layout with technical terminology:
  - Software: **نرم‌افزارها**
  - Required Files: **فایل‌های موردنیاز**
  - Drivers: **درایورها**
  - Scan: **اسکن** / **اسکن پکیج‌ها**
  - Install: **نصب**
  - Installed: **نصب شده**
  - Not Installed: **نصب نشده**
  - Present: **موجود است**
  - Missing: **موجود نیست**
  - Ready: **آماده**
  - Needs Attention: **نیاز به بررسی**
  - Not Present: **وجود ندارد**
  - Driver OK: **سالم**
  - Driver Problem: **خطای درایور**
  - System Status: **وضعیت سیستم**
- Product and hardware model names remain in Latin form.

### 6. Minimum Window Size Protection
- Enforces an appropriate minimum desktop window size ($1100 \times 700$ px with DPI scaling) via `WM_GETMINMAXINFO` in the Windows runner.

---

## 🏗️ Architecture

```
MarkaziSystem/
├── Packages/                        # Configured Software Packages Directory
│   ├── Chrome/                      # Valid Package (package.json + installer)
│   ├── WinRAR/                      # Valid Package
│   ├── VLC/                         # Valid Package
│   ├── 7Zip/                        # Valid Package (available to install)
│   └── InvalidSample/               # Invalid package test case
│
├── config/
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
│   │           ├── files_card.dart
│   │           └── ... (CPU, RAM, GPU, Motherboard, Storage, Windows, BIOS, Network)
│   └── test/                        # Automated Unit & Widget Tests
│
├── backend/                         # Modular Python Engine
│   ├── main.py                      # CLI & Server Runner (Host: 127.0.0.1:18080)
│   ├── server.py                    # Multi-threaded HTTP Server with Package API
│   ├── collector.py                 # Concurrent Task Orchestrator (Hardware + Drivers + Software + Files)
│   ├── drivers/                     # Windows PnP Driver Checker
│   │   └── checker.py
│   ├── packages/                    # Software Package Manager & Installer Runner
│   │   └── manager.py
│   ├── software/                    # Software Collectors (Registry, Office, Binary Versioning)
│   ├── files/                       # File/Folder Presence Checker
│   ├── hardware/                    # CPU, RAM, GPU, Storage, Motherboard, BIOS
│   └── windows/                     # OS & Network
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

---

## 🔒 Scope Restriction

This project strictly implements **Phase 1 and Phase 2** specifications. The following features are excluded by design until Phase 3+:
- Windows / Office activation checking or tools
- Automated driver installation
- Automated invoice OCR
- Cloud sync / Databases / User accounts
