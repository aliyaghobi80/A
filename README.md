# Central System Checker (مرکزی سیستم چکر) - Phase 2

A modern Windows desktop application built with **Flutter** (Frontend UI/UX) and **Python** (Modular Hardware & Software Verification Engine) designed to automatically inspect, verify, and display hardware specifications, Windows operating system metrics, required installed software, and required file/folder presence.

---

## 🌟 Key Features (Phase 1 & Phase 2)

### 1. Automated Required Software Verification (Phase 2)
- **Configuration-Driven**: Required software items are configured via [`config/software_requirements.json`](file:///g:/MarkaziSystem/config/software_requirements.json) without hardcoding logic in UI widgets.
- **Deep Windows Inspection**:
  - 64-bit Uninstall Registry (`HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall`)
  - 32-bit WOW6432Node Registry (`HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall`)
  - Current User Registry (`HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall`)
  - App Paths Registry (`HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths`)
  - Win32 `GetFileVersionInfoW` binary version extraction via `ctypes`.
- **Microsoft Office Detection**:
  - Automatically identifies Click-to-Run (C2R) and MSI Office installations (e.g. `Microsoft Office 2024`, `Microsoft Office 2021`, `Microsoft 365`).
  - Reports product edition and version without checking or modifying activation state.
- **Default Software Checklist**:
  - Google Chrome
  - WinRAR
  - VLC Media Player
  - Microsoft Office

### 2. Required Files and Folders Presence (Phase 2)
- **Configuration-Driven**: Required files and folders are configured via [`config/file_requirements.json`](file:///g:/MarkaziSystem/config/file_requirements.json).
- **Inspection**: Determines `Present` (`موجود است`) vs `Missing` (`موجود نیست`) without altering file system state.

### 3. Minimum Window Size Protection (Phase 1 Final UI Fix)
- Enforces an appropriate minimum desktop window size ($1100 \times 700$ px with DPI scaling) via `WM_GETMINMAXINFO` in the Windows runner.
- Prevents UI card distortion, text clipping, and header overflow in both English (LTR) and Persian (RTL). Normal resizing larger is fully preserved.

### 4. Bilingual Support (English & Persian) with Native RTL
- **English**: LTR layout, clear technical terminology.
- **Persian (فارسی)**: Native RTL layout with exact technical terminology:
  - CPU: **سی‌پی‌یو**
  - RAM: **رم**
  - GPU: **کارت گرافیک**
  - Motherboard: **مادربرد**
  - Storage: **حافظه ذخیره‌سازی**
  - Windows: **ویندوز**
  - BIOS / UEFI: **BIOS / UEFI**
  - Network: **شبکه**
  - Software: **نرم‌افزارها**
  - Required Files: **فایل‌ها و پوشه‌های موردنیاز**
  - Installed / Not Installed: **نصب شده / نصب نشده**
  - Present / Missing: **موجود است / موجود نیست**
  - Version: **نسخه**
  - Path: **مسیر**
  - Fallback: **موجود نیست**
- Hardware product names and software brand names remain in their clean original Latin form.

### 5. Dual Display Modes
- **Simple Mode (Default)**:
  - Fast invoice comparison for store staff:
    1. **Hardware Specifications**: CPU, RAM, GPU, Motherboard, Storage, Windows.
    2. **Required Software Checklist**: Google Chrome, WinRAR, VLC, Office with status badges (`✓` / `✗`).
    3. **Required Files & Folders Checklist**: Training Folder, Desktop Tools with presence badges (`✓` / `✗`).
  - 1-Click **"Copy Specifications" / "کپی خلاصه مشخصات"** clipboard export.
- **Advanced Mode**:
  - Full diagnostic dashboard including `SoftwareCard` (version, detection source, install location) and `FilesCard` (type, path, status).

### 6. Header Controls & Persistent User Preferences
- **Mode Switcher**: `[ Simple | Advanced ]` / `[ ساده | پیشرفته ]`
- **Language Switcher**: `[ EN | FA ]`
- **Theme Toggle**: Light / Dark mode
- **Refresh Button**: Live re-scan of hardware, software, and files.
- **Settings Persistence**: Stored in `%APPDATA%\CentralSystemChecker\settings.json`.

---

## 🏗️ Architecture

```
MarkaziSystem/
├── config/
│   ├── software_requirements.json   # Configurable list of required software
│   └── file_requirements.json       # Configurable list of required files/folders
│
├── frontend/                        # Flutter Desktop Application (Windows)
│   ├── lib/
│   │   ├── main.dart                # App Entry, Locale & Mode State Management
│   │   ├── l10n/                    # Localization System
│   │   │   ├── app_localizations.dart # Abstract Base & Delegate
│   │   │   ├── app_en.dart          # English Strings
│   │   │   └── app_fa.dart          # Persian Strings (Official Technical Terms)
│   │   ├── models/
│   │   │   └── system_info.dart     # Type-safe Dart Data Models
│   │   ├── services/
│   │   │   ├── api_service.dart     # HTTP client for Python Backend API
│   │   │   ├── backend_process_manager.dart # Lifecycle & auto-launcher
│   │   │   └── settings_service.dart # Lightweight JSON Preferences Storage
│   │   ├── theme/
│   │   │   └── app_theme.dart       # Modern Dark/Light Themes + Persian Typography
│   │   └── widgets/
│   │       ├── app_header.dart      # Brand Title, Mode & Language Switchers, Theme Toggle
│   │       ├── simple_mode_view.dart # Simple Invoice & Checklist View
│   │       ├── advanced_mode_view.dart # Full Hardware & Diagnostic Dashboard Grid
│   │       ├── summary_hero_bar.dart # Overview Metric Chips
│   │       ├── loading_view.dart    # Inspection Loader
│   │       ├── error_view.dart      # Error Boundary & Retry
│   │       └── cards/               # Hardware, Software, & File Diagnostic Cards
│   │           ├── software_card.dart
│   │           ├── files_card.dart
│   │           ├── cpu_card.dart
│   │           ├── ram_card.dart
│   │           ├── gpu_card.dart
│   │           ├── motherboard_card.dart
│   │           ├── storage_card.dart
│   │           ├── windows_card.dart
│   │           ├── bios_card.dart
│   │           └── network_card.dart
│   └── test/                        # Automated Widget & Unit Tests
│
├── backend/                         # Modular Python Verification Engine
│   ├── main.py                      # CLI & Server Runner (Host: 127.0.0.1:18080)
│   ├── server.py                    # Multi-threaded HTTP Server with CORS
│   ├── collector.py                 # Concurrent Task Orchestrator
│   ├── hardware/                    # Hardware Collectors (CPU, RAM, GPU, Storage, Motherboard, BIOS)
│   ├── software/                    # Software Collectors (Registry, Office, Binary Versioning)
│   │   ├── detector.py
│   │   ├── registry.py
│   │   └── office.py
│   ├── files/                       # File/Folder Presence Checker
│   │   └── checker.py
│   ├── windows/                     # Windows OS & Network Collectors
│   └── utils/                       # PowerShell Runner & Formatters
│
├── run_demo.bat                     # Windows Batch 1-Click Launcher
├── run_demo.ps1                     # Windows PowerShell 1-Click Launcher
└── README.md                        # Project Documentation
```

---

## 🚀 How to Run

### Option 1: 1-Click Launch (Recommended)
Double-click or run in terminal:
```cmd
run_demo.bat
```
*(or run `.\run_demo.ps1` in PowerShell)*

### Option 2: Running from Source / Development Mode

#### Step 1: Start Backend
```powershell
python backend/main.py
```
*(Runs on `http://127.0.0.1:18080`)*

#### Step 2: Run Flutter App
```powershell
cd frontend
flutter run -d windows
```

---

## 🧪 Testing & Validation

Run the automated test suite:
```powershell
cd frontend
flutter test
flutter analyze
```

---

## 🔒 Scope Restriction (Phase 2)

This project strictly implements **Phase 1 and Phase 2** specifications. The following features are excluded by design until Phase 3+:
- Windows / Office activation checking or tools
- Automated software installation / USB installer
- Invoice OCR / automated invoice comparison
- Databases / User accounts / Cloud sync
