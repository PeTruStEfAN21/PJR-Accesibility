import 'package:flutter/foundation.dart';

import 'sound_alert.dart';

/// "Always listen": once the user turns sound recognition on, it runs on every
/// launch, in the background, until they turn it off. Captions need the same
/// microphone, so they [hold] it and listening resumes when they [release] it.
class SoundListening extends ChangeNotifier {
  SoundListening(this._detector, {this.wanted = false, void Function(bool)? onWantedChanged})
      : _onWantedChanged = onWantedChanged;

  final SoundDetector _detector;
  final void Function(bool)? _onWantedChanged;

  /// The user's choice, remembered across launches.
  bool wanted;

  /// The microphone is actually on.
  bool listening = false;

  int _holds = 0;

  /// Start / stop calls run one after another, so a hold during a start cannot be lost.
  Future<void> _queue = Future.value();

  /// On, but waiting for captions to end.
  bool get paused => wanted && _holds > 0;

  /// Called from the user's tap: it is what asks for the microphone and notifications.
  /// The choice is remembered only if the microphone was allowed (or captions hold it).
  Future<bool> enable() => _run(() async {
        wanted = true;
        await _apply();
        if (!listening && _holds == 0) {
          wanted = false;
          return false;
        }
        _onWantedChanged?.call(true);
        return true;
      });

  Future<void> disable() => _run(() async {
        wanted = false;
        _onWantedChanged?.call(false);
        await _apply();
      });

  /// On launch: starts only if the user turned listening on before.
  Future<void> autoStart() => _run(_apply);

  Future<void> hold() => _run(() async {
        _holds++;
        await _apply();
      });

  Future<void> release() => _run(() async {
        if (_holds > 0) _holds--;
        await _apply();
      });

  /// Back in the app: a phone call or Siri may have cut the microphone off, so restart it.
  Future<void> resumed() => _run(() async {
        if (!listening) return _apply();
        await _detector.stop();
        listening = await _detector.start();
      });

  Future<void> _apply() async {
    final should = wanted && _holds == 0 && _detector.isAvailable;
    if (should && !listening) {
      listening = await _detector.start();
    } else if (!should && listening) {
      await _detector.stop();
      listening = false;
    }
  }

  Future<T> _run<T>(Future<T> Function() action) {
    final result = _queue.then((_) => action());
    _queue = result.then((_) {}, onError: (Object _) {});
    return result.whenComplete(notifyListeners);
  }
}
