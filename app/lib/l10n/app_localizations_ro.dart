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
  String get homeJoin => 'Conectează-te la speaker';

  @override
  String get homeJoinHint =>
      'Vezi ce se spune în sală și pune întrebări speakerului.';

  @override
  String get homePresent => 'Eu prezint';

  @override
  String get homePresentHint =>
      'Pornești meetingul și le arăți celorlalți codul.';

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
  String get joinTitle => 'Conectează-te la speaker';

  @override
  String get joinIntro => 'Scrie codul de pe laptopul speakerului.';

  @override
  String get joinServerChange => 'Schimbă';

  @override
  String get joinCodeLabel => 'Codul de pe laptopul speakerului';

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
  String get speakerCoordinator => 'Speaker';

  @override
  String get speakerPublic => 'Din sală';

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
  String get myQuestionButton => 'Vreau să întreb';

  @override
  String get myQuestionHint => 'Scrie întrebarea';

  @override
  String get myQuestionSend => 'Trimite întrebarea';

  @override
  String get myQuestionHandSent => 'Am trimis semnalul către speaker';

  @override
  String get myQuestionHandSeen => 'Speakerul a văzut că vrei să întrebi';

  @override
  String get myQuestionOffline => 'Speakerul nu e conectat încă';

  @override
  String get myQuestionSent => 'Trimisă, așteaptă să fie citită';

  @override
  String get myQuestionRead => 'Citită, se așteaptă răspunsul';

  @override
  String get myQuestionNotFound => 'Nu am găsit încă un răspuns';

  @override
  String get myQuestionRetry => 'Caută răspunsul';

  @override
  String get answeredTitle => 'Ți s-a răspuns';

  @override
  String answeredQuestion(String text) {
    return 'Întrebarea ta: $text';
  }

  @override
  String answeredAnnouncement(String answer) {
    return 'Ți s-a răspuns: $answer';
  }

  @override
  String get roomQuestion => 'Întrebare din sală';

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
  String get aiErrorLimit =>
      'AI-ul a primit prea multe cereri în ultima oră. Încearcă din nou mai târziu.';

  @override
  String get aiErrorOff =>
      'AI-ul nu e pornit pe server. Subtitrările merg în continuare.';

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
  String get presenterHand =>
      'Persoana care folosește Echo vrea să pună o întrebare';

  @override
  String get presenterQuestionTitle =>
      'Întrebare de la persoana care folosește Echo';

  @override
  String get presenterReadAloud => 'Citește cu voce tare';

  @override
  String get presenterReadMyself => 'Am citit-o eu';

  @override
  String get presenterRead => 'Citită';

  @override
  String get presenterReading => 'Citesc întrebarea…';

  @override
  String get presenterNoVoice =>
      'Laptopul nu are o voce în limba asta; citește-o tu';

  @override
  String get presenterReadFailed => 'Nu am putut citi întrebarea; citește-o tu';

  @override
  String get presenterForceSpeaker => 'Vorbesc eu';

  @override
  String get presenterForceSpeakerHint =>
      'Tot ce se aude apare ca spus de tine';

  @override
  String get enrollTitle => 'Învață vocea ta';

  @override
  String get enrollIntro =>
      'Citește textul de mai jos cu voce normală, cam 20 de secunde. Așa Echo îți recunoaște vocea și știe când vorbești tu și când vorbește cineva din sală. Sunetul rămâne pe acest laptop.';

  @override
  String get enrollText =>
      'Bună ziua tuturor. Astăzi vorbim despre planurile echipei pentru luna următoare. Trecem prin bugetul proiectului, prin termenele importante și prin sarcinile fiecăruia. Dacă aveți întrebări, le puteți pune oricând. Vă mulțumesc că sunteți aici și sper să avem o discuție utilă, clară și scurtă. Să începem cu subiectele cele mai urgente.';

  @override
  String get enrollStart => 'Începe';

  @override
  String get enrollListening => 'Te ascult… citește textul';

  @override
  String get enrollFinish => 'Am terminat de citit';

  @override
  String get enrollDone => 'Vocea ta e învățată';

  @override
  String get enrollTooShort =>
      'Am auzit prea puțin. Citește din nou textul, cu voce normală.';

  @override
  String get enrollFailed => 'Nu am putut învăța vocea. Încearcă din nou.';

  @override
  String get voiceUnavailable =>
      'Recunoașterea vocii nu merge în acest browser; toate replicile sunt „Speaker”';

  @override
  String get relearnVoice => 'Reînvață vocea';

  @override
  String get testMeeting => 'Meeting de test';

  @override
  String get testMeetingHint =>
      'Înregistrează clipurile pe acest laptop, pentru antrenare. Toți cei din sală trebuie să fie de acord.';

  @override
  String get testReviewTitle => 'Verifică meetingul de test';

  @override
  String get testReviewIntro =>
      'Ascultă fiecare replică și corectează cine a vorbit. Apoi descarcă arhiva și copiaz-o în ml/voice/data/meetings.';

  @override
  String testPredicted(String label, String score) {
    return 'Echo a ales: $label · scor $score';
  }

  @override
  String get testListen => 'Ascultă';

  @override
  String get testDownload => 'Descarcă';

  @override
  String get voiceDiagOff =>
      'Recunoașterea vocii e oprită: totul apare ca „Speaker”';

  @override
  String get voiceDiagNotLearned =>
      'Vocea ta nu e învățată: totul apare ca „Speaker”';

  @override
  String get voiceDiagForced =>
      '„Vorbesc eu” e pornit: totul apare ca „Speaker”';

  @override
  String get voiceDiagShort =>
      'Replică prea scurtă: păstrează eticheta de dinainte';

  @override
  String get voiceDiagError =>
      'Eroare la modelul de voce: păstrează eticheta de dinainte';

  @override
  String voiceDiagScore(String similarity, String threshold, String label) {
    return 'Asemănare cu vocea ta: $similarity (prag $threshold) → $label';
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
  String get soundsTitle => 'Vibrații';

  @override
  String get soundsListening =>
      'Pornite, și cu telefonul blocat. Pornesc singure la fiecare deschidere a aplicației.';

  @override
  String get soundsIdle => 'Alertele sunt oprite.';

  @override
  String get soundsPaused =>
      'În pauză cât merge subtitrarea. Pornesc din nou singure după.';

  @override
  String get homeSounds => 'Vibrații';

  @override
  String get homeSoundsOn =>
      'Pornite: telefonul vibrează la alarme, claxoane și numele tău.';

  @override
  String get homeSoundsOff =>
      'Oprite: atinge ca să pornești alertele prin vibrații.';

  @override
  String get homeSoundsPaused => 'Pe pauză cât rulează subtitrările.';

  @override
  String get homeSoundsUnavailable =>
      'Indisponibil pe acest dispozitiv: atinge pentru detalii.';

  @override
  String get soundsTest => 'Testează alertele';

  @override
  String get soundsDetectorMissing =>
      'Alertele automate nu merg pe acest dispozitiv. Poți testa vibrațiile mai jos.';

  @override
  String get soundsExplain =>
      'Telefonul vibrează și îți arată pe ecran când se întâmplă ceva important în jur. Totul rămâne pe telefon.';

  @override
  String get soundsSwitch => 'Alerte prin vibrații';

  @override
  String get soundsVibrations => 'Vibrația pentru fiecare nivel';

  @override
  String get soundsLevelExamplesCritical => 'Alarmă de incendiu, sirenă';

  @override
  String get soundsLevelExamplesWarning => 'Claxon, sticlă spartă';

  @override
  String get soundsLevelExamplesInfo => 'Numele tău, telefon, ușă';

  @override
  String get levelCritical => 'Critic';

  @override
  String get levelWarning => 'Important';

  @override
  String get levelInfo => 'Informativ';

  @override
  String get hapticLong => 'Lungă';

  @override
  String get hapticLongHint => 'Un buzz lung și puternic';

  @override
  String get hapticStrong => 'Triplă';

  @override
  String get hapticStrongHint => 'Trei buzz-uri puternice la rând';

  @override
  String get hapticLight => 'Scurtă';

  @override
  String get hapticLightHint => 'Un buzz scurt și ușor';

  @override
  String vibrationUsedBy(String level) {
    return 'Folosită la $level';
  }

  @override
  String vibrationSwapped(String level, String haptic) {
    return '$level folosește acum $haptic';
  }

  @override
  String get vibrationCriticalRepeats =>
      'La alertele critice vibrația se repetă până închizi alerta.';

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
      'Se șterg definitiv contul, meetingurile salvate, transcrierile, rezumatele și istoricul lor. Rămân 12 luni, cu emailul tău dar fără legătură cu contul: alarmele date de tine, răspunsurile tale la alarme și, dacă ești administrator, ce meetinguri ale angajaților ai citit (pentru anchete despre alarme și ca angajații să știe cine le-a citit meetingurile). Nu se poate anula.';

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

  @override
  String get homeOnline => 'Meeting online';

  @override
  String get homeCoach => 'Sunt coleg într-un meeting online';

  @override
  String get homeCoachHint =>
      'Echo îți arată discret când vorbești prea repede sau peste alții, ca un coleg surd să poată citi subtitrarea.';

  @override
  String get coachTitle => 'Antrenorul de claritate';

  @override
  String get coachIntro =>
      'În meetingurile online, colegii surzi citesc subtitrarea. Echo îți ascultă vocea pe acest calculator și îți arată discret când subtitrarea nu mai ține pasul. Sunetul nu pleacă de aici.';

  @override
  String get coachTeam => 'Echipa';

  @override
  String get coachCodeLabel => 'Codul echipei (opțional)';

  @override
  String get coachCodeHint =>
      'Cu același cod, Echo îți spune și când vorbești peste un coleg.';

  @override
  String get coachCreateCode => 'Creează un cod';

  @override
  String coachCodeCreated(String code) {
    return 'Codul $code e gata: spune-l colegilor.';
  }

  @override
  String get coachCodeInvalid => 'Codul are 6 litere și cifre.';

  @override
  String get coachServerError =>
      'Nu pot ajunge la serverul Echo. Încearcă din nou.';

  @override
  String get coachMicrophone => 'Microfonul';

  @override
  String get coachHeadphones => 'Folosesc căști';

  @override
  String get coachHeadphonesHint =>
      'Așa microfonul nu aude meetingul din difuzoare.';

  @override
  String get coachLearnVoice => 'Învață-mi vocea';

  @override
  String get coachVoiceHint =>
      'Citești un text 20 de secunde; apoi Echo numără doar ce spui tu.';

  @override
  String get coachVoiceLearned => 'Vocea ta e învățată';

  @override
  String get coachRelearnVoice => 'Învață din nou';

  @override
  String get coachVoiceStored =>
      'Amprenta vocii tale rămâne doar în acest browser. O poți șterge oricând.';

  @override
  String get coachForgetVoice => 'Șterge vocea';

  @override
  String get coachVoiceForgotten => 'Vocea ta a fost ștearsă.';

  @override
  String get coachVoiceError =>
      'Recunoașterea vocii nu merge în acest browser.';

  @override
  String get coachEnrollIntro =>
      'Citește textul de mai jos cu voce normală, cam 20 de secunde. Așa Echo îți recunoaște vocea și nu numără vocile colegilor care se aud din difuzoare. Sunetul rămâne pe acest calculator.';

  @override
  String get coachApproximate =>
      'Fără căști și fără vocea învățată, microfonul poate auzi și meetingul din difuzoare: alertele sunt aproximative, iar alerta de suprapunere e oprită.';

  @override
  String get coachDemo => 'Mod demonstrație';

  @override
  String get coachDemoHint =>
      'Praguri scurte, ca toate alertele să apară în câteva minute. Nu pentru meetinguri reale.';

  @override
  String get coachStart => 'Pornește antrenorul';

  @override
  String get coachMicError =>
      'Nu pot porni microfonul. Dă voie microfonului în browser; pagina trebuie deschisă pe https sau pe localhost.';

  @override
  String get coachAllGood => 'Totul e în regulă: subtitrarea ține pasul.';

  @override
  String get coachAlertOverlap => 'Vorbești în același timp cu altcineva';

  @override
  String get coachAlertWeakMic =>
      'Microfonul te prinde slab: apropie-te sau verifică-l';

  @override
  String get coachAlertTooFast => 'Vorbești prea repede pentru subtitrare';

  @override
  String get coachAlertNoPauses => 'Fă pauze între idei';

  @override
  String coachAlertLongTalk(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minute',
      one: 'un minut',
    );
    return 'Ai vorbit $_temp0 fără pauză: lasă loc de întrebări';
  }

  @override
  String get coachAlertNoise => 'Zgomot la tine: pune mute când nu vorbești';

  @override
  String get coachWatching => 'Ce urmăresc';

  @override
  String get coachWatchOverlap => 'Dacă vorbești peste alții';

  @override
  String get coachWatchWeakMic => 'Cât de bine te prinde microfonul';

  @override
  String get coachWatchTooFast => 'Cât de repede vorbești';

  @override
  String get coachWatchNoPauses => 'Pauzele dintre idei';

  @override
  String get coachWatchLongTalk => 'Cât vorbești fără să lași loc de întrebări';

  @override
  String get coachWatchNoise => 'Zgomotul de la tine, cât nu vorbești';

  @override
  String get coachPip => 'Arată alertele peste meeting';

  @override
  String get coachPipClose => 'Închide fereastra de alerte';

  @override
  String get coachPipTitle => 'Echo · alerte';

  @override
  String get coachPipUnsupported =>
      'Fereastra peste meeting merge în Chrome sau Edge pe calculator, pe https sau localhost.';

  @override
  String coachTeamStatus(String code, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count colegi conectați',
      one: 'un coleg conectat',
      zero: 'niciun alt coleg conectat',
    );
    return 'Cod $code · $_temp0';
  }

  @override
  String get coachNoTeam =>
      'Fără cod de echipă: alerta de suprapunere e oprită.';

  @override
  String coachUnknownCode(String code) {
    return 'Codul $code nu există. Verifică-l sau creează altul.';
  }

  @override
  String get coachReconnecting => 'Mă reconectez la echipă…';

  @override
  String get coachNoNoise =>
      'Recunoașterea zgomotelor nu merge aici: alerta de zgomot e oprită.';

  @override
  String get coachStop => 'Oprește';

  @override
  String get locSoundsTitle => 'Sunetele locației';

  @override
  String get locSoundsHint =>
      'Învață sunetele care contează aici: alarma halei, soneria biroului. Se păstrează doar amprenta sunetului, nu înregistrarea.';

  @override
  String get locSoundsEmpty => 'Niciun sunet învățat încă.';

  @override
  String get locSoundsLearn => 'Învață un sunet';

  @override
  String get locSoundsFromCompany => 'De la companie';

  @override
  String get locSoundsShare => 'Împarte cu compania';

  @override
  String get locSoundsShared => 'Sunetul a fost trimis companiei.';

  @override
  String get locSoundsDelete => 'Șterge sunetul';

  @override
  String get learnName => 'Numele sunetului';

  @override
  String get learnNameHint => 'De exemplu: Alarma halei 2';

  @override
  String get learnLevel => 'Cât de important e';

  @override
  String get learnLevelCritical => 'Critic: ecran roșu până confirmi';

  @override
  String get learnLevelWarning => 'Atenție: ecran galben';

  @override
  String get learnLevelInfo => 'Informativ: notificare discretă';

  @override
  String get learnRecord => 'Înregistrează o mostră (3 secunde)';

  @override
  String get learnRecording => 'Ascult… redă sunetul acum.';

  @override
  String learnSamples(int count) {
    return 'Mostre: $count din 3';
  }

  @override
  String get learnNothingHeard =>
      'N-am auzit nimic. Apropie telefonul de sunet și încearcă din nou.';

  @override
  String get learnSave => 'Salvează sunetul';

  @override
  String get orgError =>
      'Nu s-a putut. Verifică internetul și încearcă din nou.';

  @override
  String get orgLastAdmin =>
      'Ești singurul administrator al companiei și mai sunt colegi în ea. Fă pe altcineva administrator, apoi încearcă din nou.';

  @override
  String get orgTitle => 'Compania mea';

  @override
  String get orgNone => 'Nu faci parte din nicio companie.';

  @override
  String get orgInvitesTitle => 'Invitații primite';

  @override
  String orgInviteFrom(String org) {
    return '$org te invită să te alături';
  }

  @override
  String get orgAccept => 'Acceptă';

  @override
  String get orgCreateTitle => 'Creează o companie';

  @override
  String get orgCreateHint =>
      'Pentru angajator: invită angajații, împarte sunetele locației și vezi cine e în siguranță la o alarmă.';

  @override
  String get orgName => 'Numele companiei';

  @override
  String get orgCreate => 'Creează';

  @override
  String get orgRoleAdmin => 'Administrator';

  @override
  String get orgRoleEmployee => 'Angajat';

  @override
  String get orgMyNeeds => 'Nevoile mele';

  @override
  String get orgMyNeedsHint =>
      'Compania vede doar ce bifezi aici. Fără detalii medicale.';

  @override
  String get needCaptions => 'Subtitrare la meetinguri';

  @override
  String get needVisualAlerts => 'Alerte vizuale pentru sunete';

  @override
  String get needWatchAlerts => 'Alerte pe ceas';

  @override
  String get needLargeText => 'Text mare';

  @override
  String get orgSave => 'Salvează';

  @override
  String get orgSaved => 'Salvat.';

  @override
  String get orgLeave => 'Părăsește compania';

  @override
  String orgLeaveTitle(String org) {
    return 'Părăsești $org?';
  }

  @override
  String get orgLeaveBody =>
      'Compania nu va mai vedea nevoile tale și nici răspunsurile tale la alarme.';

  @override
  String get orgMembers => 'Angajați';

  @override
  String get orgMakeAdmin => 'Fă administrator';

  @override
  String get orgMakeEmployee => 'Fă angajat';

  @override
  String get orgRemove => 'Scoate din companie';

  @override
  String get orgNeedsNotShared => 'Nevoile nu sunt completate';

  @override
  String get orgInvite => 'Invită un angajat';

  @override
  String get orgEmail => 'Emailul angajatului';

  @override
  String get orgDepartment => 'Departament (opțional)';

  @override
  String get orgSendInvite => 'Trimite invitația';

  @override
  String get orgInviteSent =>
      'Invitația a fost trimisă. Angajatul o vede după ce se autentifică cu acest email.';

  @override
  String get orgPending => 'Invitații în așteptare';

  @override
  String get orgCancelInvite => 'Anulează invitația';

  @override
  String get orgAlarms => 'Alarme în desfășurare';

  @override
  String get orgNoAlarms => 'Nicio alarmă acum.';

  @override
  String orgAlarmSafe(int count) {
    return 'În siguranță: $count';
  }

  @override
  String orgAlarmHelp(int count) {
    return 'Au nevoie de ajutor: $count';
  }

  @override
  String orgAlarmNoAnswer(int count) {
    return 'Fără răspuns: $count';
  }

  @override
  String get orgCloseAlarm => 'Închide alarma';

  @override
  String get orgRollCallNote => 'Lista nu înlocuiește procedura de evacuare.';

  @override
  String get alertSafe => 'Sunt în siguranță';

  @override
  String get alertNeedHelp => 'Am nevoie de ajutor';

  @override
  String get alertAnswerSent => 'Răspunsul a fost trimis companiei.';

  @override
  String get alarmFire => 'Incendiu';

  @override
  String get alarmEvacuation => 'Evacuare';

  @override
  String get alarmSiren => 'Sirenă sau pericol afară';

  @override
  String get alarmMachine => 'Pericol la un utilaj';

  @override
  String alarmFromColleague(String name) {
    return '$name · semnalat de un coleg';
  }

  @override
  String get emergencyTitle => 'Urgență';

  @override
  String get emergencyHomeHint => 'Anunță colegii din apropiere';

  @override
  String get emergencyIntro =>
      'Alarma ajunge la colegii aflați la cel mult 500 m.';

  @override
  String get emergencyAccountable =>
      'Alarma se salvează cu contul tău, ora, locul și adresa IP.';

  @override
  String get alarmLevelCritical => 'Critic';

  @override
  String get alarmLevelWarning => 'Atenție';

  @override
  String emergencyConfirm(String name) {
    return 'Trimiți alarma „$name”?';
  }

  @override
  String get emergencySend => 'Trimite alarma';

  @override
  String get emergencyCancelDialog => 'Renunță';

  @override
  String emergencySent(String time) {
    return 'Alarmă trimisă la $time';
  }

  @override
  String get emergencyCancelAlarm => 'Anulează alarma';

  @override
  String get emergencyCancelConfirm => 'Anulezi alarma pentru toți colegii?';

  @override
  String get emergencyCancelled => 'Alarmă anulată';

  @override
  String get emergencySending => 'Se trimite…';

  @override
  String get emergencyCancelling => 'Se anulează…';

  @override
  String get emergencyErrorSignedOut => 'Intră în cont ca să poți da o alarmă.';

  @override
  String get emergencyErrorLocation =>
      'Permite accesul la locație din Setări, ca alarma să ajungă la cine e aproape.';

  @override
  String emergencyErrorTooMany(int minutes) {
    return 'Ai dat deja 3 alarme în ultima oră. Încearcă din nou peste $minutes min.';
  }

  @override
  String get emergencyErrorOffline =>
      'Nu ajungem la server. Verifică internetul și încearcă din nou.';

  @override
  String get emergencyErrorFailed => 'Alarma nu a plecat. Încearcă din nou.';

  @override
  String get emergencyErrorCancelFailed =>
      'Alarma nu mai e activă sau nu a putut fi anulată. Verifică și încearcă din nou.';

  @override
  String get emergencyErrorNotConfigured =>
      'Serverul nu are conturi pornite. Anunță administratorul.';

  @override
  String get activityTitle => 'Istoricul meu';

  @override
  String get activityHint =>
      'Alarmele tale, meetingurile salvate și cine le-a citit';

  @override
  String get activityEmpty =>
      'Nu e nimic în istoric încă. Aici apar alarmele tale, meetingurile salvate și cine le-a citit.';

  @override
  String get activityCompanyEmpty => 'Nu e nimic în istoricul companiei încă.';

  @override
  String get activityLoadError =>
      'Nu am putut încărca istoricul. Verifică internetul și încearcă din nou.';

  @override
  String get activityOlder => 'Mai vechi';

  @override
  String get activitySomeone => 'Cineva';

  @override
  String get activityNoTitle => 'fără titlu';

  @override
  String activityQuoted(String title) {
    return '„$title”';
  }

  @override
  String get activityStatusSafe => 'în siguranță';

  @override
  String get activityStatusNeedHelp => 'am nevoie de ajutor';

  @override
  String activityPlace(String lat, String lon, String accuracy) {
    return 'Locul: $lat, $lon (±$accuracy m)';
  }

  @override
  String activityAlarmRaisedMe(String kind) {
    return 'Ai dat o alarmă: $kind';
  }

  @override
  String activityAlarmRaised(String who, String kind) {
    return '$who a dat o alarmă: $kind';
  }

  @override
  String activityAlarmCancelledMe(String kind) {
    return 'Ai anulat alarma: $kind';
  }

  @override
  String activityAlarmCancelled(String who, String kind) {
    return '$who a anulat alarma: $kind';
  }

  @override
  String activityAlarmReportedMe(String kind) {
    return 'Ai semnalat companiei alarma: $kind';
  }

  @override
  String activityAlarmReported(String who, String kind) {
    return '$who a semnalat companiei alarma: $kind';
  }

  @override
  String activityAlarmAnsweredMe(String status, String kind) {
    return 'Ai răspuns „$status” la alarma: $kind';
  }

  @override
  String activityAlarmAnswered(String who, String status, String kind) {
    return '$who a răspuns „$status” la alarma: $kind';
  }

  @override
  String activityAlarmClosedMe(String kind) {
    return 'Ai închis alarma: $kind';
  }

  @override
  String activityAlarmClosed(String who, String kind) {
    return '$who a închis alarma: $kind';
  }

  @override
  String activityMeetingStartedMe(String meeting) {
    return 'Ai început meetingul $meeting';
  }

  @override
  String activityMeetingStarted(String who, String meeting) {
    return '$who a început meetingul $meeting';
  }

  @override
  String activityMeetingEndedMe(String meeting) {
    return 'Ai încheiat meetingul $meeting';
  }

  @override
  String activityMeetingEnded(String who, String meeting) {
    return '$who a încheiat meetingul $meeting';
  }

  @override
  String activityMeetingDeletedMe(String meeting) {
    return 'Ai șters meetingul $meeting';
  }

  @override
  String activityMeetingDeleted(String who, String meeting) {
    return '$who a șters meetingul $meeting';
  }

  @override
  String activityMeetingReadMine(String who, String meeting) {
    return '$who (administrator) a citit meetingul tău $meeting';
  }

  @override
  String activityMeetingReadByMe(String meeting, String owner) {
    return 'Ai citit meetingul $meeting, salvat de $owner';
  }

  @override
  String activityMeetingRead(String who, String meeting, String owner) {
    return '$who (administrator) a citit meetingul $meeting, salvat de $owner';
  }

  @override
  String get orgHistory => 'Istoricul companiei';

  @override
  String get orgHistoryHint => 'Alarmele și meetingurile din companie, cu cine';

  @override
  String get orgMeetings => 'Meetingurile companiei';

  @override
  String get orgMeetingsHint =>
      'Meetingurile salvate de angajați cât sunt în companie';

  @override
  String get orgMeetingsNotice =>
      'Când deschizi un meeting, angajatul vede în istoricul lui că l-ai citit.';

  @override
  String get orgMeetingsEmpty =>
      'Niciun meeting salvat pentru companie încă. Aici apar meetingurile salvate de angajați cât sunt în companie.';

  @override
  String get orgMeetingsLoadError =>
      'Nu am putut încărca meetingurile companiei. Verifică internetul și încearcă din nou.';

  @override
  String orgMeetingReadNotice(String owner) {
    return '$owner vede în istoricul lui că ai citit acest meeting.';
  }

  @override
  String get orgMeetingOwnerUnknown => 'Angajatul';

  @override
  String get orgMeetingLoadError =>
      'Nu am putut deschide meetingul. Poate nu mai e al companiei; încearcă din nou.';

  @override
  String get orgInviteNotice =>
      'Dacă accepți, administratorii companiei pot citi meetingurile pe care le salvezi cât ești în companie, iar alarmele tale apar în istoricul companiei.';

  @override
  String get orgEmployeeNotice =>
      'Administratorii pot citi meetingurile pe care le salvezi cât ești în companie, iar alarmele tale apar în istoricul companiei. Când un administrator îți citește un meeting, vezi asta în Istoricul meu.';

  @override
  String meetingSavingForOrg(String org) {
    return 'Meetingul se salvează pentru $org. Administratorii îl pot citi.';
  }

  @override
  String get meetingPickOrg => 'Alege compania';

  @override
  String get navLabel => 'Navigare principală';

  @override
  String get navHome => 'Dashboard';

  @override
  String get navMeeting => 'Meeting';

  @override
  String get navSounds => 'Vibrații';

  @override
  String get navAlarm => 'Urgență';

  @override
  String get navSettings => 'Setări';

  @override
  String get alarmNeedsAccount =>
      'Urgența cere un cont: numele tău pleacă împreună cu ea, ca colegii să știe cine a trimis-o.';

  @override
  String get alarmAccountsOff =>
      'Conturile nu sunt pornite pe acest server, așa că urgența nu poate fi trimisă de aici.';

  @override
  String get meetingTitle => 'Meeting';

  @override
  String get meetingModeLabel => 'Cum iei parte la meeting?';

  @override
  String get meetingModeJoin => 'Particip';

  @override
  String get meetingModePresent => 'Prezint';

  @override
  String get presentIntroTitle => 'Tu ții meetingul';

  @override
  String get presentIntroBody =>
      'Echo ascultă sala de pe acest dispozitiv și face subtitrarea în timp ce vorbești.';

  @override
  String get presentPointCode =>
      'Participanții intră cu codul sau cu QR-ul de pe ecran';

  @override
  String get presentPointQuestions =>
      'Întrebările lor îți apar în liniște, iar Echo le poate citi cu voce tare';

  @override
  String get presentPointVoice =>
      'Pe laptop, Echo îți învață vocea și știe când vorbești tu';

  @override
  String get presentStart => 'Pornește meetingul';

  @override
  String get signInRoleLabel => 'Cum intri în Echo';

  @override
  String get signInRoleAdmin => 'Admin';

  @override
  String get signInRoleEmployee => 'Angajat';

  @override
  String get signInAdminIntro =>
      'Pentru cine administrează echipa. Îți faci compania și le dai colegilor codul ei. Nu ai nevoie de parolă.';

  @override
  String get signInEmployeeIntro =>
      'Scrie codul primit de la administrator, numele tău și cum folosești Echo. Apoi confirmi emailul cu un cod.';

  @override
  String get companyCodeLabel => 'Codul companiei';

  @override
  String get joinNameLabel => 'Numele tău';

  @override
  String get joinExperienceTitle => 'Cum folosești Echo?';

  @override
  String get experienceVisual => 'Citesc ce se spune';

  @override
  String get experienceVisualHint =>
      'Subtitrări, sunete și alarme pe ecran și prin vibrații';

  @override
  String get experienceStandard => 'Aud ce se spune';

  @override
  String get experienceStandardHint =>
      'Uneltele colegului care vorbește: conversație, alarmă pentru un coleg';

  @override
  String get joinPrivacy =>
      'Intri în compania care ți-a dat codul. Administratorii ei văd numele, emailul și cum folosești Echo, ca să știe cum te anunță la o alarmă. Poți ieși oricând din Compania mea.';

  @override
  String get companyCodeInvalid =>
      'Codul companiei are 8 litere și cifre, de exemplu ABCD-EFGH.';

  @override
  String get joinNameMissing => 'Scrie-ți numele.';

  @override
  String get joinExperienceMissing => 'Alege cum folosești Echo.';

  @override
  String get joinWrongCode =>
      'Codul companiei nu e bun sau a expirat. Cere-l din nou administratorului.';

  @override
  String get joinTooMany =>
      'Prea multe coduri greșite. Încearcă din nou peste o oră.';

  @override
  String get joinRetry => 'Intră în companie';

  @override
  String joinDone(String company) {
    return 'Ai intrat în $company.';
  }

  @override
  String get orgCodeTitle => 'Codul companiei';

  @override
  String get orgCodeHint =>
      'Colegii intră cu el din Intră în cont → Angajat. Merge 7 zile.';

  @override
  String orgCodeActiveUntil(String date) {
    return 'Un cod merge până pe $date. Din motive de siguranță, îl vezi doar când îl generezi.';
  }

  @override
  String get orgCodeNone => 'Nu ai niciun cod activ.';

  @override
  String get orgCodeShown => 'Dă-le colegilor acest cod:';

  @override
  String get orgCodeNew => 'Generează un cod nou';

  @override
  String get orgCodeCopy => 'Copiază codul';

  @override
  String get orgCodeCopied => 'Codul a fost copiat';

  @override
  String get orgCodeRevoke => 'Anulează codul';

  @override
  String get memberReads => 'Citește ce se spune';

  @override
  String get memberHears => 'Aude ce se spune';
}
