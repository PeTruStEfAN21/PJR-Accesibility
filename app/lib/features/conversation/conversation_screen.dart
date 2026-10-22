import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/services.dart';
import '../../core/speech/speech_service.dart';
import '../../l10n/app_localizations.dart';
import '../../settings/app_settings.dart';

/// Bonus 1: speech bubbles next to faces. For now this shows plain live
/// captions from the phone's microphone; the camera + face detection layer
/// (ML Kit) goes on top of it (see the demo plan, person 4).
class ConversationScreen extends StatefulWidget {
  const ConversationScreen({super.key});

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final _segments = <String, SpeechSegment>{};
  StreamSubscription<SpeechSegment>? _subscription;
  SpeechService? _speech;
  bool _listening = false;

  @override
  void dispose() {
    _subscription?.cancel();
    if (_listening) _speech?.stop();
    super.dispose();
  }

  Future<void> _toggle() async {
    final speech = _speech ??= ServicesScope.of(context).speech;
    if (_listening) {
      await _subscription?.cancel();
      await speech.stop();
      setState(() => _listening = false);
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final unavailable = AppLocalizations.of(context).speechUnavailable;
    _subscription = speech.segments.listen((segment) => setState(() => _segments[segment.id] = segment));
    final ok = await speech.start(SettingsScope.of(context).speechLocaleId);
    if (!mounted) return;
    if (!ok) {
      await _subscription?.cancel();
      messenger.showSnackBar(SnackBar(content: Text(unavailable)));
      return;
    }
    setState(() => _listening = true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final segments = _segments.values.toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.conversationTitle),
        actions: [
          IconButton(
            tooltip: _listening ? l10n.stopListening : l10n.listenRoom,
            isSelected: _listening,
            icon: const Icon(Icons.mic_none),
            selectedIcon: const Icon(Icons.mic),
            onPressed: _toggle,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(padding: const EdgeInsets.all(16), child: Text(l10n.conversationPending)),
          Expanded(
            child: Semantics(
              liveRegion: true,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: segments.length,
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(segments[i].text, style: Theme.of(context).textTheme.titleLarge),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
