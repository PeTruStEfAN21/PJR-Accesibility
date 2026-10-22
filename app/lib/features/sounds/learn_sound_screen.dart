import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/services.dart';
import '../../l10n/app_localizations.dart';
import '../alerts/sound_alert.dart';
import '../alerts/yamnet_logic.dart';

/// Learns a sound of this place from 3 samples of 3 seconds. Only the averaged
/// fingerprint is kept, never the recording.
class LearnSoundScreen extends StatefulWidget {
  const LearnSoundScreen({super.key});

  static const samplesNeeded = 3;
  static const sampleLength = Duration(seconds: 3);

  @override
  State<LearnSoundScreen> createState() => _LearnSoundScreenState();
}

class _LearnSoundScreenState extends State<LearnSoundScreen> {
  final _name = TextEditingController();
  final _samples = <Float32List>[];
  AlertLevel _level = AlertLevel.warning;
  bool _recording = false;
  bool _nothingHeard = false;

  bool get _canSave =>
      !_recording && _samples.length >= LearnSoundScreen.samplesNeeded && _name.text.trim().isNotEmpty;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _record() async {
    setState(() {
      _recording = true;
      _nothingHeard = false;
    });
    final sample = await ServicesScope.of(context).sounds.recordSample(LearnSoundScreen.sampleLength);
    if (!mounted) return;
    setState(() {
      _recording = false;
      if (sample == null) {
        _nothingHeard = true;
      } else {
        _samples.add(sample);
      }
    });
  }

  Future<void> _save() async {
    final store = ServicesScope.of(context).locationSounds!;
    await store.add(_name.text.trim(), _level, fingerprint([for (final s in _samples) s.toList()]));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final count = _samples.length.clamp(0, LearnSoundScreen.samplesNeeded);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.locSoundsLearn)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              maxLength: 100,
              decoration: InputDecoration(labelText: l10n.learnName, hintText: l10n.learnNameHint),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            Semantics(header: true, child: Text(l10n.learnLevel, style: theme.textTheme.titleMedium)),
            RadioGroup<AlertLevel>(
              groupValue: _level,
              onChanged: (level) => setState(() => _level = level ?? _level),
              child: Column(
                children: [
                  for (final (level, label) in [
                    (AlertLevel.critical, l10n.levelCritical),
                    (AlertLevel.warning, l10n.levelWarning),
                    (AlertLevel.info, l10n.levelInfo),
                  ])
                    RadioListTile<AlertLevel>(value: level, title: Text(label)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(56)),
              onPressed: _recording ? null : _record,
              icon: const Icon(Icons.mic),
              label: Text(l10n.learnRecord),
            ),
            const SizedBox(height: 12),
            Semantics(
              liveRegion: true,
              child: Column(
                children: [
                  Text(
                    _recording ? l10n.learnRecording : l10n.learnSamples(count),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium,
                  ),
                  if (_nothingHeard) ...[
                    const SizedBox(height: 8),
                    Text(
                      l10n.learnNothingHeard,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
              onPressed: _canSave ? _save : null,
              child: Text(l10n.learnSave),
            ),
          ],
        ),
      ),
    );
  }
}
