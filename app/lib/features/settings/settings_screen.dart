import 'package:flutter/material.dart';

import '../../core/protocol.dart';
import '../../l10n/app_localizations.dart';
import '../../settings/app_settings.dart';
import '../../widgets/caption_tile.dart';

/// Language names are shown in their own language, whatever the UI language.
const _languageNames = {'ro': 'Română', 'en': 'English'};

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
    final theme = Theme.of(context);

    Widget section(String title) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Semantics(header: true, child: Text(title, style: theme.textTheme.titleMedium)),
        );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        padding: EdgeInsets.only(bottom: 24 + MediaQuery.paddingOf(context).bottom),
        children: [
          section(l10n.settingsPreview),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: _previewScaler(context, settings)),
              child: Column(
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
          section(l10n.settingsLanguage),
          RadioGroup<String?>(
            groupValue: settings.uiLanguage,
            onChanged: (value) => settings.update((s) => s.uiLanguage = value),
            child: Column(
              children: [
                RadioListTile<String?>(value: null, title: Text(l10n.languageSystem)),
                for (final code in supportedLanguages.keys)
                  RadioListTile<String?>(value: code, title: Text(_languageNames[code] ?? code)),
              ],
            ),
          ),
          section(l10n.settingsSpeechLanguage),
          RadioGroup<String>(
            groupValue: settings.speechLanguage,
            onChanged: (value) => settings.update((s) => s.speechLanguage = value!),
            child: Column(
              children: [
                for (final code in supportedLanguages.keys)
                  RadioListTile<String>(value: code, title: Text(_languageNames[code] ?? code)),
              ],
            ),
          ),
          section(l10n.settingsTextSize),
          Slider(
            value: _draftTextScale ?? settings.textScale,
            min: AppSettings.minTextScale,
            max: AppSettings.maxTextScale,
            divisions: 10,
            label: '${((_draftTextScale ?? settings.textScale) * 100).round()}%',
            semanticFormatterCallback: (value) => '${(value * 100).round()}%',
            onChanged: (value) => setState(() => _draftTextScale = value),
            onChangeEnd: (value) {
              settings.update((s) => s.textScale = value);
              setState(() => _draftTextScale = null);
            },
          ),
          SwitchListTile(
            title: Text(l10n.settingsDyslexia),
            subtitle: Text(l10n.settingsDyslexiaHint),
            value: settings.dyslexiaMode,
            onChanged: (value) => settings.update((s) => s.dyslexiaMode = value),
          ),
          SwitchListTile(
            title: Text(l10n.settingsHighContrast),
            value: settings.highContrast,
            onChanged: (value) => settings.update((s) => s.highContrast = value),
          ),
          SwitchListTile(
            title: Text(l10n.settingsAutoScroll),
            value: settings.autoScroll,
            onChanged: (value) => settings.update((s) => s.autoScroll = value),
          ),
          section(l10n.settingsPalette),
          RadioGroup<RolePaletteKind>(
            groupValue: settings.palette,
            onChanged: (value) => settings.update((s) => s.palette = value!),
            child: Column(
              children: [
                for (final kind in RolePaletteKind.values)
                  RadioListTile<RolePaletteKind>(
                    value: kind,
                    title: Text(switch (kind) {
                      RolePaletteKind.standard => l10n.paletteStandard,
                      RolePaletteKind.protanopia => l10n.paletteProtanopia,
                      RolePaletteKind.deuteranopia => l10n.paletteDeuteranopia,
                      RolePaletteKind.tritanopia => l10n.paletteTritanopia,
                    }),
                  ),
              ],
            ),
          ),
          section(l10n.settingsEmergencyExit),
          _TextSetting(
            initial: settings.emergencyExit,
            hint: l10n.settingsEmergencyExitHint,
            onChanged: (value) => settings.update((s) => s.emergencyExit = value),
          ),
          section(l10n.settingsServer),
          _TextSetting(
            initial: settings.serverUrl,
            hint: l10n.joinServerHint,
            keyboardType: TextInputType.url,
            onChanged: (value) => settings.update((s) => s.serverUrl = value.trim()),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _TextSetting extends StatefulWidget {
  const _TextSetting({required this.initial, required this.hint, required this.onChanged, this.keyboardType});

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
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: TextField(
          controller: _controller,
          keyboardType: widget.keyboardType,
          decoration: InputDecoration(hintText: widget.hint, border: const OutlineInputBorder()),
          onChanged: widget.onChanged,
        ),
      );
}
