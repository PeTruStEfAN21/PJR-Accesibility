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
  String get homeJoin => 'Connect to the speaker';

  @override
  String get homeJoinHint =>
      'See what is said in the room and ask the speaker questions.';

  @override
  String get homePresent => 'I\'m presenting';

  @override
  String get homePresentHint => 'Start the meeting and show everyone the code.';

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
  String get joinTitle => 'Connect to the speaker';

  @override
  String get joinIntro => 'Type the code shown on the speaker\'s laptop.';

  @override
  String get joinServerChange => 'Change';

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
  String get myQuestionHandSent => 'Sent to the speaker';

  @override
  String get myQuestionHandSeen => 'The speaker saw that you want to ask';

  @override
  String get myQuestionOffline => 'The speaker is not connected yet';

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
  String get aiErrorLimit =>
      'The AI has had too many requests this hour. Please try again later.';

  @override
  String get aiErrorOff =>
      'The AI is not set up on the server. Captions still work.';

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
  String get voiceDiagOff =>
      'Voice recognition is off: everything shows as “Speaker”';

  @override
  String get voiceDiagNotLearned =>
      'Your voice is not learned: everything shows as “Speaker”';

  @override
  String get voiceDiagForced =>
      '“I\'m speaking” is on: everything shows as “Speaker”';

  @override
  String get voiceDiagShort => 'Line too short: keeps the previous label';

  @override
  String get voiceDiagError => 'Voice model error: keeps the previous label';

  @override
  String voiceDiagScore(String similarity, String threshold, String label) {
    return 'Similarity with your voice: $similarity (threshold $threshold) → $label';
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
  String get soundsListening =>
      'Listening to sounds around you, also with the phone locked. Starts by itself every time you open the app.';

  @override
  String get soundsIdle => 'Listening is off.';

  @override
  String get soundsPaused =>
      'Listening is paused while captions run. It starts again by itself afterwards.';

  @override
  String get homeSounds => 'Sounds';

  @override
  String get homeSoundsOn =>
      'On: your phone alerts you to alarms, horns and your name.';

  @override
  String get homeSoundsOff => 'Off: tap to turn sound alerts on.';

  @override
  String get homeSoundsPaused => 'Paused while captions run.';

  @override
  String get homeSoundsUnavailable =>
      'Not available on this device: tap for details.';

  @override
  String get soundsTest => 'Test the alerts';

  @override
  String get soundsDetectorMissing =>
      'Sound recognition does not work on this device. You can test the alerts below.';

  @override
  String get soundsExplain =>
      'Your phone listens to the sounds around you, right on the device: nothing goes to the internet. When it recognises a sound, the screen changes and the phone vibrates. Critical alerts cover any screen until you close them.';

  @override
  String get soundsSwitch => 'Sound alerts';

  @override
  String get soundsVibrations => 'Vibrations';

  @override
  String get soundsLevelExamplesCritical => 'Fire alarm, siren';

  @override
  String get soundsLevelExamplesWarning => 'Car horn, breaking glass';

  @override
  String get soundsLevelExamplesInfo => 'Your name, phone, door';

  @override
  String get levelCritical => 'Critical';

  @override
  String get levelWarning => 'Important';

  @override
  String get levelInfo => 'Informational';

  @override
  String get hapticLong => 'Long';

  @override
  String get hapticLongHint => 'One long, strong buzz';

  @override
  String get hapticStrong => 'Triple';

  @override
  String get hapticStrongHint => 'Three strong buzzes in a row';

  @override
  String get hapticLight => 'Short';

  @override
  String get hapticLightHint => 'One short, light buzz';

  @override
  String vibrationUsedBy(String level) {
    return 'Used for $level';
  }

  @override
  String vibrationSwapped(String level, String haptic) {
    return '$level now uses $haptic';
  }

  @override
  String get vibrationCriticalRepeats =>
      'For critical alerts the vibration repeats until you close the alert.';

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

  @override
  String get locSoundsTitle => 'Sounds of this place';

  @override
  String get locSoundsHint =>
      'Teach the sounds that matter here: the hall alarm, the office doorbell. Only the sound\'s fingerprint is kept, never the recording.';

  @override
  String get locSoundsEmpty => 'No sounds learned yet.';

  @override
  String get locSoundsLearn => 'Learn a sound';

  @override
  String get locSoundsFromCompany => 'From your company';

  @override
  String get locSoundsShare => 'Share with the company';

  @override
  String get locSoundsShared => 'The sound was sent to your company.';

  @override
  String get locSoundsDelete => 'Delete the sound';

  @override
  String get learnName => 'Name of the sound';

  @override
  String get learnNameHint => 'For example: Hall 2 alarm';

  @override
  String get learnLevel => 'How important it is';

  @override
  String get learnLevelCritical => 'Critical: red screen until you confirm';

  @override
  String get learnLevelWarning => 'Warning: yellow screen';

  @override
  String get learnLevelInfo => 'Info: a quiet notification';

  @override
  String get learnRecord => 'Record a sample (3 seconds)';

  @override
  String get learnRecording => 'Listening… play the sound now.';

  @override
  String learnSamples(int count) {
    return 'Samples: $count of 3';
  }

  @override
  String get learnNothingHeard =>
      'I heard nothing. Bring the phone closer to the sound and try again.';

  @override
  String get learnSave => 'Save the sound';

  @override
  String get orgError => 'That didn\'t work. Check the internet and try again.';

  @override
  String get orgTitle => 'My company';

  @override
  String get orgNone => 'You are not part of a company.';

  @override
  String get orgInvitesTitle => 'Invitations';

  @override
  String orgInviteFrom(String org) {
    return '$org invites you to join';
  }

  @override
  String get orgAccept => 'Accept';

  @override
  String get orgCreateTitle => 'Create a company';

  @override
  String get orgCreateHint =>
      'For employers: invite employees, share the sounds of your sites and see who is safe during an alarm.';

  @override
  String get orgName => 'Company name';

  @override
  String get orgCreate => 'Create';

  @override
  String get orgRoleAdmin => 'Admin';

  @override
  String get orgRoleEmployee => 'Employee';

  @override
  String get orgMyNeeds => 'My needs';

  @override
  String get orgMyNeedsHint =>
      'Your company sees only what you tick here. No medical details.';

  @override
  String get needCaptions => 'Captions in meetings';

  @override
  String get needVisualAlerts => 'Visual alerts for sounds';

  @override
  String get needWatchAlerts => 'Alerts on my watch';

  @override
  String get needLargeText => 'Large text';

  @override
  String get orgSave => 'Save';

  @override
  String get orgSaved => 'Saved.';

  @override
  String get orgLeave => 'Leave the company';

  @override
  String orgLeaveTitle(String org) {
    return 'Leave $org?';
  }

  @override
  String get orgLeaveBody =>
      'The company will no longer see your needs or your answers to alarms.';

  @override
  String get orgMembers => 'Employees';

  @override
  String get orgMakeAdmin => 'Make admin';

  @override
  String get orgMakeEmployee => 'Make employee';

  @override
  String get orgRemove => 'Remove from the company';

  @override
  String get orgNeedsNotShared => 'Needs not filled in';

  @override
  String get orgInvite => 'Invite an employee';

  @override
  String get orgEmail => 'Employee\'s email';

  @override
  String get orgDepartment => 'Department (optional)';

  @override
  String get orgSendInvite => 'Send the invitation';

  @override
  String get orgInviteSent =>
      'Invitation sent. The employee sees it after signing in with this email.';

  @override
  String get orgPending => 'Pending invitations';

  @override
  String get orgCancelInvite => 'Cancel the invitation';

  @override
  String get orgAlarms => 'Alarms in progress';

  @override
  String get orgNoAlarms => 'No alarm right now.';

  @override
  String orgAlarmSafe(int count) {
    return 'Safe: $count';
  }

  @override
  String orgAlarmHelp(int count) {
    return 'Need help: $count';
  }

  @override
  String orgAlarmNoAnswer(int count) {
    return 'No answer: $count';
  }

  @override
  String get orgCloseAlarm => 'Close the alarm';

  @override
  String get orgRollCallNote =>
      'This list does not replace the evacuation procedure.';

  @override
  String get alertSafe => 'I\'m safe';

  @override
  String get alertNeedHelp => 'I need help';

  @override
  String get alertAnswerSent => 'Your answer was sent to your company.';

  @override
  String get alarmFire => 'Fire';

  @override
  String get alarmEvacuation => 'Evacuation';

  @override
  String get alarmSiren => 'Siren or danger outside';

  @override
  String get alarmMachine => 'Machine hazard';

  @override
  String alarmFromColleague(String name) {
    return '$name · raised by a colleague';
  }

  @override
  String get emergencyTitle => 'Emergency alarm';

  @override
  String get emergencyHomeHint => 'When the app can\'t hear the danger';

  @override
  String get emergencyIntro => 'The alarm reaches colleagues within 500 m.';

  @override
  String get emergencyAccountable => 'Your name is kept with the alarm.';

  @override
  String get alarmLevelCritical => 'Critical';

  @override
  String get alarmLevelWarning => 'Warning';

  @override
  String emergencyConfirm(String name) {
    return 'Send the “$name” alarm?';
  }

  @override
  String get emergencySend => 'Send alarm';

  @override
  String get emergencyCancelDialog => 'Cancel';

  @override
  String emergencySent(String time) {
    return 'Alarm sent at $time';
  }

  @override
  String get emergencyCancelAlarm => 'Cancel the alarm';

  @override
  String get emergencyCancelConfirm => 'Cancel the alarm for everyone?';

  @override
  String get emergencyCancelled => 'Alarm cancelled';

  @override
  String get emergencySending => 'Sending…';

  @override
  String get emergencyCancelling => 'Cancelling…';

  @override
  String get emergencyErrorSignedOut => 'Sign in to raise an alarm.';

  @override
  String get emergencyErrorLocation =>
      'Allow location access in Settings so the alarm reaches people nearby.';

  @override
  String emergencyErrorTooMany(int minutes) {
    return 'You\'ve raised 3 alarms in the last hour. Try again in $minutes min.';
  }

  @override
  String get emergencyErrorOffline =>
      'Can\'t reach the server. Check the internet and try again.';

  @override
  String get emergencyErrorFailed => 'The alarm didn\'t go out. Try again.';

  @override
  String get emergencyErrorCancelFailed =>
      'The alarm is no longer active or couldn\'t be cancelled. Check and try again.';

  @override
  String get emergencyErrorNotConfigured =>
      'The server has no accounts set up. Tell the administrator.';
}
