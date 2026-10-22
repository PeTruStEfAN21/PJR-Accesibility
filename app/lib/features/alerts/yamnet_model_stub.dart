import 'dart:typed_data';

import 'yamnet_logic.dart';
import 'yamnet_model.dart';

YamnetModel createYamnetModel() => _NoModel();

class _NoModel implements YamnetModel {
  @override
  bool get isSupported => false;

  @override
  String get dangerHeadAsset => 'assets/models/danger_head.json';

  @override
  Future<void> load() => Future.error(UnsupportedError('YAMNet is not available on this platform'));

  @override
  Future<YamnetOutput> run(Float32List window) => load().then((_) => throw StateError('unreachable'));

  @override
  void close() {}
}
