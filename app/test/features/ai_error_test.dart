import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pjr_accesibilitate/core/server_api.dart';
import 'package:pjr_accesibilitate/features/participant/meeting_ai.dart';
import 'package:pjr_accesibilitate/l10n/app_localizations.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('ro'));

  test('the server limit and a missing AI key each get their own message', () {
    expect(aiErrorMessage(l10n, ApiException(429, 'Too many AI requests')), l10n.aiErrorLimit);
    expect(aiErrorMessage(l10n, ApiException(503, 'AI not configured')), l10n.aiErrorOff);
  });

  test('any other failure keeps the generic message', () {
    expect(aiErrorMessage(l10n, ApiException(502, 'AI service unavailable')), l10n.aiError);
    expect(aiErrorMessage(l10n, Exception('offline')), l10n.aiError);
  });
}
