import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ro.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ro'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In ro, this message translates to:
  /// **'Echo'**
  String get appTitle;

  /// No description provided for @homeTitle.
  ///
  /// In ro, this message translates to:
  /// **'Ce vrei să faci?'**
  String get homeTitle;

  /// No description provided for @homeJoin.
  ///
  /// In ro, this message translates to:
  /// **'Conectează-te la speaker'**
  String get homeJoin;

  /// No description provided for @homeJoinHint.
  ///
  /// In ro, this message translates to:
  /// **'Vezi ce se spune în sală și pune întrebări speakerului'**
  String get homeJoinHint;

  /// No description provided for @homePresent.
  ///
  /// In ro, this message translates to:
  /// **'Prezint'**
  String get homePresent;

  /// No description provided for @homePresentHint.
  ///
  /// In ro, this message translates to:
  /// **'Lasă laptopul în fața ta și arată codul participanților'**
  String get homePresentHint;

  /// No description provided for @homeSounds.
  ///
  /// In ro, this message translates to:
  /// **'Sunetul vizibil'**
  String get homeSounds;

  /// No description provided for @homeSoundsHint.
  ///
  /// In ro, this message translates to:
  /// **'Alerte pentru alarme, claxoane și numele tău'**
  String get homeSoundsHint;

  /// No description provided for @homeConversation.
  ///
  /// In ro, this message translates to:
  /// **'Conversație'**
  String get homeConversation;

  /// No description provided for @homeConversationHint.
  ///
  /// In ro, this message translates to:
  /// **'Subtitrări lângă fața fiecărui vorbitor'**
  String get homeConversationHint;

  /// No description provided for @settings.
  ///
  /// In ro, this message translates to:
  /// **'Setări'**
  String get settings;

  /// No description provided for @close.
  ///
  /// In ro, this message translates to:
  /// **'Închide'**
  String get close;

  /// No description provided for @retry.
  ///
  /// In ro, this message translates to:
  /// **'Reîncearcă'**
  String get retry;

  /// No description provided for @send.
  ///
  /// In ro, this message translates to:
  /// **'Trimite'**
  String get send;

  /// No description provided for @joinTitle.
  ///
  /// In ro, this message translates to:
  /// **'Conectează-te la speaker'**
  String get joinTitle;

  /// No description provided for @joinCodeLabel.
  ///
  /// In ro, this message translates to:
  /// **'Codul de pe laptopul speakerului'**
  String get joinCodeLabel;

  /// No description provided for @joinServerLabel.
  ///
  /// In ro, this message translates to:
  /// **'Adresa serverului'**
  String get joinServerLabel;

  /// No description provided for @joinServerHint.
  ///
  /// In ro, this message translates to:
  /// **'de exemplu http://172.20.10.2:8000'**
  String get joinServerHint;

  /// No description provided for @joinButton.
  ///
  /// In ro, this message translates to:
  /// **'Intră'**
  String get joinButton;

  /// No description provided for @joinScan.
  ///
  /// In ro, this message translates to:
  /// **'Scanează codul QR'**
  String get joinScan;

  /// No description provided for @joinInvalidCode.
  ///
  /// In ro, this message translates to:
  /// **'Codul are 6 litere și cifre'**
  String get joinInvalidCode;

  /// No description provided for @joinInvalidServer.
  ///
  /// In ro, this message translates to:
  /// **'Adresa trebuie să înceapă cu http:// sau https://'**
  String get joinInvalidServer;

  /// No description provided for @joinInvalidQr.
  ///
  /// In ro, this message translates to:
  /// **'Codul QR nu este de la un meeting'**
  String get joinInvalidQr;

  /// No description provided for @connConnecting.
  ///
  /// In ro, this message translates to:
  /// **'Mă conectez…'**
  String get connConnecting;

  /// No description provided for @connConnected.
  ///
  /// In ro, this message translates to:
  /// **'Conectat'**
  String get connConnected;

  /// No description provided for @connReconnecting.
  ///
  /// In ro, this message translates to:
  /// **'Conexiune pierdută. Reîncerc…'**
  String get connReconnecting;

  /// No description provided for @connClosed.
  ///
  /// In ro, this message translates to:
  /// **'Meetingul nu există sau s-a încheiat'**
  String get connClosed;

  /// No description provided for @presenterOnline.
  ///
  /// In ro, this message translates to:
  /// **'Prezentatorul e conectat'**
  String get presenterOnline;

  /// No description provided for @presenterOffline.
  ///
  /// In ro, this message translates to:
  /// **'Aștept prezentatorul'**
  String get presenterOffline;

  /// No description provided for @speakerCoordinator.
  ///
  /// In ro, this message translates to:
  /// **'Speaker'**
  String get speakerCoordinator;

  /// No description provided for @speakerPublic.
  ///
  /// In ro, this message translates to:
  /// **'Din sală'**
  String get speakerPublic;

  /// No description provided for @captionsEmpty.
  ///
  /// In ro, this message translates to:
  /// **'Subtitrările apar aici când începe cineva să vorbească.'**
  String get captionsEmpty;

  /// No description provided for @captionsLive.
  ///
  /// In ro, this message translates to:
  /// **'Subtitrări live'**
  String get captionsLive;

  /// No description provided for @captionPartial.
  ///
  /// In ro, this message translates to:
  /// **'se transcrie'**
  String get captionPartial;

  /// No description provided for @quickQuestion.
  ///
  /// In ro, this message translates to:
  /// **'Am o întrebare'**
  String get quickQuestion;

  /// No description provided for @quickRepeat.
  ///
  /// In ro, this message translates to:
  /// **'Puteți repeta?'**
  String get quickRepeat;

  /// No description provided for @quickSlower.
  ///
  /// In ro, this message translates to:
  /// **'Mai rar, vă rog'**
  String get quickSlower;

  /// No description provided for @customMessageHint.
  ///
  /// In ro, this message translates to:
  /// **'Scrie un mesaj pentru prezentator'**
  String get customMessageHint;

  /// No description provided for @messageSent.
  ///
  /// In ro, this message translates to:
  /// **'Trimis: {text}'**
  String messageSent(String text);

  /// No description provided for @messageSeen.
  ///
  /// In ro, this message translates to:
  /// **'Prezentatorul a văzut: {text}'**
  String messageSeen(String text);

  /// No description provided for @myQuestionButton.
  ///
  /// In ro, this message translates to:
  /// **'Vreau să întreb'**
  String get myQuestionButton;

  /// No description provided for @myQuestionHint.
  ///
  /// In ro, this message translates to:
  /// **'Scrie întrebarea'**
  String get myQuestionHint;

  /// No description provided for @myQuestionSend.
  ///
  /// In ro, this message translates to:
  /// **'Trimite întrebarea'**
  String get myQuestionSend;

  /// No description provided for @myQuestionHandSent.
  ///
  /// In ro, this message translates to:
  /// **'Speakerul știe că vrei să întrebi'**
  String get myQuestionHandSent;

  /// No description provided for @myQuestionSent.
  ///
  /// In ro, this message translates to:
  /// **'Trimisă, așteaptă să fie citită'**
  String get myQuestionSent;

  /// No description provided for @myQuestionRead.
  ///
  /// In ro, this message translates to:
  /// **'Citită, se așteaptă răspunsul'**
  String get myQuestionRead;

  /// No description provided for @myQuestionNotFound.
  ///
  /// In ro, this message translates to:
  /// **'Nu am găsit încă un răspuns'**
  String get myQuestionNotFound;

  /// No description provided for @myQuestionRetry.
  ///
  /// In ro, this message translates to:
  /// **'Caută răspunsul'**
  String get myQuestionRetry;

  /// No description provided for @answeredTitle.
  ///
  /// In ro, this message translates to:
  /// **'Ți s-a răspuns'**
  String get answeredTitle;

  /// No description provided for @answeredQuestion.
  ///
  /// In ro, this message translates to:
  /// **'Întrebarea ta: {text}'**
  String answeredQuestion(String text);

  /// No description provided for @answeredAnnouncement.
  ///
  /// In ro, this message translates to:
  /// **'Ți s-a răspuns: {answer}'**
  String answeredAnnouncement(String answer);

  /// No description provided for @roomQuestion.
  ///
  /// In ro, this message translates to:
  /// **'Întrebare din sală'**
  String get roomQuestion;

  /// No description provided for @listenRoom.
  ///
  /// In ro, this message translates to:
  /// **'Ascultă și sala'**
  String get listenRoom;

  /// No description provided for @listenRoomHint.
  ///
  /// In ro, this message translates to:
  /// **'Telefonul subtitrează întrebările din public'**
  String get listenRoomHint;

  /// No description provided for @stopListening.
  ///
  /// In ro, this message translates to:
  /// **'Oprește ascultarea'**
  String get stopListening;

  /// No description provided for @speechUnavailable.
  ///
  /// In ro, this message translates to:
  /// **'Recunoașterea vorbirii nu e disponibilă. Verifică permisiunile pentru microfon și vorbire.'**
  String get speechUnavailable;

  /// No description provided for @summaryAction.
  ///
  /// In ro, this message translates to:
  /// **'Rezumat și sarcini'**
  String get summaryAction;

  /// No description provided for @summaryTitle.
  ///
  /// In ro, this message translates to:
  /// **'Rezumatul meetingului'**
  String get summaryTitle;

  /// No description provided for @summaryTasks.
  ///
  /// In ro, this message translates to:
  /// **'Sarcini'**
  String get summaryTasks;

  /// No description provided for @summaryNoTasks.
  ///
  /// In ro, this message translates to:
  /// **'Nicio sarcină.'**
  String get summaryNoTasks;

  /// No description provided for @summaryOwner.
  ///
  /// In ro, this message translates to:
  /// **'Responsabil: {owner}'**
  String summaryOwner(String owner);

  /// No description provided for @summaryPrivacy.
  ///
  /// In ro, this message translates to:
  /// **'Pentru rezumat se trimite doar textul transcrierii, niciodată audio.'**
  String get summaryPrivacy;

  /// No description provided for @askAction.
  ///
  /// In ro, this message translates to:
  /// **'Întreabă meetingul'**
  String get askAction;

  /// No description provided for @askHint.
  ///
  /// In ro, this message translates to:
  /// **'De exemplu: Ce trebuie să fac eu?'**
  String get askHint;

  /// No description provided for @askSources.
  ///
  /// In ro, this message translates to:
  /// **'Surse din transcriere'**
  String get askSources;

  /// No description provided for @askThinking.
  ///
  /// In ro, this message translates to:
  /// **'Caut în transcriere…'**
  String get askThinking;

  /// No description provided for @transcriptEmpty.
  ///
  /// In ro, this message translates to:
  /// **'Nu există încă replici în transcriere.'**
  String get transcriptEmpty;

  /// No description provided for @aiError.
  ///
  /// In ro, this message translates to:
  /// **'AI-ul nu a putut răspunde. Încearcă din nou.'**
  String get aiError;

  /// No description provided for @simplify.
  ///
  /// In ro, this message translates to:
  /// **'Simplifică'**
  String get simplify;

  /// No description provided for @presenterTitle.
  ///
  /// In ro, this message translates to:
  /// **'Mod prezentator'**
  String get presenterTitle;

  /// No description provided for @presenterCodeLabel.
  ///
  /// In ro, this message translates to:
  /// **'Codul meetingului'**
  String get presenterCodeLabel;

  /// No description provided for @presenterJoinHint.
  ///
  /// In ro, this message translates to:
  /// **'Participanții scanează codul QR sau introduc codul în aplicație.'**
  String get presenterJoinHint;

  /// No description provided for @presenterStart.
  ///
  /// In ro, this message translates to:
  /// **'Pornește subtitrarea'**
  String get presenterStart;

  /// No description provided for @presenterStop.
  ///
  /// In ro, this message translates to:
  /// **'Oprește subtitrarea'**
  String get presenterStop;

  /// No description provided for @presenterListening.
  ///
  /// In ro, this message translates to:
  /// **'Te ascult. Ce spui apare pe telefoanele participanților.'**
  String get presenterListening;

  /// No description provided for @presenterNotifications.
  ///
  /// In ro, this message translates to:
  /// **'Mesaje de la participanți'**
  String get presenterNotifications;

  /// No description provided for @presenterNoNotifications.
  ///
  /// In ro, this message translates to:
  /// **'Niciun mesaj încă. Mesajele apar aici fără sunet.'**
  String get presenterNoNotifications;

  /// No description provided for @presenterMarkSeen.
  ///
  /// In ro, this message translates to:
  /// **'Am văzut'**
  String get presenterMarkSeen;

  /// No description provided for @presenterSeen.
  ///
  /// In ro, this message translates to:
  /// **'Văzut'**
  String get presenterSeen;

  /// No description provided for @presenterParticipants.
  ///
  /// In ro, this message translates to:
  /// **'{count, plural, =0{Niciun participant conectat} =1{1 participant conectat} other{{count} participanți conectați}}'**
  String presenterParticipants(int count);

  /// No description provided for @presenterHand.
  ///
  /// In ro, this message translates to:
  /// **'Persoana care folosește Echo vrea să pună o întrebare'**
  String get presenterHand;

  /// No description provided for @presenterQuestionTitle.
  ///
  /// In ro, this message translates to:
  /// **'Întrebare de la persoana care folosește Echo'**
  String get presenterQuestionTitle;

  /// No description provided for @presenterReadAloud.
  ///
  /// In ro, this message translates to:
  /// **'Citește cu voce tare'**
  String get presenterReadAloud;

  /// No description provided for @presenterReadMyself.
  ///
  /// In ro, this message translates to:
  /// **'Am citit-o eu'**
  String get presenterReadMyself;

  /// No description provided for @presenterRead.
  ///
  /// In ro, this message translates to:
  /// **'Citită'**
  String get presenterRead;

  /// No description provided for @presenterReading.
  ///
  /// In ro, this message translates to:
  /// **'Citesc întrebarea…'**
  String get presenterReading;

  /// No description provided for @presenterNoVoice.
  ///
  /// In ro, this message translates to:
  /// **'Laptopul nu are o voce în limba asta; citește-o tu'**
  String get presenterNoVoice;

  /// No description provided for @presenterReadFailed.
  ///
  /// In ro, this message translates to:
  /// **'Nu am putut citi întrebarea; citește-o tu'**
  String get presenterReadFailed;

  /// No description provided for @presenterForceSpeaker.
  ///
  /// In ro, this message translates to:
  /// **'Vorbesc eu'**
  String get presenterForceSpeaker;

  /// No description provided for @presenterForceSpeakerHint.
  ///
  /// In ro, this message translates to:
  /// **'Tot ce se aude apare ca spus de tine'**
  String get presenterForceSpeakerHint;

  /// No description provided for @presenterCreateError.
  ///
  /// In ro, this message translates to:
  /// **'Nu pot crea meetingul. Verifică dacă serverul rulează.'**
  String get presenterCreateError;

  /// No description provided for @soundFireAlarm.
  ///
  /// In ro, this message translates to:
  /// **'ALARMĂ DE INCENDIU'**
  String get soundFireAlarm;

  /// No description provided for @soundSiren.
  ///
  /// In ro, this message translates to:
  /// **'Sirenă'**
  String get soundSiren;

  /// No description provided for @soundHorn.
  ///
  /// In ro, this message translates to:
  /// **'Claxon în apropiere'**
  String get soundHorn;

  /// No description provided for @soundLineSignal.
  ///
  /// In ro, this message translates to:
  /// **'Semnal de linie'**
  String get soundLineSignal;

  /// No description provided for @soundName.
  ///
  /// In ro, this message translates to:
  /// **'Cineva te strigă'**
  String get soundName;

  /// No description provided for @soundPhone.
  ///
  /// In ro, this message translates to:
  /// **'Sună un telefon'**
  String get soundPhone;

  /// No description provided for @soundDoor.
  ///
  /// In ro, this message translates to:
  /// **'Ușă sau sonerie'**
  String get soundDoor;

  /// No description provided for @alertExit.
  ///
  /// In ro, this message translates to:
  /// **'Ieșirea cea mai apropiată: {exit}'**
  String alertExit(String exit);

  /// No description provided for @alertDismiss.
  ///
  /// In ro, this message translates to:
  /// **'Am înțeles'**
  String get alertDismiss;

  /// No description provided for @soundsTitle.
  ///
  /// In ro, this message translates to:
  /// **'Sunetul vizibil'**
  String get soundsTitle;

  /// No description provided for @soundsStart.
  ///
  /// In ro, this message translates to:
  /// **'Pornește ascultarea'**
  String get soundsStart;

  /// No description provided for @soundsStop.
  ///
  /// In ro, this message translates to:
  /// **'Oprește ascultarea'**
  String get soundsStop;

  /// No description provided for @soundsListening.
  ///
  /// In ro, this message translates to:
  /// **'Ascult sunetele din jur. Alertele apar peste orice ecran.'**
  String get soundsListening;

  /// No description provided for @soundsIdle.
  ///
  /// In ro, this message translates to:
  /// **'Ascultarea e oprită.'**
  String get soundsIdle;

  /// No description provided for @soundsTest.
  ///
  /// In ro, this message translates to:
  /// **'Testează alertele'**
  String get soundsTest;

  /// No description provided for @soundsDetectorMissing.
  ///
  /// In ro, this message translates to:
  /// **'Detectorul de sunete (YAMNet) nu e încă conectat. Poți testa alertele de mai jos.'**
  String get soundsDetectorMissing;

  /// No description provided for @conversationTitle.
  ///
  /// In ro, this message translates to:
  /// **'Conversație'**
  String get conversationTitle;

  /// No description provided for @conversationPending.
  ///
  /// In ro, this message translates to:
  /// **'Baloanele lângă fețe sunt în lucru. Între timp, subtitrările apar mai jos.'**
  String get conversationPending;

  /// No description provided for @settingsLanguage.
  ///
  /// In ro, this message translates to:
  /// **'Limba aplicației'**
  String get settingsLanguage;

  /// No description provided for @settingsSpeechLanguage.
  ///
  /// In ro, this message translates to:
  /// **'Limba vorbită în meeting'**
  String get settingsSpeechLanguage;

  /// No description provided for @languageSystem.
  ///
  /// In ro, this message translates to:
  /// **'Ca sistemul'**
  String get languageSystem;

  /// No description provided for @settingsTextSize.
  ///
  /// In ro, this message translates to:
  /// **'Mărime text'**
  String get settingsTextSize;

  /// No description provided for @settingsDyslexia.
  ///
  /// In ro, this message translates to:
  /// **'Mod dislexie'**
  String get settingsDyslexia;

  /// No description provided for @settingsDyslexiaHint.
  ///
  /// In ro, this message translates to:
  /// **'Font OpenDyslexic și spațiere mai mare'**
  String get settingsDyslexiaHint;

  /// No description provided for @settingsPalette.
  ///
  /// In ro, this message translates to:
  /// **'Culori pentru roluri'**
  String get settingsPalette;

  /// No description provided for @paletteStandard.
  ///
  /// In ro, this message translates to:
  /// **'Standard'**
  String get paletteStandard;

  /// No description provided for @paletteProtanopia.
  ///
  /// In ro, this message translates to:
  /// **'Protanopie (roșu greu de văzut)'**
  String get paletteProtanopia;

  /// No description provided for @paletteDeuteranopia.
  ///
  /// In ro, this message translates to:
  /// **'Deuteranopie (verde greu de văzut)'**
  String get paletteDeuteranopia;

  /// No description provided for @paletteTritanopia.
  ///
  /// In ro, this message translates to:
  /// **'Tritanopie (albastru greu de văzut)'**
  String get paletteTritanopia;

  /// No description provided for @settingsHighContrast.
  ///
  /// In ro, this message translates to:
  /// **'Contrast ridicat'**
  String get settingsHighContrast;

  /// No description provided for @settingsTheme.
  ///
  /// In ro, this message translates to:
  /// **'Temă'**
  String get settingsTheme;

  /// No description provided for @themeSystem.
  ///
  /// In ro, this message translates to:
  /// **'Ca sistemul'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In ro, this message translates to:
  /// **'Luminoasă'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In ro, this message translates to:
  /// **'Întunecată'**
  String get themeDark;

  /// No description provided for @settingsAutoScroll.
  ///
  /// In ro, this message translates to:
  /// **'Derulare automată a subtitrărilor'**
  String get settingsAutoScroll;

  /// No description provided for @settingsEmergencyExit.
  ///
  /// In ro, this message translates to:
  /// **'Ieșirea de urgență afișată la alarmă'**
  String get settingsEmergencyExit;

  /// No description provided for @settingsEmergencyExitHint.
  ///
  /// In ro, this message translates to:
  /// **'de exemplu Scara B, la stânga liftului'**
  String get settingsEmergencyExitHint;

  /// No description provided for @settingsServer.
  ///
  /// In ro, this message translates to:
  /// **'Adresa serverului'**
  String get settingsServer;

  /// No description provided for @settingsPreview.
  ///
  /// In ro, this message translates to:
  /// **'Previzualizare'**
  String get settingsPreview;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ro'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ro':
      return AppLocalizationsRo();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
