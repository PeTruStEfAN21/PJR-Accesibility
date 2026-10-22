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

/// Learned sounds, saved only on this device.
class LocationSoundStore extends ChangeNotifier {
  LocationSoundStore(this._prefs) {
    try {
      final saved = _prefs.getString(_key);
      if (saved != null) {
        _sounds.addAll([for (final s in jsonDecode(saved) as List) LocationSound.fromJson(s as Map<String, dynamic>)]);
      }
    } catch (_) {
      // A corrupt list is dropped rather than blocking the app.
      _sounds.clear();
    }
  }

  static const _key = 'locationSounds';
  final SharedPreferences _prefs;
  final _sounds = <LocationSound>[];

  List<LocationSound> get sounds => List.unmodifiable(_sounds);

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
