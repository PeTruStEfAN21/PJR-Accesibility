import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pjr_accesibilitate/app.dart';
import 'package:pjr_accesibilitate/core/services.dart';
import 'package:pjr_accesibilitate/features/emergency/alarm_logic.dart';
import 'package:pjr_accesibilitate/features/emergency/position_source.dart';

import 'package:pjr_accesibilitate/features/emergency/alarm_scope.dart';

import '../fakes.dart';

class _Positions implements PositionSource {
  int currentCalls = 0;

  @override
  Future<Position?> current({Duration timeout = const Duration(seconds: 5)}) async {
    currentCalls++;
    return const Position(lat: 44.0, lon: 26.0, accuracyM: 10);
  }

  @override
  Future<Position?> lastKnown() async => null;
}

Map<String, Object> _fire(String id) =>
    {'type': 'alarm', 'id': id, 'kind': 'fire', 'at': 1792800000.0, 'lat': 44.0, 'lon': 26.0, 'accuracy_m': 10.0};

void main() {
  late TestHarness h;
  late _Positions positions;
  late List<FakeChannel> channels;

  Widget app({required bool signedIn}) {
    channels = [];
    positions = _Positions();
    if (signedIn) h.account!.signInAs('a@example.com');
    return EchoApp(
      settings: h.settings,
      alerts: h.alerts,
      services: AppServices(
        speech: h.speech,
        sounds: h.sounds,
        tts: h.tts,
        voice: h.voice,
        positions: positions,
        channelFactory: (uri) {
          final channel = FakeChannel()..uri = uri;
          channels.add(channel);
          return channel;
        },
        account: h.account,
        meetings: h.meetings,
      ),
    );
  }

  testWidgets('signed in: a colleague alarm covers the screen', (tester) async {
    h = await TestHarness.create(accounts: true);
    await tester.pumpWidget(app(signedIn: true));
    await tester.pump();

    expect(channels, hasLength(1));
    expect(channels.single.uri!.path, '/ws/alarms');
    expect(positions.currentCalls, greaterThan(0));
    channels.single.receive(_fire('a1'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Incendiu · semnalat de un coleg'), findsOneWidget);
    expect(find.textContaining('Ieși din clădire'), findsOneWidget);

    // The alert controller outlives the app here and may hold a timer.
    await tester.pumpWidget(const SizedBox());
    h.alerts.dismiss();
  });

  testWidgets('signed out: no socket is opened', (tester) async {
    h = await TestHarness.create(accounts: true);
    await tester.pumpWidget(app(signedIn: false));
    await tester.pump();

    expect(channels, isEmpty);
    expect(AlarmScope.maybeOf(tester.element(find.byType(MaterialApp))), isNull);
  });

  testWidgets('signing in starts the feed', (tester) async {
    h = await TestHarness.create(accounts: true);
    await tester.pumpWidget(app(signedIn: false));
    h.account!.signInAs('a@example.com');
    await tester.pump();

    expect(channels, hasLength(1));
    expect(AlarmScope.maybeOf(tester.element(find.byType(MaterialApp))), isNotNull);
  });

  testWidgets('signing out stops the feed', (tester) async {
    h = await TestHarness.create(accounts: true);
    await tester.pumpWidget(app(signedIn: true));
    await tester.pump();
    final old = channels.single;

    await h.account!.signOut();
    await tester.pump();
    old.receive(_fire('a2'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Incendiu · semnalat de un coleg'), findsNothing);
  });
}
