import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  ThemeMode themeMode = ThemeMode.system;
  bool autoScroll = true;
  String emergencyExit = '';
  String serverUrl = '';

  /// The presenter's learned voice (speaker embedding), kept so a reload does not ask for it again.
  List<double>? voiceprint;

  static const minTextScale = 1.0;
  static const maxTextScale = 2.0;

  Locale? get locale => uiLanguage == null ? null : Locale(uiLanguage!);

  /// BCP 47 tag for the speech recogniser.
  String get speechLocaleId => supportedLanguages[speechLanguage] ?? 'ro-RO';

  void _load() {
    uiLanguage = _prefs.getString('uiLanguage');
    speechLanguage = _prefs.getString('speechLanguage') ?? speechLanguage;
    textScale = (_prefs.getDouble('textScale') ?? textScale).clamp(minTextScale, maxTextScale);
    dyslexiaMode = _prefs.getBool('dyslexiaMode') ?? dyslexiaMode;
    palette = RolePaletteKind.values.asNameMap()[_prefs.getString('palette')] ?? palette;
    highContrast = _prefs.getBool('highContrast') ?? highContrast;
    themeMode = ThemeMode.values.asNameMap()[_prefs.getString('themeMode')] ?? themeMode;
    autoScroll = _prefs.getBool('autoScroll') ?? autoScroll;
    emergencyExit = _prefs.getString('emergencyExit') ?? emergencyExit;
    serverUrl = _prefs.getString('serverUrl') ?? serverUrl;
    final saved = _prefs.getString('voiceEnrollment');
    voiceprint = saved == null ? null : [for (final x in jsonDecode(saved) as List) (x as num).toDouble()];
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
      ..setString('themeMode', themeMode.name)
      ..setBool('autoScroll', autoScroll)
      ..setString('emergencyExit', emergencyExit)
      ..setString('serverUrl', serverUrl);
    if (voiceprint == null) {
      _prefs.remove('voiceEnrollment');
    } else {
      _prefs.setString('voiceEnrollment', jsonEncode(voiceprint));
    }
  }
}

/// Makes [AppSettings] reachable from any widget below it.
class SettingsScope extends InheritedNotifier<AppSettings> {
  const SettingsScope({super.key, required AppSettings settings, required super.child}) : super(notifier: settings);

  static AppSettings of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SettingsScope>()!.notifier!;
}
