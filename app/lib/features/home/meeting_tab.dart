import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/echo_style.dart';
import '../../widgets/glass.dart';
import '../../widgets/pressable.dart';
import '../participant/join_screen.dart';
import '../presenter/presenter_screen.dart';

enum MeetingMode { join, present }

/// The phone's Meeting tab: one place for both sides of a meeting. "Particip" joins with the code;
/// "Prezint" explains what presenting does and starts it.
class MeetingTab extends StatefulWidget {
  const MeetingTab({super.key});

  @override
  State<MeetingTab> createState() => _MeetingTabState();
}

class _MeetingTabState extends State<MeetingTab> {
  MeetingMode _mode = MeetingMode.join;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.meetingTitle)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: GlassSegmented<MeetingMode>(
              semanticLabel: l10n.meetingModeLabel,
              selected: _mode,
              onChanged: (mode) => setState(() => _mode = mode),
              options: [
                (MeetingMode.join, Icons.closed_caption_outlined, Icons.closed_caption, l10n.meetingModeJoin),
                (MeetingMode.present, Icons.co_present_outlined, Icons.co_present, l10n.meetingModePresent),
              ],
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 200),
              child: switch (_mode) {
                MeetingMode.join => const JoinScreen(key: ValueKey('join'), replaceOnJoin: false, embedded: true),
                MeetingMode.present => const _PresentPanel(key: ValueKey('present')),
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PresentPanel extends StatelessWidget {
  const _PresentPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final palette = EchoPalette.of(context);
    final bottom = MediaQuery.paddingOf(context).bottom;
    Widget point(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IconChip(icon: icon),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(text, style: theme.textTheme.bodyLarge),
            ),
          ),
        ],
      ),
    );
    return ListView(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 32 + bottom),
      children: [
        Semantics(header: true, child: Text(l10n.presentIntroTitle, style: theme.textTheme.headlineSmall)),
        const SizedBox(height: 10),
        Text(l10n.presentIntroBody, style: theme.textTheme.bodyLarge?.copyWith(color: palette.muted)),
        const SizedBox(height: 24),
        point(Icons.qr_code_2, l10n.presentPointCode),
        point(Icons.mark_chat_unread_outlined, l10n.presentPointQuestions),
        point(Icons.record_voice_over_outlined, l10n.presentPointVoice),
        const SizedBox(height: 16),
        Pressable(
          child: FilledButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PresenterScreen())),
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(l10n.presentStart),
          ),
        ),
      ],
    );
  }
}

/// An icon in a soft rounded chip, the small premium accent used across Echo's lists.
class _IconChip extends StatelessWidget {
  const _IconChip({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final palette = EchoPalette.of(context);
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: palette.accentTint,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
      ),
      child: Icon(icon, size: 22, color: palette.accent),
    );
  }
}
