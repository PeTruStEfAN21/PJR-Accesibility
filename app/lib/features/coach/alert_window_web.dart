import 'dart:js_interop';

import 'alert_window.dart';

/// `window.echoPip`, defined by `web/coach/pip.js`.
@JS('echoPip')
external _EchoPip? get _echoPip;

extension type _EchoPip._(JSObject _) implements JSObject {
  external bool supported();
  external JSPromise<JSBoolean> open(String title, String language, double textScale, JSFunction onClosed);
  external void show(String text, String icon, bool alert);
  external void close();
}

class WebAlertWindow implements AlertWindow {
  @override
  bool get supported => _echoPip?.supported() ?? false;

  @override
  Future<bool> open({
    required String title,
    required String language,
    required double textScale,
    required void Function() onClosed,
  }) async {
    final pip = _echoPip;
    if (pip == null) return false;
    try {
      return (await pip.open(title, language, textScale, onClosed.toJS).toDart).toDart;
    } on Object {
      return false;
    }
  }

  @override
  void show(String text, String icon, {required bool alert}) => _echoPip?.show(text, icon, alert);

  @override
  void close() => _echoPip?.close();
}

AlertWindow createAlertWindow() => WebAlertWindow();
