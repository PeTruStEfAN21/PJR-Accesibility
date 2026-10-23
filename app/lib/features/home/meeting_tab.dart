import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../widgets/glass.dart';
import '../../widgets/grouped_list.dart';
import '../../widgets/echo_mascot.dart';
import '../../widgets/large_title.dart';
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
      appBar: backBarIfPushed(context, l10n.meetingTitle),
      body: SafeArea(
        bottom: false,
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: LargeTitle(l10n.meetingTitle),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
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
    final bottom = MediaQuery.paddingOf(context).bottom;
    Widget point(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RowIcon(icon),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(text, style: theme.textTheme.bodyLarge),
            ),
          ),
        ],
      ),
    );
    return ListView(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 32 + bottom),
      children: [
        Row(
          children: [
            Expanded(child: Semantics(header: true, child: Text(l10n.presentIntroTitle, style: theme.textTheme.headlineSmall))),
            const EchoMascot(MascotPose.hello, size: 80),
          ],
        ),
        const SizedBox(height: 18),
        point(Icons.qr_code_2_rounded, l10n.presentPointCode),
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
