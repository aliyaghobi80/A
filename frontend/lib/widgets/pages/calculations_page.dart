import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';
import 'package:intl/intl.dart';

class CalculationsPage extends StatefulWidget {
  const CalculationsPage({super.key});

  @override
  State<CalculationsPage> createState() => _CalculationsPageState();
}

class _CalculationsPageState extends State<CalculationsPage> {
  final TextEditingController _gameSizeCtrl = TextEditingController();
  final TextEditingController _baseSizeCtrl = TextEditingController(text: '50');
  final TextEditingController _basePriceCtrl = TextEditingController(text: '300000');

  String _totalPrice = '۰';

  @override
  void dispose() {
    _gameSizeCtrl.dispose();
    _baseSizeCtrl.dispose();
    _basePriceCtrl.dispose();
    super.dispose();
  }

  void _calculatePrice() {
    final double? gameSize = double.tryParse(_gameSizeCtrl.text);
    final double? baseSize = double.tryParse(_baseSizeCtrl.text);
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'محاسبات و ابزارها',
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
            const SizedBox(height: 32),
            
            // Game Price Calculator Card
            Container(
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D9488).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.sports_esports_rounded,
                          color: Color(0xFF0D9488),
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'محاسبه قیمت بازی (حجمی)',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Inputs
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
                          hint: 'مثلاً 300000',
                          onChanged: (_) => _calculatePrice(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  
                  // Result display
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
          ],
        ),
      ),
    );
  }

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
        TextField(
          controller: controller,
          autofocus: autoFocus,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          onChanged: onChanged,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white : Colors.black87,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: isDark ? Colors.grey[600] : Colors.grey[400],
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
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: Color(0xFF0D9488),
                width: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
