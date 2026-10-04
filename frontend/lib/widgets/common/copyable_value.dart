import 'package:flutter/material.dart';

/// Adds an explicit, keyboard-focusable copy interaction to an existing value.
class CopyableValue extends StatelessWidget {
  final Widget child;
  final VoidCallback onCopy;
  final String tooltip;

  const CopyableValue({
    super.key,
    required this.child,
    required this.onCopy,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onCopy,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
