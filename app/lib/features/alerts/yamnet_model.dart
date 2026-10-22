import 'dart:typed_data';

import 'yamnet_logic.dart';
import 'yamnet_model_stub.dart'
    if (dart.library.js_interop) 'yamnet_model_web.dart'
    if (dart.library.ffi) 'yamnet_model_native.dart' as platform;

/// YAMNet on this device: TFLite on iOS / Android, TensorFlow.js in the browser.
abstract class YamnetModel {
  bool get isSupported;

  /// The trained danger-sound head for this model's embeddings (phone and browser YAMNet differ).
  String get dangerHeadAsset;
  Future<void> load();
  Future<YamnetOutput> run(Float32List window);
  void close();
}

YamnetModel createYamnetModel() => platform.createYamnetModel();
