import 'package:flutter/widgets.dart';

import 'alarm_feed.dart';

/// The running alarm feed, or null while signed out. Screens that raise an alarm
/// tell it so through `markOwn`, so the phone never shows its own alarm.
class AlarmScope extends InheritedWidget {
  const AlarmScope({super.key, required this.feed, required super.child});

  final AlarmFeed? feed;

  static AlarmFeed? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AlarmScope>()?.feed;

  @override
  bool updateShouldNotify(AlarmScope oldWidget) => feed != oldWidget.feed;
}
