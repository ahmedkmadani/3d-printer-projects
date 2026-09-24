import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

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
    Locale('ar'),
    Locale('en')
  ];

  /// No description provided for @tabHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get tabHome;

  /// No description provided for @tabNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get tabNotes;

  /// No description provided for @tabSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get tabSettings;

  /// No description provided for @thisWeek.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get thisWeek;

  /// No description provided for @latest.
  ///
  /// In en, this message translates to:
  /// **'Latest'**
  String get latest;

  /// No description provided for @unitNotes.
  ///
  /// In en, this message translates to:
  /// **'NOTES'**
  String get unitNotes;

  /// No description provided for @unitSeconds.
  ///
  /// In en, this message translates to:
  /// **'SECONDS'**
  String get unitSeconds;

  /// No description provided for @unitMinutes.
  ///
  /// In en, this message translates to:
  /// **'MINUTES'**
  String get unitMinutes;

  /// No description provided for @whatKeepsComingBack.
  ///
  /// In en, this message translates to:
  /// **'What keeps coming back'**
  String get whatKeepsComingBack;

  /// No description provided for @seeAllPatterns.
  ///
  /// In en, this message translates to:
  /// **'SEE ALL PATTERNS →'**
  String get seeAllPatterns;

  /// No description provided for @nothingRecordedYet.
  ///
  /// In en, this message translates to:
  /// **'Nothing recorded yet'**
  String get nothingRecordedYet;

  /// No description provided for @noPatternsYet.
  ///
  /// In en, this message translates to:
  /// **'No patterns yet'**
  String get noPatternsYet;

  /// No description provided for @notesWaiting.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 note waiting} other{{count} notes waiting}}'**
  String notesWaiting(int count);

  /// No description provided for @transcribingHeadline.
  ///
  /// In en, this message translates to:
  /// **'Transcribing'**
  String get transcribingHeadline;

  /// No description provided for @stateAsleep.
  ///
  /// In en, this message translates to:
  /// **'ASLEEP'**
  String get stateAsleep;

  /// No description provided for @stateListening.
  ///
  /// In en, this message translates to:
  /// **'LISTENING'**
  String get stateListening;

  /// No description provided for @stateSaving.
  ///
  /// In en, this message translates to:
  /// **'SAVING'**
  String get stateSaving;

  /// No description provided for @stateSynced.
  ///
  /// In en, this message translates to:
  /// **'SYNCED'**
  String get stateSynced;

  /// No description provided for @stateWaiting.
  ///
  /// In en, this message translates to:
  /// **'WAITING'**
  String get stateWaiting;

  /// No description provided for @stateNotPaired.
  ///
  /// In en, this message translates to:
  /// **'NOT PAIRED'**
  String get stateNotPaired;

  /// No description provided for @stateTapToConnect.
  ///
  /// In en, this message translates to:
  /// **'TAP TO CONNECT'**
  String get stateTapToConnect;

  /// No description provided for @stateNoJota.
  ///
  /// In en, this message translates to:
  /// **'NO JOTA'**
  String get stateNoJota;

  /// No description provided for @stateNearby.
  ///
  /// In en, this message translates to:
  /// **'NEARBY'**
  String get stateNearby;

  /// No description provided for @stateConnecting.
  ///
  /// In en, this message translates to:
  /// **'CONNECTING'**
  String get stateConnecting;

  /// No description provided for @statePaired.
  ///
  /// In en, this message translates to:
  /// **'PAIRED'**
  String get statePaired;

  /// No description provided for @searchNotes.
  ///
  /// In en, this message translates to:
  /// **'Search notes'**
  String get searchNotes;

  /// No description provided for @clearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get clearSearch;

  /// No description provided for @filter.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get filter;

  /// No description provided for @orderCaption.
  ///
  /// In en, this message translates to:
  /// **'ORDER'**
  String get orderCaption;

  /// No description provided for @tagCaption.
  ///
  /// In en, this message translates to:
  /// **'TAG'**
  String get tagCaption;

  /// No description provided for @newestFirst.
  ///
  /// In en, this message translates to:
  /// **'Newest first'**
  String get newestFirst;

  /// No description provided for @oldestFirst.
  ///
  /// In en, this message translates to:
  /// **'Oldest first'**
  String get oldestFirst;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @showAll.
  ///
  /// In en, this message translates to:
  /// **'Show all'**
  String get showAll;

  /// No description provided for @noNotesMatch.
  ///
  /// In en, this message translates to:
  /// **'No notes match'**
  String get noNotesMatch;

  /// No description provided for @noDevicePaired.
  ///
  /// In en, this message translates to:
  /// **'No device paired'**
  String get noDevicePaired;

  /// No description provided for @pairADevice.
  ///
  /// In en, this message translates to:
  /// **'Pair a device'**
  String get pairADevice;

  /// No description provided for @pressJotaButton.
  ///
  /// In en, this message translates to:
  /// **'Press the button on your Jota'**
  String get pressJotaButton;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'TODAY'**
  String get today;

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'YESTERDAY'**
  String get yesterday;

  /// No description provided for @swipeShare.
  ///
  /// In en, this message translates to:
  /// **'SHARE'**
  String get swipeShare;

  /// No description provided for @swipeDelete.
  ///
  /// In en, this message translates to:
  /// **'DELETE'**
  String get swipeDelete;

  /// No description provided for @noteDeleted.
  ///
  /// In en, this message translates to:
  /// **'Note deleted'**
  String get noteDeleted;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'UNDO'**
  String get undo;

  /// No description provided for @nNew.
  ///
  /// In en, this message translates to:
  /// **'{count} NEW'**
  String nNew(int count);

  /// No description provided for @notesSynced.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 note synced} other{{count} notes synced}}'**
  String notesSynced(int count);

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @transcribe.
  ///
  /// In en, this message translates to:
  /// **'Transcribe'**
  String get transcribe;

  /// No description provided for @transcribeAgain.
  ///
  /// In en, this message translates to:
  /// **'Transcribe again'**
  String get transcribeAgain;

  /// No description provided for @writeIt.
  ///
  /// In en, this message translates to:
  /// **'Write it'**
  String get writeIt;

  /// No description provided for @transcribing.
  ///
  /// In en, this message translates to:
  /// **'Transcribing…'**
  String get transcribing;

  /// No description provided for @notTranscribedYet.
  ///
  /// In en, this message translates to:
  /// **'Not transcribed yet'**
  String get notTranscribedYet;

  /// No description provided for @noSpeechDetected.
  ///
  /// In en, this message translates to:
  /// **'No speech detected'**
  String get noSpeechDetected;

  /// No description provided for @showMore.
  ///
  /// In en, this message translates to:
  /// **'Show more'**
  String get showMore;

  /// No description provided for @showLess.
  ///
  /// In en, this message translates to:
  /// **'Show less'**
  String get showLess;

  /// No description provided for @detailsCaption.
  ///
  /// In en, this message translates to:
  /// **'DETAILS'**
  String get detailsCaption;

  /// No description provided for @factLength.
  ///
  /// In en, this message translates to:
  /// **'Length'**
  String get factLength;

  /// No description provided for @factWords.
  ///
  /// In en, this message translates to:
  /// **'Words'**
  String get factWords;

  /// No description provided for @factReadBy.
  ///
  /// In en, this message translates to:
  /// **'Read by'**
  String get factReadBy;

  /// No description provided for @factWrittenBy.
  ///
  /// In en, this message translates to:
  /// **'Written by'**
  String get factWrittenBy;

  /// No description provided for @factYou.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get factYou;

  /// No description provided for @factOnThisPhone.
  ///
  /// In en, this message translates to:
  /// **'On this phone'**
  String get factOnThisPhone;

  /// No description provided for @factSynced.
  ///
  /// In en, this message translates to:
  /// **'Synced'**
  String get factSynced;

  /// No description provided for @factNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get factNote;

  /// No description provided for @deleteNote.
  ///
  /// In en, this message translates to:
  /// **'Delete note'**
  String get deleteNote;

  /// No description provided for @deleteThisNote.
  ///
  /// In en, this message translates to:
  /// **'Delete this note?'**
  String get deleteThisNote;

  /// No description provided for @deleteNoteBody.
  ///
  /// In en, this message translates to:
  /// **'Your Jota has already let go of its copy, so this can’t be undone.'**
  String get deleteNoteBody;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @addTag.
  ///
  /// In en, this message translates to:
  /// **'Add tag'**
  String get addTag;

  /// No description provided for @tagValue.
  ///
  /// In en, this message translates to:
  /// **'Tag: {tag}'**
  String tagValue(String tag);

  /// No description provided for @transcriptTitle.
  ///
  /// In en, this message translates to:
  /// **'Transcript'**
  String get transcriptTitle;

  /// No description provided for @whatWasSaid.
  ///
  /// In en, this message translates to:
  /// **'What was said'**
  String get whatWasSaid;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @audioFileMissing.
  ///
  /// In en, this message translates to:
  /// **'Audio file is missing'**
  String get audioFileMissing;

  /// No description provided for @couldNotPlay.
  ///
  /// In en, this message translates to:
  /// **'Could not play this note ({error})'**
  String couldNotPlay(String error);

  /// No description provided for @playSemantics.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get playSemantics;

  /// No description provided for @pauseSemantics.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pauseSemantics;

  /// No description provided for @backFifteen.
  ///
  /// In en, this message translates to:
  /// **'Back fifteen seconds'**
  String get backFifteen;

  /// No description provided for @noWordsToShareYet.
  ///
  /// In en, this message translates to:
  /// **'No words to share yet'**
  String get noWordsToShareYet;

  /// No description provided for @tagSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Tag'**
  String get tagSheetTitle;

  /// No description provided for @editTags.
  ///
  /// In en, this message translates to:
  /// **'Edit tags'**
  String get editTags;

  /// No description provided for @noTag.
  ///
  /// In en, this message translates to:
  /// **'No tag'**
  String get noTag;

  /// No description provided for @noTagsYet.
  ///
  /// In en, this message translates to:
  /// **'No tags yet'**
  String get noTagsYet;

  /// No description provided for @tagsTitle.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get tagsTitle;

  /// No description provided for @onJota.
  ///
  /// In en, this message translates to:
  /// **'ON JOTA'**
  String get onJota;

  /// No description provided for @sortByUse.
  ///
  /// In en, this message translates to:
  /// **'Sort by use'**
  String get sortByUse;

  /// No description provided for @alreadySorted.
  ///
  /// In en, this message translates to:
  /// **'Already sorted'**
  String get alreadySorted;

  /// No description provided for @readingJota.
  ///
  /// In en, this message translates to:
  /// **'Reading Jota…'**
  String get readingJota;

  /// No description provided for @tagRemoved.
  ///
  /// In en, this message translates to:
  /// **'{tag} removed'**
  String tagRemoved(String tag);

  /// No description provided for @alreadyATag.
  ///
  /// In en, this message translates to:
  /// **'{value} is already a tag'**
  String alreadyATag(String value);

  /// No description provided for @maxTags.
  ///
  /// In en, this message translates to:
  /// **'{max} is the most your Jota holds'**
  String maxTags(int max);

  /// No description provided for @savedTagsSync.
  ///
  /// In en, this message translates to:
  /// **'Saved. Jota gets them at sync'**
  String get savedTagsSync;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @captionTranscription.
  ///
  /// In en, this message translates to:
  /// **'TRANSCRIPTION'**
  String get captionTranscription;

  /// No description provided for @captionDevice.
  ///
  /// In en, this message translates to:
  /// **'DEVICE'**
  String get captionDevice;

  /// No description provided for @captionYourData.
  ///
  /// In en, this message translates to:
  /// **'YOUR DATA'**
  String get captionYourData;

  /// No description provided for @captionAbout.
  ///
  /// In en, this message translates to:
  /// **'ABOUT'**
  String get captionAbout;

  /// No description provided for @rowTranscribe.
  ///
  /// In en, this message translates to:
  /// **'Transcribe'**
  String get rowTranscribe;

  /// No description provided for @onDevice.
  ///
  /// In en, this message translates to:
  /// **'On device'**
  String get onDevice;

  /// No description provided for @spokenLanguage.
  ///
  /// In en, this message translates to:
  /// **'Spoken language'**
  String get spokenLanguage;

  /// No description provided for @languageAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get languageAuto;

  /// No description provided for @languageArabic.
  ///
  /// In en, this message translates to:
  /// **'Arabic'**
  String get languageArabic;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Spoken language'**
  String get languageSheetTitle;

  /// No description provided for @transcribeAutomatically.
  ///
  /// In en, this message translates to:
  /// **'Transcribe automatically'**
  String get transcribeAutomatically;

  /// No description provided for @valueOn.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get valueOn;

  /// No description provided for @valueOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get valueOff;

  /// No description provided for @valueUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get valueUnknown;

  /// No description provided for @rowDevice.
  ///
  /// In en, this message translates to:
  /// **'Device'**
  String get rowDevice;

  /// No description provided for @rowBattery.
  ///
  /// In en, this message translates to:
  /// **'Battery'**
  String get rowBattery;

  /// No description provided for @rowFirmware.
  ///
  /// In en, this message translates to:
  /// **'Firmware'**
  String get rowFirmware;

  /// No description provided for @firmwareTitle.
  ///
  /// In en, this message translates to:
  /// **'Firmware'**
  String get firmwareTitle;

  /// No description provided for @fwVersion.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get fwVersion;

  /// No description provided for @fwBuilt.
  ///
  /// In en, this message translates to:
  /// **'Built'**
  String get fwBuilt;

  /// No description provided for @fwLastReset.
  ///
  /// In en, this message translates to:
  /// **'Last reset'**
  String get fwLastReset;

  /// No description provided for @fwBoots.
  ///
  /// In en, this message translates to:
  /// **'Boots'**
  String get fwBoots;

  /// No description provided for @fwCrashes.
  ///
  /// In en, this message translates to:
  /// **'Crashes'**
  String get fwCrashes;

  /// No description provided for @fwNotesRecorded.
  ///
  /// In en, this message translates to:
  /// **'Notes recorded'**
  String get fwNotesRecorded;

  /// No description provided for @fwSyncs.
  ///
  /// In en, this message translates to:
  /// **'Syncs'**
  String get fwSyncs;

  /// No description provided for @fwUptime.
  ///
  /// In en, this message translates to:
  /// **'Uptime'**
  String get fwUptime;

  /// No description provided for @fwFreeMemory.
  ///
  /// In en, this message translates to:
  /// **'Free memory'**
  String get fwFreeMemory;

  /// No description provided for @rowTags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get rowTags;

  /// No description provided for @rowSyncBackground.
  ///
  /// In en, this message translates to:
  /// **'Sync in the background'**
  String get rowSyncBackground;

  /// No description provided for @forgetThisJota.
  ///
  /// In en, this message translates to:
  /// **'Forget this Jota'**
  String get forgetThisJota;

  /// No description provided for @jotaNotInRange.
  ///
  /// In en, this message translates to:
  /// **'Jota isn’t in range'**
  String get jotaNotInRange;

  /// No description provided for @forgetBody.
  ///
  /// In en, this message translates to:
  /// **'Bring your Jota close and try again, so it forgets this phone too.\n\nRemove it anyway and this Jota will still trust this phone until you erase it on the device — hold both buttons.'**
  String get forgetBody;

  /// No description provided for @removeAnyway.
  ///
  /// In en, this message translates to:
  /// **'Remove anyway'**
  String get removeAnyway;

  /// No description provided for @jotaForgotten.
  ///
  /// In en, this message translates to:
  /// **'Jota forgotten'**
  String get jotaForgotten;

  /// No description provided for @eraseDevice.
  ///
  /// In en, this message translates to:
  /// **'Erase device'**
  String get eraseDevice;

  /// No description provided for @eraseThisJota.
  ///
  /// In en, this message translates to:
  /// **'Erase this Jota?'**
  String get eraseThisJota;

  /// No description provided for @eraseBody.
  ///
  /// In en, this message translates to:
  /// **'Every note on it is deleted. It forgets this phone.'**
  String get eraseBody;

  /// No description provided for @erase.
  ///
  /// In en, this message translates to:
  /// **'Erase'**
  String get erase;

  /// No description provided for @waitingForJota.
  ///
  /// In en, this message translates to:
  /// **'Waiting for your Jota — press a button on it'**
  String get waitingForJota;

  /// No description provided for @noJotaNearby.
  ///
  /// In en, this message translates to:
  /// **'No Jota nearby'**
  String get noJotaNearby;

  /// No description provided for @jotaErased.
  ///
  /// In en, this message translates to:
  /// **'Jota erased'**
  String get jotaErased;

  /// No description provided for @couldNotErase.
  ///
  /// In en, this message translates to:
  /// **'Could not erase'**
  String get couldNotErase;

  /// No description provided for @holdBothButtons.
  ///
  /// In en, this message translates to:
  /// **'Not yet — hold both buttons on the Jota for five seconds'**
  String get holdBothButtons;

  /// No description provided for @rowStorage.
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get rowStorage;

  /// No description provided for @shareAllNotes.
  ///
  /// In en, this message translates to:
  /// **'Share all notes'**
  String get shareAllNotes;

  /// No description provided for @exportCorrections.
  ///
  /// In en, this message translates to:
  /// **'Export corrections'**
  String get exportCorrections;

  /// No description provided for @noCorrectionsYet.
  ///
  /// In en, this message translates to:
  /// **'No corrections yet'**
  String get noCorrectionsYet;

  /// No description provided for @playbackCache.
  ///
  /// In en, this message translates to:
  /// **'Playback cache'**
  String get playbackCache;

  /// No description provided for @unlockWithFingerprint.
  ///
  /// In en, this message translates to:
  /// **'Unlock with fingerprint'**
  String get unlockWithFingerprint;

  /// No description provided for @setPhoneLockFirst.
  ///
  /// In en, this message translates to:
  /// **'Set a phone lock first'**
  String get setPhoneLockFirst;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @appearanceSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get appearanceSystem;

  /// No description provided for @appearanceLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get appearanceLight;

  /// No description provided for @appearanceDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get appearanceDark;

  /// No description provided for @appLanguage.
  ///
  /// In en, this message translates to:
  /// **'App language'**
  String get appLanguage;

  /// No description provided for @appLanguageSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get appLanguageSystem;

  /// No description provided for @appLanguageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get appLanguageEnglish;

  /// No description provided for @appLanguageArabic.
  ///
  /// In en, this message translates to:
  /// **'العربية'**
  String get appLanguageArabic;

  /// No description provided for @rowThisPhone.
  ///
  /// In en, this message translates to:
  /// **'This phone'**
  String get rowThisPhone;

  /// No description provided for @rowVersion.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get rowVersion;

  /// No description provided for @replayOnboarding.
  ///
  /// In en, this message translates to:
  /// **'Replay onboarding'**
  String get replayOnboarding;

  /// No description provided for @connectYourJota.
  ///
  /// In en, this message translates to:
  /// **'Connect your Jota'**
  String get connectYourJota;

  /// No description provided for @switchOnYourJota.
  ///
  /// In en, this message translates to:
  /// **'Switch on your Jota'**
  String get switchOnYourJota;

  /// No description provided for @connect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connect;

  /// No description provided for @enterCodeOnJota.
  ///
  /// In en, this message translates to:
  /// **'Enter the code on the Jota'**
  String get enterCodeOnJota;

  /// No description provided for @pair.
  ///
  /// In en, this message translates to:
  /// **'Pair'**
  String get pair;

  /// No description provided for @pairWithJota.
  ///
  /// In en, this message translates to:
  /// **'Pair with Jota'**
  String get pairWithJota;

  /// No description provided for @setUpLater.
  ///
  /// In en, this message translates to:
  /// **'Set up later'**
  String get setUpLater;

  /// No description provided for @notNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get notNow;

  /// No description provided for @connectMyJota.
  ///
  /// In en, this message translates to:
  /// **'Connect my Jota'**
  String get connectMyJota;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @obHead1.
  ///
  /// In en, this message translates to:
  /// **'When your head\nis full.'**
  String get obHead1;

  /// No description provided for @obBody1.
  ///
  /// In en, this message translates to:
  /// **'Thoughts pile up and talk over each other. That is jota.'**
  String get obBody1;

  /// No description provided for @obHead2.
  ///
  /// In en, this message translates to:
  /// **'Say it,\nlet it out.'**
  String get obHead2;

  /// No description provided for @obBody2.
  ///
  /// In en, this message translates to:
  /// **'Press once and speak. Jota holds it for you.'**
  String get obBody2;

  /// No description provided for @obHead3.
  ///
  /// In en, this message translates to:
  /// **'Feel\nlighter.'**
  String get obHead3;

  /// No description provided for @obBody3.
  ///
  /// In en, this message translates to:
  /// **'It is out, it is saved, and it is yours.'**
  String get obBody3;

  /// No description provided for @bluetoothOff.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth is off'**
  String get bluetoothOff;

  /// No description provided for @jotaNeedsBluetooth.
  ///
  /// In en, this message translates to:
  /// **'Jota needs Bluetooth'**
  String get jotaNeedsBluetooth;

  /// No description provided for @turnOnBluetooth.
  ///
  /// In en, this message translates to:
  /// **'Turn on Bluetooth'**
  String get turnOnBluetooth;

  /// No description provided for @allowBluetooth.
  ///
  /// In en, this message translates to:
  /// **'Allow Bluetooth in Settings'**
  String get allowBluetooth;

  /// No description provided for @unlockJota.
  ///
  /// In en, this message translates to:
  /// **'Unlock Jota'**
  String get unlockJota;

  /// No description provided for @useFaceOrFingerprint.
  ///
  /// In en, this message translates to:
  /// **'Use your face or fingerprint'**
  String get useFaceOrFingerprint;

  /// No description provided for @unlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get unlock;

  /// No description provided for @patternsAcrossWeeks.
  ///
  /// In en, this message translates to:
  /// **'Across your last {weeks} weeks'**
  String patternsAcrossWeeks(int weeks);

  /// No description provided for @topicNotes.
  ///
  /// In en, this message translates to:
  /// **'{count} NOTES'**
  String topicNotes(int count);

  /// No description provided for @topicNotesThisWeek.
  ///
  /// In en, this message translates to:
  /// **'{count} NOTES · {week} THIS WEEK'**
  String topicNotesThisWeek(int count, int week);

  /// No description provided for @weeksFigure.
  ///
  /// In en, this message translates to:
  /// **'{weeks} WEEKS'**
  String weeksFigure(int weeks);

  /// No description provided for @stateNeedsPermission.
  ///
  /// In en, this message translates to:
  /// **'NEEDS PERMISSION'**
  String get stateNeedsPermission;

  /// No description provided for @stateBluetoothOff.
  ///
  /// In en, this message translates to:
  /// **'BLUETOOTH OFF'**
  String get stateBluetoothOff;

  /// No description provided for @nothingToSync.
  ///
  /// In en, this message translates to:
  /// **'Nothing to sync'**
  String get nothingToSync;

  /// No description provided for @syncFailed.
  ///
  /// In en, this message translates to:
  /// **'Sync failed'**
  String get syncFailed;

  /// No description provided for @alreadyUpToDate.
  ///
  /// In en, this message translates to:
  /// **'Already up to date'**
  String get alreadyUpToDate;

  /// No description provided for @tagHint.
  ///
  /// In en, this message translates to:
  /// **'WORK'**
  String get tagHint;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @wakeYourJota.
  ///
  /// In en, this message translates to:
  /// **'Wake your Jota'**
  String get wakeYourJota;

  /// No description provided for @pressButtonOnIt.
  ///
  /// In en, this message translates to:
  /// **'Press a button on it'**
  String get pressButtonOnIt;

  /// No description provided for @sync.
  ///
  /// In en, this message translates to:
  /// **'Sync'**
  String get sync;

  /// No description provided for @connectingLabel.
  ///
  /// In en, this message translates to:
  /// **'Connecting'**
  String get connectingLabel;

  /// No description provided for @noteReady.
  ///
  /// In en, this message translates to:
  /// **'{id} is ready'**
  String noteReady(String id);

  /// No description provided for @channelTranscripts.
  ///
  /// In en, this message translates to:
  /// **'Transcripts'**
  String get channelTranscripts;

  /// No description provided for @channelTranscriptsBody.
  ///
  /// In en, this message translates to:
  /// **'A note has been transcribed.'**
  String get channelTranscriptsBody;
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
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
