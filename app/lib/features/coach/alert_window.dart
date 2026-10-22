import 'alert_window_stub.dart' if (dart.library.js_interop) 'alert_window_web.dart' as platform;

/// A small window that stays above the meeting app and shows the coach's alert, so the colleague sees it
/// without switching to Echo (Document Picture-in-Picture).
abstract class AlertWindow {
  /// Chrome or Edge on a computer, on https or localhost.
  bool get supported;

  /// Opens the window; it must follow a click. Its text is [textScale] times the normal size. [onClosed]
  /// runs when it closes, also when the colleague closes it. False when the browser refuses.
  Future<bool> open({
    required String title,
    required String language,
    required double textScale,
    required void Function() onClosed,
  });

  /// [icon] is a symbol shown before [text]; [alert] marks it as an alert rather than the quiet state.
  void show(String text, String icon, {required bool alert});

  void close();
}

AlertWindow createAlertWindow() => platform.createAlertWindow();
