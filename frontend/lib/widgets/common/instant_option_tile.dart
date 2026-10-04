import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Keeps a frequently-used option in its own reactive/repaint boundary.
///
/// Updating [value] rebuilds only this tile, not the surrounding package list,
/// so the visual checkmark is committed on the next frame.
class InstantOptionTile extends StatelessWidget {
  final RxBool value;
  final bool enabled;
  final String title;
  final String subtitle;
  final String semanticLabel;

  const InstantOptionTile({
    super.key,
    required this.value,
    required this.enabled,
    required this.title,
    required this.subtitle,
    required this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Obx(() {
        final selected = value.value;
        return Semantics(
          label: semanticLabel,
          checked: selected,
          enabled: enabled,
          child: CheckboxListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: selected,
            onChanged: enabled
                ? (next) {
                    if (next != null && next != value.value) {
                      value.value = next;
                    }
                  }
                : null,
            title: Text(title),
            subtitle: Text(subtitle),
          ),
        );
      }),
    );
  }
}
