import 'package:flutter/material.dart';
import '../common/hardware_illustrations.dart';

enum SplashComponentType {
  motherboard,
  cpu,
  ram,
  gpu,
  ssd,
}

class SplashComponentWidget extends StatelessWidget {
  final SplashComponentType type;
  final double size;
  final Color accentColor;
  final bool isLocked;
  final double glowIntensity;

  const SplashComponentWidget({
    super.key,
    required this.type,
    this.size = 56,
    this.accentColor = const Color(0xFF00E5FF),
    this.isLocked = false,
    this.glowIntensity = 0.0,
  });

  String get _assetPath {
    switch (type) {
      case SplashComponentType.motherboard:
        return 'assets/Parts/motherboard.png';
      case SplashComponentType.cpu:
        return 'assets/Parts/cpu.png';
      case SplashComponentType.ram:
        return 'assets/Parts/ram.png';
      case SplashComponentType.gpu:
        return 'assets/Parts/graphic.png';
      case SplashComponentType.ssd:
        return 'assets/Parts/ssd_m2.png';
    }
  }

  Widget _buildFallback(BuildContext context) {
    switch (type) {
      case SplashComponentType.motherboard:
        return MotherboardIllustration(color: accentColor, useAssetImage: false);
      case SplashComponentType.cpu:
        return CpuIllustration(color: accentColor, useAssetImage: false);
      case SplashComponentType.ram:
        return RamIllustration(color: accentColor, useAssetImage: false);
      case SplashComponentType.gpu:
        return GpuIllustration(color: accentColor, useAssetImage: false);
      case SplashComponentType.ssd:
        return SsdM2Illustration(color: accentColor);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.22),
        color: const Color(0xFF131B2E).withValues(alpha: 0.85),
        border: Border.all(
          color: isLocked
              ? accentColor.withValues(alpha: 0.8)
              : const Color(0xFF334155).withValues(alpha: 0.5),
          width: isLocked ? 1.5 : 1.0,
        ),
        boxShadow: [
          if (glowIntensity > 0 || isLocked)
            BoxShadow(
              color: accentColor.withValues(
                alpha: (0.2 + (glowIntensity * 0.4)).clamp(0.0, 0.7),
              ),
              blurRadius: 10 + (glowIntensity * 14),
              spreadRadius: glowIntensity * 2,
            ),
        ],
      ),
      padding: EdgeInsets.all(size * 0.14),
      child: Center(
        child: Image.asset(
          _assetPath,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
          errorBuilder: (context, error, stackTrace) => _buildFallback(context),
        ),
      ),
    );
  }
}
