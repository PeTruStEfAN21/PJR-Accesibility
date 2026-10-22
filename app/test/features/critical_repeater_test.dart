import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pjr_accesibilitate/features/alerts/critical_repeater.dart';

void main() {
  test('repeats every 10 s, at most 12 times', () {
    fakeAsync((async) {
      var fired = 0;
      CriticalRepeater(isForeground: () => false).start(() => fired++);
      async.elapse(const Duration(seconds: 9));
      expect(fired, 0);
      async.elapse(const Duration(seconds: 1));
      expect(fired, 1);
      async.elapse(const Duration(minutes: 5));
      expect(fired, 12);
    });
  });

  test('stops when the alert is acknowledged', () {
    fakeAsync((async) {
      var fired = 0;
      final repeater = CriticalRepeater(isForeground: () => false)..start(() => fired++);
      async.elapse(const Duration(seconds: 25));
      repeater.stop();
      async.elapse(const Duration(minutes: 1));
      expect(fired, 2);
    });
  });

  test('stops once the app is on screen (the red screen is visible)', () {
    fakeAsync((async) {
      var fired = 0;
      var foreground = false;
      CriticalRepeater(isForeground: () => foreground).start(() => fired++);
      async.elapse(const Duration(seconds: 10));
      foreground = true;
      async.elapse(const Duration(minutes: 1));
      foreground = false;
      async.elapse(const Duration(minutes: 1));
      expect(fired, 1);
    });
  });

  test('a new alert restarts the count', () {
    fakeAsync((async) {
      var fired = 0;
      final repeater = CriticalRepeater(isForeground: () => false)..start(() => fired++);
      async.elapse(const Duration(seconds: 100));
      repeater.start(() => fired++);
      async.elapse(const Duration(minutes: 5));
      expect(fired, 10 + 12);
    });
  });
}
