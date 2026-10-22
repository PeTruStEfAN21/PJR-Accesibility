import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'sound_alert.dart';

/// A sound of this workplace, learned from a few samples (the alarm of hall 2, the line signal).
/// Only the fingerprint is kept, never the audio.
class LocationSound {
  const LocationSound({required this.id, required this.label, required this.level, required this.print});

  final String id;
  final String label;
  final AlertLevel level;
  final Float32List print;

  Map<String, Object> toJson() => {'id': id, 'label': label, 'level': level.name, 'print': print.toList()};

  static LocationSound fromJson(Map<String, dynamic> json) => LocationSound(
        id: json['id'] as String,
        label: json['label'] as String,
        level: AlertLevel.values.byName(json['level'] as String),
        print: Float32List.fromList([for (final v in json['print'] as List) (v as num).toDouble()]),
      );
}

/// Sounds learned on this device, plus the ones the user's company shared
/// (kept apart and replaced at each sync). Both are saved on the device, so
/// they keep working offline.
class LocationSoundStore extends ChangeNotifier {
  LocationSoundStore(this._prefs) {
    _load(_key, _sounds);
    _load(_sharedKey, _shared);
  }

  static const _key = 'locationSounds';
  static const _sharedKey = 'sharedLocationSounds';
  final SharedPreferences _prefs;
  final _sounds = <LocationSound>[];
  final _shared = <LocationSound>[];

  /// Everything the detector listens for.
  List<LocationSound> get sounds => List.unmodifiable([..._sounds, ..._shared]);

  /// Learned on this device (the user can delete these).
  List<LocationSound> get learned => List.unmodifiable(_sounds);

  /// From the company.
  List<LocationSound> get shared => List.unmodifiable(_shared);

  void _load(String key, List<LocationSound> into) {
    try {
      final saved = _prefs.getString(key);
      if (saved != null) {
        into.addAll([for (final s in jsonDecode(saved) as List) LocationSound.fromJson(s as Map<String, dynamic>)]);
      }
    } catch (_) {
      // A corrupt list is dropped rather than blocking the app.
      into.clear();
    }
  }

  Future<void> replaceShared(List<LocationSound> sounds) async {
    _shared
      ..clear()
      ..addAll(sounds);
    await _prefs.setString(_sharedKey, jsonEncode([for (final s in _shared) s.toJson()]));
    notifyListeners();
  }

  Future<void> add(String label, AlertLevel level, Float32List print) async {
    final id = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    _sounds.add(LocationSound(id: id, label: label, level: level, print: print));
    await _save();
  }

  Future<void> remove(String id) async {
    _sounds.removeWhere((s) => s.id == id);
    await _save();
  }

  Future<void> _save() async {
    await _prefs.setString(_key, jsonEncode([for (final s in _sounds) s.toJson()]));
    notifyListeners();
  }
}
