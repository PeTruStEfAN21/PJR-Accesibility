import 'package:flutter/material.dart';

import '../../core/org/activity_store.dart';
import '../../core/org/org_store.dart';
import '../../l10n/app_localizations.dart';
import '../alerts/alert_overlay.dart';
import '../alerts/sound_alert.dart';
import '../emergency/alarm_logic.dart';
import '../history/history_screen.dart';
import '../../widgets/page_column.dart';

/// One page of history, older than [beforeId] when given.
typedef ActivityLoader = Future<ActivityPage> Function(int? beforeId, int maxRows);

bool _isColleagueAlarm(ActivityEvent event) =>
    event == ActivityEvent.colleagueAlarmRaised || event == ActivityEvent.colleagueAlarmCancelled;

/// The alarm in words: colleague alarms use the manual alarm's kinds, company alarms the sound's.
String _kindName(AppLocalizations l10n, ActivityEntry entry) {
  final kind = entry.alarmKind ?? '';
  if (_isColleagueAlarm(entry.event)) {
    final alarm = AlarmKind.fromWire(kind);
    if (alarm != null) return alarmName(l10n, alarm);
  } else {
    final sound = SoundKind.values.asNameMap()[kind];
    // The alarm screen's title is in capitals; in a sentence it reads as the manual alarm's name.
    if (sound == SoundKind.fireAlarm) return l10n.alarmFire;
    if (sound != null) return soundLabel(l10n, sound);
  }
  return kind;
}

/// What happened, as a sentence: "Ai dat o alarmă: Incendiu" when [me] did it,
/// "ana@firma.ro a dat o alarmă: Incendiu" otherwise.
String activitySentence(AppLocalizations l10n, ActivityEntry entry, String? me) {
  final who = entry.actorEmail ?? l10n.activitySomeone;
  final mine = me != null && entry.actorId == me;
  final title = entry.title?.trim() ?? '';
  final meeting = title.isEmpty ? l10n.activityNoTitle : l10n.activityQuoted(title);
  final kind = _kindName(l10n, entry);
  final status = entry.status == AlarmAnswerStatus.needHelp ? l10n.activityStatusNeedHelp : l10n.activityStatusSafe;
  return switch (entry.event) {
    ActivityEvent.colleagueAlarmRaised => mine ? l10n.activityAlarmRaisedMe(kind) : l10n.activityAlarmRaised(who, kind),
    ActivityEvent.colleagueAlarmCancelled =>
      mine ? l10n.activityAlarmCancelledMe(kind) : l10n.activityAlarmCancelled(who, kind),
    ActivityEvent.orgAlarmReported => mine ? l10n.activityAlarmReportedMe(kind) : l10n.activityAlarmReported(who, kind),
    ActivityEvent.orgAlarmAnswered =>
      mine ? l10n.activityAlarmAnsweredMe(status, kind) : l10n.activityAlarmAnswered(who, status, kind),
    ActivityEvent.orgAlarmClosed => mine ? l10n.activityAlarmClosedMe(kind) : l10n.activityAlarmClosed(who, kind),
    ActivityEvent.meetingStarted =>
      mine ? l10n.activityMeetingStartedMe(meeting) : l10n.activityMeetingStarted(who, meeting),
    ActivityEvent.meetingEnded => mine ? l10n.activityMeetingEndedMe(meeting) : l10n.activityMeetingEnded(who, meeting),
    ActivityEvent.meetingDeleted =>
      mine ? l10n.activityMeetingDeletedMe(meeting) : l10n.activityMeetingDeleted(who, meeting),
    ActivityEvent.meetingReadByAdmin => mine
        ? l10n.activityMeetingReadByMe(meeting, entry.subjectEmail ?? l10n.activitySomeone)
        : me != null && entry.subjectUserId == me
            ? l10n.activityMeetingReadMine(who, meeting)
            : l10n.activityMeetingRead(who, meeting, entry.subjectEmail ?? l10n.activitySomeone),
  };
}

/// Always shown next to the sentence, never instead of it.
IconData activityIcon(ActivityEntry entry) {
  switch (entry.event) {
    case ActivityEvent.colleagueAlarmRaised:
      return AlarmKind.fromWire(entry.alarmKind ?? '')?.icon ?? Icons.campaign;
    case ActivityEvent.colleagueAlarmCancelled:
      return Icons.notifications_off_outlined;
    case ActivityEvent.orgAlarmReported:
      final sound = SoundKind.values.asNameMap()[entry.alarmKind];
      return sound != null ? soundIcon(sound) : Icons.warning_amber;
    case ActivityEvent.orgAlarmAnswered:
      return entry.status == AlarmAnswerStatus.needHelp ? Icons.front_hand_outlined : Icons.check_circle_outline;
    case ActivityEvent.orgAlarmClosed:
      return Icons.task_alt;
    case ActivityEvent.meetingStarted:
      return Icons.play_circle_outline;
    case ActivityEvent.meetingEnded:
      return Icons.stop_circle_outlined;
    case ActivityEvent.meetingDeleted:
      return Icons.delete_outline;
    case ActivityEvent.meetingReadByAdmin:
      return Icons.visibility_outlined;
  }
}

/// Where a colleague alarm was raised from, as coordinates and precision.
String? _place(AppLocalizations l10n, ActivityEntry entry) {
  final (lat, lon, accuracy) = (entry.lat, entry.lon, entry.accuracyM);
  if (lat == null || lon == null || accuracy == null) return null;
  return l10n.activityPlace(lat.toStringAsFixed(5), lon.toStringAsFixed(5), accuracy.round().toString());
}

/// A history, newest first, a page at a time: the user's own ("Istoricul meu") or a company's.
class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key, required this.title, required this.empty, required this.load, required this.me});

  final String title;
  final String empty;
  final ActivityLoader load;

  /// The signed-in user, so their own actions read "Ai…".
  final String? me;

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  static const _pageSize = 50;

  final _entries = <ActivityEntry>[];
  bool _loading = true;
  bool _failed = false;
  bool _more = false;

  /// The oldest row received, known to this app or not.
  int? _lastId;

  @override
  void initState() {
    super.initState();
    _loadPage();
  }

  Future<void> _loadPage() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final page = await widget.load(_lastId, _pageSize);
      if (!mounted) return;
      setState(() {
        _entries.addAll(page.entries);
        _lastId = page.lastId ?? _lastId;
        _more = page.rawCount == _pageSize;
        _loading = false;
      });
    } on Object catch (e) {
      debugPrint('History not loaded: $e');
      if (mounted) {
        setState(() {
          _failed = true;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: PageColumn(child: SafeArea(child: _body(context, l10n, theme))),
    );
  }

  Widget _body(BuildContext context, AppLocalizations l10n, ThemeData theme) {
    if (_entries.isEmpty) {
      if (_loading) return const Center(child: CircularProgressIndicator());
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_failed ? l10n.activityLoadError : widget.empty,
                  textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
              if (_failed) TextButton(onPressed: _loadPage, child: Text(l10n.retry)),
            ],
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _entries.length + 1,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        if (i == _entries.length) return _footer(l10n);
        final entry = _entries[i];
        return ListTile(
          leading: Icon(activityIcon(entry)),
          title: Text(activitySentence(l10n, entry, widget.me)),
          subtitle: Text([meetingDate(context, entry.at), ?_place(l10n, entry)].join('\n')),
        );
      },
    );
  }

  /// "Mai vechi" keeps its label while the next page loads.
  Widget _footer(AppLocalizations l10n) {
    if (_failed) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(l10n.activityLoadError, textAlign: TextAlign.center),
            TextButton(onPressed: _loadPage, child: Text(l10n.retry)),
          ],
        ),
      );
    }
    if (!_more) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        onPressed: _loading ? null : _loadPage,
        icon: _loading
            ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.expand_more),
        label: Text(l10n.activityOlder),
      ),
    );
  }
}
