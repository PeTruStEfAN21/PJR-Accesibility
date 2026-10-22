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
  /// **'Bună! Cu ce începem?'**
  String get homeTitle;

  /// No description provided for @homeJoin.
  ///
  /// In ro, this message translates to:
  /// **'Conectează-te la speaker'**
  String get homeJoin;

  /// No description provided for @homeJoinHint.
  ///
  /// In ro, this message translates to:
  /// **'Vezi ce se spune în sală și pune întrebări speakerului.'**
  String get homeJoinHint;

  /// No description provided for @homePresent.
  ///
  /// In ro, this message translates to:
  /// **'Eu prezint'**
  String get homePresent;

  /// No description provided for @homePresentHint.
  ///
  /// In ro, this message translates to:
  /// **'Pornești meetingul și le arăți celorlalți codul.'**
  String get homePresentHint;

  /// No description provided for @homeConversation.
  ///
  /// In ro, this message translates to:
  /// **'Vorbesc cu cineva'**
  String get homeConversation;

  /// No description provided for @homeConversationHint.
  ///
  /// In ro, this message translates to:
  /// **'Vezi ce spune fiecare, chiar lângă fața lui.'**
  String get homeConversationHint;

  /// No description provided for @homeElsewhere.
  ///
  /// In ro, this message translates to:
  /// **'În afara meetingurilor'**
  String get homeElsewhere;

  /// No description provided for @homeOtherPresent.
  ///
  /// In ro, this message translates to:
  /// **'Tu prezinți? Deschide modul prezentator'**
  String get homeOtherPresent;

  /// No description provided for @homeOtherJoin.
  ///
  /// In ro, this message translates to:
  /// **'Participi la meeting? Intră de aici'**
  String get homeOtherJoin;

  /// No description provided for @tipTitle.
  ///
  /// In ro, this message translates to:
  /// **'Prima dată aici?'**
  String get tipTitle;

  /// No description provided for @homeTipJoin.
  ///
  /// In ro, this message translates to:
  /// **'Începe de aici. Ceri codul de la cel care prezintă și urmărești meetingul pe ecran.'**
  String get homeTipJoin;

  /// No description provided for @homeTipPresent.
  ///
  /// In ro, this message translates to:
  /// **'Începe de aici. Pornești meetingul, iar Echo îți dă un cod pe care îl arăți participanților.'**
  String get homeTipPresent;

  /// No description provided for @tipGotIt.
  ///
  /// In ro, this message translates to:
  /// **'Am înțeles'**
  String get tipGotIt;

  /// No description provided for @tipSkip.
  ///
  /// In ro, this message translates to:
  /// **'Sari peste'**
  String get tipSkip;

  /// No description provided for @tipSkipLabel.
  ///
  /// In ro, this message translates to:
  /// **'Sari peste toate indiciile'**
  String get tipSkipLabel;

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

  /// No description provided for @joinIntro.
  ///
  /// In ro, this message translates to:
  /// **'Scrie codul de pe laptopul speakerului.'**
  String get joinIntro;

  /// No description provided for @joinServerChange.
  ///
  /// In ro, this message translates to:
  /// **'Schimbă'**
  String get joinServerChange;

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
  /// **'Am trimis semnalul către speaker'**
  String get myQuestionHandSent;

  /// No description provided for @myQuestionHandSeen.
  ///
  /// In ro, this message translates to:
  /// **'Speakerul a văzut că vrei să întrebi'**
  String get myQuestionHandSeen;

  /// No description provided for @myQuestionOffline.
  ///
  /// In ro, this message translates to:
  /// **'Speakerul nu e conectat încă'**
  String get myQuestionOffline;

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

  /// No description provided for @aiErrorLimit.
  ///
  /// In ro, this message translates to:
  /// **'AI-ul a primit prea multe cereri în ultima oră. Încearcă din nou mai târziu.'**
  String get aiErrorLimit;

  /// No description provided for @aiErrorOff.
  ///
  /// In ro, this message translates to:
  /// **'AI-ul nu e pornit pe server. Subtitrările merg în continuare.'**
  String get aiErrorOff;

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

  /// No description provided for @enrollTitle.
  ///
  /// In ro, this message translates to:
  /// **'Învață vocea ta'**
  String get enrollTitle;

  /// No description provided for @enrollIntro.
  ///
  /// In ro, this message translates to:
  /// **'Citește textul de mai jos cu voce normală, cam 20 de secunde. Așa Echo îți recunoaște vocea și știe când vorbești tu și când vorbește cineva din sală. Sunetul rămâne pe acest laptop.'**
  String get enrollIntro;

  /// No description provided for @enrollText.
  ///
  /// In ro, this message translates to:
  /// **'Bună ziua tuturor. Astăzi vorbim despre planurile echipei pentru luna următoare. Trecem prin bugetul proiectului, prin termenele importante și prin sarcinile fiecăruia. Dacă aveți întrebări, le puteți pune oricând. Vă mulțumesc că sunteți aici și sper să avem o discuție utilă, clară și scurtă. Să începem cu subiectele cele mai urgente.'**
  String get enrollText;

  /// No description provided for @enrollStart.
  ///
  /// In ro, this message translates to:
  /// **'Începe'**
  String get enrollStart;

  /// No description provided for @enrollListening.
  ///
  /// In ro, this message translates to:
  /// **'Te ascult… citește textul'**
  String get enrollListening;

  /// No description provided for @enrollDone.
  ///
  /// In ro, this message translates to:
  /// **'Vocea ta e învățată'**
  String get enrollDone;

  /// No description provided for @enrollTooShort.
  ///
  /// In ro, this message translates to:
  /// **'Am auzit prea puțin. Citește din nou textul, cu voce normală.'**
  String get enrollTooShort;

  /// No description provided for @enrollFailed.
  ///
  /// In ro, this message translates to:
  /// **'Nu am putut învăța vocea. Încearcă din nou.'**
  String get enrollFailed;

  /// No description provided for @voiceUnavailable.
  ///
  /// In ro, this message translates to:
  /// **'Recunoașterea vocii nu merge în acest browser; toate replicile sunt „Speaker”'**
  String get voiceUnavailable;

  /// No description provided for @relearnVoice.
  ///
  /// In ro, this message translates to:
  /// **'Reînvață vocea'**
  String get relearnVoice;

  /// No description provided for @testMeeting.
  ///
  /// In ro, this message translates to:
  /// **'Meeting de test'**
  String get testMeeting;

  /// No description provided for @testMeetingHint.
  ///
  /// In ro, this message translates to:
  /// **'Înregistrează clipurile pe acest laptop, pentru antrenare. Toți cei din sală trebuie să fie de acord.'**
  String get testMeetingHint;

  /// No description provided for @testReviewTitle.
  ///
  /// In ro, this message translates to:
  /// **'Verifică meetingul de test'**
  String get testReviewTitle;

  /// No description provided for @testReviewIntro.
  ///
  /// In ro, this message translates to:
  /// **'Ascultă fiecare replică și corectează cine a vorbit. Apoi descarcă arhiva și copiaz-o în ml/voice/data/meetings.'**
  String get testReviewIntro;

  /// No description provided for @testPredicted.
  ///
  /// In ro, this message translates to:
  /// **'Echo a ales: {label} · scor {score}'**
  String testPredicted(String label, String score);

  /// No description provided for @testListen.
  ///
  /// In ro, this message translates to:
  /// **'Ascultă'**
  String get testListen;

  /// No description provided for @testDownload.
  ///
  /// In ro, this message translates to:
  /// **'Descarcă'**
  String get testDownload;

  /// No description provided for @voiceDiagOff.
  ///
  /// In ro, this message translates to:
  /// **'Recunoașterea vocii e oprită: totul apare ca „Speaker”'**
  String get voiceDiagOff;

  /// No description provided for @voiceDiagNotLearned.
  ///
  /// In ro, this message translates to:
  /// **'Vocea ta nu e învățată: totul apare ca „Speaker”'**
  String get voiceDiagNotLearned;

  /// No description provided for @voiceDiagForced.
  ///
  /// In ro, this message translates to:
  /// **'„Vorbesc eu” e pornit: totul apare ca „Speaker”'**
  String get voiceDiagForced;

  /// No description provided for @voiceDiagShort.
  ///
  /// In ro, this message translates to:
  /// **'Replică prea scurtă: păstrează eticheta de dinainte'**
  String get voiceDiagShort;

  /// No description provided for @voiceDiagError.
  ///
  /// In ro, this message translates to:
  /// **'Eroare la modelul de voce: păstrează eticheta de dinainte'**
  String get voiceDiagError;

  /// No description provided for @voiceDiagScore.
  ///
  /// In ro, this message translates to:
  /// **'Asemănare cu vocea ta: {similarity} (prag {threshold}) → {label}'**
  String voiceDiagScore(String similarity, String threshold, String label);

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

  /// No description provided for @alertLevelCritical.
  ///
  /// In ro, this message translates to:
  /// **'CRITIC'**
  String get alertLevelCritical;

  /// No description provided for @alertLevelWarning.
  ///
  /// In ro, this message translates to:
  /// **'ATENȚIE'**
  String get alertLevelWarning;

  /// No description provided for @adviceFireAlarm.
  ///
  /// In ro, this message translates to:
  /// **'Ieși din clădire pe cea mai apropiată ieșire. Nu folosi liftul.'**
  String get adviceFireAlarm;

  /// No description provided for @adviceSiren.
  ///
  /// In ro, this message translates to:
  /// **'Un vehicul de urgență sau o alertă publică. Fă loc și urmărește ce fac cei din jur.'**
  String get adviceSiren;

  /// No description provided for @adviceHorn.
  ///
  /// In ro, this message translates to:
  /// **'Un vehicul claxonează aproape. Oprește-te și uită-te în jur înainte să mergi mai departe.'**
  String get adviceHorn;

  /// No description provided for @adviceGlassBreak.
  ///
  /// In ro, this message translates to:
  /// **'S-a spart un geam în apropiere. Ferește-te de cioburi și uită-te în jur.'**
  String get adviceGlassBreak;

  /// No description provided for @adviceLineSignal.
  ///
  /// In ro, this message translates to:
  /// **'Semnal de la un utilaj. Fii atent la mașinile din jur.'**
  String get adviceLineSignal;

  /// No description provided for @soundsTitle.
  ///
  /// In ro, this message translates to:
  /// **'Sunetul vizibil'**
  String get soundsTitle;

  /// No description provided for @soundsListening.
  ///
  /// In ro, this message translates to:
  /// **'Ascult sunetele din jur, și cu telefonul blocat. Pornesc singur la fiecare deschidere a aplicației.'**
  String get soundsListening;

  /// No description provided for @soundsIdle.
  ///
  /// In ro, this message translates to:
  /// **'Ascultarea e oprită.'**
  String get soundsIdle;

  /// No description provided for @soundsPaused.
  ///
  /// In ro, this message translates to:
  /// **'Ascultarea e în pauză cât merge subtitrarea. Pornește din nou singură după.'**
  String get soundsPaused;

  /// No description provided for @homeSounds.
  ///
  /// In ro, this message translates to:
  /// **'Sunete'**
  String get homeSounds;

  /// No description provided for @homeSoundsOn.
  ///
  /// In ro, this message translates to:
  /// **'Pornit: telefonul te alertează la alarme, claxoane și numele tău.'**
  String get homeSoundsOn;

  /// No description provided for @homeSoundsOff.
  ///
  /// In ro, this message translates to:
  /// **'Oprit: atinge ca să pornești alertele de sunet.'**
  String get homeSoundsOff;

  /// No description provided for @homeSoundsPaused.
  ///
  /// In ro, this message translates to:
  /// **'Pe pauză cât rulează subtitrările.'**
  String get homeSoundsPaused;

  /// No description provided for @homeSoundsUnavailable.
  ///
  /// In ro, this message translates to:
  /// **'Indisponibil pe acest dispozitiv: atinge pentru detalii.'**
  String get homeSoundsUnavailable;

  /// No description provided for @soundsTest.
  ///
  /// In ro, this message translates to:
  /// **'Testează alertele'**
  String get soundsTest;

  /// No description provided for @soundsDetectorMissing.
  ///
  /// In ro, this message translates to:
  /// **'Recunoașterea sunetelor nu merge pe acest dispozitiv. Poți testa alertele de mai jos.'**
  String get soundsDetectorMissing;

  /// No description provided for @soundsExplain.
  ///
  /// In ro, this message translates to:
  /// **'Telefonul ascultă sunetele din jur, direct pe dispozitiv: nimic nu pleacă pe internet. Când recunoaște un sunet, ecranul se schimbă și telefonul vibrează. Alertele critice acoperă orice ecran până le închizi.'**
  String get soundsExplain;

  /// No description provided for @soundsSwitch.
  ///
  /// In ro, this message translates to:
  /// **'Alerte de sunet'**
  String get soundsSwitch;

  /// No description provided for @soundsVibrations.
  ///
  /// In ro, this message translates to:
  /// **'Vibrații'**
  String get soundsVibrations;

  /// No description provided for @soundsLevelExamplesCritical.
  ///
  /// In ro, this message translates to:
  /// **'Alarmă de incendiu, sirenă'**
  String get soundsLevelExamplesCritical;

  /// No description provided for @soundsLevelExamplesWarning.
  ///
  /// In ro, this message translates to:
  /// **'Claxon, sticlă spartă'**
  String get soundsLevelExamplesWarning;

  /// No description provided for @soundsLevelExamplesInfo.
  ///
  /// In ro, this message translates to:
  /// **'Numele tău, telefon, ușă'**
  String get soundsLevelExamplesInfo;

  /// No description provided for @levelCritical.
  ///
  /// In ro, this message translates to:
  /// **'Critic'**
  String get levelCritical;

  /// No description provided for @levelWarning.
  ///
  /// In ro, this message translates to:
  /// **'Important'**
  String get levelWarning;

  /// No description provided for @levelInfo.
  ///
  /// In ro, this message translates to:
  /// **'Informativ'**
  String get levelInfo;

  /// No description provided for @hapticLong.
  ///
  /// In ro, this message translates to:
  /// **'Lungă'**
  String get hapticLong;

  /// No description provided for @hapticLongHint.
  ///
  /// In ro, this message translates to:
  /// **'Un buzz lung și puternic'**
  String get hapticLongHint;

  /// No description provided for @hapticStrong.
  ///
  /// In ro, this message translates to:
  /// **'Triplă'**
  String get hapticStrong;

  /// No description provided for @hapticStrongHint.
  ///
  /// In ro, this message translates to:
  /// **'Trei buzz-uri puternice la rând'**
  String get hapticStrongHint;

  /// No description provided for @hapticLight.
  ///
  /// In ro, this message translates to:
  /// **'Scurtă'**
  String get hapticLight;

  /// No description provided for @hapticLightHint.
  ///
  /// In ro, this message translates to:
  /// **'Un buzz scurt și ușor'**
  String get hapticLightHint;

  /// No description provided for @vibrationUsedBy.
  ///
  /// In ro, this message translates to:
  /// **'Folosită la {level}'**
  String vibrationUsedBy(String level);

  /// No description provided for @vibrationSwapped.
  ///
  /// In ro, this message translates to:
  /// **'{level} folosește acum {haptic}'**
  String vibrationSwapped(String level, String haptic);

  /// No description provided for @vibrationCriticalRepeats.
  ///
  /// In ro, this message translates to:
  /// **'La alertele critice vibrația se repetă până închizi alerta.'**
  String get vibrationCriticalRepeats;

  /// No description provided for @soundGlassBreak.
  ///
  /// In ro, this message translates to:
  /// **'Geam spart'**
  String get soundGlassBreak;

  /// No description provided for @soundLocation.
  ///
  /// In ro, this message translates to:
  /// **'Sunet al locației'**
  String get soundLocation;

  /// No description provided for @alertOpenApp.
  ///
  /// In ro, this message translates to:
  /// **'Deschide Echo pentru detalii.'**
  String get alertOpenApp;

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

  /// No description provided for @cancel.
  ///
  /// In ro, this message translates to:
  /// **'Anulează'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In ro, this message translates to:
  /// **'Salvează'**
  String get save;

  /// No description provided for @account.
  ///
  /// In ro, this message translates to:
  /// **'Contul meu'**
  String get account;

  /// No description provided for @signIn.
  ///
  /// In ro, this message translates to:
  /// **'Intră în cont'**
  String get signIn;

  /// No description provided for @signInIntro.
  ///
  /// In ro, this message translates to:
  /// **'Intră în cont ca să-ți salvezi meetingurile și să le revezi oricând. Nu ai nevoie de parolă.'**
  String get signInIntro;

  /// No description provided for @signInEmailLabel.
  ///
  /// In ro, this message translates to:
  /// **'Adresa de email'**
  String get signInEmailLabel;

  /// No description provided for @signInSendCode.
  ///
  /// In ro, this message translates to:
  /// **'Trimite-mi un cod'**
  String get signInSendCode;

  /// No description provided for @signInCodeSent.
  ///
  /// In ro, this message translates to:
  /// **'Ți-am trimis un cod pe {email}. Poți și să deschizi linkul din email.'**
  String signInCodeSent(String email);

  /// No description provided for @signInCodeLabel.
  ///
  /// In ro, this message translates to:
  /// **'Codul din email'**
  String get signInCodeLabel;

  /// No description provided for @signInVerify.
  ///
  /// In ro, this message translates to:
  /// **'Confirmă codul'**
  String get signInVerify;

  /// No description provided for @signInOtherEmail.
  ///
  /// In ro, this message translates to:
  /// **'Folosește altă adresă'**
  String get signInOtherEmail;

  /// No description provided for @signInOr.
  ///
  /// In ro, this message translates to:
  /// **'sau'**
  String get signInOr;

  /// No description provided for @signInGoogle.
  ///
  /// In ro, this message translates to:
  /// **'Continuă cu Google'**
  String get signInGoogle;

  /// No description provided for @signInInvalidEmail.
  ///
  /// In ro, this message translates to:
  /// **'Adresa de email nu pare corectă'**
  String get signInInvalidEmail;

  /// No description provided for @signInInvalidCode.
  ///
  /// In ro, this message translates to:
  /// **'Introdu codul din cifre primit pe email'**
  String get signInInvalidCode;

  /// No description provided for @signInFailed.
  ///
  /// In ro, this message translates to:
  /// **'Nu am putut intra în cont. Verifică datele și încearcă din nou.'**
  String get signInFailed;

  /// No description provided for @accountSignedInAs.
  ///
  /// In ro, this message translates to:
  /// **'Ești conectat ca {email}'**
  String accountSignedInAs(String email);

  /// No description provided for @accountSignOut.
  ///
  /// In ro, this message translates to:
  /// **'Ieși din cont'**
  String get accountSignOut;

  /// No description provided for @accountDelete.
  ///
  /// In ro, this message translates to:
  /// **'Șterge contul'**
  String get accountDelete;

  /// No description provided for @accountDeleteTitle.
  ///
  /// In ro, this message translates to:
  /// **'Ștergi contul?'**
  String get accountDeleteTitle;

  /// No description provided for @accountDeleteBody.
  ///
  /// In ro, this message translates to:
  /// **'Se șterg definitiv contul, toate meetingurile salvate, transcrierile și rezumatele. Nu se poate anula.'**
  String get accountDeleteBody;

  /// No description provided for @accountDeleteConfirm.
  ///
  /// In ro, this message translates to:
  /// **'Șterge definitiv'**
  String get accountDeleteConfirm;

  /// No description provided for @accountError.
  ///
  /// In ro, this message translates to:
  /// **'Ceva nu a mers. Încearcă din nou.'**
  String get accountError;

  /// No description provided for @homeHistory.
  ///
  /// In ro, this message translates to:
  /// **'Meetingurile mele'**
  String get homeHistory;

  /// No description provided for @homeHistoryHint.
  ///
  /// In ro, this message translates to:
  /// **'Revezi transcrierile și rezumatele, întreabă orice meeting'**
  String get homeHistoryHint;

  /// No description provided for @historySearchHint.
  ///
  /// In ro, this message translates to:
  /// **'Caută în meetinguri'**
  String get historySearchHint;

  /// No description provided for @historyClearSearch.
  ///
  /// In ro, this message translates to:
  /// **'Șterge căutarea'**
  String get historyClearSearch;

  /// No description provided for @historyEmpty.
  ///
  /// In ro, this message translates to:
  /// **'Nu ai încă meetinguri salvate. Când participi la un meeting cu contul deschis, transcrierea se salvează aici.'**
  String get historyEmpty;

  /// No description provided for @historyNoResults.
  ///
  /// In ro, this message translates to:
  /// **'Niciun meeting nu conține „{query}”.'**
  String historyNoResults(String query);

  /// No description provided for @historyLoadError.
  ///
  /// In ro, this message translates to:
  /// **'Nu am putut încărca meetingurile.'**
  String get historyLoadError;

  /// No description provided for @historyUntitled.
  ///
  /// In ro, this message translates to:
  /// **'Meeting din {date}'**
  String historyUntitled(String date);

  /// No description provided for @historyDelete.
  ///
  /// In ro, this message translates to:
  /// **'Șterge meetingul'**
  String get historyDelete;

  /// No description provided for @historyDeleteTitle.
  ///
  /// In ro, this message translates to:
  /// **'Ștergi meetingul?'**
  String get historyDeleteTitle;

  /// No description provided for @historyDeleteBody.
  ///
  /// In ro, this message translates to:
  /// **'Transcrierea și rezumatul acestui meeting se șterg definitiv.'**
  String get historyDeleteBody;

  /// No description provided for @historyDeleted.
  ///
  /// In ro, this message translates to:
  /// **'Meetingul a fost șters'**
  String get historyDeleted;

  /// No description provided for @meetingRename.
  ///
  /// In ro, this message translates to:
  /// **'Redenumește'**
  String get meetingRename;

  /// No description provided for @meetingNameLabel.
  ///
  /// In ro, this message translates to:
  /// **'Numele meetingului'**
  String get meetingNameLabel;

  /// No description provided for @meetingSaving.
  ///
  /// In ro, this message translates to:
  /// **'Transcrierea se salvează în contul tău'**
  String get meetingSaving;

  /// No description provided for @locSoundsTitle.
  ///
  /// In ro, this message translates to:
  /// **'Sunetele locației'**
  String get locSoundsTitle;

  /// No description provided for @locSoundsHint.
  ///
  /// In ro, this message translates to:
  /// **'Învață sunetele care contează aici: alarma halei, soneria biroului. Se păstrează doar amprenta sunetului, nu înregistrarea.'**
  String get locSoundsHint;

  /// No description provided for @locSoundsEmpty.
  ///
  /// In ro, this message translates to:
  /// **'Niciun sunet învățat încă.'**
  String get locSoundsEmpty;

  /// No description provided for @locSoundsLearn.
  ///
  /// In ro, this message translates to:
  /// **'Învață un sunet'**
  String get locSoundsLearn;

  /// No description provided for @locSoundsFromCompany.
  ///
  /// In ro, this message translates to:
  /// **'De la companie'**
  String get locSoundsFromCompany;

  /// No description provided for @locSoundsShare.
  ///
  /// In ro, this message translates to:
  /// **'Împarte cu compania'**
  String get locSoundsShare;

  /// No description provided for @locSoundsShared.
  ///
  /// In ro, this message translates to:
  /// **'Sunetul a fost trimis companiei.'**
  String get locSoundsShared;

  /// No description provided for @locSoundsDelete.
  ///
  /// In ro, this message translates to:
  /// **'Șterge sunetul'**
  String get locSoundsDelete;

  /// No description provided for @learnName.
  ///
  /// In ro, this message translates to:
  /// **'Numele sunetului'**
  String get learnName;

  /// No description provided for @learnNameHint.
  ///
  /// In ro, this message translates to:
  /// **'De exemplu: Alarma halei 2'**
  String get learnNameHint;

  /// No description provided for @learnLevel.
  ///
  /// In ro, this message translates to:
  /// **'Cât de important e'**
  String get learnLevel;

  /// No description provided for @learnLevelCritical.
  ///
  /// In ro, this message translates to:
  /// **'Critic: ecran roșu până confirmi'**
  String get learnLevelCritical;

  /// No description provided for @learnLevelWarning.
  ///
  /// In ro, this message translates to:
  /// **'Atenție: ecran galben'**
  String get learnLevelWarning;

  /// No description provided for @learnLevelInfo.
  ///
  /// In ro, this message translates to:
  /// **'Informativ: notificare discretă'**
  String get learnLevelInfo;

  /// No description provided for @learnRecord.
  ///
  /// In ro, this message translates to:
  /// **'Înregistrează o mostră (3 secunde)'**
  String get learnRecord;

  /// No description provided for @learnRecording.
  ///
  /// In ro, this message translates to:
  /// **'Ascult… redă sunetul acum.'**
  String get learnRecording;

  /// No description provided for @learnSamples.
  ///
  /// In ro, this message translates to:
  /// **'Mostre: {count} din 3'**
  String learnSamples(int count);

  /// No description provided for @learnNothingHeard.
  ///
  /// In ro, this message translates to:
  /// **'N-am auzit nimic. Apropie telefonul de sunet și încearcă din nou.'**
  String get learnNothingHeard;

  /// No description provided for @learnSave.
  ///
  /// In ro, this message translates to:
  /// **'Salvează sunetul'**
  String get learnSave;

  /// No description provided for @orgError.
  ///
  /// In ro, this message translates to:
  /// **'Nu s-a putut. Verifică internetul și încearcă din nou.'**
  String get orgError;

  /// No description provided for @orgTitle.
  ///
  /// In ro, this message translates to:
  /// **'Compania mea'**
  String get orgTitle;

  /// No description provided for @orgNone.
  ///
  /// In ro, this message translates to:
  /// **'Nu faci parte din nicio companie.'**
  String get orgNone;

  /// No description provided for @orgInvitesTitle.
  ///
  /// In ro, this message translates to:
  /// **'Invitații primite'**
  String get orgInvitesTitle;

  /// No description provided for @orgInviteFrom.
  ///
  /// In ro, this message translates to:
  /// **'{org} te invită să te alături'**
  String orgInviteFrom(String org);

  /// No description provided for @orgAccept.
  ///
  /// In ro, this message translates to:
  /// **'Acceptă'**
  String get orgAccept;

  /// No description provided for @orgCreateTitle.
  ///
  /// In ro, this message translates to:
  /// **'Creează o companie'**
  String get orgCreateTitle;

  /// No description provided for @orgCreateHint.
  ///
  /// In ro, this message translates to:
  /// **'Pentru angajator: invită angajații, împarte sunetele locației și vezi cine e în siguranță la o alarmă.'**
  String get orgCreateHint;

  /// No description provided for @orgName.
  ///
  /// In ro, this message translates to:
  /// **'Numele companiei'**
  String get orgName;

  /// No description provided for @orgCreate.
  ///
  /// In ro, this message translates to:
  /// **'Creează'**
  String get orgCreate;

  /// No description provided for @orgRoleAdmin.
  ///
  /// In ro, this message translates to:
  /// **'Administrator'**
  String get orgRoleAdmin;

  /// No description provided for @orgRoleEmployee.
  ///
  /// In ro, this message translates to:
  /// **'Angajat'**
  String get orgRoleEmployee;

  /// No description provided for @orgMyNeeds.
  ///
  /// In ro, this message translates to:
  /// **'Nevoile mele'**
  String get orgMyNeeds;

  /// No description provided for @orgMyNeedsHint.
  ///
  /// In ro, this message translates to:
  /// **'Compania vede doar ce bifezi aici. Fără detalii medicale.'**
  String get orgMyNeedsHint;

  /// No description provided for @needCaptions.
  ///
  /// In ro, this message translates to:
  /// **'Subtitrare la meetinguri'**
  String get needCaptions;

  /// No description provided for @needVisualAlerts.
  ///
  /// In ro, this message translates to:
  /// **'Alerte vizuale pentru sunete'**
  String get needVisualAlerts;

  /// No description provided for @needWatchAlerts.
  ///
  /// In ro, this message translates to:
  /// **'Alerte pe ceas'**
  String get needWatchAlerts;

  /// No description provided for @needLargeText.
  ///
  /// In ro, this message translates to:
  /// **'Text mare'**
  String get needLargeText;

  /// No description provided for @orgSave.
  ///
  /// In ro, this message translates to:
  /// **'Salvează'**
  String get orgSave;

  /// No description provided for @orgSaved.
  ///
  /// In ro, this message translates to:
  /// **'Salvat.'**
  String get orgSaved;

  /// No description provided for @orgLeave.
  ///
  /// In ro, this message translates to:
  /// **'Părăsește compania'**
  String get orgLeave;

  /// No description provided for @orgLeaveTitle.
  ///
  /// In ro, this message translates to:
  /// **'Părăsești {org}?'**
  String orgLeaveTitle(String org);

  /// No description provided for @orgLeaveBody.
  ///
  /// In ro, this message translates to:
  /// **'Compania nu va mai vedea nevoile tale și nici răspunsurile tale la alarme.'**
  String get orgLeaveBody;

  /// No description provided for @orgMembers.
  ///
  /// In ro, this message translates to:
  /// **'Angajați'**
  String get orgMembers;

  /// No description provided for @orgMakeAdmin.
  ///
  /// In ro, this message translates to:
  /// **'Fă administrator'**
  String get orgMakeAdmin;

  /// No description provided for @orgMakeEmployee.
  ///
  /// In ro, this message translates to:
  /// **'Fă angajat'**
  String get orgMakeEmployee;

  /// No description provided for @orgRemove.
  ///
  /// In ro, this message translates to:
  /// **'Scoate din companie'**
  String get orgRemove;

  /// No description provided for @orgNeedsNotShared.
  ///
  /// In ro, this message translates to:
  /// **'Nevoile nu sunt completate'**
  String get orgNeedsNotShared;

  /// No description provided for @orgInvite.
  ///
  /// In ro, this message translates to:
  /// **'Invită un angajat'**
  String get orgInvite;

  /// No description provided for @orgEmail.
  ///
  /// In ro, this message translates to:
  /// **'Emailul angajatului'**
  String get orgEmail;

  /// No description provided for @orgDepartment.
  ///
  /// In ro, this message translates to:
  /// **'Departament (opțional)'**
  String get orgDepartment;

  /// No description provided for @orgSendInvite.
  ///
  /// In ro, this message translates to:
  /// **'Trimite invitația'**
  String get orgSendInvite;

  /// No description provided for @orgInviteSent.
  ///
  /// In ro, this message translates to:
  /// **'Invitația a fost trimisă. Angajatul o vede după ce se autentifică cu acest email.'**
  String get orgInviteSent;

  /// No description provided for @orgPending.
  ///
  /// In ro, this message translates to:
  /// **'Invitații în așteptare'**
  String get orgPending;

  /// No description provided for @orgCancelInvite.
  ///
  /// In ro, this message translates to:
  /// **'Anulează invitația'**
  String get orgCancelInvite;

  /// No description provided for @orgAlarms.
  ///
  /// In ro, this message translates to:
  /// **'Alarme în desfășurare'**
  String get orgAlarms;

  /// No description provided for @orgNoAlarms.
  ///
  /// In ro, this message translates to:
  /// **'Nicio alarmă acum.'**
  String get orgNoAlarms;

  /// No description provided for @orgAlarmSafe.
  ///
  /// In ro, this message translates to:
  /// **'În siguranță: {count}'**
  String orgAlarmSafe(int count);

  /// No description provided for @orgAlarmHelp.
  ///
  /// In ro, this message translates to:
  /// **'Au nevoie de ajutor: {count}'**
  String orgAlarmHelp(int count);

  /// No description provided for @orgAlarmNoAnswer.
  ///
  /// In ro, this message translates to:
  /// **'Fără răspuns: {count}'**
  String orgAlarmNoAnswer(int count);

  /// No description provided for @orgCloseAlarm.
  ///
  /// In ro, this message translates to:
  /// **'Închide alarma'**
  String get orgCloseAlarm;

  /// No description provided for @orgRollCallNote.
  ///
  /// In ro, this message translates to:
  /// **'Lista nu înlocuiește procedura de evacuare.'**
  String get orgRollCallNote;

  /// No description provided for @alertSafe.
  ///
  /// In ro, this message translates to:
  /// **'Sunt în siguranță'**
  String get alertSafe;

  /// No description provided for @alertNeedHelp.
  ///
  /// In ro, this message translates to:
  /// **'Am nevoie de ajutor'**
  String get alertNeedHelp;

  /// No description provided for @alertAnswerSent.
  ///
  /// In ro, this message translates to:
  /// **'Răspunsul a fost trimis companiei.'**
  String get alertAnswerSent;

  /// No description provided for @alarmFire.
  ///
  /// In ro, this message translates to:
  /// **'Incendiu'**
  String get alarmFire;

  /// No description provided for @alarmEvacuation.
  ///
  /// In ro, this message translates to:
  /// **'Evacuare'**
  String get alarmEvacuation;

  /// No description provided for @alarmSiren.
  ///
  /// In ro, this message translates to:
  /// **'Sirenă sau pericol afară'**
  String get alarmSiren;

  /// No description provided for @alarmMachine.
  ///
  /// In ro, this message translates to:
  /// **'Pericol la un utilaj'**
  String get alarmMachine;

  /// No description provided for @alarmFromColleague.
  ///
  /// In ro, this message translates to:
  /// **'{name} · semnalat de un coleg'**
  String alarmFromColleague(String name);

  /// No description provided for @emergencyTitle.
  ///
  /// In ro, this message translates to:
  /// **'Alarmă de urgență'**
  String get emergencyTitle;

  /// No description provided for @emergencyHomeHint.
  ///
  /// In ro, this message translates to:
  /// **'Când aplicația nu aude pericolul'**
  String get emergencyHomeHint;

  /// No description provided for @emergencyIntro.
  ///
  /// In ro, this message translates to:
  /// **'Alarma ajunge la colegii aflați la cel mult 500 m.'**
  String get emergencyIntro;

  /// No description provided for @emergencyAccountable.
  ///
  /// In ro, this message translates to:
  /// **'Numele tău se păstrează odată cu alarma.'**
  String get emergencyAccountable;

  /// No description provided for @alarmLevelCritical.
  ///
  /// In ro, this message translates to:
  /// **'Critic'**
  String get alarmLevelCritical;

  /// No description provided for @alarmLevelWarning.
  ///
  /// In ro, this message translates to:
  /// **'Atenție'**
  String get alarmLevelWarning;

  /// No description provided for @emergencyConfirm.
  ///
  /// In ro, this message translates to:
  /// **'Trimiți alarma „{name}”?'**
  String emergencyConfirm(String name);

  /// No description provided for @emergencySend.
  ///
  /// In ro, this message translates to:
  /// **'Trimite alarma'**
  String get emergencySend;

  /// No description provided for @emergencyCancelDialog.
  ///
  /// In ro, this message translates to:
  /// **'Renunță'**
  String get emergencyCancelDialog;

  /// No description provided for @emergencySent.
  ///
  /// In ro, this message translates to:
  /// **'Alarmă trimisă la {time}'**
  String emergencySent(String time);

  /// No description provided for @emergencyCancelAlarm.
  ///
  /// In ro, this message translates to:
  /// **'Anulează alarma'**
  String get emergencyCancelAlarm;

  /// No description provided for @emergencyCancelConfirm.
  ///
  /// In ro, this message translates to:
  /// **'Anulezi alarma pentru toți colegii?'**
  String get emergencyCancelConfirm;

  /// No description provided for @emergencyCancelled.
  ///
  /// In ro, this message translates to:
  /// **'Alarmă anulată'**
  String get emergencyCancelled;

  /// No description provided for @emergencySending.
  ///
  /// In ro, this message translates to:
  /// **'Se trimite…'**
  String get emergencySending;

  /// No description provided for @emergencyCancelling.
  ///
  /// In ro, this message translates to:
  /// **'Se anulează…'**
  String get emergencyCancelling;

  /// No description provided for @emergencyErrorSignedOut.
  ///
  /// In ro, this message translates to:
  /// **'Intră în cont ca să poți da o alarmă.'**
  String get emergencyErrorSignedOut;

  /// No description provided for @emergencyErrorLocation.
  ///
  /// In ro, this message translates to:
  /// **'Permite accesul la locație din Setări, ca alarma să ajungă la cine e aproape.'**
  String get emergencyErrorLocation;

  /// No description provided for @emergencyErrorTooMany.
  ///
  /// In ro, this message translates to:
  /// **'Ai dat deja 3 alarme în ultima oră. Încearcă din nou peste {minutes} min.'**
  String emergencyErrorTooMany(int minutes);

  /// No description provided for @emergencyErrorOffline.
  ///
  /// In ro, this message translates to:
  /// **'Nu ajungem la server. Verifică internetul și încearcă din nou.'**
  String get emergencyErrorOffline;

  /// No description provided for @emergencyErrorFailed.
  ///
  /// In ro, this message translates to:
  /// **'Alarma nu a plecat. Încearcă din nou.'**
  String get emergencyErrorFailed;

  /// No description provided for @emergencyErrorCancelFailed.
  ///
  /// In ro, this message translates to:
  /// **'Alarma nu mai e activă sau nu a putut fi anulată. Verifică și încearcă din nou.'**
  String get emergencyErrorCancelFailed;

  /// No description provided for @emergencyErrorNotConfigured.
  ///
  /// In ro, this message translates to:
  /// **'Serverul nu are conturi pornite. Anunță administratorul.'**
  String get emergencyErrorNotConfigured;
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
