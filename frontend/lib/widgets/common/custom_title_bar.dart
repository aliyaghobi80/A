// frontend/lib/widgets/common/custom_title_bar.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../controllers/theme_language_controller.dart';

/// Custom in-app title bar embedding window controls (minimize, maximize/restore, close),
/// window dragging, double-click to maximize, dark/light theme styling, and RTL alignment.
class CustomTitleBar extends StatefulWidget {
  final String? title;
  final String? logoAsset;
  final VoidCallback? onMinimize;
  final VoidCallback? onMaximize;
  final VoidCallback? onClose;
  final double height;
  final bool showWindowControls;

  const CustomTitleBar({
    super.key,
    this.title,
    this.logoAsset,
    this.onMinimize,
    this.onMaximize,
    this.onClose,
    this.height = 38.0,
    this.showWindowControls = true,
  });

  /// Method channels for native window manipulation (markazi/window and window_manager)
  static const MethodChannel _windowChannel = MethodChannel('markazi/window');
  static const MethodChannel _wmChannel = MethodChannel('window_manager');

  /// Native window actions
  static Future<void> minimize() async {
    try {
      await _windowChannel.invokeMethod('minimize');
    } catch (_) {
      try {
        await _wmChannel.invokeMethod('minimize');
      } catch (_) {}
    }
  }

  static Future<void> maximize() async {
    try {
      await _windowChannel.invokeMethod('maximize');
    } catch (_) {
      try {
        await _wmChannel.invokeMethod('maximize');
      } catch (_) {}
    }
  }

  static Future<void> unmaximize() async {
    try {
      await _windowChannel.invokeMethod('unmaximize');
    } catch (_) {
      try {
        await _wmChannel.invokeMethod('unmaximize');
      } catch (_) {}
    }
  }

  static Future<void> toggleMaximize({bool? isMaximizedHint}) async {
    try {
      final bool? isMax = await _windowChannel.invokeMethod<bool>('isMaximized');
      if (isMax == true) {
        await _windowChannel.invokeMethod('unmaximize');
      } else if (isMax == false) {
        await _windowChannel.invokeMethod('maximize');
      } else {
        if (isMaximizedHint == true) {
          await _windowChannel.invokeMethod('unmaximize');
        } else {
          await _windowChannel.invokeMethod('maximize');
        }
      }
    } catch (_) {
      try {
        if (isMaximizedHint == true) {
          await _wmChannel.invokeMethod('unmaximize');
        } else {
          await _wmChannel.invokeMethod('maximize');
        }
      } catch (_) {}
    }
  }

  static Future<void> close() async {
    try {
      await _windowChannel.invokeMethod('close');
    } catch (_) {
      try {
        await _wmChannel.invokeMethod('close');
      } catch (_) {}
    }
  }

  static Future<void> startDragging() async {
    try {
      await _windowChannel.invokeMethod('startDragging');
    } catch (_) {
      try {
        await _wmChannel.invokeMethod('startDragging');
      } catch (_) {}
    }
  }

  static Future<void> setFullScreen(bool fullscreen) async {
    try {
      await _windowChannel.invokeMethod('setFullScreen', fullscreen);
    } catch (_) {
      try {
        await _wmChannel.invokeMethod('setFullScreen', fullscreen);
      } catch (_) {}
    }
  }

  /// Ratified contract layout specification:
  /// In RTL: Start is Right (branding & title), End is Left (window controls / caption controls).
  /// In LTR: Start is Left (branding & title), End is Right (window controls / caption controls).
  static Map<String, String> getTitleBarLayout({required bool isRtl}) {
    return isRtl
        ? {'right': 'branding_and_title', 'left': 'caption_controls'}
        : {'left': 'branding_and_title', 'right': 'caption_controls'};
  }

  @override
  State<CustomTitleBar> createState() => _CustomTitleBarState();
}

class _CustomTitleBarState extends State<CustomTitleBar> {
  bool _isMaximized = false;
  bool _isMinimizeHovered = false;
  bool _isMaximizeHovered = false;
  bool _isCloseHovered = false;

  void _handleMinimize() {
    if (widget.onMinimize != null) {
      widget.onMinimize!();
    } else {
      CustomTitleBar.minimize();
    }
  }

  void _handleToggleMaximize() {
    setState(() {
      _isMaximized = !_isMaximized;
    });
    if (widget.onMaximize != null) {
      widget.onMaximize!();
    } else {
      CustomTitleBar.toggleMaximize(isMaximizedHint: _isMaximized);
    }
  }

  void _handleClose() {
    if (widget.onClose != null) {
      widget.onClose!();
    } else {
      CustomTitleBar.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    // Theme matching colors
    final backgroundColor = isDark
        ? const Color(0xFF0F172A) // slate-900
        : const Color(0xFFF8FAFC); // slate-50
    final borderBottomColor = isDark
        ? const Color(0xFF1E293B) // slate-800
        : const Color(0xFFE2E8F0); // slate-200
    final textColor = isDark
        ? const Color(0xFFF1F5F9)
        : const Color(0xFF0F172A);
    final buttonHoverColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.05);
    const closeHoverColor = Color(0xFFE81123); // Windows red hover

    // Persian title by default, or localized
    String resolvedTitle = widget.title ?? 'سامانه بررسی و نصب مرکزی';
    if (widget.title == null && Get.isRegistered<ThemeLanguageController>()) {
      final langCtrl = Get.find<ThemeLanguageController>();
      if (langCtrl.currentLocale.value.languageCode != 'fa') {
        resolvedTitle = 'Markazi System Checker';
      }
    }

    return Container(
      key: const ValueKey('custom-title-bar-root'),
      height: widget.height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(
          bottom: BorderSide(
            color: borderBottomColor,
            width: 1.0,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Branding and Title (Placed at Row start: Right in RTL, Left in LTR)
          _buildBranding(
            textColor: textColor,
            title: resolvedTitle,
          ),

          // Central draggable region
          Expanded(
            child: GestureDetector(
              key: const ValueKey('custom-title-bar-drag-region'),
              behavior: HitTestBehavior.opaque,
              onPanStart: (_) => CustomTitleBar.startDragging(),
              onDoubleTap: _handleToggleMaximize,
              child: Container(color: Colors.transparent),
            ),
          ),

          // Window controls (Placed at Row end: Left in RTL, Right in LTR)
          if (widget.showWindowControls)
            _buildWindowControls(
              textColor: textColor,
              hoverColor: buttonHoverColor,
              closeHoverColor: closeHoverColor,
              isRtl: isRtl,
            ),
        ],
      ),
    );
  }

  Widget _buildBranding({
    required Color textColor,
    required String title,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (_) => CustomTitleBar.startDragging(),
      onDoubleTap: _handleToggleMaximize,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Logo
            Image.asset(
              widget.logoAsset ?? 'assets/logo/logo.png',
              key: const ValueKey('custom-title-bar-logo'),
              width: 18,
              height: 18,
              errorBuilder: (context, error, stackTrace) => Icon(
                Icons.computer_rounded,
                size: 18,
                color: textColor.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(width: 8),
            // Title text
            Text(
              title,
              key: const ValueKey('custom-title-bar-title'),
              style: TextStyle(
                fontFamily: 'Vazirmatn',
                fontSize: 12.0,
                fontWeight: FontWeight.w600,
                color: textColor,
                letterSpacing: 0.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWindowControls({
    required Color textColor,
    required Color hoverColor,
    required Color closeHoverColor,
    required bool isRtl,
  }) {
    // In RTL, standard desktop layout places the window controls on the left side,
    // with Close at the outer edge (far left), Maximize in the center, and Minimize on the inner side.
    // In LTR, Minimize is inner (left), Maximize is center, Close is outer (far right).
    final buttons = isRtl
        ? [
            _buildCloseButton(textColor: textColor, hoverColor: closeHoverColor),
            _buildMaximizeButton(textColor: textColor, hoverColor: hoverColor),
            _buildMinimizeButton(textColor: textColor, hoverColor: hoverColor),
          ]
        : [
            _buildMinimizeButton(textColor: textColor, hoverColor: hoverColor),
            _buildMaximizeButton(textColor: textColor, hoverColor: hoverColor),
            _buildCloseButton(textColor: textColor, hoverColor: closeHoverColor),
          ];

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: buttons,
      ),
    );
  }

  Widget _buildMinimizeButton({
    required Color textColor,
    required Color hoverColor,
  }) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isMinimizeHovered = true),
      onExit: (_) => setState(() => _isMinimizeHovered = false),
      child: GestureDetector(
        key: const ValueKey('window-control-minimize'),
        behavior: HitTestBehavior.opaque,
        onTap: _handleMinimize,
        child: Container(
          width: 46.0,
          alignment: Alignment.center,
          color: _isMinimizeHovered ? hoverColor : Colors.transparent,
          child: Container(
            width: 10.0,
            height: 1.5,
            color: textColor,
          ),
        ),
      ),
    );
  }

  Widget _buildMaximizeButton({
    required Color textColor,
    required Color hoverColor,
  }) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isMaximizeHovered = true),
      onExit: (_) => setState(() => _isMaximizeHovered = false),
      child: GestureDetector(
        key: const ValueKey('window-control-maximize'),
        behavior: HitTestBehavior.opaque,
        onTap: _handleToggleMaximize,
        child: Container(
          width: 46.0,
          alignment: Alignment.center,
          color: _isMaximizeHovered ? hoverColor : Colors.transparent,
          child: _isMaximized
              ? CustomPaint(
                  size: const Size(10, 10),
                  painter: _RestoreIconPainter(color: textColor),
                )
              : Container(
                  width: 10.0,
                  height: 10.0,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: textColor,
                      width: 1.2,
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildCloseButton({
    required Color textColor,
    required Color hoverColor,
  }) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isCloseHovered = true),
      onExit: (_) => setState(() => _isCloseHovered = false),
      child: GestureDetector(
        key: const ValueKey('window-control-close'),
        behavior: HitTestBehavior.opaque,
        onTap: _handleClose,
        child: Container(
          width: 46.0,
          alignment: Alignment.center,
          color: _isCloseHovered ? hoverColor : Colors.transparent,
          child: Icon(
            Icons.close_rounded,
            size: 16.0,
            color: _isCloseHovered ? Colors.white : textColor,
          ),
        ),
      ),
    );
  }
}

/// Custom painter for the Windows restore window icon (two overlapping squares)
class _RestoreIconPainter extends CustomPainter {
  final Color color;
  const _RestoreIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Back square (offset up and right)
    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.25, 0, size.width * 0.75, size.height * 0.75),
      paint,
    );

    // Front square (down and left)
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.25, size.width * 0.75, size.height * 0.75),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _RestoreIconPainter oldDelegate) =>
      oldDelegate.color != color;
}
