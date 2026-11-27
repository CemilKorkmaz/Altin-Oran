import 'package:flutter/material.dart';

/// Quiet, left-aligned section heading used across grouped screens.
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.icon, required this.title, this.subtitle, this.iconColor});
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 0, 2, 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: theme.textTheme.titleMedium?.copyWith(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -.45)),
        if (subtitle != null && subtitle!.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(subtitle!, style: theme.textTheme.bodySmall),
        ],
      ]),
    );
  }
}
