import 'package:flutter/material.dart';

class EmptyStateView extends StatelessWidget {
  const EmptyStateView({super.key, required this.icon, required this.title, required this.description, this.actionLabel, this.onAction});
  final IconData icon;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(child: SingleChildScrollView(child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 88, height: 88, decoration: BoxDecoration(
          color: theme.colorScheme.surface, borderRadius: BorderRadius.circular(30),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .035), blurRadius: 24, offset: const Offset(0, 8))],
        ), child: Icon(icon, size: 36, color: theme.colorScheme.primary)),
        const SizedBox(height: 24),
        Text(title, style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
        const SizedBox(height: 10),
        ConstrainedBox(constraints: const BoxConstraints(maxWidth: 300), child: Text(description, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline))),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: 24),
          FilledButton.icon(onPressed: onAction, icon: const Icon(Icons.add_rounded, size: 18), label: Text(actionLabel!)),
        ],
      ]),
    )));
  }
}
