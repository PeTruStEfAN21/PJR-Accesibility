import 'dart:js_interop';
import 'dart:typed_data';

import 'yamnet_logic.dart';
import 'yamnet_model.dart';

YamnetModel createYamnetModel() => _TfjsYamnet();

@JS('echoYamnet.load')
external JSPromise<JSAny?> _load();

@JS('echoYamnet.run')
external JSPromise<_Result> _run(JSFloat32Array window);

extension type _Result(JSObject _) implements JSObject {
  external JSFloat32Array get scores;
  external JSFloat32Array get embedding;
}

/// TensorFlow.js YAMNet from web/models/yamnet, driven by web/js/yamnet.js.
class _TfjsYamnet implements YamnetModel {
  @override
  bool get isSupported => true;

  @override
  String get dangerHeadAsset => 'assets/models/danger_head_web.json';

  @override
  Future<void> load() => _load().toDart;

  @override
  Future<YamnetOutput> run(Float32List window) async {
    final result = await _run(window.toJS).toDart;
    return YamnetOutput(result.scores.toDart, result.embedding.toDart);
  }

  @override
  void close() {}
}
