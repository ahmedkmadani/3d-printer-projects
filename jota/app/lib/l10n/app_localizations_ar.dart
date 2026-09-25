// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get tabHome => 'الرئيسية';

  @override
  String get tabNotes => 'الملاحظات';

  @override
  String get tabSettings => 'الإعدادات';

  @override
  String get thisWeek => 'هذا الأسبوع';

  @override
  String get latest => 'الأخيرة';

  @override
  String get unitNotes => 'ملاحظات';

  @override
  String get unitSeconds => 'ثوانٍ';

  @override
  String get unitMinutes => 'دقائق';

  @override
  String get whatKeepsComingBack => 'ما يتكرر';

  @override
  String get seeAllPatterns => 'كل الأنماط ←';

  @override
  String get nothingRecordedYet => 'لا تسجيلات بعد';

  @override
  String get noPatternsYet => 'لا أنماط بعد';

  @override
  String notesWaiting(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ملاحظات بانتظارك',
      two: 'ملاحظتان بانتظارك',
      one: 'ملاحظة واحدة بانتظارك',
    );
    return '$_temp0';
  }

  @override
  String get transcribingHeadline => 'يجري التفريغ';

  @override
  String get stateAsleep => 'نائم';

  @override
  String get stateListening => 'يستمع';

  @override
  String get stateSaving => 'يحفظ';

  @override
  String get stateSynced => 'مُزامَن';

  @override
  String get stateWaiting => 'بانتظار';

  @override
  String get stateNotPaired => 'غير مقترن';

  @override
  String get stateTapToConnect => 'انقر للاتصال';

  @override
  String get stateNoJota => 'لا جوطة';

  @override
  String get stateNearby => 'قريب';

  @override
  String get stateConnecting => 'يتصل';

  @override
  String get statePaired => 'مقترن';

  @override
  String get searchNotes => 'ابحث في الملاحظات';

  @override
  String get clearSearch => 'مسح البحث';

  @override
  String get filter => 'تصفية';

  @override
  String get orderCaption => 'الترتيب';

  @override
  String get tagCaption => 'الوسم';

  @override
  String get newestFirst => 'الأحدث أولًا';

  @override
  String get oldestFirst => 'الأقدم أولًا';

  @override
  String get all => 'الكل';

  @override
  String get clear => 'مسح';

  @override
  String get showAll => 'عرض الكل';

  @override
  String get noNotesMatch => 'لا نتائج';

  @override
  String get noDevicePaired => 'لا جهاز مقترنًا';

  @override
  String get pairADevice => 'اقرن جهازًا';

  @override
  String get pressJotaButton => 'اضغط زر جوطة';

  @override
  String get today => 'اليوم';

  @override
  String get yesterday => 'أمس';

  @override
  String get swipeShare => 'مشاركة';

  @override
  String get swipeDelete => 'حذف';

  @override
  String get noteDeleted => 'حُذفت الملاحظة';

  @override
  String get undo => 'تراجع';

  @override
  String nNew(int count) {
    return '$count جديدة';
  }

  @override
  String notesSynced(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تمت مزامنة $count ملاحظات',
      two: 'تمت مزامنة ملاحظتين',
      one: 'تمت مزامنة ملاحظة',
    );
    return '$_temp0';
  }

  @override
  String get edit => 'تعديل';

  @override
  String get transcribe => 'تفريغ';

  @override
  String get transcribeAgain => 'إعادة التفريغ';

  @override
  String get writeIt => 'اكتبها';

  @override
  String get transcribing => 'يجري التفريغ…';

  @override
  String get notTranscribedYet => 'لم تُفرَّغ بعد';

  @override
  String get noSpeechDetected => 'لا كلام في التسجيل';

  @override
  String get showMore => 'المزيد';

  @override
  String get showLess => 'أقل';

  @override
  String get detailsCaption => 'التفاصيل';

  @override
  String get factLength => 'المدة';

  @override
  String get factWords => 'الكلمات';

  @override
  String get factReadBy => 'فُرِّغت';

  @override
  String get factWrittenBy => 'كتبها';

  @override
  String get factYou => 'أنت';

  @override
  String get factOnThisPhone => 'على هذا الهاتف';

  @override
  String get factSynced => 'المزامنة';

  @override
  String get factNote => 'الملاحظة';

  @override
  String get deleteNote => 'حذف الملاحظة';

  @override
  String get deleteThisNote => 'أتحذف هذه الملاحظة؟';

  @override
  String get deleteNoteBody => 'تخلّت جوطة عن نسختها، فلا رجوع بعد الحذف.';

  @override
  String get cancel => 'إلغاء';

  @override
  String get delete => 'حذف';

  @override
  String get share => 'مشاركة';

  @override
  String get addTag => 'أضف وسمًا';

  @override
  String tagValue(String tag) {
    return 'الوسم: $tag';
  }

  @override
  String get transcriptTitle => 'النص';

  @override
  String get whatWasSaid => 'ما قيل';

  @override
  String get save => 'حفظ';

  @override
  String get audioFileMissing => 'ملف الصوت مفقود';

  @override
  String couldNotPlay(String error) {
    return 'تعذر تشغيل الملاحظة ($error)';
  }

  @override
  String get playSemantics => 'تشغيل';

  @override
  String get pauseSemantics => 'إيقاف';

  @override
  String get backFifteen => 'خمس عشرة ثانية للخلف';

  @override
  String get noWordsToShareYet => 'لا نص للمشاركة بعد';

  @override
  String get tagSheetTitle => 'الوسم';

  @override
  String get editTags => 'تعديل الوسوم';

  @override
  String get noTag => 'أزل الوسم';

  @override
  String get noTagsYet => 'لا وسوم بعد';

  @override
  String get tagsTitle => 'الوسوم';

  @override
  String get onJota => 'على جوطة';

  @override
  String get sortByUse => 'رتّب بالاستخدام';

  @override
  String get alreadySorted => 'مرتبة أصلًا';

  @override
  String get readingJota => 'يقرأ جوطة…';

  @override
  String tagRemoved(String tag) {
    return 'أُزيل $tag';
  }

  @override
  String alreadyATag(String value) {
    return '$value وسم موجود';
  }

  @override
  String maxTags(int max) {
    return '$max هو أقصى ما تحمله جوطة';
  }

  @override
  String get savedTagsSync => 'حُفظت. تصل جوطة عند المزامنة';

  @override
  String get settingsTitle => 'الإعدادات';

  @override
  String get captionTranscription => 'التفريغ';

  @override
  String get captionDevice => 'الجهاز';

  @override
  String get captionYourData => 'بياناتك';

  @override
  String get captionAbout => 'حول';

  @override
  String get rowTranscribe => 'التفريغ';

  @override
  String get onDevice => 'على الهاتف';

  @override
  String get spokenLanguage => 'لغة الكلام';

  @override
  String get languageAuto => 'تلقائي';

  @override
  String get languageArabic => 'العربية';

  @override
  String get languageEnglish => 'الإنجليزية';

  @override
  String get languageSheetTitle => 'لغة الكلام';

  @override
  String get transcribeAutomatically => 'تفريغ تلقائي';

  @override
  String get valueOn => 'مفعّل';

  @override
  String get valueOff => 'معطّل';

  @override
  String get valueUnknown => 'غير معروف';

  @override
  String get rowDevice => 'الجهاز';

  @override
  String get rowBattery => 'البطارية';

  @override
  String get rowFirmware => 'البرنامج الثابت';

  @override
  String get firmwareTitle => 'البرنامج الثابت';

  @override
  String get fwVersion => 'الإصدار';

  @override
  String get fwBuilt => 'بُني';

  @override
  String get fwLastReset => 'آخر إعادة تشغيل';

  @override
  String get fwBoots => 'مرات الإقلاع';

  @override
  String get fwCrashes => 'الأعطال';

  @override
  String get fwNotesRecorded => 'الملاحظات المسجلة';

  @override
  String get fwSyncs => 'المزامنات';

  @override
  String get fwUptime => 'مدة التشغيل';

  @override
  String get fwFreeMemory => 'الذاكرة الحرة';

  @override
  String get rowTags => 'الوسوم';

  @override
  String get rowSyncBackground => 'مزامنة في الخلفية';

  @override
  String get forgetThisJota => 'نسيان جوطة';

  @override
  String get jotaNotInRange => 'جوطة خارج النطاق';

  @override
  String get forgetBody =>
      'قرّب جوطة وحاول مجددًا لتنسى هذا الهاتف أيضًا.\n\nإن أزلتها الآن فستظل تثق بهذا الهاتف حتى تمسحها على الجهاز — اضغط الزرين معًا.';

  @override
  String get removeAnyway => 'أزلها على أي حال';

  @override
  String get jotaForgotten => 'نُسيت جوطة';

  @override
  String get eraseDevice => 'مسح الجهاز';

  @override
  String get eraseThisJota => 'أتمسح جوطة؟';

  @override
  String get eraseBody => 'تُحذف كل ملاحظاتها وتنسى هذا الهاتف.';

  @override
  String get erase => 'مسح';

  @override
  String get waitingForJota => 'في انتظار جوطة — اضغط زرًا عليها';

  @override
  String get noJotaNearby => 'لا جوطة قريبًا';

  @override
  String get jotaErased => 'تم مسح جوطة';

  @override
  String get couldNotErase => 'تعذر المسح';

  @override
  String get holdBothButtons => 'ليس بعد — اضغط زرّي جوطة معًا خمس ثوانٍ';

  @override
  String get rowStorage => 'التخزين';

  @override
  String get shareAllNotes => 'مشاركة كل الملاحظات';

  @override
  String get exportCorrections => 'تصدير التصحيحات';

  @override
  String get noCorrectionsYet => 'لا تصحيحات بعد';

  @override
  String get playbackCache => 'ذاكرة التشغيل';

  @override
  String get unlockWithFingerprint => 'فتح بالبصمة';

  @override
  String get setPhoneLockFirst => 'فعّل قفل الهاتف أولًا';

  @override
  String get appearance => 'المظهر';

  @override
  String get appearanceSystem => 'النظام';

  @override
  String get appearanceLight => 'فاتح';

  @override
  String get appearanceDark => 'داكن';

  @override
  String get appLanguage => 'لغة التطبيق';

  @override
  String get appLanguageSystem => 'النظام';

  @override
  String get appLanguageEnglish => 'English';

  @override
  String get appLanguageArabic => 'العربية';

  @override
  String get rowThisPhone => 'هذا الهاتف';

  @override
  String get rowVersion => 'الإصدار';

  @override
  String get replayOnboarding => 'إعادة الجولة';

  @override
  String get connectYourJota => 'وصّل جوطة';

  @override
  String get switchOnYourJota => 'شغّل جوطة';

  @override
  String get connect => 'اتصال';

  @override
  String get enterCodeOnJota => 'أدخل الرمز الظاهر على جوطة';

  @override
  String get pair => 'اقتران';

  @override
  String get pairWithJota => 'الاقتران بجوطة';

  @override
  String get setUpLater => 'لاحقًا';

  @override
  String get notNow => 'ليس الآن';

  @override
  String get connectMyJota => 'وصّل جوطة';

  @override
  String get next => 'التالي';

  @override
  String get skip => 'تخطٍّ';

  @override
  String get obHead1 => 'حين يمتلئ\nرأسك.';

  @override
  String get obBody1 => 'الأفكار تتكدس وتتداخل. لهذا جوطة.';

  @override
  String get obHead2 => 'قلها،\nأطلقها.';

  @override
  String get obBody2 => 'اضغط مرة وتكلّم. جوطة تحفظها لك.';

  @override
  String get obHead3 => 'اشعر\nبالخفة.';

  @override
  String get obBody3 => 'خرجت، وحُفظت، وهي لك.';

  @override
  String get bluetoothOff => 'البلوتوث مطفأ';

  @override
  String get jotaNeedsBluetooth => 'جوطة تحتاج البلوتوث';

  @override
  String get turnOnBluetooth => 'شغّل البلوتوث';

  @override
  String get allowBluetooth => 'اسمح بالبلوتوث من الإعدادات';

  @override
  String get unlockJota => 'افتح جوطة';

  @override
  String get useFaceOrFingerprint => 'استخدم وجهك أو بصمتك';

  @override
  String get unlock => 'فتح';

  @override
  String patternsAcrossWeeks(int weeks) {
    String _temp0 = intl.Intl.pluralLogic(
      weeks,
      locale: localeName,
      other: 'خلال آخر $weeks أسابيع',
      two: 'خلال آخر أسبوعين',
      one: 'خلال أسبوعك الأخير',
    );
    return '$_temp0';
  }

  @override
  String topicNotes(int count) {
    return '$count ملاحظات';
  }

  @override
  String topicNotesThisWeek(int count, int week) {
    return '$count ملاحظات · $week هذا الأسبوع';
  }

  @override
  String weeksFigure(int weeks) {
    return '$weeks أسابيع';
  }

  @override
  String get stateNeedsPermission => 'يحتاج إذنًا';

  @override
  String get stateBluetoothOff => 'البلوتوث مطفأ';

  @override
  String get nothingToSync => 'لا شيء للمزامنة';

  @override
  String get syncFailed => 'فشلت المزامنة';

  @override
  String get alreadyUpToDate => 'محدَّث أصلًا';

  @override
  String get tagHint => 'عمل';

  @override
  String get done => 'تم';

  @override
  String get remove => 'إزالة';

  @override
  String get back => 'رجوع';

  @override
  String get wakeYourJota => 'أيقظ جوطة';

  @override
  String get pressButtonOnIt => 'اضغط زرًا عليه';

  @override
  String get sync => 'مزامنة';

  @override
  String get connectingLabel => 'يتصل';

  @override
  String noteReady(String id) {
    return '$id جاهزة';
  }

  @override
  String get channelTranscripts => 'التفريغات';

  @override
  String get channelTranscriptsBody => 'فُرِّغت ملاحظة.';
}
