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
  String get homeTitle => 'What would you like to do?';

  @override
  String get homeJoin => 'Connect to the speaker';

  @override
  String get homeJoinHint =>
      'See what is said in the room and ask the speaker questions';

  @override
  String get homePresent => 'I\'m presenting';

  @override
  String get homePresentHint =>
      'Keep the laptop in front of you and show the code to participants';

  @override
  String get homeSounds => 'Visible sound';

  @override
  String get homeSoundsHint => 'Alerts for alarms, horns and your name';

  @override
  String get homeConversation => 'Conversation';

  @override
  String get homeConversationHint => 'Captions next to each speaker\'s face';

  @override
  String get settings => 'Settings';

  @override
  String get close => 'Close';

  @override
  String get retry => 'Try again';

  @override
  String get send => 'Send';

  @override
  String get joinTitle => 'Connect to the speaker';

  @override
  String get joinCodeLabel => 'The code on the speaker\'s laptop';

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
  String get speakerCoordinator => 'Speaker';

  @override
  String get speakerPublic => 'Room';

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
  String get myQuestionButton => 'I want to ask';

  @override
  String get myQuestionHint => 'Type your question';

  @override
  String get myQuestionSend => 'Send the question';

  @override
  String get myQuestionHandSent => 'The speaker knows you want to ask';

  @override
  String get myQuestionSent => 'Sent, waiting to be read out';

  @override
  String get myQuestionRead => 'Read out, waiting for the answer';

  @override
  String get myQuestionNotFound => 'No answer found yet';

  @override
  String get myQuestionRetry => 'Look for the answer';

  @override
  String get answeredTitle => 'You got an answer';

  @override
  String answeredQuestion(String text) {
    return 'Your question: $text';
  }

  @override
  String answeredAnnouncement(String answer) {
    return 'You got an answer: $answer';
  }

  @override
  String get roomQuestion => 'Question from the room';

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
  String get presenterHand => 'The person using Echo wants to ask a question';

  @override
  String get presenterQuestionTitle => 'Question from the person using Echo';

  @override
  String get presenterReadAloud => 'Read it aloud';

  @override
  String get presenterReadMyself => 'I read it myself';

  @override
  String get presenterRead => 'Read out';

  @override
  String get presenterReading => 'Reading the question…';

  @override
  String get presenterNoVoice =>
      'This laptop has no voice for this language; read it yourself';

  @override
  String get presenterReadFailed =>
      'Couldn\'t read the question; read it yourself';

  @override
  String get presenterForceSpeaker => 'I\'m speaking';

  @override
  String get presenterForceSpeakerHint =>
      'Everything heard shows as said by you';

  @override
  String get enrollTitle => 'Learn your voice';

  @override
  String get enrollIntro =>
      'Read the text below in your normal voice, for about 20 seconds. This is how Echo recognises your voice and knows when you are speaking and when someone in the room is. The sound stays on this laptop.';

  @override
  String get enrollText =>
      'Good afternoon, everyone. Today we talk about the team\'s plans for next month. We go through the project budget, the important deadlines and everyone\'s tasks. If you have questions, you can ask them at any time. Thank you for being here, and I hope we have a useful, clear and short discussion. Let\'s start with the most urgent topics.';

  @override
  String get enrollStart => 'Start';

  @override
  String get enrollListening => 'Listening… read the text';

  @override
  String get enrollDone => 'Your voice is learned';

  @override
  String get enrollTooShort =>
      'I heard too little. Read the text again, in your normal voice.';

  @override
  String get enrollFailed => 'Could not learn your voice. Try again.';

  @override
  String get voiceUnavailable =>
      'Voice recognition does not work in this browser; every line is labelled “Speaker”';

  @override
  String get relearnVoice => 'Learn my voice again';

  @override
  String get testMeeting => 'Test meeting';

  @override
  String get testMeetingHint =>
      'Records the clips on this laptop, for training. Everyone in the room must agree.';

  @override
  String get testReviewTitle => 'Check the test meeting';

  @override
  String get testReviewIntro =>
      'Listen to each line and fix who said it. Then download the archive and copy it to ml/voice/data/meetings.';

  @override
  String testPredicted(String label, String score) {
    return 'Echo chose: $label · score $score';
  }

  @override
  String get testListen => 'Listen';

  @override
  String get testDownload => 'Download';

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
  String get soundsTitle => 'Visible sound';

  @override
  String get soundsStart => 'Start listening';

  @override
  String get soundsStop => 'Stop listening';

  @override
  String get soundsListening =>
      'Listening to sounds around you. Alerts appear over any screen.';

  @override
  String get soundsIdle => 'Listening is off.';

  @override
  String get soundsTest => 'Test the alerts';

  @override
  String get soundsDetectorMissing =>
      'The sound detector (YAMNet) is not connected yet. You can test the alerts below.';

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
}
