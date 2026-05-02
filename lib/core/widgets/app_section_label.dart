import 'package:flutter/material.dart';

class AppSectionLabel extends StatelessWidget {
  final String text;
  final EdgeInsetsGeometry padding;

  const AppSectionLabel({
    super.key,
    required this.text,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: padding,
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Text(
          text,
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.75),
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}
