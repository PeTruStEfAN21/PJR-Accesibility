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
    this.company,
    this.refreshCompanies,
    this.flushEvery = const Duration(seconds: 30),
  });

  final MeetingStore store;
  final Transcript transcript;
  final String lang;
  final String? sessionCode;

  /// The company to save the meeting for, asked when the meeting row is created
  /// (the participant may pick another one until then); null: only the user's.
  final String? Function()? company;

  /// Reloads the user's companies, when the one asked for turned out to be gone.
  final Future<void> Function()? refreshCompanies;
  final Duration flushEvery;

  String? _meetingId;
  String? _orgId;
  final _seqs = <String, int>{};
  final _pending = <SavedLine>[];
  Timer? _timer;
  Future<void>? _flushing;
  bool _stopped = false;

  /// Null until the first line has been saved.
  String? get meetingId => _meetingId;

  /// The company the meeting was saved for, once it was saved.
  String? get orgId => _orgId;

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
      final id = _meetingId ??= await _create();
      await store.saveLines(id, batch);
      _pending.removeRange(0, batch.length);
    } on Object catch (error) {
      debugPrint('Saving the meeting failed, will retry: $error');
    }
  }

  /// Creates the meeting row. If the company was left meanwhile, reloads the companies and
  /// tries once more with what is left (another company, or only the user's account).
  Future<String> _create() async {
    var orgId = company?.call();
    String id;
    try {
      id = await store.createMeeting(sessionCode: sessionCode, lang: lang, orgId: orgId);
    } on CompanyGoneException {
      await refreshCompanies?.call();
      orgId = company?.call();
      id = await store.createMeeting(sessionCode: sessionCode, lang: lang, orgId: orgId);
    }
    _orgId = orgId;
    return id;
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
