// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Romanian Moldavian Moldovan (`ro`).
class AppLocalizationsRo extends AppLocalizations {
  AppLocalizationsRo([String locale = 'ro']) : super(locale);

  @override
  String get appTitle => 'Echo';

  @override
  String get homeTitle => 'Bună! Cu ce începem?';

  @override
  String get homeJoin => 'Sunt la un meeting';

  @override
  String get homeJoinHint => 'Vezi tot ce se spune și cine vorbește.';

  @override
  String get homePresent => 'Eu prezint';

  @override
  String get homePresentHint =>
      'Pornești meetingul și le arăți celorlalți codul.';

  @override
  String get homeSounds => 'Sunetele din jur';

  @override
  String get homeSoundsHint =>
      'Te anunțăm când sună o alarmă, un claxon sau cineva te strigă.';

  @override
  String get homeConversation => 'Vorbesc cu cineva';

  @override
  String get homeConversationHint =>
      'Vezi ce spune fiecare, chiar lângă fața lui.';

  @override
  String get homeElsewhere => 'În afara meetingurilor';

  @override
  String get homeOtherPresent => 'Tu prezinți? Deschide modul prezentator';

  @override
  String get homeOtherJoin => 'Participi la meeting? Intră de aici';

  @override
  String get tipTitle => 'Prima dată aici?';

  @override
  String get homeTipJoin =>
      'Începe de aici. Ceri codul de la cel care prezintă și urmărești meetingul pe ecran.';

  @override
  String get homeTipPresent =>
      'Începe de aici. Pornești meetingul, iar Echo îți dă un cod pe care îl arăți participanților.';

  @override
  String get tipGotIt => 'Am înțeles';

  @override
  String get tipSkip => 'Sari peste';

  @override
  String get tipSkipLabel => 'Sari peste toate indiciile';

  @override
  String get settings => 'Setări';

  @override
  String get close => 'Închide';

  @override
  String get retry => 'Reîncearcă';

  @override
  String get send => 'Trimite';

  @override
  String get joinTitle => 'Intră în meeting';

  @override
  String get joinIntro => 'Scrie codul de pe ecranul celui care prezintă.';

  @override
  String get joinServerChange => 'Schimbă';

  @override
  String get joinCodeLabel => 'Codul de pe ecranul prezentatorului';

  @override
  String get joinServerLabel => 'Adresa serverului';

  @override
  String get joinServerHint => 'de exemplu http://172.20.10.2:8000';

  @override
  String get joinButton => 'Intră';

  @override
  String get joinScan => 'Scanează codul QR';

  @override
  String get joinInvalidCode => 'Codul are 6 litere și cifre';

  @override
  String get joinInvalidServer =>
      'Adresa trebuie să înceapă cu http:// sau https://';

  @override
  String get joinInvalidQr => 'Codul QR nu este de la un meeting';

  @override
  String get connConnecting => 'Mă conectez…';

  @override
  String get connConnected => 'Conectat';

  @override
  String get connReconnecting => 'Conexiune pierdută. Reîncerc…';

  @override
  String get connClosed => 'Meetingul nu există sau s-a încheiat';

  @override
  String get presenterOnline => 'Prezentatorul e conectat';

  @override
  String get presenterOffline => 'Aștept prezentatorul';

  @override
  String get speakerCoordinator => 'Coordonator';

  @override
  String get speakerPublic => 'Public';

  @override
  String get captionsEmpty =>
      'Subtitrările apar aici când începe cineva să vorbească.';

  @override
  String get captionsLive => 'Subtitrări live';

  @override
  String get captionPartial => 'se transcrie';

  @override
  String get quickQuestion => 'Am o întrebare';

  @override
  String get quickRepeat => 'Puteți repeta?';

  @override
  String get quickSlower => 'Mai rar, vă rog';

  @override
  String get customMessageHint => 'Scrie un mesaj pentru prezentator';

  @override
  String messageSent(String text) {
    return 'Trimis: $text';
  }

  @override
  String messageSeen(String text) {
    return 'Prezentatorul a văzut: $text';
  }

  @override
  String get listenRoom => 'Ascultă și sala';

  @override
  String get listenRoomHint => 'Telefonul subtitrează întrebările din public';

  @override
  String get stopListening => 'Oprește ascultarea';

  @override
  String get speechUnavailable =>
      'Recunoașterea vorbirii nu e disponibilă. Verifică permisiunile pentru microfon și vorbire.';

  @override
  String get summaryAction => 'Rezumat și sarcini';

  @override
  String get summaryTitle => 'Rezumatul meetingului';

  @override
  String get summaryTasks => 'Sarcini';

  @override
  String get summaryNoTasks => 'Nicio sarcină.';

  @override
  String summaryOwner(String owner) {
    return 'Responsabil: $owner';
  }

  @override
  String get summaryPrivacy =>
      'Pentru rezumat se trimite doar textul transcrierii, niciodată audio.';

  @override
  String get askAction => 'Întreabă meetingul';

  @override
  String get askHint => 'De exemplu: Ce trebuie să fac eu?';

  @override
  String get askSources => 'Surse din transcriere';

  @override
  String get askThinking => 'Caut în transcriere…';

  @override
  String get transcriptEmpty => 'Nu există încă replici în transcriere.';

  @override
  String get aiError => 'AI-ul nu a putut răspunde. Încearcă din nou.';

  @override
  String get simplify => 'Simplifică';

  @override
  String get presenterTitle => 'Mod prezentator';

  @override
  String get presenterCodeLabel => 'Codul meetingului';

  @override
  String get presenterJoinHint =>
      'Participanții scanează codul QR sau introduc codul în aplicație.';

  @override
  String get presenterStart => 'Pornește subtitrarea';

  @override
  String get presenterStop => 'Oprește subtitrarea';

  @override
  String get presenterListening =>
      'Te ascult. Ce spui apare pe telefoanele participanților.';

  @override
  String get presenterNotifications => 'Mesaje de la participanți';

  @override
  String get presenterNoNotifications =>
      'Niciun mesaj încă. Mesajele apar aici fără sunet.';

  @override
  String get presenterMarkSeen => 'Am văzut';

  @override
  String get presenterSeen => 'Văzut';

  @override
  String presenterParticipants(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count participanți conectați',
      one: '1 participant conectat',
      zero: 'Niciun participant conectat',
    );
    return '$_temp0';
  }

  @override
  String get presenterCreateError =>
      'Nu pot crea meetingul. Verifică dacă serverul rulează.';

  @override
  String get soundFireAlarm => 'ALARMĂ DE INCENDIU';

  @override
  String get soundSiren => 'Sirenă';

  @override
  String get soundHorn => 'Claxon în apropiere';

  @override
  String get soundLineSignal => 'Semnal de linie';

  @override
  String get soundName => 'Cineva te strigă';

  @override
  String get soundPhone => 'Sună un telefon';

  @override
  String get soundDoor => 'Ușă sau sonerie';

  @override
  String alertExit(String exit) {
    return 'Ieșirea cea mai apropiată: $exit';
  }

  @override
  String get alertDismiss => 'Am înțeles';

  @override
  String get alertLevelCritical => 'CRITIC';

  @override
  String get alertLevelWarning => 'ATENȚIE';

  @override
  String get adviceFireAlarm =>
      'Ieși din clădire pe cea mai apropiată ieșire. Nu folosi liftul.';

  @override
  String get adviceSiren =>
      'Un vehicul de urgență sau o alertă publică. Fă loc și urmărește ce fac cei din jur.';

  @override
  String get adviceHorn =>
      'Un vehicul claxonează aproape. Oprește-te și uită-te în jur înainte să mergi mai departe.';

  @override
  String get adviceGlassBreak =>
      'S-a spart un geam în apropiere. Ferește-te de cioburi și uită-te în jur.';

  @override
  String get adviceLineSignal =>
      'Semnal de la un utilaj. Fii atent la mașinile din jur.';

  @override
  String get soundsTitle => 'Sunetul vizibil';

  @override
  String get soundsStart => 'Pornește ascultarea';

  @override
  String get soundsStop => 'Oprește ascultarea';

  @override
  String get soundsListening =>
      'Ascult sunetele din jur, și cu telefonul blocat. Pornesc singur la fiecare deschidere a aplicației.';

  @override
  String get soundsIdle => 'Ascultarea e oprită.';

  @override
  String get soundsPaused =>
      'Ascultarea e în pauză cât merge subtitrarea. Pornește din nou singură după.';

  @override
  String get soundsPill => 'Sunete';

  @override
  String get soundsPillOn => 'Sunetul vizibil: pornit';

  @override
  String get soundsPillOff => 'Sunetul vizibil: oprit';

  @override
  String get soundsPillPaused =>
      'Sunetul vizibil: în pauză cât merge subtitrarea';

  @override
  String get soundsTest => 'Testează alertele';

  @override
  String get soundsDetectorMissing =>
      'Recunoașterea sunetelor nu merge pe acest dispozitiv. Poți testa alertele de mai jos.';

  @override
  String get soundGlassBreak => 'Geam spart';

  @override
  String get soundLocation => 'Sunet al locației';

  @override
  String get alertOpenApp => 'Deschide Echo pentru detalii.';

  @override
  String get conversationTitle => 'Conversație';

  @override
  String get conversationPending =>
      'Baloanele lângă fețe sunt în lucru. Între timp, subtitrările apar mai jos.';

  @override
  String get settingsLanguage => 'Limba aplicației';

  @override
  String get settingsSpeechLanguage => 'Limba vorbită în meeting';

  @override
  String get languageSystem => 'Ca sistemul';

  @override
  String get settingsTextSize => 'Mărime text';

  @override
  String get settingsDyslexia => 'Mod dislexie';

  @override
  String get settingsDyslexiaHint => 'Font OpenDyslexic și spațiere mai mare';

  @override
  String get settingsPalette => 'Culori pentru roluri';

  @override
  String get paletteStandard => 'Standard';

  @override
  String get paletteProtanopia => 'Protanopie (roșu greu de văzut)';

  @override
  String get paletteDeuteranopia => 'Deuteranopie (verde greu de văzut)';

  @override
  String get paletteTritanopia => 'Tritanopie (albastru greu de văzut)';

  @override
  String get settingsHighContrast => 'Contrast ridicat';

  @override
  String get settingsTheme => 'Temă';

  @override
  String get themeSystem => 'Ca sistemul';

  @override
  String get themeLight => 'Luminoasă';

  @override
  String get themeDark => 'Întunecată';

  @override
  String get settingsAutoScroll => 'Derulare automată a subtitrărilor';

  @override
  String get settingsEmergencyExit => 'Ieșirea de urgență afișată la alarmă';

  @override
  String get settingsEmergencyExitHint =>
      'de exemplu Scara B, la stânga liftului';

  @override
  String get settingsServer => 'Adresa serverului';

  @override
  String get settingsPreview => 'Previzualizare';

  @override
  String get cancel => 'Anulează';

  @override
  String get save => 'Salvează';

  @override
  String get account => 'Contul meu';

  @override
  String get signIn => 'Intră în cont';

  @override
  String get signInIntro =>
      'Intră în cont ca să-ți salvezi meetingurile și să le revezi oricând. Nu ai nevoie de parolă.';

  @override
  String get signInEmailLabel => 'Adresa de email';

  @override
  String get signInSendCode => 'Trimite-mi un cod';

  @override
  String signInCodeSent(String email) {
    return 'Ți-am trimis un cod pe $email. Poți și să deschizi linkul din email.';
  }

  @override
  String get signInCodeLabel => 'Codul din email';

  @override
  String get signInVerify => 'Confirmă codul';

  @override
  String get signInOtherEmail => 'Folosește altă adresă';

  @override
  String get signInOr => 'sau';

  @override
  String get signInGoogle => 'Continuă cu Google';

  @override
  String get signInInvalidEmail => 'Adresa de email nu pare corectă';

  @override
  String get signInInvalidCode => 'Introdu codul din cifre primit pe email';

  @override
  String get signInFailed =>
      'Nu am putut intra în cont. Verifică datele și încearcă din nou.';

  @override
  String accountSignedInAs(String email) {
    return 'Ești conectat ca $email';
  }

  @override
  String get accountSignOut => 'Ieși din cont';

  @override
  String get accountDelete => 'Șterge contul';

  @override
  String get accountDeleteTitle => 'Ștergi contul?';

  @override
  String get accountDeleteBody =>
      'Se șterg definitiv contul, toate meetingurile salvate, transcrierile și rezumatele. Nu se poate anula.';

  @override
  String get accountDeleteConfirm => 'Șterge definitiv';

  @override
  String get accountError => 'Ceva nu a mers. Încearcă din nou.';

  @override
  String get homeHistory => 'Meetingurile mele';

  @override
  String get homeHistoryHint =>
      'Revezi transcrierile și rezumatele, întreabă orice meeting';

  @override
  String get historySearchHint => 'Caută în meetinguri';

  @override
  String get historyClearSearch => 'Șterge căutarea';

  @override
  String get historyEmpty =>
      'Nu ai încă meetinguri salvate. Când participi la un meeting cu contul deschis, transcrierea se salvează aici.';

  @override
  String historyNoResults(String query) {
    return 'Niciun meeting nu conține „$query”.';
  }

  @override
  String get historyLoadError => 'Nu am putut încărca meetingurile.';

  @override
  String historyUntitled(String date) {
    return 'Meeting din $date';
  }

  @override
  String get historyDelete => 'Șterge meetingul';

  @override
  String get historyDeleteTitle => 'Ștergi meetingul?';

  @override
  String get historyDeleteBody =>
      'Transcrierea și rezumatul acestui meeting se șterg definitiv.';

  @override
  String get historyDeleted => 'Meetingul a fost șters';

  @override
  String get meetingRename => 'Redenumește';

  @override
  String get meetingNameLabel => 'Numele meetingului';

  @override
  String get meetingSaving => 'Transcrierea se salvează în contul tău';
}
