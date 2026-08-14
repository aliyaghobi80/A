import 'package:flutter/material.dart';
import '../../models/system_info.dart';
import 'card_wrapper.dart';
import 'info_row.dart';

class NetworkCard extends StatelessWidget {
  final List<NetworkInfo> network;

  const NetworkCard({super.key, required this.network});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final activeAdapters = network.where((a) => a.isConnected).toList();

    return CardWrapper(
      icon: Icons.lan_rounded,
      title: 'Network Adapters',
      iconColor: const Color(0xFF14B8A6),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: (activeAdapters.isNotEmpty
                  ? const Color(0xFF10B981)
                  : const Color(0xFF64748B))
              .withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: activeAdapters.isNotEmpty
                    ? const Color(0xFF10B981)
                    : const Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(width: 5),
            Text(
              '${activeAdapters.length} Active / ${network.length} Total',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: activeAdapters.isNotEmpty
                    ? (isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857))
                    : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              ),
            ),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (network.isEmpty)
            const Text('No network adapters detected')
          else
            ...network.asMap().entries.map((entry) {
              final idx = entry.key;
              final adapter = entry.value;

              final isUp = adapter.isConnected;
              final statusColor = isUp
                  ? (isDark ? const Color(0xFF10B981) : const Color(0xFF059669))
                  : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8));

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (idx > 0) ...[
                    const SizedBox(height: 12),
                    Divider(
                      color: isDark ? const Color(0xFF1E2C4A) : const Color(0xFFF1F5F9),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: statusColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          adapter.name,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          adapter.status,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (adapter.description != 'Not available' &&
                      adapter.description != adapter.name) ...[
                    const SizedBox(height: 2),
                    Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: Text(
                        adapter.description,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  InfoRow(
                    label: 'IPv4 Address',
                    value: adapter.ipv4Address,
                    icon: Icons.link_rounded,
                    isMonospace: true,
                    copyable: true,
                    isPrimary: isUp && adapter.ipv4Address != 'Not available',
                  ),
                  InfoRow(
                    label: 'MAC Address',
                    value: adapter.macAddress,
                    icon: Icons.fingerprint_rounded,
                    isMonospace: true,
                    copyable: true,
                  ),
                  if (adapter.linkSpeed != 'Not available' && adapter.linkSpeed != '0 bps')
                    InfoRow(
                      label: 'Link Speed',
                      value: adapter.linkSpeed,
                      icon: Icons.speed_rounded,
                    ),
                ],
              );
            }),
        ],
      ),
    );
  }
}
