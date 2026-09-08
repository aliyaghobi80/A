import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Premium vector illustrations for hardware components.
/// Renders 100% offline, crystal clear at any DPI on Windows desktop.

class HardwareIllustrationBadge extends StatelessWidget {
  final Widget illustration;
  final Color accentColor;
  final double size;

  const HardwareIllustrationBadge({
    super.key,
    required this.illustration,
    required this.accentColor,
    this.size = 72,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: isDark ? 0.12 : 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: accentColor.withValues(alpha: isDark ? 0.35 : 0.2),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: isDark ? 0.15 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(8),
      child: Center(
        child: SizedBox(
          width: size - 16,
          height: size - 16,
          child: illustration,
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// 1. CPU Illustration (Microprocessor Die + Heatspreader + Pins)
// -------------------------------------------------------------
class CpuIllustration extends StatelessWidget {
  final Color color;
  final bool useAssetImage;
  const CpuIllustration({
    super.key,
    this.color = const Color(0xFF3B82F6),
    this.useAssetImage = true,
  });

  @override
  Widget build(BuildContext context) {
    if (useAssetImage) {
      return Image.asset(
        'assets/Parts/cpu.png',
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        errorBuilder: (context, error, stackTrace) => CustomPaint(
          painter: _CpuPainter(color: color),
          child: const SizedBox.expand(),
        ),
      );
    }
    return CustomPaint(
      painter: _CpuPainter(color: color),
      child: const SizedBox.expand(),
    );
  }
}

class _CpuPainter extends CustomPainter {
  final Color color;
  _CpuPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // PCB substrate (Greenish/Dark Blueish square)
    final pcbPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [color.withValues(alpha: 0.3), color.withValues(alpha: 0.15)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    final pcbBorder = Paint()
      ..color = color.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final pcbRRect = RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.1, h * 0.1, w * 0.8, h * 0.8), const Radius.circular(6));
    canvas.drawRRect(pcbRRect, pcbPaint);
    canvas.drawRRect(pcbRRect, pcbBorder);

    // Gold Pins / Contact notches along perimeter
    final pinPaint = Paint()
      ..color = const Color(0xFFF59E0B).withValues(alpha: 0.8)
      ..strokeWidth = 1.5;
    for (int i = 1; i <= 5; i++) {
      final frac = 0.1 + (i * 0.13);
      // Top & Bottom pins
      canvas.drawLine(Offset(w * frac, 0), Offset(w * frac, h * 0.08), pinPaint);
      canvas.drawLine(Offset(w * frac, h * 0.92), Offset(w * frac, h), pinPaint);
      // Left & Right pins
      canvas.drawLine(Offset(0, h * frac), Offset(w * 0.08, h * frac), pinPaint);
      canvas.drawLine(Offset(w * 0.92, h * frac), Offset(w, h * frac), pinPaint);
    }

    // Heatspreader (IHS) Metallic Center
    final ihsRect = Rect.fromLTWH(w * 0.22, h * 0.22, w * 0.56, h * 0.56);
    final ihsPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Colors.white.withValues(alpha: 0.4), color.withValues(alpha: 0.4), color.withValues(alpha: 0.7)],
      ).createShader(ihsRect);
    canvas.drawRRect(RRect.fromRectAndRadius(ihsRect, const Radius.circular(4)), ihsPaint);

    final ihsBorder = Paint()
      ..color = Colors.white.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawRRect(RRect.fromRectAndRadius(ihsRect, const Radius.circular(4)), ihsBorder);

    // Inner Silicon Die / Core with glowing grid
    final coreRect = Rect.fromLTWH(w * 0.35, h * 0.35, w * 0.3, h * 0.3);
    final corePaint = Paint()..color = color;
    canvas.drawRRect(RRect.fromRectAndRadius(coreRect, const Radius.circular(2)), corePaint);

    // Golden Pin 1 triangle indicator on top-left corner
    final trianglePath = Path()
      ..moveTo(w * 0.13, h * 0.13)
      ..lineTo(w * 0.22, h * 0.13)
      ..lineTo(w * 0.13, h * 0.22)
      ..close();
    canvas.drawPath(trianglePath, Paint()..color = const Color(0xFFF59E0B));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// -------------------------------------------------------------
// 2. RAM Illustration (DDR Memory Module Stick + IC Chips + Pins)
// -------------------------------------------------------------
class RamIllustration extends StatelessWidget {
  final Color color;
  final bool useAssetImage;
  const RamIllustration({
    super.key,
    this.color = const Color(0xFFF59E0B),
    this.useAssetImage = true,
  });

  @override
  Widget build(BuildContext context) {
    if (useAssetImage) {
      return Image.asset(
        'assets/Parts/ram.png',
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        errorBuilder: (context, error, stackTrace) => CustomPaint(
          painter: _RamPainter(color: color),
          child: const SizedBox.expand(),
        ),
      );
    }
    return CustomPaint(
      painter: _RamPainter(color: color),
      child: const SizedBox.expand(),
    );
  }
}

class _RamPainter extends CustomPainter {
  final Color color;
  _RamPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // PCB Module Stick (Horizontal PCB bar)
    final pcbRect = Rect.fromLTWH(w * 0.04, h * 0.22, w * 0.92, h * 0.56);
    final pcbPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.35), color.withValues(alpha: 0.15)],
      ).createShader(pcbRect);
    canvas.drawRRect(RRect.fromRectAndRadius(pcbRect, const Radius.circular(4)), pcbPaint);

    final pcbBorder = Paint()
      ..color = color.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;
    canvas.drawRRect(RRect.fromRectAndRadius(pcbRect, const Radius.circular(4)), pcbBorder);

    // 4 Memory IC Chips
    final chipPaint = Paint()..color = const Color(0xFF1E293B);
    final chipBorder = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    final chipWidth = w * 0.16;
    final chipHeight = h * 0.3;
    for (int i = 0; i < 4; i++) {
      final chipLeft = w * (0.1 + i * 0.2);
      final chipTop = h * 0.32;
      final cRect = Rect.fromLTWH(chipLeft, chipTop, chipWidth, chipHeight);
      canvas.drawRRect(RRect.fromRectAndRadius(cRect, const Radius.circular(2)), chipPaint);
      canvas.drawRRect(RRect.fromRectAndRadius(cRect, const Radius.circular(2)), chipBorder);
    }

    // Gold Contact Edge Pins (Bottom with Center Key Notch)
    final goldPinPaint = Paint()
      ..color = const Color(0xFFF59E0B)
      ..strokeWidth = 1.2;

    for (int i = 0; i < 18; i++) {
      // Leave center notch space
      if (i == 8 || i == 9) continue;
      final x = w * (0.08 + i * 0.046);
      canvas.drawLine(Offset(x, h * 0.78), Offset(x, h * 0.88), goldPinPaint);
    }

    // Notch cut
    final notchPaint = Paint()..color = Colors.black.withValues(alpha: 0.5);
    canvas.drawRect(Rect.fromLTWH(w * 0.46, h * 0.78, w * 0.08, h * 0.1), notchPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// -------------------------------------------------------------
// 3. GPU Illustration (Graphics Card + Dual Cooling Fans + PCIe)
// -------------------------------------------------------------
class GpuIllustration extends StatelessWidget {
  final Color color;
  final bool useAssetImage;
  const GpuIllustration({
    super.key,
    this.color = const Color(0xFF8B5CF6),
    this.useAssetImage = true,
  });

  @override
  Widget build(BuildContext context) {
    if (useAssetImage) {
      return Image.asset(
        'assets/Parts/graphic.png',
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        errorBuilder: (context, error, stackTrace) => CustomPaint(
          painter: _GpuPainter(color: color),
          child: const SizedBox.expand(),
        ),
      );
    }
    return CustomPaint(
      painter: _GpuPainter(color: color),
      child: const SizedBox.expand(),
    );
  }
}

class _GpuPainter extends CustomPainter {
  final Color color;
  _GpuPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Metal IO Bracket on Left
    final bracketRect = Rect.fromLTWH(w * 0.04, h * 0.15, w * 0.08, h * 0.7);
    final bracketPaint = Paint()..color = const Color(0xFF94A3B8);
    canvas.drawRRect(RRect.fromRectAndRadius(bracketRect, const Radius.circular(2)), bracketPaint);

    // GPU Main Shroud Body
    final shroudRect = Rect.fromLTWH(w * 0.14, h * 0.2, w * 0.82, h * 0.58);
    final shroudPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [color.withValues(alpha: 0.4), const Color(0xFF0F172A)],
      ).createShader(shroudRect);
    canvas.drawRRect(RRect.fromRectAndRadius(shroudRect, const Radius.circular(5)), shroudPaint);

    final shroudBorder = Paint()
      ..color = color.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;
    canvas.drawRRect(RRect.fromRectAndRadius(shroudRect, const Radius.circular(5)), shroudBorder);

    // Dual Axial Fans (Left Fan & Right Fan)
    final fanRadius = w * 0.16;
    final fanCenters = [
      Offset(w * 0.36, h * 0.49),
      Offset(w * 0.74, h * 0.49),
    ];

    for (final center in fanCenters) {
      // Fan circle ring
      final ringPaint = Paint()
        ..color = color.withValues(alpha: 0.3)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, fanRadius, ringPaint);

      final ringBorder = Paint()
        ..color = Colors.white.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawCircle(center, fanRadius, ringBorder);

      // Fan blades
      final bladePaint = Paint()
        ..color = color.withValues(alpha: 0.8)
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round;

      for (int b = 0; b < 6; b++) {
        final angle = (b * math.pi / 3);
        final dx = math.cos(angle) * (fanRadius * 0.75);
        final dy = math.sin(angle) * (fanRadius * 0.75);
        canvas.drawLine(center, Offset(center.dx + dx, center.dy + dy), bladePaint);
      }

      // Fan hub center
      canvas.drawCircle(center, fanRadius * 0.28, Paint()..color = const Color(0xFF0F172A));
      canvas.drawCircle(center, fanRadius * 0.28, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.0);
    }

    // Bottom PCIe Connector Finger
    final pciePaint = Paint()
      ..color = const Color(0xFFF59E0B)
      ..strokeWidth = 1.2;
    for (int i = 0; i < 10; i++) {
      final x = w * (0.24 + i * 0.04);
      canvas.drawLine(Offset(x, h * 0.78), Offset(x, h * 0.86), pciePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// -------------------------------------------------------------
// 4. Motherboard Illustration (Mainboard ATX PCB + Socket + Slots)
// -------------------------------------------------------------
class MotherboardIllustration extends StatelessWidget {
  final Color color;
  final bool useAssetImage;
  const MotherboardIllustration({
    super.key,
    this.color = const Color(0xFF10B981),
    this.useAssetImage = true,
  });

  @override
  Widget build(BuildContext context) {
    if (useAssetImage) {
      return Image.asset(
        'assets/Parts/motherboard.png',
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        errorBuilder: (context, error, stackTrace) => CustomPaint(
          painter: _MotherboardPainter(color: color),
          child: const SizedBox.expand(),
        ),
      );
    }
    return CustomPaint(
      painter: _MotherboardPainter(color: color),
      child: const SizedBox.expand(),
    );
  }
}

class _MotherboardPainter extends CustomPainter {
  final Color color;
  _MotherboardPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // ATX Mainboard PCB
    final pcbRect = Rect.fromLTWH(w * 0.06, h * 0.06, w * 0.88, h * 0.88);
    final pcbPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [color.withValues(alpha: 0.3), const Color(0xFF064E3B).withValues(alpha: 0.6)],
      ).createShader(pcbRect);
    canvas.drawRRect(RRect.fromRectAndRadius(pcbRect, const Radius.circular(6)), pcbPaint);

    final pcbBorder = Paint()
      ..color = color.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawRRect(RRect.fromRectAndRadius(pcbRect, const Radius.circular(6)), pcbBorder);

    // CPU Socket Area (Top Left quadrant)
    final socketRect = Rect.fromLTWH(w * 0.16, h * 0.16, w * 0.36, h * 0.36);
    canvas.drawRRect(RRect.fromRectAndRadius(socketRect, const Radius.circular(3)), Paint()..color = const Color(0xFF1E293B));
    canvas.drawRRect(RRect.fromRectAndRadius(socketRect, const Radius.circular(3)), Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.0);
    // Socket Core Center
    canvas.drawRect(Rect.fromLTWH(w * 0.24, h * 0.24, w * 0.2, h * 0.2), Paint()..color = color.withValues(alpha: 0.4));

    // RAM Slots (Top Right quadrant: 2 Vertical Slots)
    final ramSlotPaint = Paint()..color = const Color(0xFF0F172A);
    final ramSlotBorder = Paint()..color = const Color(0xFFF59E0B)..style = PaintingStyle.stroke..strokeWidth = 0.9;

    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.62, h * 0.14, w * 0.09, h * 0.42), const Radius.circular(1.5)), ramSlotPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.62, h * 0.14, w * 0.09, h * 0.42), const Radius.circular(1.5)), ramSlotBorder);

    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.77, h * 0.14, w * 0.09, h * 0.42), const Radius.circular(1.5)), ramSlotPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.77, h * 0.14, w * 0.09, h * 0.42), const Radius.circular(1.5)), ramSlotBorder);

    // PCIe x16 Slot (Bottom Horizontal Slot)
    final pcieRect = Rect.fromLTWH(w * 0.16, h * 0.66, w * 0.68, h * 0.1);
    canvas.drawRRect(RRect.fromRectAndRadius(pcieRect, const Radius.circular(2)), Paint()..color = const Color(0xFF1E293B));
    canvas.drawRRect(RRect.fromRectAndRadius(pcieRect, const Radius.circular(2)), Paint()..color = const Color(0xFF8B5CF6)..style = PaintingStyle.stroke..strokeWidth = 1.0);

    // Chipset Heatsink (Bottom Right)
    final chipHeatsink = Rect.fromLTWH(w * 0.62, h * 0.78, w * 0.22, h * 0.12);
    canvas.drawRRect(RRect.fromRectAndRadius(chipHeatsink, const Radius.circular(2)), Paint()..color = color.withValues(alpha: 0.6));

    // Circuit Traces Lines
    final tracePaint = Paint()
      ..color = color.withValues(alpha: 0.4)
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(w * 0.34, h * 0.52), Offset(w * 0.34, h * 0.66), tracePaint);
    canvas.drawLine(Offset(w * 0.52, h * 0.34), Offset(w * 0.62, h * 0.34), tracePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// -------------------------------------------------------------
// 5. Storage Illustration (NVMe M.2 SSD / SATA SSD / HDD)
// -------------------------------------------------------------
class StorageIllustration extends StatelessWidget {
  final Color color;
  final String? storageType;
  final String? busType;
  final String? model;
  final String? typeDescription;
  final bool? isM2;
  final bool? isSata;
  final bool? isHdd;
  final bool useAssetImage;

  const StorageIllustration({
    super.key,
    this.color = const Color(0xFF06B6D4),
    this.storageType,
    this.busType,
    this.model,
    this.typeDescription,
    this.isM2,
    this.isSata,
    this.isHdd,
    this.useAssetImage = true,
  });

  String get assetPath {
    if (isM2 == true) return 'assets/Parts/ssd_m2.png';
    if (isHdd == true) return 'assets/Parts/hdd.png';
    if (isSata == true) return 'assets/Parts/ssd_sata.png';

    final td = (typeDescription ?? '').toLowerCase();
    final st = (storageType ?? '').toLowerCase();
    final bt = (busType ?? '').toLowerCase();
    final md = (model ?? '').toLowerCase();

    // 0. Check typeDescription first — most reliable (set by backend normalizer)
    if (td.contains('usb') || td.contains('removable')) {
      return 'assets/Parts/usb_flash.png';
    }
    if (td.contains('nvme') || td.contains('m.2') || td.contains('pcie')) {
      return 'assets/Parts/ssd_m2.png';
    }
    if (td.contains('hdd') || td.contains('hard disk')) {
      return 'assets/Parts/hdd.png';
    }
    if (td.contains('ssd') || td.contains('sata')) {
      return 'assets/Parts/ssd_sata.png';
    }

    // 1. Fallback: raw storageType / busType / model string checks
    if (st.contains('usb') || bt.contains('usb') || md.contains('usb') ||
        st.contains('removable') || md.contains('sandisk') ||
        md.contains('cruzer') || md.contains('flash')) {
      return 'assets/Parts/usb_flash.png';
    }
    if (st.contains('nvme') || bt.contains('nvme') || md.contains('nvme') ||
        md.contains('m.2') || md.contains('m2') || md.contains('pcie')) {
      return 'assets/Parts/ssd_m2.png';
    }
    if (st.contains('hdd') || st.contains('hard') || md.contains('wd') ||
        md.contains('seagate') || md.contains('toshiba') ||
        md.contains('barracuda') || md.contains('caviar')) {
      if (!md.contains('ssd') && !st.contains('ssd')) {
        return 'assets/Parts/hdd.png';
      }
    }
    if (st.contains('ssd') || md.contains('ssd') || md.contains('sata') ||
        md.contains('evo') || md.contains('crucial')) {
      return 'assets/Parts/ssd_sata.png';
    }

    if (st == 'hdd') return 'assets/Parts/hdd.png';
    return 'assets/Parts/ssd_sata.png';
  }

  @override
  Widget build(BuildContext context) {
    if (useAssetImage) {
      return Image.asset(
        assetPath,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        errorBuilder: (context, error, stackTrace) => CustomPaint(
          painter: _StoragePainter(color: color),
          child: const SizedBox.expand(),
        ),
      );
    }
    return CustomPaint(
      painter: _StoragePainter(color: color),
      child: const SizedBox.expand(),
    );
  }
}

class SsdM2Illustration extends StatelessWidget {
  final Color color;
  const SsdM2Illustration({super.key, this.color = const Color(0xFF06B6D4)});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/Parts/ssd_m2.png',
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      errorBuilder: (context, error, stackTrace) => CustomPaint(
        painter: _StoragePainter(color: color),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class SsdSataIllustration extends StatelessWidget {
  final Color color;
  const SsdSataIllustration({super.key, this.color = const Color(0xFF06B6D4)});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/Parts/ssd_sata.png',
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      errorBuilder: (context, error, stackTrace) => CustomPaint(
        painter: _StoragePainter(color: color),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class HddIllustration extends StatelessWidget {
  final Color color;
  const HddIllustration({super.key, this.color = const Color(0xFF06B6D4)});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/Parts/hdd.png',
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      errorBuilder: (context, error, stackTrace) => CustomPaint(
        painter: _StoragePainter(color: color),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _StoragePainter extends CustomPainter {
  final Color color;
  _StoragePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // M.2 NVMe SSD PCB Stick (Diagonal or Horizontal)
    final pcbRect = Rect.fromLTWH(w * 0.08, h * 0.25, w * 0.84, h * 0.5);
    final pcbPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [color.withValues(alpha: 0.35), const Color(0xFF0F172A)],
      ).createShader(pcbRect);
    canvas.drawRRect(RRect.fromRectAndRadius(pcbRect, const Radius.circular(4)), pcbPaint);

    final pcbBorder = Paint()
      ..color = color.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;
    canvas.drawRRect(RRect.fromRectAndRadius(pcbRect, const Radius.circular(4)), pcbBorder);

    // M.2 Screw Notch on Left Edge
    final notchPaint = Paint()..color = Colors.black.withValues(alpha: 0.7);
    canvas.drawCircle(Offset(w * 0.08, h * 0.5), w * 0.04, notchPaint);

    // Controller Chip (Metallic Square)
    final ctrlRect = Rect.fromLTWH(w * 0.22, h * 0.35, w * 0.2, h * 0.3);
    canvas.drawRRect(RRect.fromRectAndRadius(ctrlRect, const Radius.circular(2)), Paint()..color = const Color(0xFF334155));
    canvas.drawRRect(RRect.fromRectAndRadius(ctrlRect, const Radius.circular(2)), Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 0.8);

    // 2 NAND Flash Memory IC Blocks
    for (int i = 0; i < 2; i++) {
      final nandRect = Rect.fromLTWH(w * (0.48 + i * 0.2), h * 0.33, w * 0.17, h * 0.34);
      canvas.drawRRect(RRect.fromRectAndRadius(nandRect, const Radius.circular(2)), Paint()..color = const Color(0xFF1E293B));
      canvas.drawRRect(RRect.fromRectAndRadius(nandRect, const Radius.circular(2)), Paint()..color = color.withValues(alpha: 0.6)..style = PaintingStyle.stroke..strokeWidth = 0.8);
    }

    // Gold M.2 Pins on Right Edge
    final goldPinPaint = Paint()..color = const Color(0xFFF59E0B)..strokeWidth = 1.2;
    for (int i = 0; i < 7; i++) {
      final y = h * (0.32 + i * 0.056);
      canvas.drawLine(Offset(w * 0.88, y), Offset(w * 0.94, y), goldPinPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// -------------------------------------------------------------
// 6. Windows Illustration (Fluent 4-Tile Modern OS Logo)
// -------------------------------------------------------------
class WindowsIllustration extends StatelessWidget {
  final Color color;
  const WindowsIllustration({super.key, this.color = const Color(0xFF0284C7)});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _WindowsPainter(color: color),
      child: const SizedBox.expand(),
    );
  }
}

class _WindowsPainter extends CustomPainter {
  final Color color;
  _WindowsPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final gap = w * 0.08;
    final tileW = (w * 0.8 - gap) / 2;
    final tileH = (h * 0.8 - gap) / 2;

    final tiles = [
      Rect.fromLTWH(w * 0.1, h * 0.1, tileW, tileH), // Top-Left
      Rect.fromLTWH(w * 0.1 + tileW + gap, h * 0.1, tileW, tileH), // Top-Right
      Rect.fromLTWH(w * 0.1, h * 0.1 + tileH + gap, tileW, tileH), // Bottom-Left
      Rect.fromLTWH(w * 0.1 + tileW + gap, h * 0.1 + tileH + gap, tileW, tileH), // Bottom-Right
    ];

    for (final rect in tiles) {
      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF38BDF8),
            color,
          ],
        ).createShader(rect);

      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(3)), paint);

      final border = Paint()
        ..color = Colors.white.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(3)), border);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// -------------------------------------------------------------
// 7. Office Illustration (Modern Fluent 3D Microsoft Office Tile)
// -------------------------------------------------------------
class OfficeIllustration extends StatelessWidget {
  final Color color;
  const OfficeIllustration({super.key, this.color = const Color(0xFFD97706)});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _OfficePainter(color: color),
      child: const SizedBox.expand(),
    );
  }
}

class _OfficePainter extends CustomPainter {
  final Color color;
  _OfficePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Back Hexagonal / Square Tile
    final backRect = Rect.fromLTWH(w * 0.14, h * 0.14, w * 0.72, h * 0.72);
    final backPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [const Color(0xFFFB923C), color, const Color(0xFFEA580C)],
      ).createShader(backRect);
    canvas.drawRRect(RRect.fromRectAndRadius(backRect, const Radius.circular(8)), backPaint);

    final backBorder = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawRRect(RRect.fromRectAndRadius(backRect, const Radius.circular(8)), backBorder);

    // Front Overlapping Fold Badge
    final frontRect = Rect.fromLTWH(w * 0.28, h * 0.28, w * 0.44, h * 0.44);
    final frontPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Colors.white, Color(0xFFFED7AA)],
      ).createShader(frontRect);
    canvas.drawRRect(RRect.fromRectAndRadius(frontRect, const Radius.circular(5)), frontPaint);

    // Office 'O' Emblem in Center
    final oPaint = Paint()
      ..color = const Color(0xFFEA580C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;
    canvas.drawCircle(Offset(w * 0.5, h * 0.5), w * 0.12, oPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// -------------------------------------------------------------
// 8. Battery Illustration (Smart Battery + Health Gauge + Charging Bolt)
// -------------------------------------------------------------
class BatteryIllustration extends StatelessWidget {
  final Color color;
  final double? healthPercent;
  final bool isCharging;

  const BatteryIllustration({
    super.key,
    this.color = const Color(0xFF10B981),
    this.healthPercent,
    this.isCharging = false,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BatteryPainter(
        color: color,
        healthPercent: healthPercent ?? 100.0,
        isCharging: isCharging,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _BatteryPainter extends CustomPainter {
  final Color color;
  final double healthPercent;
  final bool isCharging;

  _BatteryPainter({
    required this.color,
    required this.healthPercent,
    required this.isCharging,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Battery Main Casing
    final bodyRect = Rect.fromLTWH(w * 0.15, h * 0.18, w * 0.7, h * 0.64);
    final bodyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.25), const Color(0xFF0F172A)],
      ).createShader(bodyRect);
    canvas.drawRRect(RRect.fromRectAndRadius(bodyRect, const Radius.circular(6)), bodyPaint);

    final bodyBorder = Paint()
      ..color = color.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawRRect(RRect.fromRectAndRadius(bodyRect, const Radius.circular(6)), bodyBorder);

    // Battery Positive Terminal Cap (Top)
    final capRect = Rect.fromLTWH(w * 0.38, h * 0.1, w * 0.24, h * 0.08);
    canvas.drawRRect(RRect.fromRectAndRadius(capRect, const Radius.circular(2)), Paint()..color = color.withValues(alpha: 0.9));

    // Health Level Bar Fill inside battery
    final fillFrac = (healthPercent.clamp(0.0, 100.0) / 100.0);
    final fillHeight = (h * 0.56) * fillFrac;
    final fillTop = (h * 0.78) - fillHeight;
    final fillRect = Rect.fromLTWH(w * 0.21, fillTop, w * 0.58, fillHeight);

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color, color.withValues(alpha: 0.6)],
      ).createShader(fillRect);
    canvas.drawRRect(RRect.fromRectAndRadius(fillRect, const Radius.circular(3)), fillPaint);

    // Lightning bolt in center if charging or healthy
    final boltPaint = Paint()..color = Colors.white;
    final boltPath = Path()
      ..moveTo(w * 0.54, h * 0.32)
      ..lineTo(w * 0.42, h * 0.5)
      ..lineTo(w * 0.5, h * 0.5)
      ..lineTo(w * 0.46, h * 0.68)
      ..lineTo(w * 0.60, h * 0.46)
      ..lineTo(w * 0.52, h * 0.46)
      ..close();
    canvas.drawPath(boltPath, boltPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// -------------------------------------------------------------
// 8. USB Flash Drive Illustration (SanDisk / Removable USB)
// -------------------------------------------------------------
class UsbFlashIllustration extends StatelessWidget {
  final double? width;
  final double? height;
  final BoxFit fit;

  const UsbFlashIllustration({
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/Parts/usb_flash.png',
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) => const Icon(
        Icons.usb_rounded,
        size: 40,
        color: Color(0xFFEF4444),
      ),
    );
  }
}

