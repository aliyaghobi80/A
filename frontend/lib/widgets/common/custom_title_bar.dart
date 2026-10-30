// frontend/lib/widgets/common/custom_title_bar.dart
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../controllers/driver_install_controller.dart';
import '../../controllers/software_controller.dart';
import '../../controllers/theme_language_controller.dart';
import '../../services/install_state_service.dart';
import '../../theme/app_theme.dart';
import '../dialogs/exit_dialog.dart';

/// Custom in-app title bar embedding Windows 11 style window controls (minimize,
/// maximize/restore, close), window dragging, double-click to maximize,
/// dark/light theme synchronization, focus/blur dimming, and active queue protection.
class CustomTitleBar extends StatefulWidget {
  final String? title;
  final String? logoAsset;
  final VoidCallback? onMinimize;
  final VoidCallback? onMaximize;
  final VoidCallback? onClose;
  final double height;
  final bool showWindowControls;
  final bool? overrideMaximized;
  final bool? isFocused;

  /// Build timestamp identifier from environment (passed via --dart-define)
  static const String buildTimestamp = String.fromEnvironment(
    'BUILD_TIMESTAMP',
    defaultValue: 'dev',
  );

  const CustomTitleBar({
    super.key,
    this.title,
    this.logoAsset,
    this.onMinimize,
    this.onMaximize,
    this.onClose,
    this.height = 32.0,
    this.showWindowControls = true,
    bool? isMaximized,
    this.isFocused,
  }) : overrideMaximized = isMaximized;

  /// Method channel fallback for DWM theme sync (immersive dark mode, caption colors).
  /// Window control actions use bitsdojo_window's appWindow directly.
  static const MethodChannel _windowChannel = MethodChannel('markazi/window');

  /// Asynchronously queries whether the native OS window is currently maximized.
  static Future<bool> isMaximized() async {
    try {
      final bool? isMax =
          await _windowChannel.invokeMethod<bool>('isMaximized');
      if (isMax != null) return isMax;
    } catch (_) {}
    try {
      return appWindow.isMaximized;
    } catch (_) {}
    return false;
  }

  /// Native window actions — delegate to bitsdojo_window and _windowChannel
  static Future<void> minimize() async {
    try {
      appWindow.minimize();
    } catch (_) {}
    try {
      await _windowChannel.invokeMethod('minimize');
    } catch (_) {}
  }

  static Future<void> maximize() async {
    try {
      appWindow.maximize();
    } catch (_) {}
    try {
      await _windowChannel.invokeMethod('maximize');
    } catch (_) {}
  }

  static Future<void> unmaximize() async {
    try {
      appWindow.restore();
    } catch (_) {}
    try {
      await _windowChannel.invokeMethod('unmaximize');
    } catch (_) {}
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
        appWindow.maximizeOrRestore();
      } catch (_) {}
    }
  }

  static Future<void> close() async {
    try {
      appWindow.close();
    } catch (_) {}
    try {
      await _windowChannel.invokeMethod('close');
    } catch (_) {}
  }

  /// startDragging: triggers bitsdojo_window native drag and _windowChannel
  static Future<void> startDragging() async {
    try {
      appWindow.startDragging();
    } catch (_) {}
    try {
      await _windowChannel.invokeMethod('startDragging');
    } catch (_) {}
  }

  static Future<void> setFullScreen(bool fullscreen) async {
    try {
      await _windowChannel.invokeMethod('setFullScreen', fullscreen);
    } catch (_) {}
  }

  /// Synchronize DWM window attributes (immersive dark mode, caption colors) with the active theme
  static Future<void> setTheme({required bool isDark}) async {
    try {
      await _windowChannel.invokeMethod('setTheme', {'isDark': isDark});
    } catch (_) {}
  }

  /// Ratified contract layout specification:
  /// Controls are ALWAYS at the top-right corner (Windows desktop convention, even in RTL layouts).
  /// Logo and Title are ALWAYS at the top-left corner, coordinating with the right sidebar.
  static Map<String, String> getTitleBarLayout({required bool isRtl}) {
    return const {
      'left': 'branding_and_title',
      'right': 'caption_controls',
    };
  }

  @override
  State<CustomTitleBar> createState() => _CustomTitleBarState();
}

class _CustomTitleBarState extends State<CustomTitleBar>
    with WidgetsBindingObserver {
  bool _isMaximized = false;
  bool _isWindowFocused = true;
  bool _isMinimizeHovered = false;
  bool _isMaximizeHovered = false;
  bool _isCloseHovered = false;
  Worker? _themeWorker;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.overrideMaximized != null) {
      _isMaximized = widget.overrideMaximized!;
    }
    if (widget.isFocused != null) {
      _isWindowFocused = widget.isFocused!;
    }
    CustomTitleBar._windowChannel.setMethodCallHandler(_handleWindowMethodCall);
    _syncWindowState();

    if (Get.isRegistered<ThemeLanguageController>()) {
      final themeCtrl = Get.find<ThemeLanguageController>();
      _themeWorker = ever(themeCtrl.themeMode, (mode) {
        CustomTitleBar.setTheme(isDark: mode == ThemeMode.dark);
      });
    }
  }

  @override
  void didUpdateWidget(covariant CustomTitleBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.overrideMaximized != null &&
        widget.overrideMaximized != oldWidget.overrideMaximized) {
      _isMaximized = widget.overrideMaximized!;
    }
    if (widget.isFocused != null && widget.isFocused != oldWidget.isFocused) {
      _isWindowFocused = widget.isFocused!;
    }
  }

  @override
  void dispose() {
    CustomTitleBar._windowChannel.setMethodCallHandler(null);
    _themeWorker?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    _syncWindowState();
  }

  Future<void> _syncWindowState() async {
    try {
      final isMax = await CustomTitleBar.isMaximized();
      if (mounted && _isMaximized != isMax) {
        setState(() {
          _isMaximized = isMax;
        });
      }
    } catch (_) {}
  }

  Future<dynamic> _handleWindowMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onWindowFocus':
        if (mounted && !_isWindowFocused) setState(() => _isWindowFocused = true);
        break;
      case 'onWindowBlur':
        if (mounted && _isWindowFocused) setState(() => _isWindowFocused = false);
        break;
      case 'onWindowMaximize':
      case 'onWindowMaximized':
        if (mounted && !_isMaximized) setState(() => _isMaximized = true);
        break;
      case 'onWindowUnmaximize':
      case 'onWindowUnmaximized':
      case 'onWindowRestore':
      case 'onWindowRestored':
        if (mounted && _isMaximized) setState(() => _isMaximized = false);
        break;
    }
    return null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final bool focused = state == AppLifecycleState.resumed;
    if (_isWindowFocused != focused && mounted) {
      setState(() {
        _isWindowFocused = focused;
      });
    }
  }

  void _handleMinimize() {
    if (widget.onMinimize != null) {
      widget.onMinimize!();
    } else {
      CustomTitleBar.minimize();
    }
  }

  void _handleToggleMaximize() {
    final wasMaximized = _isMaximized;
    setState(() {
      _isMaximized = !_isMaximized;
    });
    if (widget.onMaximize != null) {
      widget.onMaximize!();
    } else {
      CustomTitleBar.toggleMaximize(isMaximizedHint: wasMaximized);
    }
  }

  void _handleClose(BuildContext context) {
    final isInstalling = (Get.isRegistered<InstallStateService>() &&
            (InstallStateService.to.isDriverRunning.value ||
                InstallStateService.to.isSoftwareRunning.value)) ||
        (Get.isRegistered<SoftwareController>() &&
            Get.find<SoftwareController>().isBatchInstalling.value) ||
        (Get.isRegistered<DriverInstallController>() &&
            (Get.find<DriverInstallController>().isBatchRunning.value ||
                Get.find<DriverInstallController>().isBatchInstalling.value));
    if (isInstalling) {
      ExitDialog.show(context);
    } else if (widget.onClose != null) {
      widget.onClose!();
    } else {
      CustomTitleBar.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Synchronize native DWM frame attributes with active theme
    CustomTitleBar.setTheme(isDark: isDark);

    // Theme matching surface and border colors
    final backgroundColor =
        isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final borderBottomColor =
        isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final textColor =
        isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final buttonHoverColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.05);
    const closeHoverColor = Color(0xFFE81123); // Windows red hover

    // Localized title resolution
    String resolvedTitle = widget.title ?? 'سامانه بررسی و نصب مرکزی';
    if (widget.title == null && Get.isRegistered<ThemeLanguageController>()) {
      final langCtrl = Get.find<ThemeLanguageController>();
      if (langCtrl.currentLocale.value.languageCode != 'fa') {
        resolvedTitle = 'Markazi System Checker';
      }
    }

    final bool effectiveFocused = widget.isFocused ?? _isWindowFocused;
    final bool effectiveMaximized = widget.overrideMaximized ?? _isMaximized;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
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
            // Top-left branding and title (Windows standard top-left position)
            _buildBranding(
              textColor: textColor,
              title: resolvedTitle,
              isFocused: effectiveFocused,
            ),

            // Central draggable region — uses bitsdojo_window's MoveWindow
            // widget so dragging is handled at the native Win32 level (no
            // polling, no SendMessage race). Double-tap to maximize/restore.
            Expanded(
              child: MoveWindow(
                key: const ValueKey('custom-title-bar-drag-region'),
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (event) {
                    if ((event.buttons & 1) != 0) {
                      CustomTitleBar.startDragging();
                    }
                  },
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onDoubleTap: _handleToggleMaximize,
                    child: Container(color: Colors.transparent),
                  ),
                ),
              ),
            ),

            // Top-right window controls (Windows standard top-right position)
            if (widget.showWindowControls)
              _buildWindowControls(
                textColor: textColor,
                hoverColor: buttonHoverColor,
                closeHoverColor: closeHoverColor,
                isMaximized: effectiveMaximized,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBranding({
    required Color textColor,
    required String title,
    required bool isFocused,
  }) {
    final double brandingOpacity = isFocused ? 1.0 : 0.55;

    return MoveWindow(
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (event) {
          if ((event.buttons & 1) != 0) {
            CustomTitleBar.startDragging();
          }
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onDoubleTap: _handleToggleMaximize,
          child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: Opacity(
            key: const ValueKey('custom-title-bar-branding-opacity'),
            opacity: brandingOpacity,
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
                // Title text with build timestamp tooltip
                Tooltip(
                  key: const ValueKey('custom-title-bar-build-tooltip'),
                  message: 'Build: ${CustomTitleBar.buildTimestamp}',
                  child: Text(
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
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

  Widget _buildWindowControls({
    required Color textColor,
    required Color hoverColor,
    required Color closeHoverColor,
    required bool isMaximized,
  }) {
    // Windows convention: Minimize (inner left), Maximize (center), Close (outer right)
    // Control buttons row wrapped in Directionality.ltr so Minimize, Maximize/Restore,
    // and Close buttons always remain anchored to top-right corner.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        key: const ValueKey('custom-title-bar-controls-row'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildMinimizeButton(textColor: textColor, hoverColor: hoverColor),
          _buildMaximizeButton(
            textColor: textColor,
            hoverColor: hoverColor,
            isMaximized: isMaximized,
          ),
          _buildCloseButton(textColor: textColor, hoverColor: closeHoverColor),
        ],
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
    required bool isMaximized,
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
          child: isMaximized
              ? CustomPaint(
                  key: const ValueKey('window-control-restore-icon'),
                  size: const Size(10, 10),
                  painter: RestoreIconPainter(color: textColor),
                )
              : Container(
                  key: const ValueKey('window-control-maximize-icon'),
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
        onTap: () => _handleClose(context),
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
class RestoreIconPainter extends CustomPainter {
  final Color color;
  const RestoreIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Back square (offset up and right)
    canvas.drawRect(
      Rect.fromLTWH(
          size.width * 0.25, 0, size.width * 0.75, size.height * 0.75),
      paint,
    );

    // Front square (down and left)
    canvas.drawRect(
      Rect.fromLTWH(
          0, size.height * 0.25, size.width * 0.75, size.height * 0.75),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant RestoreIconPainter oldDelegate) =>
      oldDelegate.color != color;
}
