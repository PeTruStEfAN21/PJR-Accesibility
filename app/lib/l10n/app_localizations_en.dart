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
  String get soundsTitle => 'Vibrations';

  @override
  String get soundsListening =>
      'On, even with the phone locked. They start by themselves whenever the app opens.';

  @override
  String get soundsIdle => 'Alerts are off.';

  @override
  String get soundsPaused =>
      'Paused while captions run. They start again by themselves afterwards.';

  @override
  String get homeSounds => 'Vibrations';

  @override
  String get homeSoundsOn =>
      'On: the phone vibrates for alarms, horns and your name.';

  @override
  String get homeSoundsOff => 'Off: tap to turn on vibration alerts.';

  @override
  String get homeSoundsPaused => 'Paused while captions run.';

  @override
  String get homeSoundsUnavailable =>
      'Not available on this device: tap for details.';

  @override
  String get soundsTest => 'Test the alerts';

  @override
  String get soundsDetectorMissing =>
      'Automatic alerts don\'t work on this device. You can test the vibrations below.';

  @override
  String get soundsExplain =>
      'Your phone vibrates and shows you on screen when something important happens around you. Everything stays on the phone.';

  @override
  String get soundsSwitch => 'Vibration alerts';

  @override
  String get soundsVibrations => 'Vibration for each level';

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
      'Your account, saved meetings, transcripts, summaries and their history are deleted for good. Kept for 12 months, with your email but no longer linked to the account: the alarms you raised, your answers to alarms and, if you are an admin, which employees\' meetings you read (for investigations into alarms, and so employees know who read their meetings). This cannot be undone.';

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
  String get homeOnline => 'Online meeting';

  @override
  String get homeCoach => 'I\'m a colleague in an online meeting';

  @override
  String get homeCoachHint =>
      'Echo quietly tells you when you talk too fast or over others, so a deaf colleague can read the captions.';

  @override
  String get coachTitle => 'Clarity coach';

  @override
  String get coachIntro =>
      'In online meetings, deaf colleagues read the captions. Echo listens to your voice on this computer and quietly tells you when the captions can\'t keep up. The sound never leaves this computer.';

  @override
  String get coachTeam => 'Team';

  @override
  String get coachCodeLabel => 'Team code (optional)';

  @override
  String get coachCodeHint =>
      'With the same code, Echo also tells you when you talk over a colleague.';

  @override
  String get coachCreateCode => 'Create a code';

  @override
  String coachCodeCreated(String code) {
    return 'Code $code is ready: tell your colleagues.';
  }

  @override
  String get coachCodeInvalid => 'The code has 6 letters and digits.';

  @override
  String get coachServerError => 'Can\'t reach the Echo server. Try again.';

  @override
  String get coachMicrophone => 'Microphone';

  @override
  String get coachHeadphones => 'I\'m wearing headphones';

  @override
  String get coachHeadphonesHint =>
      'Then the microphone doesn\'t hear the meeting from the speakers.';

  @override
  String get coachLearnVoice => 'Learn my voice';

  @override
  String get coachVoiceHint =>
      'You read a text for 20 seconds; then Echo only counts what you say.';

  @override
  String get coachVoiceLearned => 'Your voice is learned';

  @override
  String get coachRelearnVoice => 'Learn again';

  @override
  String get coachVoiceStored =>
      'Your voice fingerprint stays only in this browser. You can delete it at any time.';

  @override
  String get coachForgetVoice => 'Delete my voice';

  @override
  String get coachVoiceForgotten => 'Your voice was deleted.';

  @override
  String get coachVoiceError =>
      'Voice recognition doesn\'t work in this browser.';

  @override
  String get coachEnrollIntro =>
      'Read the text below in a normal voice, for about 20 seconds. Echo then recognises your voice and doesn\'t count your colleagues\' voices coming from the speakers. The sound stays on this computer.';

  @override
  String get coachApproximate =>
      'Without headphones or a learned voice, the microphone may also hear the meeting from the speakers: the alerts are approximate and the overlap alert is off.';

  @override
  String get coachDemo => 'Demo mode';

  @override
  String get coachDemoHint =>
      'Short timings, so every alert shows up within a few minutes. Not for real meetings.';

  @override
  String get coachStart => 'Start the coach';

  @override
  String get coachMicError =>
      'Can\'t start the microphone. Allow the microphone in the browser; the page must be opened on https or localhost.';

  @override
  String get coachAllGood => 'All good: the captions are keeping up.';

  @override
  String get coachAlertOverlap =>
      'You\'re talking at the same time as someone else';

  @override
  String get coachAlertWeakMic =>
      'The microphone barely picks you up: move closer or check it';

  @override
  String get coachAlertTooFast => 'You\'re talking too fast for the captions';

  @override
  String get coachAlertNoPauses => 'Pause between ideas';

  @override
  String coachAlertLongTalk(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minutes',
      one: 'a minute',
    );
    return 'You\'ve talked for $_temp0 without a break: leave room for questions';
  }

  @override
  String get coachAlertNoise =>
      'Noise on your side: mute when you\'re not talking';

  @override
  String get coachWatching => 'What I watch';

  @override
  String get coachWatchOverlap => 'Whether you talk over others';

  @override
  String get coachWatchWeakMic => 'How well the microphone picks you up';

  @override
  String get coachWatchTooFast => 'How fast you talk';

  @override
  String get coachWatchNoPauses => 'The pauses between ideas';

  @override
  String get coachWatchLongTalk =>
      'How long you talk without leaving room for questions';

  @override
  String get coachWatchNoise => 'Noise on your side while you\'re quiet';

  @override
  String get coachPip => 'Show alerts over the meeting';

  @override
  String get coachPipClose => 'Close the alert window';

  @override
  String get coachPipTitle => 'Echo · alerts';

  @override
  String get coachPipUnsupported =>
      'The window over the meeting works in Chrome or Edge on a computer, on https or localhost.';

  @override
  String coachTeamStatus(String code, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count colleagues connected',
      one: 'one colleague connected',
      zero: 'no other colleague connected',
    );
    return 'Code $code · $_temp0';
  }

  @override
  String get coachNoTeam => 'No team code: the overlap alert is off.';

  @override
  String coachUnknownCode(String code) {
    return 'Code $code doesn\'t exist. Check it or create another.';
  }

  @override
  String get coachReconnecting => 'Reconnecting to the team…';

  @override
  String get coachNoNoise =>
      'Noise recognition doesn\'t work here: the noise alert is off.';

  @override
  String get coachStop => 'Stop';

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
  String get orgLastAdmin =>
      'You are the company\'s only admin and others are still in it. Make someone else admin, then try again.';

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
  String get emergencyTitle => 'Emergency';

  @override
  String get emergencyHomeHint => 'Alert colleagues nearby';

  @override
  String get emergencyIntro => 'The alarm reaches colleagues within 500 m.';

  @override
  String get emergencyAccountable =>
      'The alarm is saved with your account, the time, the place and your IP address.';

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

  @override
  String get activityTitle => 'My history';

  @override
  String get activityHint => 'Your alarms, saved meetings and who read them';

  @override
  String get activityEmpty =>
      'Nothing in your history yet. Your alarms, saved meetings and who read them show up here.';

  @override
  String get activityCompanyEmpty => 'Nothing in the company history yet.';

  @override
  String get activityLoadError =>
      'Could not load the history. Check the internet connection and try again.';

  @override
  String get activityOlder => 'Older';

  @override
  String get activitySomeone => 'Someone';

  @override
  String get activityNoTitle => 'without a title';

  @override
  String activityQuoted(String title) {
    return '“$title”';
  }

  @override
  String get activityStatusSafe => 'I\'m safe';

  @override
  String get activityStatusNeedHelp => 'I need help';

  @override
  String activityPlace(String lat, String lon, String accuracy) {
    return 'Place: $lat, $lon (±$accuracy m)';
  }

  @override
  String activityAlarmRaisedMe(String kind) {
    return 'You raised an alarm: $kind';
  }

  @override
  String activityAlarmRaised(String who, String kind) {
    return '$who raised an alarm: $kind';
  }

  @override
  String activityAlarmCancelledMe(String kind) {
    return 'You cancelled the alarm: $kind';
  }

  @override
  String activityAlarmCancelled(String who, String kind) {
    return '$who cancelled the alarm: $kind';
  }

  @override
  String activityAlarmReportedMe(String kind) {
    return 'You reported the alarm to the company: $kind';
  }

  @override
  String activityAlarmReported(String who, String kind) {
    return '$who reported the alarm to the company: $kind';
  }

  @override
  String activityAlarmAnsweredMe(String status, String kind) {
    return 'You answered “$status” to the alarm: $kind';
  }

  @override
  String activityAlarmAnswered(String who, String status, String kind) {
    return '$who answered “$status” to the alarm: $kind';
  }

  @override
  String activityAlarmClosedMe(String kind) {
    return 'You closed the alarm: $kind';
  }

  @override
  String activityAlarmClosed(String who, String kind) {
    return '$who closed the alarm: $kind';
  }

  @override
  String activityMeetingStartedMe(String meeting) {
    return 'You started the meeting $meeting';
  }

  @override
  String activityMeetingStarted(String who, String meeting) {
    return '$who started the meeting $meeting';
  }

  @override
  String activityMeetingEndedMe(String meeting) {
    return 'You ended the meeting $meeting';
  }

  @override
  String activityMeetingEnded(String who, String meeting) {
    return '$who ended the meeting $meeting';
  }

  @override
  String activityMeetingDeletedMe(String meeting) {
    return 'You deleted the meeting $meeting';
  }

  @override
  String activityMeetingDeleted(String who, String meeting) {
    return '$who deleted the meeting $meeting';
  }

  @override
  String activityMeetingReadMine(String who, String meeting) {
    return '$who (admin) read your meeting $meeting';
  }

  @override
  String activityMeetingReadByMe(String meeting, String owner) {
    return 'You read the meeting $meeting, saved by $owner';
  }

  @override
  String activityMeetingRead(String who, String meeting, String owner) {
    return '$who (admin) read the meeting $meeting, saved by $owner';
  }

  @override
  String get orgHistory => 'Company history';

  @override
  String get orgHistoryHint => 'Alarms and meetings in the company, and who';

  @override
  String get orgMeetings => 'Company meetings';

  @override
  String get orgMeetingsHint =>
      'Meetings saved by employees while in the company';

  @override
  String get orgMeetingsNotice =>
      'When you open a meeting, the employee sees in their history that you read it.';

  @override
  String get orgMeetingsEmpty =>
      'No meetings saved for the company yet. Meetings employees save while in the company show up here.';

  @override
  String get orgMeetingsLoadError =>
      'Could not load the company meetings. Check the internet connection and try again.';

  @override
  String orgMeetingReadNotice(String owner) {
    return '$owner sees in their history that you read this meeting.';
  }

  @override
  String get orgMeetingOwnerUnknown => 'The employee';

  @override
  String get orgMeetingLoadError =>
      'Could not open the meeting. It may no longer belong to the company; try again.';

  @override
  String get orgInviteNotice =>
      'If you accept, the company\'s admins can read the meetings you save while in the company, and your alarms show up in the company history.';

  @override
  String get orgEmployeeNotice =>
      'Admins can read the meetings you save while in the company, and your alarms show up in the company history. When an admin reads one of your meetings, you see it in My history.';

  @override
  String meetingSavingForOrg(String org) {
    return 'The meeting is being saved for $org. Its admins can read it.';
  }

  @override
  String get meetingPickOrg => 'Choose the company';

  @override
  String get navLabel => 'Main navigation';

  @override
  String get navHome => 'Dashboard';

  @override
  String get navMeeting => 'Meeting';

  @override
  String get navSounds => 'Vibrations';

  @override
  String get navAlarm => 'Emergency';

  @override
  String get navSettings => 'Settings';

  @override
  String get alarmNeedsAccount =>
      'An emergency needs an account: your name goes with it, so colleagues know who sent it.';

  @override
  String get alarmAccountsOff =>
      'Accounts are not turned on for this server, so an emergency cannot be sent from here.';

  @override
  String get meetingTitle => 'Meeting';

  @override
  String get meetingModeLabel => 'How are you taking part?';

  @override
  String get meetingModeJoin => 'Joining';

  @override
  String get meetingModePresent => 'Presenting';

  @override
  String get presentIntroTitle => 'You run the meeting';

  @override
  String get presentIntroBody =>
      'Echo listens to the room on this device and captions you as you speak.';

  @override
  String get presentPointCode =>
      'Participants join with the code or the QR code on screen';

  @override
  String get presentPointQuestions =>
      'Their questions reach you silently, and Echo can read them aloud';

  @override
  String get presentPointVoice =>
      'On a laptop, Echo learns your voice and knows when it\'s you speaking';

  @override
  String get presentStart => 'Start the meeting';
}
