import 'dart:async';

/// Re-sends a critical alert's notification while the phone is locked or in a
/// pocket, so it is felt more than once (and on a watch), until the user sees it.
class CriticalRepeater {
  CriticalRepeater({required this.isForeground, this.every = const Duration(seconds: 10), this.times = 12});

  /// True when the app is on screen: the red screen is visible, no need to repeat.
  final bool Function() isForeground;
  final Duration every;
  final int times;
  Timer? _timer;

  void start(void Function() fire) {
    stop();
    var fired = 0;
    _timer = Timer.periodic(every, (timer) {
      if (isForeground()) return stop();
      fire();
      if (++fired >= times) stop();
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}
