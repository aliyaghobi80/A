# Markazi System Checker — Activation Tools Directory

This directory contains corporate activation tools and scripts configured for Markazi System Checker.

## Directory Structure
```
Tools/
├── WindowsActivation/
│   └── activate.cmd       # Windows activation launcher/script
└── OfficeActivation/
    └── activate.cmd       # Microsoft Office activation launcher/script
```

## Security & Usage Rules
1. **Approved Location Only**: Markazi System Checker strictly enforces execution only from within the `Tools/` directory.
2. **Configuration**: Tool paths are configured via `config/activation.json`.
3. **No Automatic Execution**: Activation scripts are **never** run automatically during system scanning or refreshing. They are only invoked when an employee/technician explicitly clicks the activation button and confirms the prompt.
4. **Legitimate Licensing**: Place your organization's legitimate licensing scripts (e.g., KMS activation, Volume License activation commands) in the respective subdirectories.
