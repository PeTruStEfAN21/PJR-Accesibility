import 'package:flutter/material.dart';

import '../../core/protocol.dart';
import '../../l10n/app_localizations.dart';
import '../../settings/app_settings.dart';
import '../../theme/echo_style.dart';
import '../../widgets/caption_tile.dart';
import '../../widgets/grouped_list.dart';
import '../../widgets/large_title.dart';

/// Language names are shown in their own language, whatever the UI language.
const _languageNames = {'ro': 'Română', 'en': 'English'};

/// Settings as on iOS: a large title, then grouped panels with a small header, a check mark on the
/// chosen row and controls on the right.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  /// The text size while the slider is being dragged. Only the preview follows it, so the page
  /// does not jump on every step; the whole app takes the new size when the slider is released.
  double? _draftTextScale;

  /// The preview's text size: the system size times the slider's value, even mid-drag.
  TextScaler _previewScaler(BuildContext context, AppSettings settings) {
    // The app already applies system x settings.textScale; swap the second factor for the draft.
    final system = MediaQuery.textScalerOf(context).scale(1) / settings.textScale;
    return TextScaler.linear(system * (_draftTextScale ?? settings.textScale));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = SettingsScope.of(context);
    final palette = EchoPalette.of(context);
    final theme = Theme.of(context);
    final scale = _draftTextScale ?? settings.textScale;

    Widget check(bool chosen) => chosen
        ? Icon(Icons.check_rounded, color: palette.accent)
        : const SizedBox(width: 24);

    return Scaffold(
      appBar: backBarIfPushed(context, l10n.settings),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 32 + MediaQuery.paddingOf(context).bottom),
          children: [
            LargeTitle(l10n.settings),
            EchoGroup(
              title: l10n.settingsPreview,
              rows: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: MediaQuery(
                    data: MediaQuery.of(context).copyWith(textScaler: _previewScaler(context, settings)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        CaptionTile(
                          caption: Caption(id: 'p1', speaker: Speaker.coordinator, text: l10n.quickRepeat, isFinal: true, lang: '', ts: 0),
                          emphasized: true,
                        ),
                        CaptionTile(
                          caption: Caption(id: 'p2', speaker: Speaker.public, text: l10n.quickQuestion, isFinal: true, lang: '', ts: 0),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            EchoGroup(
              title: l10n.settingsTextSize,
              rows: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      ExcludeSemantics(child: Text('A', style: theme.textTheme.bodyMedium?.copyWith(color: palette.muted))),
                      Expanded(
                        child: Slider(
                          value: scale,
                          min: AppSettings.minTextScale,
                          max: AppSettings.maxTextScale,
                          divisions: 10,
                          label: '${(scale * 100).round()}%',
                          semanticFormatterCallback: (value) => '${(value * 100).round()}%',
                          onChanged: (value) => setState(() => _draftTextScale = value),
                          onChangeEnd: (value) {
                            settings.update((s) => s.textScale = value);
                            setState(() => _draftTextScale = null);
                          },
                        ),
                      ),
                      ExcludeSemantics(child: Text('A', style: theme.textTheme.titleLarge?.copyWith(color: palette.muted))),
                    ],
                  ),
                ),
                SwitchListTile(
                  value: settings.autoScroll,
                  onChanged: (value) => settings.update((s) => s.autoScroll = value),
                  activeTrackColor: palette.accent,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  secondary: const RowIcon(Icons.swap_vert_rounded),
                  title: Text(l10n.settingsAutoScroll, style: theme.textTheme.titleMedium?.copyWith(color: palette.text, fontWeight: FontWeight.w500)),
                ),
              ],
            ),
            const SizedBox(height: 28),
            EchoGroup(
              title: l10n.settingsLanguage,
              rows: [
                EchoGroupRow(
                  title: l10n.languageSystem,
                  selected: settings.uiLanguage == null,
                  trailing: check(settings.uiLanguage == null),
                  onTap: () => settings.update((s) => s.uiLanguage = null),
                ),
                for (final code in supportedLanguages.keys)
                  EchoGroupRow(
                    title: _languageNames[code] ?? code,
                    selected: settings.uiLanguage == code,
                    trailing: check(settings.uiLanguage == code),
                    onTap: () => settings.update((s) => s.uiLanguage = code),
                  ),
              ],
            ),
            const SizedBox(height: 28),
            EchoGroup(
              title: l10n.settingsSpeechLanguage,
              rows: [
                for (final code in supportedLanguages.keys)
                  EchoGroupRow(
                    title: _languageNames[code] ?? code,
                    selected: settings.speechLanguage == code,
                    trailing: check(settings.speechLanguage == code),
                    onTap: () => settings.update((s) => s.speechLanguage = code),
                  ),
              ],
            ),
            const SizedBox(height: 28),
            EchoGroup(
              title: l10n.settingsEmergencyExit,
              rows: [
                _TextSetting(
                  icon: Icons.exit_to_app_rounded,
                  initial: settings.emergencyExit,
                  hint: l10n.settingsEmergencyExitHint,
                  onChanged: (value) => settings.update((s) => s.emergencyExit = value),
                ),
              ],
            ),
            const SizedBox(height: 28),
            EchoGroup(
              title: l10n.settingsServer,
              rows: [
                _TextSetting(
                  icon: Icons.dns_outlined,
                  initial: settings.serverUrl,
                  hint: l10n.joinServerHint,
                  keyboardType: TextInputType.url,
                  onChanged: (value) => settings.update((s) => s.serverUrl = value.trim()),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A text field as a row of a group: the icon on the left, no box of its own.
class _TextSetting extends StatefulWidget {
  const _TextSetting({required this.icon, required this.initial, required this.hint, required this.onChanged, this.keyboardType});

  final IconData icon;
  final String initial;
  final String hint;
  final ValueChanged<String> onChanged;
  final TextInputType? keyboardType;

  @override
  State<_TextSetting> createState() => _TextSettingState();
}

class _TextSettingState extends State<_TextSetting> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        child: Row(
          children: [
            RowIcon(widget.icon),
            const SizedBox(width: 14),
            Expanded(
              child: TextField(
                controller: _controller,
                keyboardType: widget.keyboardType,
                decoration: InputDecoration(
                  hintText: widget.hint,
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onChanged: widget.onChanged,
              ),
            ),
          ],
        ),
      );
}
