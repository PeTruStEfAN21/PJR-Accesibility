import 'package:flutter_test/flutter_test.dart';
import 'package:pjr_accesibilitate/core/echo_filter.dart';

void main() {
  final t0 = DateTime(2026, 10, 23, 16);

  test('nothing is an echo before the coordinator speaks', () {
    expect(EchoFilter().isEcho('am o întrebare', t0), isFalse);
  });

  test('anything heard while the coordinator is speaking is an echo', () {
    final filter = EchoFilter()..coordinatorSpoke('azi discutăm bugetul', t0);
    expect(filter.isEcho('altceva complet', t0.add(const Duration(milliseconds: 800))), isTrue);
  });

  test('a late copy of the coordinator words is an echo', () {
    final filter = EchoFilter()..coordinatorSpoke('azi discutăm bugetul pe trimestrul trei', t0);
    expect(filter.isEcho('Azi discutăm bugetul', t0.add(const Duration(seconds: 4))), isTrue);
  });

  test('a different question after a pause is kept', () {
    final filter = EchoFilter()..coordinatorSpoke('azi discutăm bugetul', t0);
    expect(filter.isEcho('cine se ocupă de raport', t0.add(const Duration(seconds: 3))), isFalse);
  });

  test('old coordinator lines are forgotten', () {
    final filter = EchoFilter()..coordinatorSpoke('azi discutăm bugetul', t0);
    expect(filter.isEcho('azi discutăm bugetul', t0.add(const Duration(seconds: 30))), isFalse);
  });
}
