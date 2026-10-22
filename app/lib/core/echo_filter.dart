/// In two-device mode the participant's phone also hears the presenter. This
/// filter drops what the phone recognised when it is most likely the presenter
/// again: either the presenter spoke very recently, or the words largely match
/// something the presenter said moments ago.
class EchoFilter {
  EchoFilter({
    this.quietWindow = const Duration(milliseconds: 1500),
    this.memory = const Duration(seconds: 10),
    this.overlapThreshold = 0.6,
  });

  final Duration quietWindow;
  final Duration memory;
  final double overlapThreshold;

  final List<(DateTime, Set<String>)> _recent = [];

  void coordinatorSpoke(String text, DateTime at) {
    _recent.add((at, _words(text)));
    _recent.removeWhere((entry) => at.difference(entry.$1) > memory);
  }

  bool isEcho(String text, DateTime at) {
    if (_recent.isEmpty) return false;
    final lastSpoke = _recent.last.$1;
    if (at.difference(lastSpoke) <= quietWindow) return true;

    final words = _words(text);
    if (words.isEmpty) return false;
    for (final (time, coordinatorWords) in _recent) {
      if (at.difference(time) > memory) continue;
      final shared = words.intersection(coordinatorWords).length;
      if (shared / words.length >= overlapThreshold) return true;
    }
    return false;
  }

  static Set<String> _words(String text) =>
      text.toLowerCase().split(RegExp(r'[^\p{L}\p{N}]+', unicode: true)).where((w) => w.length > 1).toSet();
}
