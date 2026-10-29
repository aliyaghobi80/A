// frontend/lib/widgets/hardware_tests/keyboard_test_view.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../controllers/hardware_test_controller.dart';
import '../../theme/app_theme.dart';

class KeyboardTestView extends StatefulWidget {
  const KeyboardTestView({super.key});

  @override
  State<KeyboardTestView> createState() => _KeyboardTestViewState();
}

class _KeyboardTestViewState extends State<KeyboardTestView> {
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  String _mapKey(PhysicalKeyboardKey physicalKey, LogicalKeyboardKey logicalKey) {
    // Return standard key id code matching our visual layout
    if (physicalKey == PhysicalKeyboardKey.escape) return 'Escape';
    if (physicalKey == PhysicalKeyboardKey.f1) return 'F1';
    if (physicalKey == PhysicalKeyboardKey.f2) return 'F2';
    if (physicalKey == PhysicalKeyboardKey.f3) return 'F3';
    if (physicalKey == PhysicalKeyboardKey.f4) return 'F4';
    if (physicalKey == PhysicalKeyboardKey.f5) return 'F5';
    if (physicalKey == PhysicalKeyboardKey.f6) return 'F6';
    if (physicalKey == PhysicalKeyboardKey.f7) return 'F7';
    if (physicalKey == PhysicalKeyboardKey.f8) return 'F8';
    if (physicalKey == PhysicalKeyboardKey.f9) return 'F9';
    if (physicalKey == PhysicalKeyboardKey.f10) return 'F10';
    if (physicalKey == PhysicalKeyboardKey.f11) return 'F11';
    if (physicalKey == PhysicalKeyboardKey.f12) return 'F12';

    if (physicalKey == PhysicalKeyboardKey.backquote) return 'Backquote';
    if (physicalKey == PhysicalKeyboardKey.digit1) return 'Digit1';
    if (physicalKey == PhysicalKeyboardKey.digit2) return 'Digit2';
    if (physicalKey == PhysicalKeyboardKey.digit3) return 'Digit3';
    if (physicalKey == PhysicalKeyboardKey.digit4) return 'Digit4';
    if (physicalKey == PhysicalKeyboardKey.digit5) return 'Digit5';
    if (physicalKey == PhysicalKeyboardKey.digit6) return 'Digit6';
    if (physicalKey == PhysicalKeyboardKey.digit7) return 'Digit7';
    if (physicalKey == PhysicalKeyboardKey.digit8) return 'Digit8';
    if (physicalKey == PhysicalKeyboardKey.digit9) return 'Digit9';
    if (physicalKey == PhysicalKeyboardKey.digit0) return 'Digit0';
    if (physicalKey == PhysicalKeyboardKey.minus) return 'Minus';
    if (physicalKey == PhysicalKeyboardKey.equal) return 'Equal';
    if (physicalKey == PhysicalKeyboardKey.backspace) return 'Backspace';

    if (physicalKey == PhysicalKeyboardKey.tab) return 'Tab';
    if (physicalKey == PhysicalKeyboardKey.keyQ) return 'KeyQ';
    if (physicalKey == PhysicalKeyboardKey.keyW) return 'KeyW';
    if (physicalKey == PhysicalKeyboardKey.keyE) return 'KeyE';
    if (physicalKey == PhysicalKeyboardKey.keyR) return 'KeyR';
    if (physicalKey == PhysicalKeyboardKey.keyT) return 'KeyT';
    if (physicalKey == PhysicalKeyboardKey.keyY) return 'KeyY';
    if (physicalKey == PhysicalKeyboardKey.keyU) return 'KeyU';
    if (physicalKey == PhysicalKeyboardKey.keyI) return 'KeyI';
    if (physicalKey == PhysicalKeyboardKey.keyO) return 'KeyO';
    if (physicalKey == PhysicalKeyboardKey.keyP) return 'KeyP';
    if (physicalKey == PhysicalKeyboardKey.bracketLeft) return 'BracketLeft';
    if (physicalKey == PhysicalKeyboardKey.bracketRight) return 'BracketRight';
    if (physicalKey == PhysicalKeyboardKey.backslash) return 'Backslash';

    if (physicalKey == PhysicalKeyboardKey.capsLock) return 'CapsLock';
    if (physicalKey == PhysicalKeyboardKey.keyA) return 'KeyA';
    if (physicalKey == PhysicalKeyboardKey.keyS) return 'KeyS';
    if (physicalKey == PhysicalKeyboardKey.keyD) return 'KeyD';
    if (physicalKey == PhysicalKeyboardKey.keyF) return 'KeyF';
    if (physicalKey == PhysicalKeyboardKey.keyG) return 'KeyG';
    if (physicalKey == PhysicalKeyboardKey.keyH) return 'KeyH';
    if (physicalKey == PhysicalKeyboardKey.keyJ) return 'KeyJ';
    if (physicalKey == PhysicalKeyboardKey.keyK) return 'KeyK';
    if (physicalKey == PhysicalKeyboardKey.keyL) return 'KeyL';
    if (physicalKey == PhysicalKeyboardKey.semicolon) return 'Semicolon';
    if (physicalKey == PhysicalKeyboardKey.quote) return 'Quote';
    if (physicalKey == PhysicalKeyboardKey.enter) return 'Enter';

    if (physicalKey == PhysicalKeyboardKey.shiftLeft) return 'ShiftLeft';
    if (physicalKey == PhysicalKeyboardKey.keyZ) return 'KeyZ';
    if (physicalKey == PhysicalKeyboardKey.keyX) return 'KeyX';
    if (physicalKey == PhysicalKeyboardKey.keyC) return 'KeyC';
    if (physicalKey == PhysicalKeyboardKey.keyV) return 'KeyV';
    if (physicalKey == PhysicalKeyboardKey.keyB) return 'KeyB';
    if (physicalKey == PhysicalKeyboardKey.keyN) return 'KeyN';
    if (physicalKey == PhysicalKeyboardKey.keyM) return 'KeyM';
    if (physicalKey == PhysicalKeyboardKey.comma) return 'Comma';
    if (physicalKey == PhysicalKeyboardKey.period) return 'Period';
    if (physicalKey == PhysicalKeyboardKey.slash) return 'Slash';
    if (physicalKey == PhysicalKeyboardKey.shiftRight) return 'ShiftRight';

    if (physicalKey == PhysicalKeyboardKey.controlLeft) return 'ControlLeft';
    if (physicalKey == PhysicalKeyboardKey.metaLeft) return 'MetaLeft';
    if (physicalKey == PhysicalKeyboardKey.altLeft) return 'AltLeft';
    if (physicalKey == PhysicalKeyboardKey.space) return 'Space';
    if (physicalKey == PhysicalKeyboardKey.altRight) return 'AltRight';
    if (physicalKey == PhysicalKeyboardKey.contextMenu) return 'ContextMenu';
    if (physicalKey == PhysicalKeyboardKey.controlRight) return 'ControlRight';

    if (physicalKey == PhysicalKeyboardKey.printScreen) return 'PrintScreen';
    if (physicalKey == PhysicalKeyboardKey.scrollLock) return 'ScrollLock';
    if (physicalKey == PhysicalKeyboardKey.pause) return 'Pause';
    if (physicalKey == PhysicalKeyboardKey.insert) return 'Insert';
    if (physicalKey == PhysicalKeyboardKey.home) return 'Home';
    if (physicalKey == PhysicalKeyboardKey.pageUp) return 'PageUp';
    if (physicalKey == PhysicalKeyboardKey.delete) return 'Delete';
    if (physicalKey == PhysicalKeyboardKey.end) return 'End';
    if (physicalKey == PhysicalKeyboardKey.pageDown) return 'PageDown';

    if (physicalKey == PhysicalKeyboardKey.arrowUp) return 'ArrowUp';
    if (physicalKey == PhysicalKeyboardKey.arrowDown) return 'ArrowDown';
    if (physicalKey == PhysicalKeyboardKey.arrowLeft) return 'ArrowLeft';
    if (physicalKey == PhysicalKeyboardKey.arrowRight) return 'ArrowRight';

    if (physicalKey == PhysicalKeyboardKey.numLock) return 'NumLock';
    if (physicalKey == PhysicalKeyboardKey.numpadDivide) return 'NumpadDivide';
    if (physicalKey == PhysicalKeyboardKey.numpadMultiply) return 'NumpadMultiply';
    if (physicalKey == PhysicalKeyboardKey.numpadSubtract) return 'NumpadSubtract';
    if (physicalKey == PhysicalKeyboardKey.numpadAdd) return 'NumpadAdd';
    if (physicalKey == PhysicalKeyboardKey.numpadEnter) return 'NumpadEnter';
    if (physicalKey == PhysicalKeyboardKey.numpadDecimal) return 'NumpadDecimal';
    if (physicalKey == PhysicalKeyboardKey.numpad0) return 'Numpad0';
    if (physicalKey == PhysicalKeyboardKey.numpad1) return 'Numpad1';
    if (physicalKey == PhysicalKeyboardKey.numpad2) return 'Numpad2';
    if (physicalKey == PhysicalKeyboardKey.numpad3) return 'Numpad3';
    if (physicalKey == PhysicalKeyboardKey.numpad4) return 'Numpad4';
    if (physicalKey == PhysicalKeyboardKey.numpad5) return 'Numpad5';
    if (physicalKey == PhysicalKeyboardKey.numpad6) return 'Numpad6';
    if (physicalKey == PhysicalKeyboardKey.numpad7) return 'Numpad7';
    if (physicalKey == PhysicalKeyboardKey.numpad8) return 'Numpad8';
    if (physicalKey == PhysicalKeyboardKey.numpad9) return 'Numpad9';

    return logicalKey.keyLabel;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ctrl = Get.find<HardwareTestController>();

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (node, event) {
        final code = _mapKey(event.physicalKey, event.logicalKey);
        final label = event.logicalKey.keyLabel.isNotEmpty ? event.logicalKey.keyLabel : code;
        if (event is KeyDownEvent) {
          ctrl.onKeyDown(code, label);
          return KeyEventResult.handled;
        } else if (event is KeyUpEvent) {
          ctrl.onKeyUp(code);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => _focusNode.requestFocus(),
        child: Container(
          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
          child: Stack(
            children: [
              // 1. Dominant Workspace: Center Keyboard Layout (>85% of screen)
              Positioned.fill(
                bottom: 48,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 52, 16, 12),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Center(
                        child: FittedBox(
                          fit: BoxFit.contain,
                          alignment: Alignment.center,
                          child: SizedBox(
                            width: 936,
                            height: 288,
                            child: _buildKeyboardChassis(ctrl, isDark),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              // 2. Minimal Floating Overlay (Top-Right)
              Positioned(
                top: 12,
                right: 16,
                child: _buildFloatingOverlay(ctrl),
              ),

              // 3. Compact Bottom Status Bar
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 48,
                child: _buildBottomStatusBar(ctrl, isDark),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- FLOATING OVERLAY ---
  Widget _buildFloatingOverlay(HardwareTestController ctrl) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF334155)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: () => ctrl.selectSubTest('hub'),
            icon: const Icon(Icons.arrow_forward_rounded, size: 16),
            tooltip: 'بازگشت به هاب تست‌ها',
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            style: IconButton.styleFrom(
              foregroundColor: const Color(0xFFCBD5E1),
            ),
          ),
          Container(
            width: 1,
            height: 16,
            color: const Color(0xFF334155),
            margin: const EdgeInsets.symmetric(horizontal: 4),
          ),
          IconButton(
            onPressed: () => ctrl.resetKeyboard(),
            icon: const Icon(Icons.refresh_rounded, size: 16),
            tooltip: 'شروع مجدد تست کیبورد',
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            style: IconButton.styleFrom(
              foregroundColor: const Color(0xFFCBD5E1),
            ),
          ),
          Container(
            width: 1,
            height: 16,
            color: const Color(0xFF334155),
            margin: const EdgeInsets.symmetric(horizontal: 4),
          ),
          Obx(() {
            final count = ctrl.testedKeys.length;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF10B981).withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$count / 105',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'monospace',
                      color: Color(0xFF10B981),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // --- KEYBOARD CHASSIS CONTAINER ---
  Widget _buildKeyboardChassis(HardwareTestController ctrl, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF334155),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cluster 1: Main Typing Cluster (width: 592)
            _buildMainCluster(ctrl, isDark),
            _gap(16),
            // Cluster 2: Navigation Cluster (width: 116)
            _buildNavCluster(ctrl, isDark),
            _gap(16),
            // Cluster 3: Numpad Cluster (width: 156)
            _buildNumpadCluster(ctrl, isDark),
          ],
        ),
      ),
    );
  }

  // --- CLUSTER 1: MAIN TYPING CLUSTER (Width = 592px) ---
  Widget _buildMainCluster(HardwareTestController ctrl, bool isDark) {
    return SizedBox(
      width: 592,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 0: Function Row (Esc + F1..F4 + F5..F8 + F9..F12)
          Row(
            children: [
              _buildKey(ctrl, isDark, 'Escape', 'Esc', width: 36),
              _gap(24),
              _buildKey(ctrl, isDark, 'F1', 'F1', width: 36),
              _gap(4),
              _buildKey(ctrl, isDark, 'F2', 'F2', width: 36),
              _gap(4),
              _buildKey(ctrl, isDark, 'F3', 'F3', width: 36),
              _gap(4),
              _buildKey(ctrl, isDark, 'F4', 'F4', width: 36),
              _gap(32),
              _buildKey(ctrl, isDark, 'F5', 'F5', width: 36),
              _gap(4),
              _buildKey(ctrl, isDark, 'F6', 'F6', width: 36),
              _gap(4),
              _buildKey(ctrl, isDark, 'F7', 'F7', width: 36),
              _gap(4),
              _buildKey(ctrl, isDark, 'F8', 'F8', width: 36),
              _gap(32),
              _buildKey(ctrl, isDark, 'F9', 'F9', width: 36),
              _gap(4),
              _buildKey(ctrl, isDark, 'F10', 'F10', width: 36),
              _gap(4),
              _buildKey(ctrl, isDark, 'F11', 'F11', width: 36),
              _gap(4),
              _buildKey(ctrl, isDark, 'F12', 'F12', width: 36),
            ],
          ),
          _vGap(10),

          // Row 1: Number Row (~ 1..0 - = Backspace)
          Row(
            children: [
              _buildKey(ctrl, isDark, 'Backquote', '`', width: 36),
              _gap(4),
              _buildKey(ctrl, isDark, 'Digit1', '1', width: 36),
              _gap(4),
              _buildKey(ctrl, isDark, 'Digit2', '2', width: 36),
              _gap(4),
              _buildKey(ctrl, isDark, 'Digit3', '3', width: 36),
              _gap(4),
              _buildKey(ctrl, isDark, 'Digit4', '4', width: 36),
              _gap(4),
              _buildKey(ctrl, isDark, 'Digit5', '5', width: 36),
              _gap(4),
              _buildKey(ctrl, isDark, 'Digit6', '6', width: 36),
              _gap(4),
              _buildKey(ctrl, isDark, 'Digit7', '7', width: 36),
              _gap(4),
              _buildKey(ctrl, isDark, 'Digit8', '8', width: 36),
              _gap(4),
              _buildKey(ctrl, isDark, 'Digit9', '9', width: 36),
              _gap(4),
              _buildKey(ctrl, isDark, 'Digit0', '0', width: 36),
              _gap(4),
              _buildKey(ctrl, isDark, 'Minus', '-', width: 36),
              _gap(4),
              _buildKey(ctrl, isDark, 'Equal', '=', width: 36),
              _gap(4),
              _buildKey(ctrl, isDark, 'Backspace', '⌫ Backspace', width: 72),
            ],
          ),
          _vGap(5),

          // Row 2: Tab QWERTY [ ] \
          Row(
            children: [
              _buildKey(ctrl, isDark, 'Tab', 'Tab', width: 58),
              _gap(4),
              _buildKey(ctrl, isDark, 'KeyQ', 'Q', width: 36),
              _gap(4),
              _buildKey(ctrl, isDark, 'KeyW', 'W', width: 36),
              _gap(4),
              _buildKey(ctrl, isDark, 'KeyE', 'E', width: 36),
              _gap(4),
              _buildKey(ctrl, isDark, 'KeyR', 'R', width: 36),
              _gap(4),
              _buildKey(ctrl, isDark, 'KeyT', 'T', width: 36),
              _gap(4),
              _buildKey(ctrl, isDark, 'KeyY', 'Y', width: 36),
              _gap(4),
              _buildKey(ctrl, isDark, 'KeyU', 'U', width: 36),
              _gap(4),
              _buildKey(ctrl, isDark, 'KeyI', 'I', width: 36),
              _gap(4),
              _buildKey(ctrl, isDark, 'KeyO', 'O', width: 36),
              _gap(4),
              _buildKey(ctrl, isDark, 'KeyP', 'P', width: 36),
              _gap(4),
              _buildKey(ctrl, isDark, 'BracketLeft', '[', width: 36),
              _gap(4),
              _buildKey(ctrl, isDark, 'BracketRight', ']', width: 36),
              _gap(4),
              _buildKey(ctrl, isDark, 'Backslash', '\\', width: 50),
            ],
          ),
          _vGap(5),

          // Row 3: Caps ASDF Enter
          Row(
            children: [
              _buildKey(ctrl, isDark, 'CapsLock', 'Caps', width: 66),
              _gap(4),
              _buildKey(ctrl, isDark, 'KeyA', 'A', width: 36),
              _gap(4),
              _buildKey(ctrl, isDark, 'KeyS', 'S', width: 36),
              _gap(4),
              _buildKey(ctrl, isDark, 'KeyD', 'D', width: 36),
              _gap(4),
              _buildKey(ctrl, isDark, 'KeyF', 'F', width: 36),
              _gap(4),
              _buildKey(ctrl, isDark, 'KeyG', 'G', width: 36),
              _gap(4),
              _buildKey(ctrl, isDark, 'KeyH', 'H', width: 36),
              _gap(4),
              _buildKey(ctrl, isDark, 'KeyJ', 'J', width: 36),
              _gap(4),
              _buildKey(ctrl, isDark, 'KeyK', 'K', width: 36),
              _gap(4),
              _buildKey(ctrl, isDark, 'KeyL', 'L', width: 36),
              _gap(4),
              _buildKey(ctrl, isDark, 'Semicolon', ';', width: 36),
              _gap(4),
              _buildKey(ctrl, isDark, 'Quote', '\'', width: 36),
              _gap(4),
              _buildKey(ctrl, isDark, 'Enter', 'Enter ↵', width: 82),
            ],
          ),
          _vGap(5),

          // Row 4: Shift ZXCV Shift
          Row(
            children: [
              _buildKey(ctrl, isDark, 'ShiftLeft', 'Shift ⇧', width: 86),
              _gap(4),
              _buildKey(ctrl, isDark, 'KeyZ', 'Z', width: 36),
              _gap(4),
              _buildKey(ctrl, isDark, 'KeyX', 'X', width: 36),
              _gap(4),
              _buildKey(ctrl, isDark, 'KeyC', 'C', width: 36),
              _gap(4),
              _buildKey(ctrl, isDark, 'KeyV', 'V', width: 36),
              _gap(4),
              _buildKey(ctrl, isDark, 'KeyB', 'B', width: 36),
              _gap(4),
              _buildKey(ctrl, isDark, 'KeyN', 'N', width: 36),
              _gap(4),
              _buildKey(ctrl, isDark, 'KeyM', 'M', width: 36),
              _gap(4),
              _buildKey(ctrl, isDark, 'Comma', ',', width: 36),
              _gap(4),
              _buildKey(ctrl, isDark, 'Period', '.', width: 36),
              _gap(4),
              _buildKey(ctrl, isDark, 'Slash', '/', width: 36),
              _gap(4),
              _buildKey(ctrl, isDark, 'ShiftRight', 'Shift ⇧', width: 102),
            ],
          ),
          _vGap(5),

          // Row 5: Modifiers Row (Ctrl Win Alt Space Alt Menu Ctrl)
          Row(
            children: [
              _buildKey(ctrl, isDark, 'ControlLeft', 'Ctrl', width: 46),
              _gap(4),
              _buildKey(ctrl, isDark, 'MetaLeft', 'Win', width: 42),
              _gap(4),
              _buildKey(ctrl, isDark, 'AltLeft', 'Alt', width: 42),
              _gap(4),
              _buildKey(ctrl, isDark, 'Space', 'Space', width: 308),
              _gap(4),
              _buildKey(ctrl, isDark, 'AltRight', 'Alt', width: 42),
              _gap(4),
              _buildKey(ctrl, isDark, 'ContextMenu', 'Menu', width: 42),
              _gap(4),
              _buildKey(ctrl, isDark, 'ControlRight', 'Ctrl', width: 46),
            ],
          ),
        ],
      ),
    );
  }

  // --- CLUSTER 2: NAVIGATION CLUSTER (Width = 116px) ---
  Widget _buildNavCluster(HardwareTestController ctrl, bool isDark) {
    return SizedBox(
      width: 116,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 0: PrtSc, ScrLk, Pause
          Row(
            children: [
              _buildKey(ctrl, isDark, 'PrintScreen', 'PrtSc', width: 36),
              _gap(4),
              _buildKey(ctrl, isDark, 'ScrollLock', 'ScrLk', width: 36),
              _gap(4),
              _buildKey(ctrl, isDark, 'Pause', 'Pause', width: 36),
            ],
          ),
          _vGap(10),

          // Row 1: Ins, Home, PgUp
          Row(
            children: [
              _buildKey(ctrl, isDark, 'Insert', 'Ins', width: 36),
              _gap(4),
              _buildKey(ctrl, isDark, 'Home', 'Home', width: 36),
              _gap(4),
              _buildKey(ctrl, isDark, 'PageUp', 'PgUp', width: 36),
            ],
          ),
          _vGap(5),

          // Row 2: Del, End, PgDn
          Row(
            children: [
              _buildKey(ctrl, isDark, 'Delete', 'Del', width: 36),
              _gap(4),
              _buildKey(ctrl, isDark, 'End', 'End', width: 36),
              _gap(4),
              _buildKey(ctrl, isDark, 'PageDown', 'PgDn', width: 36),
            ],
          ),
          _vGap(5),

          // Row 3: Spacer
          const SizedBox(width: 116, height: 36),
          _vGap(5),

          // Row 4: Arrow Up (centered)
          Row(
            children: [
              _gap(40),
              _buildKey(ctrl, isDark, 'ArrowUp', '▲', width: 36),
              _gap(40),
            ],
          ),
          _vGap(5),

          // Row 5: Arrow Left, Down, Right
          Row(
            children: [
              _buildKey(ctrl, isDark, 'ArrowLeft', '◀', width: 36),
              _gap(4),
              _buildKey(ctrl, isDark, 'ArrowDown', '▼', width: 36),
              _gap(4),
              _buildKey(ctrl, isDark, 'ArrowRight', '▶', width: 36),
            ],
          ),
        ],
      ),
    );
  }

  // --- CLUSTER 3: NUMPAD CLUSTER (Width = 156px) ---
  Widget _buildNumpadCluster(HardwareTestController ctrl, bool isDark) {
    return SizedBox(
      width: 156,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 0: LED Indicator Plate
          _buildNumpadLedPanel(ctrl, isDark),
          _vGap(10),

          // Row 1: NumLock, /, *, -
          Row(
            children: [
              _buildKey(ctrl, isDark, 'NumLock', 'Num', width: 36),
              _gap(4),
              _buildKey(ctrl, isDark, 'NumpadDivide', '/', width: 36),
              _gap(4),
              _buildKey(ctrl, isDark, 'NumpadMultiply', '*', width: 36),
              _gap(4),
              _buildKey(ctrl, isDark, 'NumpadSubtract', '-', width: 36),
            ],
          ),
          _vGap(5),

          // Rows 2-5: Decoupled columns preventing tall keys from expanding rows
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left sub-column: 3 standard key columns (width: 116)
              SizedBox(
                width: 116,
                child: Column(
                  children: [
                    // Row 2: 7, 8, 9
                    Row(
                      children: [
                        _buildKey(ctrl, isDark, 'Numpad7', '7', width: 36),
                        _gap(4),
                        _buildKey(ctrl, isDark, 'Numpad8', '8', width: 36),
                        _gap(4),
                        _buildKey(ctrl, isDark, 'Numpad9', '9', width: 36),
                      ],
                    ),
                    _vGap(5),

                    // Row 3: 4, 5, 6
                    Row(
                      children: [
                        _buildKey(ctrl, isDark, 'Numpad4', '4', width: 36),
                        _gap(4),
                        _buildKey(ctrl, isDark, 'Numpad5', '5', width: 36),
                        _gap(4),
                        _buildKey(ctrl, isDark, 'Numpad6', '6', width: 36),
                      ],
                    ),
                    _vGap(5),

                    // Row 4: 1, 2, 3
                    Row(
                      children: [
                        _buildKey(ctrl, isDark, 'Numpad1', '1', width: 36),
                        _gap(4),
                        _buildKey(ctrl, isDark, 'Numpad2', '2', width: 36),
                        _gap(4),
                        _buildKey(ctrl, isDark, 'Numpad3', '3', width: 36),
                      ],
                    ),
                    _vGap(5),

                    // Row 5: 0 (wide), .
                    Row(
                      children: [
                        _buildKey(ctrl, isDark, 'Numpad0', '0', width: 76),
                        _gap(4),
                        _buildKey(ctrl, isDark, 'NumpadDecimal', '.', width: 36),
                      ],
                    ),
                  ],
                ),
              ),
              _gap(4),

              // Right sub-column: Tall keys + and Enter (width: 36)
              SizedBox(
                width: 36,
                child: Column(
                  children: [
                    _buildKey(ctrl, isDark, 'NumpadAdd', '+', width: 36, height: 77),
                    _vGap(5),
                    _buildKey(ctrl, isDark, 'NumpadEnter', '↵', width: 36, height: 77),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- NUMPAD LED INDICATOR PANEL ---
  Widget _buildNumpadLedPanel(HardwareTestController ctrl, bool isDark) {
    return Obx(() {
      final numActive = ctrl.testedKeys.contains('NumLock');
      final capsActive = ctrl.testedKeys.contains('CapsLock');
      final scrollActive = ctrl.testedKeys.contains('ScrollLock');

      return Container(
        width: 156,
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFF334155),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: const Color(0xFF334155),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildLedItem('NUM', numActive),
            _buildLedItem('CAPS', capsActive),
            _buildLedItem('SCR', scrollActive),
          ],
        ),
      );
    });
  }

  Widget _buildLedItem(String label, bool isActive) {
    final ledColor = isActive ? const Color(0xFF10B981) : const Color(0xFF475569);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(
            color: ledColor,
            shape: BoxShape.circle,
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: const Color(0xFF10B981).withValues(alpha: 0.8),
                      blurRadius: 5,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            fontFamily: 'monospace',
            color: isActive ? const Color(0xFF10B981) : const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  // --- TACTILE 3D KEYCAP WIDGET ---
  Widget _buildKey(
    HardwareTestController ctrl,
    bool isDark,
    String code,
    String label, {
    double width = 36,
    double height = 36,
  }) {
    return Obx(() {
      final isDown = ctrl.activeKeys.contains(code);
      final isTested = ctrl.testedKeys.contains(code);

      final LinearGradient gradient;
      final Border border;
      final List<BoxShadow> shadows;
      final Color textColor;
      final FontWeight fontWeight;

      if (isDown) {
        // Pressed State: Electric Blue with bright glow & recessed bevel
        gradient = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF60A5FA), Color(0xFF2563EB)],
        );
        border = Border.all(
          color: const Color(0xFF93C5FD),
          width: 1.5,
        );
        shadows = [
          BoxShadow(
            color: const Color(0xFF3B82F6).withValues(alpha: 0.85),
            blurRadius: 14,
            spreadRadius: 1,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            offset: const Offset(0, 1),
            blurRadius: 2,
          ),
        ];
        textColor = Colors.white;
        fontWeight = FontWeight.w900;
      } else if (isTested) {
        // Tested State: Permanent Emerald Green with subtle confirmed glow & 3D bottom bevel
        gradient = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF10B981), Color(0xFF059669)],
        );
        border = Border.all(
          color: const Color(0xFF34D399),
          width: 1.2,
        );
        shadows = [
          // 3D bottom bevel lip
          const BoxShadow(
            color: Color(0xFF047857),
            offset: Offset(0, 2),
            blurRadius: 0,
          ),
          // Subtle confirmed emerald glow
          BoxShadow(
            color: const Color(0xFF10B981).withValues(alpha: 0.35),
            offset: const Offset(0, 2),
            blurRadius: 6,
          ),
        ];
        textColor = Colors.white;
        fontWeight = FontWeight.w800;
      } else {
        // Untested State: 3D Raised Physical Keycap (Top highlight + Bottom bevel shadow)
        gradient = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? const [Color(0xFF334155), Color(0xFF1E293B)]
              : const [Color(0xFFFFFFFF), Color(0xFFE2E8F0)],
        );
        border = Border.all(
          color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
          width: 1.0,
        );
        shadows = [
          // 3D bottom shelf / bevel lip (unblurred for crisp physical keycap edge)
          BoxShadow(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
            offset: const Offset(0, 2.5),
            blurRadius: 0,
          ),
          // Ambient drop shadow beneath the keycap
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.40 : 0.10),
            offset: const Offset(0, 3.5),
            blurRadius: 3.5,
          ),
        ];
        textColor = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155);
        fontWeight = FontWeight.w700;
      }

      final double fontSize = label.length > 5
          ? 9.5
          : label.length > 3
              ? 10.5
              : 11.5;

      return GestureDetector(
        onTapDown: (_) => ctrl.onKeyDown(code, label),
        onTapUp: (_) => ctrl.onKeyUp(code),
        onTapCancel: () => ctrl.onKeyUp(code),
        child: AnimatedScale(
          scale: isDown ? 0.92 : 1.0,
          duration: const Duration(milliseconds: 60),
          curve: Curves.easeOutQuad,
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              gradient: gradient,
              border: border,
              borderRadius: BorderRadius.circular(6),
              boxShadow: shadows,
            ),
            child: Center(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: fontWeight,
                  color: textColor,
                  fontFamily: 'monospace',
                  letterSpacing: -0.2,
                  shadows: isDown
                      ? [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 2,
                          ),
                        ]
                      : null,
                ),
              ),
            ),
          ),
        ),
      );
    });
  }

  // --- COMPACT BOTTOM STATUS BAR ---
  Widget _buildBottomStatusBar(HardwareTestController ctrl, bool isDark) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            offset: const Offset(0, -2),
            blurRadius: 6,
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 700;
          final isNarrow = constraints.maxWidth < 500;
          final isUltraNarrow = constraints.maxWidth < 380;

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 1. Last Key Pressed Indicator (Flexible so it shrinks gracefully)
              Flexible(
                flex: isNarrow ? 1 : 2,
                fit: FlexFit.loose,
                child: Obx(() {
                  final label = ctrl.lastKeyLabel.value;
                  final code = ctrl.lastKeyCode.value;
                  final hasKey = code != '-';
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: hasKey ? const Color(0xFF3B82F6) : const Color(0xFF64748B),
                          shape: BoxShape.circle,
                          boxShadow: hasKey
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF3B82F6).withValues(alpha: 0.6),
                                    blurRadius: 6,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                      if (!isNarrow) ...[
                        const SizedBox(width: 8),
                        Text(
                          'آخرین کلید: ',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                          ),
                        ),
                      ] else
                        const SizedBox(width: 6),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: const Color(0xFF3B82F6).withValues(alpha: 0.35),
                            ),
                          ),
                          child: Text(
                            hasKey ? '$label ($code)' : '-',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'monospace',
                              color: Color(0xFF3B82F6),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ),

              const SizedBox(width: 8),

              // 2. Center Progress Bar & Counter
              Obx(() {
                final count = ctrl.testedKeys.length;
                final progress = (count / 105.0).clamp(0.0, 1.0);
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isCompact) ...[
                      SizedBox(
                        width: 90,
                        height: 6,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: progress,
                            backgroundColor: const Color(0xFF334155),
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      isCompact ? '$count / 105' : '$count / 105 کلید',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'monospace',
                        color: Color(0xFF10B981),
                      ),
                    ),
                  ],
                );
              }),

              const SizedBox(width: 8),

              // 3. Compact Pass / Fail evaluation buttons
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FilledButton.icon(
                    onPressed: () {
                      final testedCount = ctrl.testedKeys.length;
                      ctrl.recordResult(
                        testName: 'تست کیبورد و دکمه‌ها',
                        status: 'passed',
                        details: '$testedCount کلید فیزیکی آزمایش شد؛ عملکرد کلیدها بدون گیرکردن تأیید گردید.',
                      );
                      Get.snackbar(
                        'ثبت شد',
                        'سلامت کیبورد در کارنامه ثبت شد.',
                        snackPosition: SnackPosition.BOTTOM,
                        backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.9),
                        colorText: Colors.white,
                        duration: const Duration(seconds: 2),
                      );
                    },
                    icon: const Icon(Icons.check_rounded, size: 14),
                    label: Text(
                      isUltraNarrow ? '' : (isNarrow ? 'تأیید' : 'تأیید سلامت'),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: isUltraNarrow ? 8 : (isNarrow ? 8 : 10),
                        vertical: 6,
                      ),
                      minimumSize: const Size(0, 32),
                    ),
                  ),
                  const SizedBox(width: 6),
                  OutlinedButton.icon(
                    onPressed: () {
                      ctrl.recordResult(
                        testName: 'تست کیبورد و دکمه‌ها',
                        status: 'failed',
                        details: 'یک یا چند کلید کار نمی‌کند، گیر دارد یا کد نادرست به سیستم گزارش می‌دهد.',
                      );
                      Get.snackbar(
                        'ثبت شد',
                        'ایراد کیبورد در کارنامه ثبت شد.',
                        snackPosition: SnackPosition.BOTTOM,
                        backgroundColor: const Color(0xFFEF4444).withValues(alpha: 0.9),
                        colorText: Colors.white,
                        duration: const Duration(seconds: 2),
                      );
                    },
                    icon: const Icon(Icons.close_rounded, size: 14),
                    label: Text(
                      isUltraNarrow ? '' : (isNarrow ? 'ایراد' : 'ثبت ایراد'),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFEF4444),
                      side: const BorderSide(color: Color(0xFFEF4444)),
                      padding: EdgeInsets.symmetric(
                        horizontal: isUltraNarrow ? 8 : (isNarrow ? 8 : 10),
                        vertical: 6,
                      ),
                      minimumSize: const Size(0, 32),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  // --- HELPER SPACERS ---
  Widget _gap(double width) => SizedBox(width: width);
  Widget _vGap(double height) => SizedBox(height: height);
}
