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
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Navigation Breadcrumb
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () => ctrl.selectSubTest('hub'),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                  label: const Text('بازگشت به لیست تست‌ها'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
                const SizedBox(width: 14),
                Text(
                  'تست کیبورد و تشخیص سلامت کلیدها',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                  ),
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: () => ctrl.resetKeyboard(),
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('شروع از ابتدا'),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Status & Counter Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Obx(() {
                      final label = ctrl.lastKeyLabel.value;
                      final code = ctrl.lastKeyCode.value;
                      return Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: Color(0xFF10B981),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'آخرین کلید شناسایی‌شده: ',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3B82F6).withValues(alpha: isDark ? 0.2 : 0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.4)),
                            ),
                            child: Text(
                              '$label ($code)',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'monospace',
                                color: Color(0xFF3B82F6),
                              ),
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                  // Progress Count
                  Obx(() {
                    final testedCount = ctrl.testedKeys.length;
                    return Row(
                      children: [
                        Text(
                          '$testedCount / 105',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'monospace',
                            color: Color(0xFF10B981),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text('کلید تست‌شده', style: TextStyle(fontSize: 12)),
                      ],
                    );
                  }),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // 105-Key Visual Keyboard Board
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Row 0: Esc + F1..F12 + PrtSc..Pause
                      _buildRow([
                        _key('Escape', 'Esc', width: 44),
                        _gap(20),
                        _key('F1', 'F1'),
                        _key('F2', 'F2'),
                        _key('F3', 'F3'),
                        _key('F4', 'F4'),
                        _gap(16),
                        _key('F5', 'F5'),
                        _key('F6', 'F6'),
                        _key('F7', 'F7'),
                        _key('F8', 'F8'),
                        _gap(16),
                        _key('F9', 'F9'),
                        _key('F10', 'F10'),
                        _key('F11', 'F11'),
                        _key('F12', 'F12'),
                        _gap(20),
                        _key('PrintScreen', 'PrtSc'),
                        _key('ScrollLock', 'ScrLk'),
                        _key('Pause', 'Pause'),
                      ]),
                      const SizedBox(height: 8),

                      // Row 1: ` 1..0 - = Backspace | Ins Home PgUp | Num / * -
                      _buildRow([
                        _key('Backquote', '`'),
                        _key('Digit1', '1'),
                        _key('Digit2', '2'),
                        _key('Digit3', '3'),
                        _key('Digit4', '4'),
                        _key('Digit5', '5'),
                        _key('Digit6', '6'),
                        _key('Digit7', '7'),
                        _key('Digit8', '8'),
                        _key('Digit9', '9'),
                        _key('Digit0', '0'),
                        _key('Minus', '-'),
                        _key('Equal', '='),
                        _key('Backspace', '← Backspace', width: 72),
                        _gap(20),
                        _key('Insert', 'Ins'),
                        _key('Home', 'Home'),
                        _key('PageUp', 'PgUp'),
                        _gap(20),
                        _key('NumLock', 'Num'),
                        _key('NumpadDivide', '/'),
                        _key('NumpadMultiply', '*'),
                        _key('NumpadSubtract', '-'),
                      ]),
                      const SizedBox(height: 6),

                      // Row 2: Tab QWERTY [ ] \ | Del End PgDn | 7 8 9 +
                      _buildRow([
                        _key('Tab', 'Tab', width: 56),
                        _key('KeyQ', 'Q'),
                        _key('KeyW', 'W'),
                        _key('KeyE', 'E'),
                        _key('KeyR', 'R'),
                        _key('KeyT', 'T'),
                        _key('KeyY', 'Y'),
                        _key('KeyU', 'U'),
                        _key('KeyI', 'I'),
                        _key('KeyO', 'O'),
                        _key('KeyP', 'P'),
                        _key('BracketLeft', '['),
                        _key('BracketRight', ']'),
                        _key('Backslash', '\\', width: 44),
                        _gap(20),
                        _key('Delete', 'Del'),
                        _key('End', 'End'),
                        _key('PageDown', 'PgDn'),
                        _gap(20),
                        _key('Numpad7', '7'),
                        _key('Numpad8', '8'),
                        _key('Numpad9', '9'),
                        _key('NumpadAdd', '+', height: 74),
                      ]),
                      const SizedBox(height: 6),

                      // Row 3: Caps ASDF Enter | 4 5 6
                      _buildRow([
                        _key('CapsLock', 'Caps', width: 64),
                        _key('KeyA', 'A'),
                        _key('KeyS', 'S'),
                        _key('KeyD', 'D'),
                        _key('KeyF', 'F'),
                        _key('KeyG', 'G'),
                        _key('KeyH', 'H'),
                        _key('KeyJ', 'J'),
                        _key('KeyK', 'K'),
                        _key('KeyL', 'L'),
                        _key('Semicolon', ';'),
                        _key('Quote', '\''),
                        _key('Enter', 'Enter ↵', width: 78),
                        _gap(140),
                        _key('Numpad4', '4'),
                        _key('Numpad5', '5'),
                        _key('Numpad6', '6'),
                      ]),
                      const SizedBox(height: 6),

                      // Row 4: Shift ZXCV Shift | ArrowUp | 1 2 3 Enter
                      _buildRow([
                        _key('ShiftLeft', 'Shift ⇧', width: 80),
                        _key('KeyZ', 'Z'),
                        _key('KeyX', 'X'),
                        _key('KeyC', 'C'),
                        _key('KeyV', 'V'),
                        _key('KeyB', 'B'),
                        _key('KeyN', 'N'),
                        _key('KeyM', 'M'),
                        _key('Comma', ','),
                        _key('Period', '.'),
                        _key('Slash', '/'),
                        _key('ShiftRight', 'Shift ⇧', width: 94),
                        _gap(58),
                        _key('ArrowUp', '▲'),
                        _gap(58),
                        _key('Numpad1', '1'),
                        _key('Numpad2', '2'),
                        _key('Numpad3', '3'),
                        _key('NumpadEnter', '↵', height: 74),
                      ]),
                      const SizedBox(height: 6),

                      // Row 5: Ctrl Win Alt Space Alt Menu Ctrl | ArrowLeft ArrowDown ArrowRight | 0 .
                      _buildRow([
                        _key('ControlLeft', 'Ctrl', width: 48),
                        _key('MetaLeft', 'Win', width: 44),
                        _key('AltLeft', 'Alt', width: 44),
                        _key('Space', 'Space', width: 220),
                        _key('AltRight', 'Alt', width: 44),
                        _key('ContextMenu', 'Menu', width: 44),
                        _key('ControlRight', 'Ctrl', width: 48),
                        _gap(20),
                        _key('ArrowLeft', '◀'),
                        _key('ArrowDown', '▼'),
                        _key('ArrowRight', '▶'),
                        _gap(20),
                        _key('Numpad0', '0', width: 74),
                        _key('NumpadDecimal', '.'),
                      ]),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Legend
            Row(
              children: [
                _buildLegendItem(const Color(0xFF10B981), 'تست‌شده (سالم)'),
                const SizedBox(width: 16),
                _buildLegendItem(const Color(0xFF3B82F6), 'در حال فشردن'),
                const SizedBox(width: 16),
                _buildLegendItem(Colors.grey.shade400, 'بررسی‌نشده'),
              ],
            ),

            const SizedBox(height: 16),

            // Evaluation Row
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ثبت نتیجه تست کیبورد',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'آیا تمام کلیدهای مدنظر بدون گیرکردن یا ثبت نشدن به‌درستی واکنش نشان دادند؟',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      final testedCount = ctrl.testedKeys.length;
                      ctrl.recordResult(
                        testName: 'تست کیبورد (۱۰۵ کلید)',
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
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: const Text('کلیدها کاملاً سالم هستند (موفق)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: () {
                      ctrl.recordResult(
                        testName: 'تست کیبورد (۱۰۵ کلید)',
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
                    icon: const Icon(Icons.error_outline_rounded, size: 16),
                    label: const Text('ایراد در کلیدها'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFEF4444),
                      side: const BorderSide(color: Color(0xFFEF4444)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(List<Widget> children) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  Widget _gap(double width) => SizedBox(width: width);

  Widget _key(String code, String label, {double width = 34, double height = 34}) {
    final ctrl = Get.find<HardwareTestController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Obx(() {
      final isDown = ctrl.activeKeys.contains(code);
      final isTested = ctrl.testedKeys.contains(code);

      Color bgColor = isDark ? const Color(0xFF1E293B) : Colors.white;
      Color textColor = isDark ? Colors.white : Colors.black87;
      Color borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);

      if (isDown) {
        bgColor = const Color(0xFF3B82F6);
        textColor = Colors.white;
        borderColor = const Color(0xFF60A5FA);
      } else if (isTested) {
        bgColor = const Color(0xFF10B981);
        textColor = Colors.white;
        borderColor = const Color(0xFF34D399);
      }

      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: borderColor, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
              offset: const Offset(0, 1.5),
              blurRadius: 2,
            ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: textColor,
              fontFamily: 'monospace',
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    });
  }

  Widget _buildLegendItem(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 5),
        Text(text, style: const TextStyle(fontSize: 11.5)),
      ],
    );
  }
}
