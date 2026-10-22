import 'dart:async';

import 'package:flutter/foundation.dart';

import '../transcript.dart';
import 'meeting_store.dart';

/// Saves the final captions of a live meeting to the user's account, in batches.
///
/// The meeting row is created with the first final line, so meetings where
/// nobody spoke leave nothing behind. A failed save keeps its lines for the next
/// flush; saving never interrupts the captions on screen.
class MeetingRecorder {
  MeetingRecorder({
    required this.store,
    required this.transcript,
    required this.lang,
    this.sessionCode,
    this.flushEvery = const Duration(seconds: 30),
  });

  final MeetingStore store;
  final Transcript transcript;
  final String lang;
  final String? sessionCode;
  final Duration flushEvery;

  String? _meetingId;
  final _seqs = <String, int>{};
  final _pending = <SavedLine>[];
  Timer? _timer;
  Future<void>? _flushing;
  bool _stopped = false;

  /// Null until the first line has been saved.
  String? get meetingId => _meetingId;

  int get pendingCount => _pending.length;

  void start() {
    transcript.addListener(_collect);
    _collect();
    _timer = Timer.periodic(flushEvery, (_) => flush());
  }

  /// Captions become lines the first time they are seen final, numbered in that order.
  void _collect() {
    for (final caption in transcript.captions) {
      final text = caption.text.trim();
      if (!caption.isFinal || text.isEmpty || _seqs.containsKey(caption.id)) continue;
      final seq = _seqs.length + 1;
      _seqs[caption.id] = seq;
      _pending.add(SavedLine(
        seq: seq,
        captionId: caption.id,
        speaker: caption.speaker,
        text: text,
        spokenAt: DateTime.fromMillisecondsSinceEpoch(caption.ts),
      ));
    }
  }

  /// Saves the pending lines now. Calls made while a save runs share it.
  Future<void> flush() => _flushing ??= _save().whenComplete(() => _flushing = null);

  Future<void> _save() async {
    if (_pending.isEmpty) return;
    final batch = List.of(_pending);
    try {
      final id = _meetingId ??= await store.createMeeting(sessionCode: sessionCode, lang: lang);
      await store.saveLines(id, batch);
      _pending.removeRange(0, batch.length);
    } on Object catch (error) {
      debugPrint('Saving the meeting failed, will retry: $error');
    }
  }

  /// Stops listening (synchronously, so the transcript can be disposed right
  /// after), then saves what is left and marks the meeting as ended.
  Future<void> stop() async {
    if (_stopped) return;
    _stopped = true;
    _timer?.cancel();
    transcript.removeListener(_collect);
    await _flushing;
    await flush();
    final id = _meetingId;
    if (id == null) return;
    try {
      await store.finishMeeting(id);
    } on Object catch (error) {
      debugPrint('Marking the meeting as ended failed: $error');
    }
  }
}
