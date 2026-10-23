import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/alerts/alert_controller.dart' as alerts show defaultAlertHaptics;
import '../features/alerts/alert_controller.dart' show Haptic;
import '../features/alerts/sound_alert.dart';

enum RolePaletteKind { standard, protanopia, deuteranopia, tritanopia }

/// Languages the app ships with. Adding one: a new ARB file plus an entry here.
const supportedLanguages = {'ro': 'ro-RO', 'en': 'en-US'};

/// Accessibility and app preferences, saved on the device.
class AppSettings extends ChangeNotifier {
  AppSettings(this._prefs) {
    _load();
  }

  final SharedPreferences _prefs;

  /// null = follow the system language.
  String? uiLanguage;
  String speechLanguage = 'ro';
  double textScale = 1.0;
  bool dyslexiaMode = false;
  RolePaletteKind palette = RolePaletteKind.standard;
  bool highContrast = false;
  bool autoScroll = true;
  String emergencyExit = '';
  String serverUrl = '';

  /// The presenter's learned voice (speaker embedding), kept so a reload does not ask for it again, and the
  /// voice model it was made with: a voice from another model means nothing to the current one.
  List<double>? voiceprint;
  String? voiceprintModel;

  /// The colleague's own voice for the clarity coach (online meetings), kept apart from the presenter's:
  /// one laptop can be both.
  List<double>? coachVoiceprint;
  String? coachVoiceprintModel;

  /// In-app onboarding: false once the user taps "Skip" on any tip.
  bool tipsEnabled = true;

  /// Ids of the tips the user has already dismissed.
  Set<String> seenTips = {};

  bool shouldShowTip(String id) => tipsEnabled && !seenTips.contains(id);

  /// The vibration of each alert level; always three different ones, so the levels stay tellable apart.
  static const defaultAlertHaptics = alerts.defaultAlertHaptics;

  Map<AlertLevel, Haptic> _alertHaptics = {...defaultAlertHaptics};

  Map<AlertLevel, Haptic> get alertHaptics => Map.unmodifiable(_alertHaptics);

  Haptic hapticFor(AlertLevel level) => _alertHaptics[level]!;

  /// Gives [level] the vibration [haptic]. If another level had it, that level takes [level]'s old one and is
  /// returned, so the three stay different; null when nothing else changed.
  AlertLevel? chooseHaptic(AlertLevel level, Haptic haptic) {
    final old = _alertHaptics[level]!;
    if (old == haptic) return null;
    final other = _alertHaptics.keys.firstWhere((l) => _alertHaptics[l] == haptic);
    _alertHaptics = {..._alertHaptics, level: haptic, other: old};
    _save();
    notifyListeners();
    return other;
  }

  static const minTextScale = 1.0;
  static const maxTextScale = 2.0;

  Locale? get locale => uiLanguage == null ? null : Locale(uiLanguage!);

  /// BCP 47 tag for the speech recogniser.
  String get speechLocaleId => supportedLanguages[speechLanguage] ?? 'ro-RO';

  void _load() {
    uiLanguage = _prefs.getString('uiLanguage');
    speechLanguage = _prefs.getString('speechLanguage') ?? speechLanguage;
    textScale = (_prefs.getDouble('textScale') ?? textScale).clamp(minTextScale, maxTextScale);
    // The dyslexia font, high contrast and role colours are no longer offered in Settings, so one saved
    // before is not loaded: nobody stays stuck with a look they cannot turn off.
    autoScroll = _prefs.getBool('autoScroll') ?? autoScroll;
    emergencyExit = _prefs.getString('emergencyExit') ?? emergencyExit;
    serverUrl = _prefs.getString('serverUrl') ?? serverUrl;
    tipsEnabled = _prefs.getBool('tipsEnabled') ?? tipsEnabled;
    seenTips = (_prefs.getStringList('seenTips') ?? const []).toSet();
    _alertHaptics = _decodeHaptics(_prefs.getString('alertHaptics'));
    final saved = _prefs.getString('voiceEnrollment');
    final decoded = saved == null ? null : jsonDecode(saved);
    // Older saves were a bare list, without the model: they count as made by an unknown model.
    if (decoded is Map) {
      voiceprintModel = decoded['model'] as String?;
      voiceprint = [for (final x in decoded['vector'] as List) (x as num).toDouble()];
    }
    final coach = _prefs.getString('coachVoiceEnrollment');
    if (coach != null) {
      final decoded = jsonDecode(coach) as Map;
      coachVoiceprintModel = decoded['model'] as String?;
      coachVoiceprint = [for (final x in decoded['vector'] as List) (x as num).toDouble()];
    }
  }

  /// The saved vibrations, or the defaults when the save is missing or not three different ones.
  static Map<AlertLevel, Haptic> _decodeHaptics(String? saved) {
    try {
      final decoded = jsonDecode(saved ?? '') as Map;
      final map = {
        for (final level in AlertLevel.values)
          level: Haptic.values.byName(decoded[level.name] as String),
      };
      if (map.values.toSet().length == AlertLevel.values.length) return map;
    } catch (_) {}
    return {...defaultAlertHaptics};
  }

  void update(void Function(AppSettings s) change) {
    change(this);
    textScale = textScale.clamp(minTextScale, maxTextScale);
    _save();
    notifyListeners();
  }

  void _save() {
    if (uiLanguage == null) {
      _prefs.remove('uiLanguage');
    } else {
      _prefs.setString('uiLanguage', uiLanguage!);
    }
    _prefs
      ..setString('speechLanguage', speechLanguage)
      ..setDouble('textScale', textScale)
      ..setBool('dyslexiaMode', dyslexiaMode)
      ..setString('palette', palette.name)
      ..setBool('highContrast', highContrast)
      ..setBool('autoScroll', autoScroll)
      ..setString('emergencyExit', emergencyExit)
      ..setString('serverUrl', serverUrl)
      ..setBool('tipsEnabled', tipsEnabled)
      ..setStringList('seenTips', seenTips.toList())
      ..setString('alertHaptics', jsonEncode({for (final e in _alertHaptics.entries) e.key.name: e.value.name}));
    if (voiceprint == null) {
      _prefs.remove('voiceEnrollment');
    } else {
      _prefs.setString('voiceEnrollment', jsonEncode({'model': voiceprintModel, 'vector': voiceprint}));
    }
    if (coachVoiceprint == null) {
      _prefs.remove('coachVoiceEnrollment');
    } else {
      _prefs.setString('coachVoiceEnrollment', jsonEncode({'model': coachVoiceprintModel, 'vector': coachVoiceprint}));
    }
  }
}

/// Makes [AppSettings] reachable from any widget below it.
class SettingsScope extends InheritedNotifier<AppSettings> {
  const SettingsScope({super.key, required AppSettings settings, required super.child}) : super(notifier: settings);

  static AppSettings of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SettingsScope>()!.notifier!;
}
