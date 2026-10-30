// frontend/lib/widgets/common/app_frame.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/hardware_test_controller.dart';
import 'custom_title_bar.dart';

/// AppFrame wraps the top-level application view tree, embedding the CustomTitleBar
/// while supporting complete hiding in fullscreen test modes (e.g. Monitor & Pixel test).
class AppFrame extends StatelessWidget {
  final Widget child;
  final bool? isFullscreen;
  final Widget? titleBar;

  const AppFrame({
    super.key,
    required this.child,
    this.isFullscreen,
    this.titleBar,
  });

  /// Evaluates title bar visibility contract:
  /// Title bar must be completely hidden during fullscreen diagnostic tests.
  static bool isTitleBarVisible({required bool isFullscreenTest}) => !isFullscreenTest;

  @override
  Widget build(BuildContext context) {
    // If HardwareTestController is registered in GetX, observe monitor test fullscreen state reactively
    if (Get.isRegistered<HardwareTestController>()) {
      final hwCtrl = Get.find<HardwareTestController>();
      return Obx(() {
        final bool activeFullscreen = isFullscreen ?? hwCtrl.isMonitorFullScreen.value;
        return _buildFrame(
          context: context,
          hideTitleBar: !isTitleBarVisible(isFullscreenTest: activeFullscreen),
        );
      });
    }

    // Default static resolution when controller is not registered (e.g. unit/widget tests)
    final bool activeFullscreen = isFullscreen ?? false;
    return _buildFrame(
      context: context,
      hideTitleBar: !isTitleBarVisible(isFullscreenTest: activeFullscreen),
    );
  }

  Widget _buildFrame({
    required BuildContext context,
    required bool hideTitleBar,
  }) {
    if (hideTitleBar) {
      return Container(
        key: const ValueKey('app-frame-root'),
        color: Theme.of(context).scaffoldBackgroundColor,
        child: child,
      );
    }

    return Container(
      key: const ValueKey('app-frame-root'),
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          KeyedSubtree(
            key: const ValueKey('app-frame-titlebar'),
            child: titleBar ?? const CustomTitleBar(),
          ),
          Expanded(
            child: KeyedSubtree(
              key: const ValueKey('app-frame-content'),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}
