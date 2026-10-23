import 'dart:io';
import 'dart:typed_data';

import 'package:tflite_flutter/tflite_flutter.dart';

import 'yamnet_logic.dart';
import 'yamnet_model.dart';

YamnetModel createYamnetModel() => _TfliteYamnet();

/// assets/models/yamnet.tflite, rebuilt by tools/yamnet_embeddings.py: output 0 = scores, 1 = embedding.
class _TfliteYamnet implements YamnetModel {
  Interpreter? _interpreter;

  @override
  bool get isSupported => Platform.isIOS || Platform.isAndroid;

  @override
  String get dangerHeadAsset => 'assets/models/danger_head.json';

  @override
  Future<void> load() async {
    _interpreter ??= await Interpreter.fromAsset('assets/models/yamnet.tflite');
  }

  @override
  Future<YamnetOutput> run(Float32List window) async {
    final interpreter = _interpreter!;
    interpreter.getInputTensor(0).setTo(window.buffer.asUint8List(window.offsetInBytes, window.lengthInBytes));
    interpreter.invoke();
    return YamnetOutput(_floats(interpreter.getOutputTensor(0)), _floats(interpreter.getOutputTensor(1)));
  }

  // copyTo rejects a buffer of another size; data is a view of the interpreter's memory,
  // so it is copied before the next invoke overwrites it.
  Float32List _floats(Tensor tensor) => Uint8List.fromList(tensor.data).buffer.asFloat32List();

  @override
  void close() {
    _interpreter?.close();
    _interpreter = null;
  }
}
