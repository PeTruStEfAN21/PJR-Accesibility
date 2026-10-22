import 'dart:math';
import 'dart:typed_data';

/// One 30 ms slice of the microphone: how loud it was, whether it is voice, and whether a syllable
/// was confirmed at this frame.
class VoiceFrame {
  const VoiceFrame({
    required this.time,
    required this.db,
    required this.voiced,
    required this.syllable,
    this.noiseDb = -60,
  });

  /// Seconds since the analyzer started.
  final double time;

  /// Frame energy in dB relative to full scale.
  final double db;
  final bool voiced;

  /// A syllable nucleus was confirmed here (it peaked a few frames earlier).
  final bool syllable;

  /// The room's level (the noise floor) when this frame was heard, in dBFS.
  final double noiseDb;
}

/// Turns microphone samples (16 kHz mono) into [VoiceFrame]s, without a transcript and in any language.
///
/// A frame is voice when it stands 12 dB above the noise floor (the quietest tenth of the last 10 s) and
/// above -60 dBFS. Unlike a clip that is all voice, an open microphone always has pauses between words,
/// so the quietest tenth is the room, and steady noise never counts as voice.
/// Syllables are counted as in de Jong & Wempe (2009): a peak of loudness in voice,
/// with a dip of at least 2 dB before and after it, at least 100 ms after the previous one.
class FrameAnalyzer {
  FrameAnalyzer({this.sampleRate = 16000, this.frameMs = 30});

  final int sampleRate;
  final int frameMs;

  static const _historySeconds = 10;
  static const _dipDb = 2.0;
  static const _minSyllableGap = 0.1;

  late final int _frameSize = sampleRate * frameMs ~/ 1000;
  late final int _historyFrames = _historySeconds * 1000 ~/ frameMs;

  final _pending = <double>[];
  final _energies = <double>[];
  int _index = 0;

  // Syllable tracking.
  double _dipSincePeak = double.infinity;
  double _candidateDb = double.negativeInfinity;
  double _candidateTime = double.negativeInfinity;
  bool _candidateArmed = false;
  double _lastSyllableTime = double.negativeInfinity;

  List<VoiceFrame> add(Float32List samples) {
    _pending.addAll(samples);
    final frames = <VoiceFrame>[];
    var start = 0;
    while (_pending.length - start >= _frameSize) {
      var sum = 0.0;
      for (var i = start; i < start + _frameSize; i++) {
        sum += _pending[i] * _pending[i];
      }
      frames.add(_frame(sum / _frameSize));
      start += _frameSize;
    }
    _pending.removeRange(0, start);
    return frames;
  }

  VoiceFrame _frame(double energy) {
    final time = _index++ * frameMs / 1000;
    _energies.add(energy);
    if (_energies.length > _historyFrames) _energies.removeAt(0);
    final floor = _floor();
    final voiced = energy >= floor;
    final db = _db(energy);
    final syllable = _syllable(time, db, voiced);
    // The floor is 12 dB above the room: the room itself is 12 dB below it.
    return VoiceFrame(time: time, db: db, voiced: voiced, syllable: syllable, noiseDb: _db(floor) - 12);
  }

  static double _db(double energy) => 10 * log(max(energy, 1e-12)) / ln10;

  double _floor() {
    // Until a second of sound is in, there is no room to measure: a fixed -50 dBFS floor.
    if (_energies.length < 1000 ~/ frameMs) return 1e-5;
    final sorted = [..._energies]..sort();
    final noise = sorted[(sorted.length * 0.1).floor()];
    return max(noise * pow(10, 12 / 10), 1e-6).toDouble();
  }

  /// A candidate peak is armed once it rose 2 dB above the dip before it, and confirmed once the
  /// loudness falls 2 dB below it again.
  bool _syllable(double time, double db, bool voiced) {
    if (!voiced) {
      final confirmed = _confirm(time, db);
      _dipSincePeak = min(_dipSincePeak, db);
      return confirmed;
    }
    if (db > _candidateDb || !_candidateArmed) {
      if (db >= _dipSincePeak + _dipDb || _dipSincePeak == double.infinity) {
        _candidateDb = db;
        _candidateTime = time;
        _candidateArmed = true;
      }
      _dipSincePeak = min(_dipSincePeak, db);
      return false;
    }
    return _confirm(time, db);
  }

  bool _confirm(double time, double db) {
    if (!_candidateArmed || db > _candidateDb - _dipDb) return false;
    _candidateArmed = false;
    _dipSincePeak = db;
    _candidateDb = double.negativeInfinity;
    if (_candidateTime - _lastSyllableTime < _minSyllableGap) return false;
    _lastSyllableTime = _candidateTime;
    return true;
  }
}
