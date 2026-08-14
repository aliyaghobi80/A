# PC System Inspector (Phase 1)

A modern Windows desktop application built with **Flutter** (Frontend UI/UX) and **Python** (Modular System Information Engine) designed to automatically inspect and display real hardware and Windows operating system specifications.

---

## 📸 Overview & Features

### Core Inspection Capabilities (Phase 1)

1. **CPU**
   - Processor Model Name (e.g. `12th Gen Intel(R) Core(TM) i3-12100F`)
   - Manufacturer (e.g. `Intel`)
   - Physical Cores and Logical Threads count (e.g. `4 Cores / 8 Threads`)
   - Maximum Clock Speed (e.g. `3.30 GHz`)

2. **Motherboard**
   - Manufacturer (e.g. `Gigabyte Technology Co., Ltd.`, `ASUS`)
   - Product / Model (e.g. `H610M K DDR4`)
   - Serial Number (with automatic placeholder sanitization)

3. **RAM (Memory)**
   - Total Installed RAM Capacity (e.g. `16 GB`)
   - Module Count (e.g. `2 Modules`)
   - Configuration breakdown (e.g. `8 GB + 8 GB`)
   - Speed (e.g. `2133 MHz`, `3200 MHz`)
   - Per-module details (Slot Locator, Capacity, Type DDR4/DDR5, Speed, Manufacturer, Part Number)

4. **GPU (Graphics)**
   - All installed Graphics Cards detected (discrete and integrated)
   - Manufacturer
   - Dedicated VRAM (accurate 64-bit detection via Registry `qwMemorySize`, `nvidia-smi`, WMI)
   - Driver Version

5. **Physical Storage Devices**
   - All physical storage drives enumerated (NVMe SSD, SATA SSD, HDD)
   - Model / Friendly Name
   - Drive Type (NVMe SSD, SATA SSD, HDD)
   - Bus Interface (NVMe, SATA, USB)
   - Formatted Capacity (e.g. `1.0 TB`, `512 GB`, `466 GB`)
   - Serial Number and Health Status

6. **Windows Information**
   - OS Edition (e.g. `Windows 11 Enterprise`, `Windows 11 Pro`)
   - Display Version (e.g. `Version 25H2`, `Version 24H2`)
   - Build Number & UBR (e.g. `26200.9168`)
   - Architecture (`64-bit` / `32-bit`)
   - Computer Name (Host Name)
   - System Manufacturer and System Model

7. **BIOS / UEFI**
   - BIOS Manufacturer (e.g. `American Megatrends International, LLC.`)
   - BIOS Version / SMBIOS Version (e.g. `F22`)
   - Release Date (e.g. `2023-06-05`)

8. **Network Adapters**
   - Adapter Name & Description
   - Connection Status (`Up` / `Disconnected`) with visual indicator
   - IPv4 Address
   - MAC Address
   - Link Speed

---

## 🏗️ Architecture

```
pc_system_inspector/
│
├── frontend/                        # Flutter Desktop Application (Windows)
│   ├── lib/
│   │   ├── main.dart                # Main Dashboard View & Responsive Grid
│   │   ├── models/
│   │   │   └── system_info.dart     # Type-safe Dart Data Models
│   │   ├── services/
│   │   │   ├── api_service.dart     # HTTP client communicating with Backend
│   │   │   └── backend_process_manager.dart # Lifecycle & auto-launcher
│   │   ├── theme/
│   │   │   └── app_theme.dart       # Modern Dark/Light theme system
│   │   └── widgets/
│   │       ├── app_header.dart      # Title, Subtitle, Theme Toggle, Refresh Button
│   │       ├── summary_hero_bar.dart# Top quick-metric overview chips
│   │       ├── loading_view.dart    # Startup inspection loader
│   │       ├── error_view.dart      # Retry and error boundary view
│   │       └── cards/               # Hardware category cards
│   │           ├── cpu_card.dart
│   │           ├── motherboard_card.dart
│   │           ├── ram_card.dart
│   │           ├── gpu_card.dart
│   │           ├── storage_card.dart
│   │           ├── windows_card.dart
│   │           ├── bios_card.dart
│   │           ├── network_card.dart
│   │           ├── card_wrapper.dart
│   │           └── info_row.dart
│   └── test/                        # Flutter widget and unit tests
│
├── backend/                         # Modular Python System Information Engine
│   ├── main.py                      # CLI & Server Runner (Host: 127.0.0.1:18080)
│   ├── server.py                    # Multi-threaded HTTP Server with CORS
│   ├── collector.py                 # Concurrent Task Orchestrator
│   ├── hardware/                    # Hardware Collectors
│   │   ├── cpu.py
│   │   ├── motherboard.py
│   │   ├── ram.py
│   │   ├── gpu.py
│   │   ├── storage.py
│   │   └── bios.py
│   ├── windows/                     # Windows OS Collectors
│   │   ├── system.py
│   │   └── network.py
│   └── utils/                       # Helpers & Formatters
│       ├── powershell.py
│       └── formatters.py
│
├── run_demo.bat                     # Windows Batch 1-Click Launcher
├── run_demo.ps1                     # Windows PowerShell 1-Click Launcher
└── README.md                        # Documentation
```

---

## 🚀 How to Run the Demo

### Option 1: Quick Launch (Recommended)

Double-click or run:
```cmd
run_demo.bat
```
*(or run `.\run_demo.ps1` in PowerShell)*

This automatically starts the Python backend service in the background and launches the compiled Windows executable.

---

### Option 2: Running from Source / Development Mode

#### Step 1: Start the Backend Service
In a terminal, start the local Python server:
```powershell
python backend/main.py
```
*(The backend runs on `http://127.0.0.1:18080`)*

To test the backend independently and print the JSON payload:
```powershell
python backend/main.py --test
```

#### Step 2: Run Flutter Desktop Application
In a separate terminal:
```powershell
cd frontend
flutter run -d windows
```

---

### Option 3: Run the Compiled Executable Directly

The release build has been compiled:
```powershell
.\frontend\build\windows\x64\runner\Release\pc_system_inspector.exe
```

---

## 🧪 Testing

To run the automated tests:
```powershell
cd frontend
flutter test
```

---

## 🔒 Scope Restriction (Phase 1)

This project strictly implements **Phase 1** specifications. The following features are excluded from Phase 1 by design:
- Invoice comparison
- Windows / Office activation
- Software installer / USB automation
- Cloud sync / database / user accounts
