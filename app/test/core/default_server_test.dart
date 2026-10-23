import 'package:flutter_test/flutter_test.dart';
import 'package:pjr_accesibilitate/core/services.dart';

void main() {
  final fallback = Uri.parse('http://localhost:8000');

  Uri resolve({String saved = '', bool web = false, String page = 'http://localhost:5173/'}) =>
      resolveServer(saved: saved, web: web, page: Uri.parse(page), fallback: fallback);

  test('a saved address always wins', () {
    expect(resolve(saved: 'http://172.20.10.2:8000', web: true, page: 'https://echo.onrender.com/'),
        Uri.parse('http://172.20.10.2:8000'));
  });

  test('the page served by the local server talks to it', () {
    expect(resolve(web: true, page: 'http://192.168.1.5:8000/#/'), Uri.parse('http://192.168.1.5:8000'));
  });

  test('a page on a hosted HTTPS address talks to that address', () {
    expect(resolve(web: true, page: 'https://pjr-accesibility.onrender.com/?v=2'),
        Uri.parse('https://pjr-accesibility.onrender.com'));
  });

  test('flutter run in Chrome keeps the local server', () {
    expect(resolve(web: true, page: 'http://localhost:5173/'), fallback);
  });

  test('the phone app uses the build address when nothing is saved', () {
    expect(resolve(page: 'file:///'), fallback);
  });
}
