// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Echo';

  @override
  String get homeTitle => 'Hi! Where do we start?';

  @override
  String get homeJoin => 'I\'m in a meeting';

  @override
  String get homeJoinHint =>
      'See everything that\'s said, and who\'s saying it.';

  @override
  String get homePresent => 'I\'m presenting';

  @override
  String get homePresentHint => 'Start the meeting and show everyone the code.';

  @override
  String get homeSounds => 'Sounds around you';

  @override
  String get homeSoundsHint =>
      'We\'ll tell you when there\'s an alarm, a horn, or someone calls your name.';

  @override
  String get homeConversation => 'I\'m talking with someone';

  @override
  String get homeConversationHint =>
      'See what each person says, right next to their face.';

  @override
  String get homeElsewhere => 'Outside meetings';

  @override
  String get homeOtherPresent => 'Presenting? Open presenter mode';

  @override
  String get homeOtherJoin => 'Joining a meeting? Start here';

  @override
  String get tipTitle => 'First time here?';

  @override
  String get homeTipJoin =>
      'Start here. Ask the presenter for the code and follow the meeting on screen.';

  @override
  String get homeTipPresent =>
      'Start here. Start the meeting and Echo gives you a code to show everyone.';

  @override
  String get tipGotIt => 'Got it';

  @override
  String get tipSkip => 'Skip';

  @override
  String get tipSkipLabel => 'Skip all tips';

  @override
  String get settings => 'Settings';

  @override
  String get close => 'Close';

  @override
  String get retry => 'Try again';

  @override
  String get send => 'Send';

  @override
  String get joinTitle => 'Join a meeting';

  @override
  String get joinIntro => 'Type the code shown on the presenter\'s screen.';

  @override
  String get joinServerChange => 'Change';

  @override
  String get joinCodeLabel => 'Code shown on the presenter\'s screen';

  @override
  String get joinServerLabel => 'Server address';

  @override
  String get joinServerHint => 'for example http://172.20.10.2:8000';

  @override
  String get joinButton => 'Join';

  @override
  String get joinScan => 'Scan QR code';

  @override
  String get joinInvalidCode => 'The code has 6 letters and digits';

  @override
  String get joinInvalidServer =>
      'The address must start with http:// or https://';

  @override
  String get joinInvalidQr => 'This QR code is not from a meeting';

  @override
  String get connConnecting => 'Connecting…';

  @override
  String get connConnected => 'Connected';

  @override
  String get connReconnecting => 'Connection lost. Retrying…';

  @override
  String get connClosed => 'This meeting does not exist or has ended';

  @override
  String get presenterOnline => 'Presenter connected';

  @override
  String get presenterOffline => 'Waiting for the presenter';

  @override
  String get speakerCoordinator => 'Coordinator';

  @override
  String get speakerPublic => 'Audience';

  @override
  String get captionsEmpty =>
      'Captions appear here when someone starts speaking.';

  @override
  String get captionsLive => 'Live captions';

  @override
  String get captionPartial => 'transcribing';

  @override
  String get quickQuestion => 'I have a question';

  @override
  String get quickRepeat => 'Could you repeat that?';

  @override
  String get quickSlower => 'Slower, please';

  @override
  String get customMessageHint => 'Write a message to the presenter';

  @override
  String messageSent(String text) {
    return 'Sent: $text';
  }

  @override
  String messageSeen(String text) {
    return 'The presenter saw: $text';
  }

  @override
  String get listenRoom => 'Listen to the room too';

  @override
  String get listenRoomHint =>
      'Your phone captions questions from the audience';

  @override
  String get stopListening => 'Stop listening';

  @override
  String get speechUnavailable =>
      'Speech recognition is not available. Check microphone and speech permissions.';

  @override
  String get summaryAction => 'Summary and tasks';

  @override
  String get summaryTitle => 'Meeting summary';

  @override
  String get summaryTasks => 'Tasks';

  @override
  String get summaryNoTasks => 'No tasks.';

  @override
  String summaryOwner(String owner) {
    return 'Owner: $owner';
  }

  @override
  String get summaryPrivacy =>
      'Only the transcript text is sent for the summary, never audio.';

  @override
  String get askAction => 'Ask the meeting';

  @override
  String get askHint => 'For example: What do I need to do?';

  @override
  String get askSources => 'Sources from the transcript';

  @override
  String get askThinking => 'Searching the transcript…';

  @override
  String get transcriptEmpty => 'There are no lines in the transcript yet.';

  @override
  String get aiError => 'The AI could not answer. Please try again.';

  @override
  String get simplify => 'Simplify';

  @override
  String get presenterTitle => 'Presenter mode';

  @override
  String get presenterCodeLabel => 'Meeting code';

  @override
  String get presenterJoinHint =>
      'Participants scan the QR code or type the code in the app.';

  @override
  String get presenterStart => 'Start captions';

  @override
  String get presenterStop => 'Stop captions';

  @override
  String get presenterListening =>
      'Listening. What you say appears on participants\' phones.';

  @override
  String get presenterNotifications => 'Messages from participants';

  @override
  String get presenterNoNotifications =>
      'No messages yet. Messages appear here without sound.';

  @override
  String get presenterMarkSeen => 'Seen it';

  @override
  String get presenterSeen => 'Seen';

  @override
  String presenterParticipants(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count participants connected',
      one: '1 participant connected',
      zero: 'No participants connected',
    );
    return '$_temp0';
  }

  @override
  String get presenterCreateError =>
      'Could not create the meeting. Check that the server is running.';

  @override
  String get soundFireAlarm => 'FIRE ALARM';

  @override
  String get soundSiren => 'Siren';

  @override
  String get soundHorn => 'Horn nearby';

  @override
  String get soundLineSignal => 'Line signal';

  @override
  String get soundName => 'Someone is calling you';

  @override
  String get soundPhone => 'A phone is ringing';

  @override
  String get soundDoor => 'Door or doorbell';

  @override
  String alertExit(String exit) {
    return 'Nearest exit: $exit';
  }

  @override
  String get alertDismiss => 'Got it';

  @override
  String get alertLevelCritical => 'CRITICAL';

  @override
  String get alertLevelWarning => 'WARNING';

  @override
  String get adviceFireAlarm =>
      'Leave the building by the nearest exit. Do not use the lift.';

  @override
  String get adviceSiren =>
      'An emergency vehicle or a public alert. Make way and watch what people around you do.';

  @override
  String get adviceHorn =>
      'A vehicle is honking nearby. Stop and look around before you go on.';

  @override
  String get adviceGlassBreak =>
      'Glass broke nearby. Keep away from the shards and look around.';

  @override
  String get adviceLineSignal =>
      'A signal from a machine. Watch the machines around you.';

  @override
  String get soundsTitle => 'Visible sound';

  @override
  String get soundsStart => 'Start listening';

  @override
  String get soundsStop => 'Stop listening';

  @override
  String get soundsListening =>
      'Listening to sounds around you, also with the phone locked. Starts by itself every time you open the app.';

  @override
  String get soundsIdle => 'Listening is off.';

  @override
  String get soundsPaused =>
      'Listening is paused while captions run. It starts again by itself afterwards.';

  @override
  String get soundsPill => 'Sounds';

  @override
  String get soundsPillOn => 'Visible sound: on';

  @override
  String get soundsPillOff => 'Visible sound: off';

  @override
  String get soundsPillPaused => 'Visible sound: paused while captions run';

  @override
  String get soundsTest => 'Test the alerts';

  @override
  String get soundsDetectorMissing =>
      'Sound recognition does not work on this device. You can test the alerts below.';

  @override
  String get soundGlassBreak => 'Breaking glass';

  @override
  String get soundLocation => 'Workplace sound';

  @override
  String get alertOpenApp => 'Open Echo for details.';

  @override
  String get conversationTitle => 'Conversation';

  @override
  String get conversationPending =>
      'Speech bubbles next to faces are in progress. Meanwhile, captions appear below.';

  @override
  String get settingsLanguage => 'App language';

  @override
  String get settingsSpeechLanguage => 'Language spoken in the meeting';

  @override
  String get languageSystem => 'Same as system';

  @override
  String get settingsTextSize => 'Text size';

  @override
  String get settingsDyslexia => 'Dyslexia mode';

  @override
  String get settingsDyslexiaHint => 'OpenDyslexic font and wider spacing';

  @override
  String get settingsPalette => 'Role colours';

  @override
  String get paletteStandard => 'Standard';

  @override
  String get paletteProtanopia => 'Protanopia (red is hard to see)';

  @override
  String get paletteDeuteranopia => 'Deuteranopia (green is hard to see)';

  @override
  String get paletteTritanopia => 'Tritanopia (blue is hard to see)';

  @override
  String get settingsHighContrast => 'High contrast';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get themeSystem => 'Same as system';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get settingsAutoScroll => 'Auto-scroll captions';

  @override
  String get settingsEmergencyExit => 'Emergency exit shown during an alarm';

  @override
  String get settingsEmergencyExitHint =>
      'for example Stairs B, left of the lift';

  @override
  String get settingsServer => 'Server address';

  @override
  String get settingsPreview => 'Preview';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get account => 'My account';

  @override
  String get signIn => 'Sign in';

  @override
  String get signInIntro =>
      'Sign in to save your meetings and review them any time. No password needed.';

  @override
  String get signInEmailLabel => 'Email address';

  @override
  String get signInSendCode => 'Send me a code';

  @override
  String signInCodeSent(String email) {
    return 'We sent a code to $email. You can also open the link in the email.';
  }

  @override
  String get signInCodeLabel => 'Code from the email';

  @override
  String get signInVerify => 'Confirm code';

  @override
  String get signInOtherEmail => 'Use another address';

  @override
  String get signInOr => 'or';

  @override
  String get signInGoogle => 'Continue with Google';

  @override
  String get signInInvalidEmail => 'This email address doesn\'t look right';

  @override
  String get signInInvalidCode => 'Enter the numeric code from the email';

  @override
  String get signInFailed =>
      'We couldn\'t sign you in. Check the details and try again.';

  @override
  String accountSignedInAs(String email) {
    return 'Signed in as $email';
  }

  @override
  String get accountSignOut => 'Sign out';

  @override
  String get accountDelete => 'Delete account';

  @override
  String get accountDeleteTitle => 'Delete your account?';

  @override
  String get accountDeleteBody =>
      'Your account and all saved meetings, transcripts and summaries are deleted for good. This cannot be undone.';

  @override
  String get accountDeleteConfirm => 'Delete for good';

  @override
  String get accountError => 'Something went wrong. Try again.';

  @override
  String get homeHistory => 'My meetings';

  @override
  String get homeHistoryHint =>
      'Review transcripts and summaries, ask any meeting';

  @override
  String get historySearchHint => 'Search your meetings';

  @override
  String get historyClearSearch => 'Clear search';

  @override
  String get historyEmpty =>
      'No saved meetings yet. When you join a meeting while signed in, the transcript is saved here.';

  @override
  String historyNoResults(String query) {
    return 'No meeting contains “$query”.';
  }

  @override
  String get historyLoadError => 'We couldn\'t load your meetings.';

  @override
  String historyUntitled(String date) {
    return 'Meeting on $date';
  }

  @override
  String get historyDelete => 'Delete meeting';

  @override
  String get historyDeleteTitle => 'Delete this meeting?';

  @override
  String get historyDeleteBody =>
      'This meeting\'s transcript and summary are deleted for good.';

  @override
  String get historyDeleted => 'Meeting deleted';

  @override
  String get meetingRename => 'Rename';

  @override
  String get meetingNameLabel => 'Meeting name';

  @override
  String get meetingSaving => 'The transcript is being saved to your account';
}
