import 'package:flutter/material.dart';
import '../common/hardware_illustrations.dart';

/// Modern, minimal, and expandable card wrapper for Advanced Mode.
/// Supports vector illustrations, concise summary subtitles, and smooth accordion expansion.

class CardWrapper extends StatefulWidget {
  final IconData icon;
  final String title;
  final String? summarySubtitle;
  final Widget? illustration;
  final Widget? trailing;
  final Widget child;
  final Color? iconColor;
  final bool isCollapsible;
  final bool initiallyExpanded;
  final bool? isExpanded;
  final ValueChanged<bool>? onExpansionChanged;

  const CardWrapper({
    super.key,
    required this.icon,
    required this.title,
    this.summarySubtitle,
    this.illustration,
    this.trailing,
    required this.child,
    this.iconColor,
    this.isCollapsible = true,
    this.initiallyExpanded = false,
    this.isExpanded,
    this.onExpansionChanged,
  });

  @override
  State<CardWrapper> createState() => _CardWrapperState();
}

class _CardWrapperState extends State<CardWrapper> with SingleTickerProviderStateMixin {
  late bool _expanded;
  late AnimationController _animController;
  late Animation<double> _iconTurns;

  @override
  void initState() {
    super.initState();
    _expanded = widget.isExpanded ?? widget.initiallyExpanded;
    _animController = AnimationController(
      duration: const Duration(milliseconds: 260),
      vsync: this,
    );
    _iconTurns = Tween<double>(begin: 0.0, end: 0.5).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOutCubic),
    );

    if (_expanded) {
      _animController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(covariant CardWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isExpanded != null && widget.isExpanded != _expanded) {
      _handleExpansion(widget.isExpanded!);
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _handleExpansion(bool expand) {
    setState(() {
      _expanded = expand;
      if (_expanded) {
        _animController.forward();
      } else {
        _animController.reverse();
      }
    });
    widget.onExpansionChanged?.call(_expanded);
  }

  void _toggleExpanded() {
    if (!widget.isCollapsible) return;
    _handleExpansion(!_expanded);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final effectiveColor = widget.iconColor ?? (isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB));
    final iconBgColor = effectiveColor.withValues(alpha: isDark ? 0.15 : 0.1);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131D33) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF22304E) : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Bar (Clickable for Expand/Collapse)
          InkWell(
            onTap: widget.isCollapsible ? _toggleExpanded : null,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  // Vector Illustration Badge or Icon Container
                  if (widget.illustration != null)
                    HardwareIllustrationBadge(
                      illustration: widget.illustration!,
                      accentColor: effectiveColor,
                      size: 44,
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: iconBgColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: effectiveColor.withValues(alpha: isDark ? 0.4 : 0.2),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        widget.icon,
                        size: 20,
                        color: effectiveColor,
                      ),
                    ),
                  const SizedBox(width: 14),

                  // Title & Optional Subtitle
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                            color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                          ),
                        ),
                        if (widget.summarySubtitle != null && widget.summarySubtitle!.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Directionality(
                            textDirection: TextDirection.ltr,
                            child: Text(
                              widget.summarySubtitle!,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: effectiveColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Trailing widget (e.g. status badges, action buttons)
                  if (widget.trailing != null) ...[
                    const SizedBox(width: 8),
                    widget.trailing!,
                  ],

                  // Expand/Collapse Chevron Indicator
                  if (widget.isCollapsible) ...[
                    const SizedBox(width: 8),
                    RotationTransition(
                      turns: _iconTurns,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 18,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Collapsible Detailed Content Body
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Divider(
                  color: isDark ? const Color(0xFF1E2C4A) : const Color(0xFFF1F5F9),
                  thickness: 1,
                  height: 1,
                ),
                Padding(
                  padding: const EdgeInsets.all(18.0),
                  child: widget.child,
                ),
              ],
            ),
            crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 240),
          ),
        ],
      ),
    );
  }
}
