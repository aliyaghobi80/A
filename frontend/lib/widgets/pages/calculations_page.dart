import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';
import 'package:intl/intl.dart';

// --- Formatters ---

class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  static const separator = ',';

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    String newValueText = newValue.text.replaceAll(separator, '');
    
    // Only allow numbers and optionally a dot
    if (newValueText == '.' || newValueText == '-' || newValueText == '-.') return newValue;
    
    final int selectionIndex = newValue.selection.end;
    
    // Calculate the number of commas in the original string before cursor
    int commasBeforeCursor = 0;
    for (int i = 0; i < oldValue.selection.end && i < oldValue.text.length; i++) {
      if (oldValue.text[i] == separator) {
        commasBeforeCursor++;
      }
    }
    
    // Check if we are deleting a comma
    if (oldValue.text.length > newValue.text.length && 
        selectionIndex < oldValue.text.length &&
        oldValue.text[selectionIndex] == separator) {
      // It's handled naturally by just recreating the string
    }

    try {
      final parts = newValueText.split('.');
      String integerPart = parts[0];
      String formattedInteger = '';
      
      bool isNegative = integerPart.startsWith('-');
      if (isNegative) {
        integerPart = integerPart.substring(1);
      }

      for (int i = integerPart.length - 1; i >= 0; i--) {
        formattedInteger = integerPart[i] + formattedInteger;
        if ((integerPart.length - i) % 3 == 0 && i != 0) {
          formattedInteger = separator + formattedInteger;
        }
      }
      
      if (isNegative) {
        formattedInteger = '-\$formattedInteger';
      }

      String finalString = formattedInteger;
      if (parts.length > 1) {
        finalString += '.\${parts[1]}';
      } else if (newValueText.endsWith('.')) {
        finalString += '.';
      }

      // Calculate new cursor position
      int newCommasBeforeCursor = 0;
      int charCount = 0;
      int newCursorPosition = 0;
      
      int targetChars = selectionIndex - commasBeforeCursor;
      
      for (int i = 0; i < finalString.length; i++) {
        if (charCount == targetChars) {
          newCursorPosition = i;
          break;
        }
        if (finalString[i] != separator) {
          charCount++;
        }
      }
      
      if (charCount < targetChars) {
        newCursorPosition = finalString.length;
      }

      return TextEditingValue(
        text: finalString,
        selection: TextSelection.collapsed(offset: newCursorPosition),
      );
    } catch (e) {
      return oldValue;
    }
  }
}

// --- Main Page ---

class CalculationsPage extends StatefulWidget {
  const CalculationsPage({super.key});

  @override
  State<CalculationsPage> createState() => _CalculationsPageState();
}

class _CalculationsPageState extends State<CalculationsPage> {
  // 0: Dashboard, 1: Game Price, 2: Partition
  int _currentView = 0; 

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              children: [
                if (_currentView != 0) ...[
                  IconButton(
                    icon: Icon(Icons.arrow_back_rounded, color: isDark ? Colors.white : Colors.black87),
                    onPressed: () => setState(() => _currentView = 0),
                    tooltip: 'بازگشت به منوی محاسبات',
                  ),
                  const SizedBox(width: 8),
                ],
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currentView == 0 
                          ? 'محاسبات و ابزارها' 
                          : _currentView == 1 
                              ? 'محاسبه قیمت بازی (حجمی)' 
                              : 'محاسبه پارتیشن‌بندی',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'ابزارهای محاسبه سریع برای فروشگاه',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _currentView == 0
                  ? _buildDashboard(isDark)
                  : _currentView == 1
                      ? const GamePriceCalculatorView()
                      : const PartitionCalculatorView(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
      child: Wrap(
        spacing: 24,
        runSpacing: 24,
        children: [
          _buildToolCard(
            title: 'محاسبه قیمت بازی',
            description: 'محاسبه قیمت فروش بازی بر اساس حجم کل بازی‌های انتخابی مشتری',
            icon: Icons.sports_esports_rounded,
            color: const Color(0xFF0D9488),
            isDark: isDark,
            onTap: () => setState(() => _currentView = 1),
          ),
          _buildToolCard(
            title: 'محاسبه پارتیشن‌بندی',
            description: 'محاسبه دقیق مگابایت برای درایو C و سایر درایوها جهت نصب ویندوز',
            icon: Icons.data_usage_rounded,
            color: const Color(0xFF6366F1),
            isDark: isDark,
            onTap: () => setState(() => _currentView = 2),
          ),
        ],
      ),
    );
  }

  Widget _buildToolCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return ToolCard(
      title: title,
      description: description,
      icon: icon,
      color: color,
      isDark: isDark,
      onTap: onTap,
    );
  }
}

// --- Game Price View ---

class GamePriceCalculatorView extends StatefulWidget {
  const GamePriceCalculatorView({super.key});

  @override
  State<GamePriceCalculatorView> createState() => _GamePriceCalculatorViewState();
}

class _GamePriceCalculatorViewState extends State<GamePriceCalculatorView> {
  final TextEditingController _gameSizeCtrl = TextEditingController();
  final TextEditingController _baseSizeCtrl = TextEditingController(text: '50');
  final TextEditingController _basePriceCtrl = TextEditingController(text: '300,000');

  String _totalPrice = '۰';

  @override
  void dispose() {
    _gameSizeCtrl.dispose();
    _baseSizeCtrl.dispose();
    _basePriceCtrl.dispose();
    super.dispose();
  }

  void _calculatePrice() {
    final double? gameSize = double.tryParse(_gameSizeCtrl.text.replaceAll(',', ''));
    final double? baseSize = double.tryParse(_baseSizeCtrl.text.replaceAll(',', ''));
    final double? basePrice = double.tryParse(_basePriceCtrl.text.replaceAll(',', ''));

    if (gameSize != null && baseSize != null && baseSize > 0 && basePrice != null) {
      final double total = (gameSize / baseSize) * basePrice;
      
      final format = NumberFormat.decimalPattern('en');
      setState(() {
        _totalPrice = format.format(total);
      });
    } else {
      setState(() {
        _totalPrice = '۰';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildInputField(
                    label: 'حجم کل بازی‌ها (گیگابایت)',
                    controller: _gameSizeCtrl,
                    isDark: isDark,
                    hint: 'مثلاً 120',
                    autoFocus: true,
                    onChanged: (_) => _calculatePrice(),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildInputField(
                    label: 'حجم پایه فروش (گیگ)',
                    controller: _baseSizeCtrl,
                    isDark: isDark,
                    hint: 'مثلاً 50',
                    onChanged: (_) => _calculatePrice(),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildInputField(
                    label: 'قیمت پایه (تومان)',
                    controller: _basePriceCtrl,
                    isDark: isDark,
                    hint: 'مثلاً 300,000',
                    onChanged: (_) => _calculatePrice(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF0D9488).withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'مبلغ قابل پرداخت:',
                    style: TextStyle(
                      fontSize: 16,
                      color: isDark ? Colors.grey[400] : Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _totalPrice,
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0D9488),
                          letterSpacing: 2.0,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8.0),
                        child: Text(
                          'تومان',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0D9488),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Partition View ---

class PartitionCalculatorView extends StatefulWidget {
  const PartitionCalculatorView({super.key});

  @override
  State<PartitionCalculatorView> createState() => _PartitionCalculatorViewState();
}

class _PartitionCalculatorViewState extends State<PartitionCalculatorView> {
  final TextEditingController _totalDiskCtrl = TextEditingController(text: '500');
  final TextEditingController _cDriveSizeCtrl = TextEditingController(text: '150');
  final TextEditingController _otherPartitionsCtrl = TextEditingController(text: '2');

  String _cDriveMB = '153600';
  String _otherDriveMB = '0';
  String _actualTotalGB = '465.6'; // Estimated usable space
  bool _hasError = false;
  String _errorMsg = '';

  @override
  void initState() {
    super.initState();
    _calculatePartitions();
  }

  @override
  void dispose() {
    _totalDiskCtrl.dispose();
    _cDriveSizeCtrl.dispose();
    _otherPartitionsCtrl.dispose();
    super.dispose();
  }

  void _calculatePartitions() {
    setState(() {
      _hasError = false;
      _errorMsg = '';
    });

    final double? totalDisk = double.tryParse(_totalDiskCtrl.text.replaceAll(',', ''));
    final double? cDriveGB = double.tryParse(_cDriveSizeCtrl.text.replaceAll(',', ''));
    final int? otherCount = int.tryParse(_otherPartitionsCtrl.text.replaceAll(',', ''));

    if (totalDisk == null || cDriveGB == null || otherCount == null) {
      return;
    }

    // Windows setup uses 1 GB = 1024 MB
    // A 500GB drive sold by manufacturers is 500 * 10^9 bytes.
    // Usable capacity in GiB (what Windows reports) = (500 * 10^9) / (1024^3) ≈ 465.66 GiB
    final double realTotalGB = (totalDisk * 1000 * 1000 * 1000) / (1024 * 1024 * 1024);
    _actualTotalGB = realTotalGB.toStringAsFixed(1);
    
    // In MB, Windows setup uses MiB
    final double realTotalMB = realTotalGB * 1024;
    final double cDriveMB = cDriveGB * 1024; // e.g. 150 * 1024 = 153600 MB
    
    if (cDriveMB >= realTotalMB) {
      setState(() {
        _hasError = true;
        _errorMsg = 'حجم درایو C نمی‌تواند از کل حجم قابل استفاده بیشتر باشد.';
        _cDriveMB = cDriveMB.toStringAsFixed(0);
        _otherDriveMB = '0';
      });
      return;
    }

    final double remainingMB = realTotalMB - cDriveMB;
    
    double otherDriveMB = 0;
    if (otherCount > 0) {
      otherDriveMB = remainingMB / otherCount;
    }

    setState(() {
      _cDriveMB = cDriveMB.toStringAsFixed(0);
      _otherDriveMB = otherDriveMB.toStringAsFixed(0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: Color(0xFF6366F1)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'نکته: حجم اسمی هارد (مثلاً 500 گیگ) به دلیل تفاوت در سیستم‌های محاسبه‌ای (ده‌دهی در برابر دودویی) در ویندوز کمتر نمایش داده می‌شود. این ابزار به صورت خودکار حجم واقعی (مثلاً حدود 465 گیگ برای یک هارد 500) را در نظر می‌گیرد.',
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.5,
                        color: isDark ? Colors.grey[300] : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildInputField(
                    label: 'حجم اسمی کل دیسک (گیگابایت)',
                    controller: _totalDiskCtrl,
                    isDark: isDark,
                    hint: '500, 1000, 2000...',
                    autoFocus: true,
                    onChanged: (_) => _calculatePartitions(),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildInputField(
                    label: 'حجم درایو C (گیگابایت)',
                    controller: _cDriveSizeCtrl,
                    isDark: isDark,
                    hint: '150',
                    onChanged: (_) => _calculatePartitions(),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildInputField(
                    label: 'تعداد پارتیشن‌های باقی‌مانده (D, E...)',
                    controller: _otherPartitionsCtrl,
                    isDark: isDark,
                    hint: '2, 3...',
                    onChanged: (_) => _calculatePartitions(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'حجم واقعی و قابل استفاده هارد شما در ویندوز تقریباً \$_actualTotalGB گیگابایت است.',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6366F1),
                ),
              ),
            ),
            const SizedBox(height: 32),
            
            if (_hasError)
              Container(
                margin: const EdgeInsets.only(bottom: 24),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444)),
                    const SizedBox(width: 12),
                    Text(
                      _errorMsg,
                      style: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),

            // Results Row
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _buildResultCard(
                    title: 'حجم مگابایت درایو C',
                    value: _cDriveMB,
                    color: const Color(0xFF0D9488),
                    isDark: isDark,
                    context: context,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 3,
                  child: _buildResultCard(
                    title: 'حجم مگابایت برای سایر درایوها (هر کدام)',
                    value: _otherDriveMB,
                    color: const Color(0xFF3B82F6),
                    isDark: isDark,
                    context: context,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard({
    required String title,
    required String value,
    required Color color,
    required bool isDark,
    required BuildContext context,
  }) {
    final format = NumberFormat.decimalPattern('en');
    String formattedValue = '0';
    try {
      formattedValue = format.format(int.parse(value));
    } catch (_) {}

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.1 : 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey[300] : Colors.grey[700],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formattedValue,
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: color,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 6.0),
                child: Text(
                  'MB',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: value != '0' ? () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('عدد \$value با موفقیت کپی شد'),
                  backgroundColor: color,
                  duration: const Duration(seconds: 2),
                ),
              );
            } : null,
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('کپی دقیق عدد'),
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}

// --- Shared Input Builder ---

Widget _buildInputField({
  required String label,
  required TextEditingController controller,
  required bool isDark,
  String? hint,
  bool autoFocus = false,
  void Function(String)? onChanged,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.grey[300] : Colors.grey[700],
        ),
      ),
      const SizedBox(height: 8),
      Directionality(
        textDirection: ui.TextDirection.ltr,
        child: TextField(
          controller: controller,
          autofocus: autoFocus,
          textAlign: TextAlign.center,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ThousandsSeparatorInputFormatter(),
          ],
          onChanged: onChanged,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
            color: isDark ? Colors.white : Colors.black87,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: isDark ? Colors.grey[600] : Colors.grey[400],
              letterSpacing: 0,
            ),
            filled: true,
            fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
              ),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(10)),
              borderSide: BorderSide(
                color: Color(0xFF0D9488),
                width: 2,
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

class ToolCard extends StatefulWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const ToolCard({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<ToolCard> createState() => _ToolCardState();
}

class _ToolCardState extends State<ToolCard> with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => _controller.forward(),
        onTapUp: (_) {
          _controller.reverse();
          widget.onTap();
        },
        onTapCancel: () => _controller.reverse(),
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _isHovered ? (_scaleAnimation.value + 0.02) : _scaleAnimation.value,
              child: child,
            );
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 320,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: widget.isDark ? AppTheme.darkCard : AppTheme.lightCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _isHovered 
                  ? widget.color.withValues(alpha: 0.5) 
                  : (widget.isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
              ),
              boxShadow: _isHovered
                  ? [
                      // Neomorphic-style glowing shadow on hover
                      BoxShadow(
                        color: widget.color.withValues(alpha: widget.isDark ? 0.3 : 0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: widget.isDark ? 0.4 : 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: widget.isDark ? 0.2 : 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: widget.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    widget.icon,
                    color: widget.color,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: widget.isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.description,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: widget.isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

