import 'package:flutter/material.dart';

import '../../settings/app_settings.dart';
import '../../theme/echo_style.dart';

/// An iOS-style grouped section: a small header, rows on one tonal panel with hairline dividers,
/// and an optional note under the panel.
class EchoGroup extends StatelessWidget {
  const EchoGroup({super.key, this.title, required this.rows, this.footer});

  final String? title;
  final List<Widget> rows;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = EchoPalette.of(context);
    final highContrast = SettingsScope.of(context).highContrast;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Semantics(
              header: true,
              child: Text(title!, style: theme.textTheme.titleSmall?.copyWith(color: palette.muted, fontWeight: FontWeight.w600)),
            ),
          ),
        Material(
          color: palette.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: highContrast ? BorderSide(color: palette.border, width: 2) : BorderSide.none,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, row) in rows.indexed) ...[
                if (i > 0) Divider(height: 1, thickness: 1, indent: 16, color: palette.border),
                row,
              ],
            ],
          ),
        ),
        if (footer != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: DefaultTextStyle.merge(style: theme.textTheme.bodyMedium?.copyWith(color: palette.muted), child: footer!),
          ),
      ],
    );
  }
}

/// A tappable row inside an [EchoGroup]: at least 48 px tall, grows with the text.
class EchoGroupRow extends StatelessWidget {
  const EchoGroupRow({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.selected,
    required this.onTap,
  });

  final Widget? leading;
  final String title;
  final List<String>? subtitle;
  final Widget? trailing;

  /// Non-null for rows that are one choice in a list: read out as selected or not.
  final bool? selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = EchoPalette.of(context);
    return MergeSemantics(
      child: Semantics(
        button: true,
        selected: selected,
        child: InkWell(
          onTap: onTap,
          splashFactory: NoSplash.splashFactory,
          highlightColor: palette.text.withValues(alpha: 0.06),
          hoverColor: palette.text.withValues(alpha: 0.03),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  if (leading != null) ...[leading!, const SizedBox(width: 14)],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: theme.textTheme.titleMedium?.copyWith(color: palette.text, fontWeight: FontWeight.w500)),
                        for (final line in subtitle ?? const <String>[]) ...[
                          const SizedBox(height: 2),
                          Text(line, style: theme.textTheme.bodyMedium?.copyWith(color: palette.muted)),
                        ],
                      ],
                    ),
                  ),
                  if (trailing != null) ...[const SizedBox(width: 8), trailing!],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
