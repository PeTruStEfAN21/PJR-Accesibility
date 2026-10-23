import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pjr_accesibilitate/core/services.dart';
import 'package:pjr_accesibilitate/features/account/account_screen.dart';
import 'package:pjr_accesibilitate/features/history/history_screen.dart';
import 'package:pjr_accesibilitate/features/organization/org_screen.dart';
import 'package:pjr_accesibilitate/l10n/app_localizations.dart';
import 'package:pjr_accesibilitate/settings/app_settings.dart';
import 'package:pjr_accesibilitate/theme/app_theme.dart';

import '../fakes.dart';

/// [screen] on a wide desktop window, signed in.
Future<TestHarness> wide(WidgetTester tester, Widget Function(TestHarness h) screen) async {
  tester.view.physicalSize = const Size(1536, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final h = await TestHarness.create(accounts: true);
  h.account!.signInAs('ion@firma.ro');
  await tester.pumpWidget(ServicesScope(
    services: AppServices(
      speech: h.speech,
      sounds: h.sounds,
      account: h.account,
      meetings: h.meetings,
      organizations: h.organizations,
      activity: h.activity,
    ),
    child: SettingsScope(
      settings: h.settings,
      child: MaterialApp(
        locale: const Locale('ro'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: buildTheme(h.settings),
        home: screen(h),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  return h;
}

/// The page's content sits in a centred column no wider than the other desktop forms.
void expectNarrow(WidgetTester tester, Finder content) {
  final rect = tester.getRect(content);
  expect(rect.width, lessThanOrEqualTo(560));
  expect(rect.center.dx, moreOrLessEquals(1536 / 2, epsilon: 1));
}

void main() {
  testWidgets('Contul meu keeps a narrow column on a desktop', (tester) async {
    await wide(tester, (h) => AccountScreen(account: h.account!, meetings: h.meetings!));
    expectNarrow(tester, find.ancestor(of: find.text('Meetingurile mele'), matching: find.byType(ListTile)));
  });

  testWidgets('Meetingurile mele keeps a narrow column on a desktop', (tester) async {
    await wide(tester, (h) => HistoryScreen(meetings: h.meetings!));
    expectNarrow(tester, find.byType(TextField).first);
  });

  testWidgets('Compania mea keeps a narrow column on a desktop', (tester) async {
    await wide(tester, (h) => OrgScreen(organizations: h.organizations!));
    expectNarrow(tester, find.byType(TextField).first);
  });
}
