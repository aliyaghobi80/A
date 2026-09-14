# backend/qc/qc_engine.py
"""
Quality Control (QC) & System Readiness Evaluation Engine
Evaluates complete hardware, operating system, device drivers, required/optional software,
and activation licenses (Windows & Office) into standardized QC States:
- PASS
- WARNING
- FAIL
- UNKNOWN
- NOT_PRESENT

Calculates overall system status (READY vs NEEDS_ATTENTION) and generates
actionable, clickable issue records for one-click fix and batch preparation.
"""

import logging
from typing import Dict, Any, List, Optional
from datetime import datetime

logger = logging.getLogger(__name__)

# QC State Constants
STATE_PASS = "PASS"
STATE_WARNING = "WARNING"
STATE_FAIL = "FAIL"
STATE_UNKNOWN = "UNKNOWN"
STATE_NOT_PRESENT = "NOT_PRESENT"

# Overall Status Constants
STATUS_READY = "READY"
STATUS_NEEDS_ATTENTION = "NEEDS_ATTENTION"


def evaluate_system_qc(system_info: Dict[str, Any], packages_data: Optional[Dict[str, Any]] = None, device_settings: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
    """
    Evaluates complete system info dictionary into structured QC results across all 8-9 domains.
    Guarantees a clean, non-crashing structured dictionary.
    """
    if not isinstance(system_info, dict):
        system_info = {}

    categories: List[Dict[str, Any]] = []
    problems: List[Dict[str, Any]] = []

    # Map available discovered package installers by app id / name
    discovered_pkgs = {}
    if packages_data and isinstance(packages_data.get("packages"), list):
        for pkg in packages_data["packages"]:
            p_id = (pkg.get("id") or "").lower()
            p_name = (pkg.get("name") or "").lower()
            p_file = (pkg.get("filename") or "").lower()
            discovered_pkgs[p_id] = pkg
            discovered_pkgs[p_name] = pkg
            discovered_pkgs[p_file] = pkg

    # -------------------------------------------------------------------------
    # 1. HARDWARE CHECK
    # -------------------------------------------------------------------------
    hw_items = []
    cpu = system_info.get("cpu", {})
    cpu_name = cpu.get("model") or cpu.get("name") or "Not detected"
    cpu_pass = cpu_name != "Not detected" and cpu.get("cores", 0) > 0
    hw_items.append({
        "id": "hw_cpu",
        "name": "CPU Processor",
        "detail": f"{cpu_name} ({cpu.get('cores', 0)} Cores / {cpu.get('threads', 0)} Threads)",
        "state": STATE_PASS if cpu_pass else STATE_UNKNOWN,
        "is_required": True,
    })

    ram = system_info.get("ram", {})
    ram_gb = ram.get("total_gb", 0)
    ram_pass = ram_gb >= 4
    hw_items.append({
        "id": "hw_ram",
        "name": "RAM Memory",
        "detail": f"{ram_gb} GB ({len(ram.get('modules', []))} Modules)",
        "state": STATE_PASS if ram_pass else STATE_WARNING if ram_gb > 0 else STATE_FAIL,
        "is_required": True,
    })

    gpu_list = system_info.get("gpu", [])
    if isinstance(gpu_list, list) and gpu_list:
        g = gpu_list[0]
        gpu_name = g.get("name", "Graphics Card")
        vram = g.get("vram_gb", 0)
        hw_items.append({
            "id": "hw_gpu",
            "name": "Graphics Card (GPU)",
            "detail": f"{gpu_name}" + (f" ({vram} GB VRAM)" if vram else ""),
            "state": STATE_PASS,
            "is_required": True,
        })
    else:
        hw_items.append({
            "id": "hw_gpu",
            "name": "Graphics Card (GPU)",
            "detail": "No dedicated/integrated GPU reported",
            "state": STATE_UNKNOWN,
            "is_required": False,
        })

    storage_list = system_info.get("storage", [])
    if isinstance(storage_list, list) and storage_list:
        total_drives = len(storage_list)
        hw_items.append({
            "id": "hw_storage",
            "name": "Storage Disks",
            "detail": f"{total_drives} Drive(s) detected",
            "state": STATE_PASS,
            "is_required": True,
        })
    else:
        hw_items.append({
            "id": "hw_storage",
            "name": "Storage Disks",
            "detail": "No storage disks found",
            "state": STATE_FAIL,
            "is_required": True,
        })

    mb = system_info.get("motherboard", {})
    mb_name = f"{mb.get('manufacturer', '')} {mb.get('product', '')}".strip() or "Motherboard"
    hw_items.append({
        "id": "hw_mb",
        "name": "Motherboard",
        "detail": mb_name,
        "state": STATE_PASS if mb.get("product") else STATE_UNKNOWN,
        "is_required": False,
    })

    bat = system_info.get("battery", {})
    if bat.get("has_battery"):
        hp = bat.get("health_percent", 100.0)
        grade_fa = bat.get("health_grade_fa", "سالم")
        if hp >= 70.0:
            bat_state = STATE_PASS
        elif hp >= 50.0:
            bat_state = STATE_WARNING
            problems.append({
                "id": "qc_prob_battery_warn",
                "title": f"افت ظرفیت باتری لپ‌تاپ ({hp}٪)",
                "category": "hardware",
                "category_name": "سخت‌افزار",
                "name": "باتری لپ‌تاپ",
                "status": STATE_WARNING,
                "severity": "WARNING",
                "description": f"سلامت باتری {hp}٪ است ({grade_fa}). ظرفیت مفید کاهش یافته است.",
                "solution_title": "بررسی و کالیبراسیون باتری",
                "solution_steps": "شارژر لپ‌تاپ را متصل نگه دارید و در صورت استفاده پرتابل، وضعیت باتری را با نرم‌افزار سازنده کالیبره کنید.",
                "action_type": "CHECK_BATTERY",
                "action_label": "بررسی باتری",
                "action_target": "battery",
                "package_filename": None,
                "can_auto_prepare": False,
                "is_required": False,
            })
        else:
            bat_state = STATE_FAIL
            problems.append({
                "id": "qc_prob_battery_fail",
                "title": f"فرسودگی شدید باتری لپ‌تاپ ({hp}٪)",
                "category": "hardware",
                "category_name": "سخت‌افزار",
                "name": "باتری لپ‌تاپ",
                "status": STATE_FAIL,
                "severity": "FAIL",
                "description": f"سلامت باتری {hp}٪ و در وضعیت ضعیف است. باتری کارایی خود را از دست داده است.",
                "solution_title": "تعویض سلول یا باتری لپ‌تاپ",
                "solution_steps": "باتری فرسوده است و نیاز به تعویض فیزیکی دارد. در صورت نیاز به تحویل بدون باتری، به مشتری اطلاع دهید.",
                "action_type": "CHECK_BATTERY",
                "action_label": "بررسی باتری",
                "action_target": "battery",
                "package_filename": None,
                "can_auto_prepare": False,
                "is_required": True,
            })

        hw_items.append({
            "id": "hw_battery",
            "name": "Laptop Battery Health",
            "detail": f"{hp}% ({grade_fa}) - {bat.get('power_source_fa', '')}",
            "state": bat_state,
            "is_required": True,
        })
    else:
        hw_items.append({
            "id": "hw_battery",
            "name": "Power Source",
            "detail": "Desktop AC Power (No Battery)",
            "state": STATE_PASS,
            "is_required": False,
        })

    hw_state = STATE_PASS
    if any(i["state"] == STATE_FAIL for i in hw_items):
        hw_state = STATE_FAIL
    elif any(i["state"] == STATE_WARNING for i in hw_items):
        hw_state = STATE_WARNING
    elif any(i["state"] == STATE_UNKNOWN for i in hw_items):
        hw_state = STATE_PASS

    categories.append({
        "id": "hardware",
        "name": "Hardware",
        "displayName": "سخت‌افزار",
        "state": hw_state,
        "items": hw_items,
        "passed_count": sum(1 for i in hw_items if i["state"] in [STATE_PASS, STATE_NOT_PRESENT]),
        "total_count": len(hw_items),
    })

    # -------------------------------------------------------------------------
    # 2. WINDOWS OS CHECK
    # -------------------------------------------------------------------------
    win = system_info.get("windows", {})
    win_items = []
    edition = win.get("edition") or win.get("caption") or "Windows"
    build = win.get("build") or win.get("version") or "Unknown"
    arch = win.get("architecture") or "64-bit"

    win_items.append({
        "id": "win_edition",
        "name": "Windows Edition",
        "detail": f"{edition} ({arch})",
        "state": STATE_PASS if edition != "Windows" else STATE_UNKNOWN,
        "is_required": True,
    })
    win_items.append({
        "id": "win_build",
        "name": "OS Build & Version",
        "detail": f"Build {build}",
        "state": STATE_PASS if build != "Unknown" else STATE_UNKNOWN,
        "is_required": True,
    })

    proxy = system_info.get("proxy", {})
    if proxy.get("has_manual_proxy"):
        server_str = proxy.get("server", "")
        win_items.append({
            "id": "win_proxy",
            "name": "Manual Proxy Setting",
            "detail": f"پروکسی دستی روشن است ({server_str})",
            "state": STATE_WARNING,
            "is_required": False,
        })
        problems.append({
            "id": "proxy_manual_enabled",
            "category": "windows",
            "category_name": "سیستم‌عامل ویندوز",
            "name": f"پروکسی دستی روشن است ({server_str})",
            "status": STATE_WARNING,
            "severity": STATE_WARNING,
            "description": f"پروکسی دستی روی آدرس {server_str} فعال است. این موضوع باعث قطع اینترنت مشتری می‌شود.",
            "solution_title": "خاموش کردن پروکسی دستی",
            "solution_steps": "با زدن دکمه «خاموش کردن پروکسی» در پایین یا از بخش تنظیمات شبکه ویندوز، پروکسی دستی را غیرفعال کنید.",
            "is_required": False,
            "action_type": "disable_proxy",
            "action_label": "خاموش کردن پروکسی",
            "action_target": "proxy",
            "package_filename": None,
            "can_auto_prepare": True,
        })
    else:
        win_items.append({
            "id": "win_proxy",
            "name": "Manual Proxy Setting",
            "detail": "پروکسی دستی خاموش است (اتصال مستقیم)",
            "state": STATE_PASS,
            "is_required": False,
        })

    categories.append({
        "id": "windows",
        "name": "Windows",
        "displayName": "سیستم‌عامل ویندوز",
        "state": STATE_PASS if all(i["state"] == STATE_PASS for i in win_items) else STATE_UNKNOWN,
        "items": win_items,
        "passed_count": sum(1 for i in win_items if i["state"] == STATE_PASS),
        "total_count": len(win_items),
    })

    # -------------------------------------------------------------------------
    # 3. IMPORTANT DRIVERS CHECK
    # -------------------------------------------------------------------------
    driver_items = []
    drivers = system_info.get("drivers", [])
    for d in drivers:
        d_id = d.get("id", "driver")
        d_name = d.get("name", "Device Driver")
        d_device = d.get("device_name", "")
        d_cat = d.get("category", "Hardware")
        d_cat_fa = d.get("category_fa", "سخت‌افزار")
        is_healthy = d.get("is_healthy", False)
        is_present = d.get("is_present", True)
        prob_code = int(d.get("problem_code", 0) or 0)
        status_desc = d.get("status_description") or "دستگاه به درستی کار می‌کند"

        if not is_present:
            state = STATE_NOT_PRESENT
        elif is_healthy:
            state = STATE_PASS
        else:
            state = STATE_FAIL if (prob_code == 28 or d_cat in ["Display", "Audio", "Ethernet", "Wi-Fi", "Unknown / Missing"]) else STATE_WARNING

        driver_items.append({
            "id": f"driver_{d_id}",
            "name": f"{d_name} ({d_cat_fa})" if d_cat_fa else d_name,
            "detail": f"{d_device} — {status_desc}" if is_present else "سخت‌افزار بر روی این سیستم موجود نیست",
            "state": state,
            "is_required": d_cat in ["Display", "Audio", "Ethernet", "Wi-Fi", "Unknown / Missing"],
            "problem_code": prob_code,
            "category": d_cat,
        })

        if is_present and not is_healthy:
            problems.append({
                "id": f"driver_issue_{d_id}",
                "category": "drivers",
                "category_name": "درایورهای سیستم",
                "name": f"{d_name}",
                "status": state,
                "severity": state,
                "description": f"دستگاه «{d_device}»: {status_desc} (کد خطا: {prob_code})",
                "solution_title": f"نصب درایور {d_name}",
                "solution_steps": "پوشه درایورهای مادربرد/لپ‌تاپ را در تب درایورها انتخاب کنید و دکمه «نصب خودکار از پوشه» را بزنید.",
                "is_required": True,
                "action_type": "install_drivers",
                "action_label": "نصب درایورها",
                "action_target": "drivers",
                "package_filename": None,
                "can_auto_prepare": False,
            })

    drv_state = STATE_PASS
    if any(i["state"] == STATE_FAIL for i in driver_items):
        drv_state = STATE_FAIL
    elif any(i["state"] == STATE_WARNING for i in driver_items):
        drv_state = STATE_WARNING

    categories.append({
        "id": "drivers",
        "name": "Drivers",
        "displayName": "درایورهای سخت‌افزاری",
        "state": drv_state,
        "items": driver_items,
        "passed_count": sum(1 for i in driver_items if i["state"] in [STATE_PASS, STATE_NOT_PRESENT]),
        "total_count": len(driver_items),
    })

    # -------------------------------------------------------------------------
    # 4. REQUIRED & OPTIONAL SOFTWARE CHECK
    # -------------------------------------------------------------------------
    soft_items = []
    software_list = system_info.get("software", [])
    for s in software_list:
        s_id = s.get("id", "app")
        s_name = s.get("displayName") or s.get("name", "Software")
        is_installed = s.get("is_installed", False) or s.get("installed", False) or s.get("status") == "Installed"
        is_req = s.get("required", True)
        ver = s.get("version") or "Not installed"

        if is_installed:
            state = STATE_PASS
        else:
            state = STATE_FAIL if is_req else STATE_WARNING

        # Check if local installer .exe exists in Packages directory
        matched_pkg = (
            discovered_pkgs.get(s_id.lower())
            or discovered_pkgs.get(s_name.lower())
            or discovered_pkgs.get(f"{s_id}.exe")
        )

        item = {
            "id": f"soft_{s_id}",
            "name": s_name,
            "detail": f"نسخه {ver}" if is_installed else ("نصب نشده است (ضروری)" if is_req else "نصب نشده است (اختیاری)"),
            "state": state,
            "is_required": is_req,
            "is_installed": is_installed,
            "package_id": matched_pkg.get("id") if matched_pkg else None,
            "package_filename": matched_pkg.get("filename") if matched_pkg else None,
        }
        soft_items.append(item)

        if not is_installed:
            problems.append({
                "id": f"software_{s_id}",
                "category": "software",
                "category_name": "نرم‌افزارها",
                "name": s_name,
                "status": state,
                "severity": STATE_FAIL if is_req else STATE_WARNING,
                "description": f"نرم‌افزار {s_name} بر روی سیستم نصب نشده است.",
                "solution_title": f"نصب خودکار {s_name}",
                "solution_steps": f"با کلیک روی دکمه «نصب برنامه»، نرم‌افزار {s_name} به صورت خودکار و سایلنت نصب خواهد شد.",
                "is_required": is_req,
                "action_type": "install_software",
                "action_label": "نصب برنامه",
                "action_target": matched_pkg.get("id") if matched_pkg else s_id,
                "package_filename": matched_pkg.get("filename") if matched_pkg else None,
                "can_auto_prepare": matched_pkg is not None,
            })

    soft_state = STATE_PASS
    if any(i["state"] == STATE_FAIL for i in soft_items):
        soft_state = STATE_FAIL
    elif any(i["state"] == STATE_WARNING for i in soft_items):
        soft_state = STATE_WARNING

    categories.append({
        "id": "software",
        "name": "Software",
        "displayName": "نرم‌افزارهای موردنیاز",
        "state": soft_state,
        "items": soft_items,
        "passed_count": sum(1 for i in soft_items if i["state"] == STATE_PASS),
        "total_count": len(soft_items),
    })

    # -------------------------------------------------------------------------
    # 5. WINDOWS ACTIVATION CHECK
    # -------------------------------------------------------------------------
    win_act = system_info.get("windows_activation", {})
    win_is_activated = win_act.get("activated", False)
    win_status_text = win_act.get("status_text", "Not Activated")

    win_act_item = {
        "id": "win_act_status",
        "name": "Windows Activation",
        "detail": win_status_text,
        "state": STATE_PASS if win_is_activated else STATE_FAIL,
        "is_required": True,
    }

    if not win_is_activated:
        problems.append({
            "id": "windows_activation",
            "category": "windows_activation",
            "category_name": "فعالسازی ویندوز",
            "name": "Windows Activation",
            "status": STATE_FAIL,
            "severity": STATE_FAIL,
            "description": f"ویندوز فعال (Activate) نشده است. وضعیت فعلی: {win_status_text}",
            "solution_title": "فعال‌سازی خودکار و قانونی ویندوز",
            "solution_steps": "با کلیک روی دکمه «فعالسازی ویندوز»، ابزار خودکار فعال‌سازی دیجیتال اجرا شده و ویندوز فعال می‌شود.",
            "is_required": True,
            "action_type": "activate_windows",
            "action_label": "فعالسازی ویندوز",
            "action_target": "windows",
            "package_filename": None,
            "can_auto_prepare": True,
        })

    categories.append({
        "id": "windows_activation",
        "name": "Windows Activation",
        "displayName": "فعالسازی ویندوز",
        "state": STATE_PASS if win_is_activated else STATE_FAIL,
        "items": [win_act_item],
        "passed_count": 1 if win_is_activated else 0,
        "total_count": 1,
    })

    # -------------------------------------------------------------------------
    # 6. OFFICE INSTALLATION & ACTIVATION CHECK
    # -------------------------------------------------------------------------
    off_act = system_info.get("office_activation", {})
    off_installed = off_act.get("installed", False)
    off_activated = off_act.get("activated", False)
    off_product = off_act.get("product", "Microsoft Office")
    off_status_text = off_act.get("status_text", "Not Installed")

    off_items = []
    off_items.append({
        "id": "off_install_status",
        "name": "Office Installation",
        "detail": off_product if off_installed else "نرم‌افزار آفیس نصب نیست",
        "state": STATE_PASS if off_installed else STATE_FAIL,
        "is_required": True,
    })

    if off_installed:
        off_items.append({
            "id": "off_act_status",
            "name": "Office Activation",
            "detail": off_status_text,
            "state": STATE_PASS if off_activated else STATE_FAIL,
            "is_required": True,
        })
        if not off_activated:
            problems.append({
                "id": "office_activation",
                "category": "office_activation",
                "category_name": "فعالسازی آفیس",
                "name": "Office Activation",
                "status": STATE_FAIL,
                "severity": STATE_FAIL,
                "description": f"مجموعه مایکروسافت آفیس فعال نشده است. وضعیت: {off_status_text}",
                "solution_title": "فعال‌سازی بسته مایکروسافت آفیس",
                "solution_steps": "با کلیک روی دکمه «فعالسازی آفیس»، ابزار فعال‌سازی اجرا شده و لایسنس آفیس اعمال می‌شود.",
                "is_required": True,
                "action_type": "activate_office",
                "action_label": "فعالسازی آفیس",
                "action_target": "office",
                "package_filename": None,
                "can_auto_prepare": True,
            })
    else:
        # If Office is completely missing
        problems.append({
            "id": "office_installation",
            "category": "office",
            "category_name": "مایکروسافت آفیس",
            "name": "Microsoft Office",
            "status": STATE_FAIL,
            "severity": STATE_FAIL,
            "description": "بسته مایکروسافت آفیس بر روی سیستم نصب نشده است.",
            "solution_title": "نصب بسته مایکروسافت آفیس",
            "solution_steps": "بسته نصبی آفیس را از پوشه Packages یا نصاب مربوطه نصب کنید.",
            "is_required": True,
            "action_type": "install_software",
            "action_label": "نصب آفیس",
            "action_target": "office",
            "package_filename": None,
            "can_auto_prepare": False,
        })

    off_state = STATE_PASS if (off_installed and off_activated) else STATE_FAIL

    categories.append({
        "id": "office",
        "name": "Office",
        "displayName": "مایکروسافت آفیس",
        "state": off_state,
        "items": off_items,
        "passed_count": sum(1 for i in off_items if i["state"] == STATE_PASS),
        "total_count": len(off_items),
    })

    # -------------------------------------------------------------------------
    # Device preparation uses a fresh verified snapshot supplied by the API.
    if device_settings is not None:
        checks = [
            ('timeouts', 'Screen / Sleep / Hibernate', device_settings.get('timeouts', {}).get('all_never'),
             'یادتان نرفته Screen، Sleep و Hibernate را برای برق و باتری روی Never قرار دهید؟'),
            ('startup', 'Startup Apps', device_settings.get('startup', {}).get('all_disabled'),
             'برنامه‌های Startup هنوز خاموش نشده‌اند یا وضعیت آن‌ها قابل تأیید نیست.'),
        ]
        if device_settings.get('background_apps_supported'):
            checks.append(('background', 'Background Apps', device_settings.get('background_apps', {}).get('all_disabled'),
                           'Background Apps ویندوز ۱۰ را بررسی و خاموش کنید.'))
        if device_settings.get('has_battery'):
            checks.append(('power_modes', 'Laptop Power Mode', device_settings.get('power_modes', {}).get('configured'),
                           'Power mode لپ‌تاپ را بررسی کنید: برق Best performance و باتری Balanced.'))
        items = []
        for key, name, ready, message in checks:
            state = STATE_PASS if ready is True else STATE_WARNING if ready is False else STATE_UNKNOWN
            items.append({'id': key, 'name': name, 'detail': 'تأیید شد' if ready is True else message,
                          'state': state, 'is_required': True})
            if ready is not True:
                problems.append({'id': 'preparation_' + key, 'category': 'device_settings',
                                 'category_name': 'تنظیمات مهم دستگاه', 'name': name,
                                 'status': state, 'severity': STATE_WARNING, 'description': message,
                                 'solution_title': 'بررسی تنظیمات مهم دستگاه',
                                 'solution_steps': 'بخش تنظیمات مهم دستگاه را باز کنید؛ وضعیت باید پس از بررسی سبز شود.',
                                 'action_type': '', 'action_label': '', 'action_target': '',
                                 'can_auto_prepare': False, 'is_required': True})
        passed = sum(item['state'] == STATE_PASS for item in items)
        categories.append({'id': 'device_settings', 'name': 'Device preparation', 'displayName': 'تنظیمات مهم دستگاه',
                           'state': STATE_PASS if passed == len(items) else STATE_WARNING,
                           'items': items, 'passed_count': passed, 'total_count': len(items)})

    # 7. OVERALL SYSTEM EVALUATION (READY vs NEEDS_ATTENTION)
    # -------------------------------------------------------------------------
    # System is READY ONLY IF all required checks are satisfied (PASS or NOT_PRESENT).
    # Any required FAIL causes NEEDS_ATTENTION.
    has_required_fail = any(p.get("is_required", True) and p.get("severity") in (STATE_FAIL, STATE_WARNING) for p in problems)
    overall_status = STATUS_NEEDS_ATTENTION if has_required_fail else STATUS_READY

    passed_categories = sum(1 for c in categories if c["state"] in [STATE_PASS, STATE_NOT_PRESENT])
    total_categories = len(categories)

    return {
        "timestamp": datetime.now().isoformat(),
        "overall_status": overall_status,
        "is_ready": overall_status == STATUS_READY,
        "has_problems": len(problems) > 0,
        "problems_count": len(problems),
        "required_problems_count": sum(1 for p in problems if p.get("is_required", True)),
        "categories": categories,
        "passed_categories_count": passed_categories,
        "total_categories_count": total_categories,
        "problems": problems,
    }
