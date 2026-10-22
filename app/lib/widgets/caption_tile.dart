import 'package:flutter/material.dart';

import '../core/protocol.dart';
import '../l10n/app_localizations.dart';
import '../theme/role_palette.dart';

String speakerLabel(AppLocalizations l10n, Speaker speaker) =>
    speaker == Speaker.coordinator ? l10n.speakerCoordinator : l10n.speakerPublic;

IconData speakerIcon(Speaker speaker) => speaker == Speaker.coordinator ? Icons.mic_external_on : Icons.person;

/// One caption. The role is shown four ways: icon, text label, colour, and the
/// position chosen by the parent (coordinator pinned on top).
class CaptionTile extends StatelessWidget {
  const CaptionTile({super.key, required this.caption, this.number, this.emphasized = false, this.isQuestion = false});

  final Caption caption;

  /// Someone in the room asked a question: shown with an icon and a label, not only a colour.
  final bool isQuestion;

  /// Line number as cited by "Întreabă meetingul" ([#3]).
  final int? number;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final color = context.roles.of(caption.speaker);
    final label = speakerLabel(l10n, caption.speaker);
    final heading = isQuestion ? '$label, ${l10n.roomQuestion}' : label;

    return Semantics(
      container: true,
      label: '$heading: ${caption.text}',
      excludeSemantics: true,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: emphasized ? 1 : 0.6),
          borderRadius: BorderRadius.circular(12),
          border: Border(left: BorderSide(color: color, width: 6)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Icon(speakerIcon(caption.speaker), size: 20, color: color),
                Text(label, style: theme.textTheme.labelLarge?.copyWith(color: color, fontWeight: FontWeight.w700)),
                if (isQuestion) ...[
                  Icon(Icons.contact_support, size: 20, color: theme.colorScheme.onSurface),
                  Text(l10n.roomQuestion, style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
                ],
                if (number != null) Text('#$number', style: theme.textTheme.labelMedium),
                if (!caption.isFinal)
                  Text('· ${l10n.captionPartial}', style: theme.textTheme.labelMedium?.copyWith(fontStyle: FontStyle.italic)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              caption.text,
              style: (emphasized ? theme.textTheme.titleLarge : theme.textTheme.bodyLarge)?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
