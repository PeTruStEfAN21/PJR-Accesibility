import 'alert_window.dart';

/// No window above other apps outside the browser: the alert stays on Echo's own screen.
class UnavailableAlertWindow implements AlertWindow {
  @override
  bool get supported => false;

  @override
  Future<bool> open({required String title, required String language, required void Function() onClosed}) async =>
      false;

  @override
  void show(String text, String icon, {required bool alert}) {}

  @override
  void close() {}
}

AlertWindow createAlertWindow() => UnavailableAlertWindow();
