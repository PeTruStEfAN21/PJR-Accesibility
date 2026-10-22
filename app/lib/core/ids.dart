import 'dart:math';

final _random = Random.secure();

/// Short random id for captions and messages; unique enough within one meeting.
String newId() => List.generate(12, (_) => _random.nextInt(36).toRadixString(36)).join();

int nowMs() => DateTime.now().millisecondsSinceEpoch;
