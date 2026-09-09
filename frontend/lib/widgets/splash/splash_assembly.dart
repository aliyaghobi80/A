import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'splash_component.dart';

class SplashAssemblyWidget extends StatelessWidget {
  final double progress; // Overall splash progress 0.0 to 1.0 (corresponds to 0s to 4s)
  final Color accentColor;

  const SplashAssemblyWidget({
    super.key,
    required this.progress,
    this.accentColor = const Color(0xFF00E5FF),
  });

  @override
  Widget build(BuildContext context) {
    // Phase 1 (0.0 to 0.20 = 0s to 0.8s): Fade & scale in around center
    // Phase 2 (0.20 to 0.525 = 0.8s to 2.1s): Smooth assembly into motherboard
    // Phase 3 (0.525 to 0.72 = 2.1s to 2.9s): Circuit pulse and dissolve into logo
    // Beyond 0.72: Assembly is fully dissolved

    if (progress >= 0.75) {
      return const SizedBox.shrink();
    }

    // Assembly visibility: fades in 0.0 -> 0.15, stays 1.0, fades out 0.525 -> 0.72
    final double overallOpacity;
    if (progress < 0.15) {
      overallOpacity = (progress / 0.15).clamp(0.0, 1.0);
    } else if (progress > 0.525) {
      overallOpacity = (1.0 - ((progress - 0.525) / 0.20)).clamp(0.0, 1.0);
    } else {
      overallOpacity = 1.0;
    }

    // Assembly progress from 0.0 (initial spread) to 1.0 (fully locked)
    // Runs between 0.20 and 0.50 of total timeline
    final double assemblyProgress = ((progress - 0.20) / 0.30).clamp(0.0, 1.0);
    final double curvedAssembly = Curves.easeInOutCubic.transform(assemblyProgress);

    // Individual component lock triggers
    final bool cpuLocked = assemblyProgress >= 0.55;
    final bool ramLocked = assemblyProgress >= 0.70;
    final bool gpuLocked = assemblyProgress >= 0.85;
    final bool ssdLocked = assemblyProgress >= 0.95;
    final bool allLocked = assemblyProgress >= 0.98;

    // Pulse intensity after assembly completes (0.50 to 0.65)
    final double circuitPulse;
    if (progress >= 0.50 && progress <= 0.65) {
      circuitPulse = math.sin(((progress - 0.50) / 0.15) * math.pi);
    } else {
      circuitPulse = 0.0;
    }

    // Positions (Relative to center (0,0))
    // Motherboard: center base
    final double mbScale = 0.85 + (curvedAssembly * 0.15);

    // CPU: Orbit (-130, -80) -> Target (-18, -18)
    final Offset cpuPos = Offset.lerp(
      const Offset(-130, -85),
      const Offset(-18, -18),
      curvedAssembly,
    )!;
    final double cpuAngle = (1.0 - curvedAssembly) * -0.22;

    // RAM: Orbit (130, -75) -> Target (38, -22)
    final Offset ramPos = Offset.lerp(
      const Offset(135, -75),
      const Offset(38, -22),
      curvedAssembly,
    )!;
    final double ramAngle = (1.0 - curvedAssembly) * 0.28;

    // GPU: Orbit (-125, 95) -> Target (0, 38)
    final Offset gpuPos = Offset.lerp(
      const Offset(-125, 95),
      const Offset(0, 38),
      curvedAssembly,
    )!;
    final double gpuAngle = (1.0 - curvedAssembly) * 0.16;

    // SSD: Orbit (120, 85) -> Target (24, 8)
    final Offset ssdPos = Offset.lerp(
      const Offset(120, 85),
      const Offset(24, 8),
      curvedAssembly,
    )!;
    final double ssdAngle = (1.0 - curvedAssembly) * -0.18;

    return Opacity(
      opacity: overallOpacity,
      child: Center(
        child: SizedBox(
          width: 380,
          height: 340,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // Circuit lines and energy traces painter
              Positioned.fill(
                child: CustomPaint(
                  painter: _CircuitAssemblyPainter(
                    accentColor: accentColor,
                    assemblyProgress: curvedAssembly,
                    allLocked: allLocked,
                    pulseIntensity: circuitPulse,
                  ),
                ),
              ),

              // 1. Motherboard (Foundation base)
              Transform.scale(
                scale: mbScale,
                child: SplashComponentWidget(
                  type: SplashComponentType.motherboard,
                  size: 154,
                  accentColor: accentColor,
                  isLocked: allLocked,
                  glowIntensity: circuitPulse * 0.6,
                ),
              ),

              // 2. CPU (Microprocessor landing on socket)
              Transform.translate(
                offset: cpuPos,
                child: Transform.rotate(
                  angle: cpuAngle,
                  child: SplashComponentWidget(
                    type: SplashComponentType.cpu,
                    size: 58,
                    accentColor: const Color(0xFF38BDF8),
                    isLocked: cpuLocked,
                    glowIntensity: cpuLocked ? 0.4 + (circuitPulse * 0.5) : 0.0,
                  ),
                ),
              ),

              // 3. RAM (Memory module snapping into DIMM slot)
              Transform.translate(
                offset: ramPos,
                child: Transform.rotate(
                  angle: ramAngle,
                  child: SplashComponentWidget(
                    type: SplashComponentType.ram,
                    size: 52,
                    accentColor: const Color(0xFF34D399),
                    isLocked: ramLocked,
                    glowIntensity: ramLocked ? 0.35 + (circuitPulse * 0.5) : 0.0,
                  ),
                ),
              ),

              // 4. GPU (Dedicated graphics card locking into PCIe slot)
              Transform.translate(
                offset: gpuPos,
                child: Transform.rotate(
                  angle: gpuAngle,
                  child: SplashComponentWidget(
                    type: SplashComponentType.gpu,
                    size: 64,
                    accentColor: const Color(0xFFA78BFA),
                    isLocked: gpuLocked,
                    glowIntensity: gpuLocked ? 0.4 + (circuitPulse * 0.5) : 0.0,
                  ),
                ),
              ),

              // 5. SSD M.2 (High speed storage snapping into slot)
              Transform.translate(
                offset: ssdPos,
                child: Transform.rotate(
                  angle: ssdAngle,
                  child: SplashComponentWidget(
                    type: SplashComponentType.ssd,
                    size: 48,
                    accentColor: const Color(0xFFF59E0B),
                    isLocked: ssdLocked,
                    glowIntensity: ssdLocked ? 0.35 + (circuitPulse * 0.5) : 0.0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircuitAssemblyPainter extends CustomPainter {
  final Color accentColor;
  final double assemblyProgress;
  final bool allLocked;
  final double pulseIntensity;

  _CircuitAssemblyPainter({
    required this.accentColor,
    required this.assemblyProgress,
    required this.allLocked,
    required this.pulseIntensity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (assemblyProgress <= 0.05) return;

    final center = Offset(size.width / 2, size.height / 2);
    final tracePaint = Paint()
      ..color = accentColor.withValues(
        alpha: (0.15 + (pulseIntensity * 0.55)).clamp(0.0, 0.8),
      )
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final glowPaint = Paint()
      ..color = accentColor.withValues(
        alpha: (0.05 + (pulseIntensity * 0.35)).clamp(0.0, 0.5),
      )
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke;

    // Draw converging circuit paths
    final path = Path();

    // CPU to Socket trace
    path.moveTo(center.dx - 90, center.dy - 60);
    path.lineTo(center.dx - 35, center.dy - 60);
    path.lineTo(center.dx - 18, center.dy - 18);

    // RAM to DIMM trace
    path.moveTo(center.dx + 90, center.dy - 50);
    path.lineTo(center.dx + 50, center.dy - 50);
    path.lineTo(center.dx + 38, center.dy - 22);

    // GPU to PCIe trace
    path.moveTo(center.dx - 80, center.dy + 70);
    path.lineTo(center.dx - 40, center.dy + 70);
    path.lineTo(center.dx, center.dy + 38);

    // SSD to M.2 trace
    path.moveTo(center.dx + 80, center.dy + 60);
    path.lineTo(center.dx + 40, center.dy + 60);
    path.lineTo(center.dx + 24, center.dy + 8);

    if (allLocked) {
      // Connect all components into a closed circuit loop
      path.moveTo(center.dx - 18, center.dy - 18);
      path.lineTo(center.dx + 38, center.dy - 22);
      path.lineTo(center.dx + 24, center.dy + 8);
      path.lineTo(center.dx, center.dy + 38);
      path.close();
    }

    if (pulseIntensity > 0) {
      canvas.drawPath(path, glowPaint);
    }
    canvas.drawPath(path, tracePaint);

    // Draw small node dots at key trace joints
    final nodePaint = Paint()
      ..color = accentColor.withValues(alpha: 0.6 + (pulseIntensity * 0.4))
      ..style = PaintingStyle.fill;

    final nodes = [
      Offset(center.dx - 35, center.dy - 60),
      Offset(center.dx + 50, center.dy - 50),
      Offset(center.dx - 40, center.dy + 70),
      Offset(center.dx + 40, center.dy + 60),
    ];

    for (final node in nodes) {
      canvas.drawCircle(node, 2.2, nodePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CircuitAssemblyPainter oldDelegate) {
    return oldDelegate.assemblyProgress != assemblyProgress ||
        oldDelegate.pulseIntensity != pulseIntensity ||
        oldDelegate.allLocked != allLocked;
  }
}
