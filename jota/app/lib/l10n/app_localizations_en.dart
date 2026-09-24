// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get tabHome => 'Home';

  @override
  String get tabNotes => 'Notes';

  @override
  String get tabSettings => 'Settings';

  @override
  String get thisWeek => 'This week';

  @override
  String get latest => 'Latest';

  @override
  String get unitNotes => 'NOTES';

  @override
  String get unitSeconds => 'SECONDS';

  @override
  String get unitMinutes => 'MINUTES';

  @override
  String get whatKeepsComingBack => 'What keeps coming back';

  @override
  String get seeAllPatterns => 'SEE ALL PATTERNS →';

  @override
  String get nothingRecordedYet => 'Nothing recorded yet';

  @override
  String get noPatternsYet => 'No patterns yet';

  @override
  String notesWaiting(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notes waiting',
      one: '1 note waiting',
    );
    return '$_temp0';
  }

  @override
  String get transcribingHeadline => 'Transcribing';

  @override
  String get stateAsleep => 'ASLEEP';

  @override
  String get stateListening => 'LISTENING';

  @override
  String get stateSaving => 'SAVING';

  @override
  String get stateSynced => 'SYNCED';

  @override
  String get stateWaiting => 'WAITING';

  @override
  String get stateNotPaired => 'NOT PAIRED';

  @override
  String get stateTapToConnect => 'TAP TO CONNECT';

  @override
  String get stateNoJota => 'NO JOTA';

  @override
  String get stateNearby => 'NEARBY';

  @override
  String get stateConnecting => 'CONNECTING';

  @override
  String get statePaired => 'PAIRED';

  @override
  String get searchNotes => 'Search notes';

  @override
  String get clearSearch => 'Clear search';

  @override
  String get filter => 'Filter';

  @override
  String get orderCaption => 'ORDER';

  @override
  String get tagCaption => 'TAG';

  @override
  String get newestFirst => 'Newest first';

  @override
  String get oldestFirst => 'Oldest first';

  @override
  String get all => 'All';

  @override
  String get clear => 'Clear';

  @override
  String get showAll => 'Show all';

  @override
  String get noNotesMatch => 'No notes match';

  @override
  String get noDevicePaired => 'No device paired';

  @override
  String get pairADevice => 'Pair a device';

  @override
  String get pressJotaButton => 'Press the button on your Jota';

  @override
  String get today => 'TODAY';

  @override
  String get yesterday => 'YESTERDAY';

  @override
  String get swipeShare => 'SHARE';

  @override
  String get swipeDelete => 'DELETE';

  @override
  String get noteDeleted => 'Note deleted';

  @override
  String get undo => 'UNDO';

  @override
  String nNew(int count) {
    return '$count NEW';
  }

  @override
  String notesSynced(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notes synced',
      one: '1 note synced',
    );
    return '$_temp0';
  }

  @override
  String get edit => 'Edit';

  @override
  String get transcribe => 'Transcribe';

  @override
  String get transcribeAgain => 'Transcribe again';

  @override
  String get writeIt => 'Write it';

  @override
  String get transcribing => 'Transcribing…';

  @override
  String get notTranscribedYet => 'Not transcribed yet';

  @override
  String get noSpeechDetected => 'No speech detected';

  @override
  String get showMore => 'Show more';

  @override
  String get showLess => 'Show less';

  @override
  String get detailsCaption => 'DETAILS';

  @override
  String get factLength => 'Length';

  @override
  String get factWords => 'Words';

  @override
  String get factReadBy => 'Read by';

  @override
  String get factWrittenBy => 'Written by';

  @override
  String get factYou => 'You';

  @override
  String get factOnThisPhone => 'On this phone';

  @override
  String get factSynced => 'Synced';

  @override
  String get factNote => 'Note';

  @override
  String get deleteNote => 'Delete note';

  @override
  String get deleteThisNote => 'Delete this note?';

  @override
  String get deleteNoteBody =>
      'Your Jota has already let go of its copy, so this can’t be undone.';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get share => 'Share';

  @override
  String get addTag => 'Add tag';

  @override
  String tagValue(String tag) {
    return 'Tag: $tag';
  }

  @override
  String get transcriptTitle => 'Transcript';

  @override
  String get whatWasSaid => 'What was said';

  @override
  String get save => 'Save';

  @override
  String get audioFileMissing => 'Audio file is missing';

  @override
  String couldNotPlay(String error) {
    return 'Could not play this note ($error)';
  }

  @override
  String get playSemantics => 'Play';

  @override
  String get pauseSemantics => 'Pause';

  @override
  String get backFifteen => 'Back fifteen seconds';

  @override
  String get noWordsToShareYet => 'No words to share yet';

  @override
  String get tagSheetTitle => 'Tag';

  @override
  String get editTags => 'Edit tags';

  @override
  String get noTag => 'No tag';

  @override
  String get noTagsYet => 'No tags yet';

  @override
  String get tagsTitle => 'Tags';

  @override
  String get onJota => 'ON JOTA';

  @override
  String get sortByUse => 'Sort by use';

  @override
  String get alreadySorted => 'Already sorted';

  @override
  String get readingJota => 'Reading Jota…';

  @override
  String tagRemoved(String tag) {
    return '$tag removed';
  }

  @override
  String alreadyATag(String value) {
    return '$value is already a tag';
  }

  @override
  String maxTags(int max) {
    return '$max is the most your Jota holds';
  }

  @override
  String get savedTagsSync => 'Saved. Jota gets them at sync';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get captionTranscription => 'TRANSCRIPTION';

  @override
  String get captionDevice => 'DEVICE';

  @override
  String get captionYourData => 'YOUR DATA';

  @override
  String get captionAbout => 'ABOUT';

  @override
  String get rowTranscribe => 'Transcribe';

  @override
  String get onDevice => 'On device';

  @override
  String get spokenLanguage => 'Spoken language';

  @override
  String get languageAuto => 'Auto';

  @override
  String get languageArabic => 'Arabic';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageSheetTitle => 'Spoken language';

  @override
  String get transcribeAutomatically => 'Transcribe automatically';

  @override
  String get valueOn => 'On';

  @override
  String get valueOff => 'Off';

  @override
  String get valueUnknown => 'Unknown';

  @override
  String get rowDevice => 'Device';

  @override
  String get rowBattery => 'Battery';

  @override
  String get rowFirmware => 'Firmware';

  @override
  String get firmwareTitle => 'Firmware';

  @override
  String get fwVersion => 'Version';

  @override
  String get fwBuilt => 'Built';

  @override
  String get fwLastReset => 'Last reset';

  @override
  String get fwBoots => 'Boots';

  @override
  String get fwCrashes => 'Crashes';

  @override
  String get fwNotesRecorded => 'Notes recorded';

  @override
  String get fwSyncs => 'Syncs';

  @override
  String get fwUptime => 'Uptime';

  @override
  String get fwFreeMemory => 'Free memory';

  @override
  String get rowTags => 'Tags';

  @override
  String get rowSyncBackground => 'Sync in the background';

  @override
  String get forgetThisJota => 'Forget this Jota';

  @override
  String get jotaNotInRange => 'Jota isn’t in range';

  @override
  String get forgetBody =>
      'Bring your Jota close and try again, so it forgets this phone too.\n\nRemove it anyway and this Jota will still trust this phone until you erase it on the device — hold both buttons.';

  @override
  String get removeAnyway => 'Remove anyway';

  @override
  String get jotaForgotten => 'Jota forgotten';

  @override
  String get eraseDevice => 'Erase device';

  @override
  String get eraseThisJota => 'Erase this Jota?';

  @override
  String get eraseBody => 'Every note on it is deleted. It forgets this phone.';

  @override
  String get erase => 'Erase';

  @override
  String get waitingForJota => 'Waiting for your Jota — press a button on it';

  @override
  String get noJotaNearby => 'No Jota nearby';

  @override
  String get jotaErased => 'Jota erased';

  @override
  String get couldNotErase => 'Could not erase';

  @override
  String get holdBothButtons =>
      'Not yet — hold both buttons on the Jota for five seconds';

  @override
  String get rowStorage => 'Storage';

  @override
  String get shareAllNotes => 'Share all notes';

  @override
  String get exportCorrections => 'Export corrections';

  @override
  String get noCorrectionsYet => 'No corrections yet';

  @override
  String get playbackCache => 'Playback cache';

  @override
  String get unlockWithFingerprint => 'Unlock with fingerprint';

  @override
  String get setPhoneLockFirst => 'Set a phone lock first';

  @override
  String get appearance => 'Appearance';

  @override
  String get appearanceSystem => 'System';

  @override
  String get appearanceLight => 'Light';

  @override
  String get appearanceDark => 'Dark';

  @override
  String get appLanguage => 'App language';

  @override
  String get appLanguageSystem => 'System';

  @override
  String get appLanguageEnglish => 'English';

  @override
  String get appLanguageArabic => 'العربية';

  @override
  String get rowThisPhone => 'This phone';

  @override
  String get rowVersion => 'Version';

  @override
  String get replayOnboarding => 'Replay onboarding';

  @override
  String get connectYourJota => 'Connect your Jota';

  @override
  String get switchOnYourJota => 'Switch on your Jota';

  @override
  String get connect => 'Connect';

  @override
  String get enterCodeOnJota => 'Enter the code on the Jota';

  @override
  String get pair => 'Pair';

  @override
  String get pairWithJota => 'Pair with Jota';

  @override
  String get setUpLater => 'Set up later';

  @override
  String get notNow => 'Not now';

  @override
  String get connectMyJota => 'Connect my Jota';

  @override
  String get next => 'Next';

  @override
  String get skip => 'Skip';

  @override
  String get obHead1 => 'When your head\nis full.';

  @override
  String get obBody1 =>
      'Thoughts pile up and talk over each other. That is jota.';

  @override
  String get obHead2 => 'Say it,\nlet it out.';

  @override
  String get obBody2 => 'Press once and speak. Jota holds it for you.';

  @override
  String get obHead3 => 'Feel\nlighter.';

  @override
  String get obBody3 => 'It is out, it is saved, and it is yours.';

  @override
  String get bluetoothOff => 'Bluetooth is off';

  @override
  String get jotaNeedsBluetooth => 'Jota needs Bluetooth';

  @override
  String get turnOnBluetooth => 'Turn on Bluetooth';

  @override
  String get allowBluetooth => 'Allow Bluetooth in Settings';

  @override
  String get unlockJota => 'Unlock Jota';

  @override
  String get useFaceOrFingerprint => 'Use your face or fingerprint';

  @override
  String get unlock => 'Unlock';

  @override
  String patternsAcrossWeeks(int weeks) {
    return 'Across your last $weeks weeks';
  }

  @override
  String topicNotes(int count) {
    return '$count NOTES';
  }

  @override
  String topicNotesThisWeek(int count, int week) {
    return '$count NOTES · $week THIS WEEK';
  }

  @override
  String weeksFigure(int weeks) {
    return '$weeks WEEKS';
  }

  @override
  String get stateNeedsPermission => 'NEEDS PERMISSION';

  @override
  String get stateBluetoothOff => 'BLUETOOTH OFF';

  @override
  String get nothingToSync => 'Nothing to sync';

  @override
  String get syncFailed => 'Sync failed';

  @override
  String get alreadyUpToDate => 'Already up to date';

  @override
  String get tagHint => 'WORK';

  @override
  String get done => 'Done';

  @override
  String get remove => 'Remove';

  @override
  String get back => 'Back';

  @override
  String get wakeYourJota => 'Wake your Jota';

  @override
  String get pressButtonOnIt => 'Press a button on it';

  @override
  String get sync => 'Sync';

  @override
  String get connectingLabel => 'Connecting';

  @override
  String noteReady(String id) {
    return '$id is ready';
  }

  @override
  String get channelTranscripts => 'Transcripts';

  @override
  String get channelTranscriptsBody => 'A note has been transcribed.';
}
