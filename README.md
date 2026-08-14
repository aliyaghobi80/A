# Central System Checker (مرکزی سیستم چکر) - Phase 1

A modern Windows desktop application built with **Flutter** (Frontend UI/UX) and **Python** (Modular Hardware Information Engine) designed to automatically inspect, verify, and display hardware and Windows operating system specifications.

---

## 🌟 Key Features (Phase 1)

### 1. Bilingual Support (English & Persian) with Native RTL
- **English**: LTR layout, clear technical terminology.
- **Persian (فارسی)**: Native RTL layout with natural Persian technical terminology:
  - CPU: **سی‌پی‌یو**
  - RAM: **رم**
  - GPU: **کارت گرافیک**
  - Motherboard: **مادربرد**
  - Storage: **حافظه ذخیره‌سازی**
  - Windows: **ویندوز**
  - BIOS / UEFI: **BIOS / UEFI**
  - Network: **شبکه**
  - Computer Name: **نام کامپیوتر**
  - System Model: **مدل سیستم**
  - Manufacturer: **سازنده**
  - Serial Number: **شماره سریال**
  - Architecture: **معماری**
  - Version: **نسخه**
  - Build Number: **شماره ساخت**
  - Unavailable Fallback: **موجود نیست**
- Hardware product names, CPU/GPU models, motherboard models, and Windows editions remain in their clean original Latin form (e.g. `Intel Core i3-12100F`, `NVIDIA GeForce RTX 3060`, `Gigabyte H610M K DDR4`, `Windows 11 Enterprise`).

### 2. Dual Display Modes
- **Simple Mode (Default)**:
  - Tailored for employees quickly comparing actual PC components with a paper purchase invoice.
  - Prioritizes the 6 core components:
    1. **CPU / سی‌پی‌یو**
    2. **RAM / رم**
    3. **GPU / کارت گرافیک**
    4. **Motherboard / مادربرد**
    5. **Storage / حافظه ذخیره‌سازی**
    6. **Windows / ویندوز**
  - High-contrast, easy-to-scan invoice cards with copy buttons and total specs summary copy.
- **Advanced Mode**:
  - Full diagnostic dashboard with detailed hardware metrics:
    - CPU cores, threads, clock speed
    - RAM slot locator, module types (DDR4/DDR5), speeds, part numbers
    - GPU dedicated 64-bit VRAM, driver versions
    - Physical storage disks, drive types (NVMe SSD, SATA SSD, HDD), bus interfaces, serial numbers
    - Motherboard serial number and manufacturer
    - Windows build number, UBR, host metadata
    - BIOS / UEFI version, vendor, release date
    - Network adapters, connection states, IPv4, MAC addresses, link speeds

### 3. Header Controls & Persistent User Preferences
- In-header **Mode Switcher**: `[ Simple | Advanced ]` / `[ ساده | پیشرفته ]`
- In-header **Language Switcher**: `[ EN | FA ]`
- In-header **Theme Toggle**: Light / Dark mode
- In-header **Refresh Button**: Instant live re-scan
- **Settings Persistence**: User preferences (language, display mode, theme) are remembered between sessions without any external database.

---

## 🏗️ Architecture

```
MarkaziSystem/
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
│   │       ├── simple_mode_view.dart # Invoice-comparison Checklist View
│   │       ├── advanced_mode_view.dart # Full Hardware Dashboard Grid
│   │       ├── summary_hero_bar.dart # Overview Metric Chips
│   │       ├── loading_view.dart    # Inspection Loader
│   │       ├── error_view.dart      # Error Boundary & Retry
│   │       └── cards/               # Hardware Category Cards
│   └── test/                        # Automated Widget & Unit Tests
│
├── backend/                         # Modular Python Hardware Detection Engine
│   ├── main.py                      # CLI & Server Runner (Host: 127.0.0.1:18080)
│   ├── server.py                    # Multi-threaded HTTP Server with CORS
│   ├── collector.py                 # Concurrent Task Orchestrator
│   ├── hardware/                    # Hardware Collectors (CPU, RAM, GPU, Storage, Motherboard, BIOS)
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

## 🔒 Scope Restriction (Phase 1)

This project strictly implements **Phase 1** specifications. The following features are excluded by design:
- Invoice comparison automation (Phase 2)
- Windows / Office activation tools
- Software installer / USB automation
- Cloud sync / database
