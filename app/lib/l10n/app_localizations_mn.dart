// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Mongolian (`mn`).
class WordsMn extends Words {
  WordsMn([String locale = 'mn']) : super(locale);

  @override
  String get languageTitle => 'Хэл';

  @override
  String get languageSameAsMac => 'Энэ Mac-тай адил';

  @override
  String get languageSameAsWindows => 'Windows-той адил';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageMongolian => 'Монгол';

  @override
  String languageShowingNow(String language, String system) {
    return 'Одоо $language · $system солигдоход дагаж солигдоно';
  }

  @override
  String languageUndoLabel(String choice) {
    return 'Хэл: $choice';
  }

  @override
  String get theMac => 'Mac';

  @override
  String get windowsName => 'Windows';

  @override
  String dayMonth(String month, String day, int monthNumber, int dayNumber) {
    return '$monthNumber-р сарын $dayNumber';
  }

  @override
  String dayMonthYear(
    String year,
    String month,
    String day,
    int monthNumber,
    int dayNumber,
  ) {
    return '$year оны $monthNumber-р сарын $dayNumber';
  }

  @override
  String calendarMonth(String month, String year, int monthNumber) {
    return '$year оны $monthNumber-р сар';
  }

  @override
  String get monthNames =>
      '1-р сар|2-р сар|3-р сар|4-р сар|5-р сар|6-р сар|7-р сар|8-р сар|9-р сар|10-р сар|11-р сар|12-р сар';

  @override
  String get today => 'Өнөөдөр';

  @override
  String get yesterday => 'Өчигдөр';

  @override
  String get ledgerStartEmpty => 'Хоосноос эхлэх';

  @override
  String ledgerAdded(String name) {
    return '$name нэмэгдлээ';
  }

  @override
  String ledgerAddedTo(String name, String account) {
    return '$account дансанд $name нэмэгдлээ';
  }

  @override
  String ledgerNewCategory(String name) {
    return 'шинэ ангилал “$name”';
  }

  @override
  String ledgerScheduledFor(String date) {
    return 'товлосон огноо: $date';
  }

  @override
  String get ledgerNotInThisView => 'энэ жагсаалтад харагдахгүй';

  @override
  String ledgerScheduledToast(String date) {
    return 'Товлосон огноо: $date · бүртгэх хүртэл үлдэгдэлд орохгүй';
  }

  @override
  String ledgerCouldntSave(String error) {
    return 'Хадгалж чадсангүй: $error';
  }

  @override
  String ledgerUndoNewerFirst(String shortcut) {
    return 'Эхлээд сүүлийн өөрчлөлтүүдийг буцаана уу · $shortcut';
  }

  @override
  String get ledgerNothingToUndo => 'Буцаах зүйл алга';

  @override
  String get ledgerNothingToRedo => 'Дахин хийх зүйл алга';

  @override
  String ledgerCouldntUndo(String action) {
    return 'Буцааж чадсангүй: “$action” · дараа нь өөрчлөгдсөн';
  }

  @override
  String ledgerCouldntRedo(String action) {
    return 'Дахин хийж чадсангүй: “$action” · дараа нь өөрчлөгдсөн';
  }

  @override
  String ledgerUndone(String action) {
    return 'Буцаалаа · $action';
  }

  @override
  String ledgerRedone(String action) {
    return 'Дахин хийлээ · $action';
  }

  @override
  String get ledgerUndo => 'Буцаах';

  @override
  String get ledgerSaveOrDiscard =>
      'Хадгалах бол Enter, өөрчлөлтөө хаях бол Esc дарна уу';

  @override
  String get ledgerFinishReconcileFirst =>
      'Эхлээд тулгалтаа дуусгах эсвэл болиулна уу';

  @override
  String ledgerConfirmed(String name) {
    return '$name бүртгэгдлээ';
  }

  @override
  String ledgerConfirmedAmount(String when, String name, String amount) {
    String _temp0 = intl.Intl.selectLogic(when, {
      'early': '$name эрт бүртгэгдлээ · $amount',
      'other': '$name бүртгэгдлээ · $amount',
    });
    return '$_temp0';
  }

  @override
  String ledgerConfirmedAmountPlanned(
    String when,
    String name,
    String amount,
    String planned,
  ) {
    String _temp0 = intl.Intl.selectLogic(when, {
      'early': '$name эрт бүртгэгдлээ · $amount, төлөвлөсөн $planned',
      'other': '$name бүртгэгдлээ · $amount, төлөвлөсөн $planned',
    });
    return '$_temp0';
  }

  @override
  String ledgerStillOwed(String amount, String date) {
    return 'үлдсэн $amount орох ёстой · $date';
  }

  @override
  String ledgerPostedToday(String date) {
    return 'өнөөдрийн огноогоор бүртгэсэн, $date';
  }

  @override
  String ledgerPostedOn(String date) {
    return 'бүртгэсэн огноо: $date';
  }

  @override
  String ledgerUnderEstimate(String amount) {
    return 'тооцоолсноос $amount бага · Төсөв хэсэгт бууруулж болно';
  }

  @override
  String ledgerEdited(String name) {
    return '$name засагдлаа';
  }

  @override
  String ledgerMovedToFuture(String date) {
    return 'Огноо $date болсон · одоо товлосон, бүртгэх хүртэл үлдэгдэлд орохгүй';
  }

  @override
  String get ledgerChangesSaved => 'Өөрчлөлт хадгалагдлаа';

  @override
  String ledgerTypeADate(String example) {
    return 'Огноог $example хэлбэрээр бичнэ үү';
  }

  @override
  String get ledgerStatementAfterToday =>
      'Хуулгын огноо өнөөдрөөс хойш байж болохгүй';

  @override
  String ledgerAlreadyReconciled(String date) {
    return '$date хүртэл аль хэдийн тулгасан';
  }

  @override
  String get ledgerClearedRowsChanged =>
      'Баталгаажсан мөрүүд өөрчлөгдсөн · зөрүүг дахин шалгана уу';

  @override
  String ledgerReconciledThrough(String account, String date) {
    return '$account: $date хүртэл тулгалаа';
  }

  @override
  String ledgerLocked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count мөр түгжигдлээ',
    );
    return '$_temp0';
  }

  @override
  String ledgerAdjustmentAdded(String amount) {
    return '$amount залруулга нэмэгдлээ';
  }

  @override
  String ledgerReconcileUndone(String date) {
    return '$date өдрийн тулгалтыг буцаалаа';
  }

  @override
  String ledgerBackToCleared(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count мөр баталгаажсан төлөвт буцлаа',
    );
    return '$_temp0';
  }

  @override
  String ledgerMarkedCleared(String name) {
    return '$name баталгаажсан гэж тэмдэглэлээ';
  }

  @override
  String ledgerMarkedUncleared(String name) {
    return '$name хүлээгдэж буй гэж тэмдэглэлээ';
  }

  @override
  String ledgerCantDeleteTransfer(String account) {
    return 'Устгах боломжгүй · энэ шилжүүлгийг $account дансанд тулгасан';
  }

  @override
  String get ledgerCantDeleteReconciled =>
      'Устгах боломжгүй · банкны хуулгатай тулгасан';

  @override
  String ledgerDeleted(String name) {
    return '$name устгагдлаа';
  }

  @override
  String ledgerScheduledDeleted(String name) {
    return 'Товлосон $name устгагдлаа';
  }

  @override
  String ledgerScheduledDeletedAlreadyIn(String name, String date) {
    return 'Товлосон $name устгагдлаа · $date-нд аль хэдийн бий';
  }

  @override
  String ledgerCantMove(String reason) {
    return 'Зөөх боломжгүй · $reason';
  }

  @override
  String get ledgerCouldntMove => 'Зөөж чадсангүй';

  @override
  String ledgerMovedTo(String name, String account) {
    return '$name $account данс руу зөөгдлөө';
  }

  @override
  String ledgerScheduledDeletedShort(String name, String short) {
    return 'Товлосон $name устгагдлаа · үүний $short нь товлогдоогүй болсон';
  }

  @override
  String get ledgerShowMoved => 'Харах';

  @override
  String ledgerTransferToMovedTo(String payee, String account) {
    return '$payee данс руу хийсэн шилжүүлэг $account данс руу зөөгдлөө';
  }

  @override
  String ledgerTransferFromMovedTo(String payee, String account) {
    return '$payee данснаас ирсэн шилжүүлэг $account данс руу зөөгдлөө';
  }

  @override
  String get ledgerUnclearedThere => 'тэнд баталгаажих хүртэл хүлээгдэж буй';

  @override
  String get ledgerAddBankAccountFirst => 'Эхлээд банкны данс нэмнэ үү';

  @override
  String get ledgerPayStopped => 'Цалин зогслоо';

  @override
  String get ledgerPayStoppedToast =>
      'Цалин товлогдохоо больсон · өнгөрсөн цалингийн өдрүүд хэвээр үлдэнэ';

  @override
  String ledgerPayStoppedMoved(int count, String how) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Цалин товлогдохоо больсон · $count ангилал одоо $how',
      one: 'Цалин товлогдохоо больсон · 1 ангилал одоо $how',
    );
    return '$_temp0';
  }

  @override
  String get ledgerPaySaved => 'Цалин хадгалагдлаа';

  @override
  String ledgerPaySavedNext(String date) {
    return 'Цалин хадгалагдлаа · дараагийн цалингийн өдөр $date';
  }

  @override
  String get ledgerNoRegularPay => 'Тогтмол цалингүй';

  @override
  String get ledgerAskingForPayAgain => 'Цалинг дахин асууна';

  @override
  String get ledgerNoRegularPayToast =>
      'Тогтмол цалингүй · апп цалин асуухгүй · Төсөв хуудасны Орлого хэсгээс өөрчилнө';

  @override
  String get ledgerAskForPayAgainToast => 'Төсөөлөл таны цалинг дахин асууна';

  @override
  String get ledgerBudgetByMonth => 'Төсвийг сараар харуулав';

  @override
  String ledgerBudgetByPayPeriod(String name) {
    return 'Төсвийг цалингийн үеэр харуулав · $name';
  }

  @override
  String get ledgerAppearanceTitle => 'Харагдах байдал';

  @override
  String get ledgerAppearanceLight => 'Цайвар';

  @override
  String get ledgerAppearanceDark => 'Бараан';

  @override
  String ledgerAppearanceUndoLabel(String choice) {
    return 'Харагдах байдал: $choice';
  }

  @override
  String ledgerShowingLightNow(String system) {
    return 'Одоо цайвар · $system солигдоход дагаж солигдоно';
  }

  @override
  String ledgerShowingDarkNow(String system) {
    return 'Одоо бараан · $system солигдоход дагаж солигдоно';
  }

  @override
  String get ledgerAllAccounts => 'Бүх данс';

  @override
  String ledgerCategoryChip(String name) {
    return 'Ангилал: $name';
  }

  @override
  String get ledgerAdd => 'Нэмэх';

  @override
  String ledgerFilterRows(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count мөр',
    );
    return '$_temp0';
  }

  @override
  String ledgerFilterTotal(String kind, String amount) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'received': '$amount орсон',
      'paidBack': '$amount буцааж төлсөн',
      'refunded': '$amount буцаан авсан',
      'other': '$amount зарцуулсан',
    });
    return '$_temp0';
  }

  @override
  String ledgerFilterTotalSince(String kind, String amount, String date) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'received': '$date өдрөөс хойш $amount орсон',
      'paidBack': '$date өдрөөс хойш $amount буцааж төлсөн',
      'refunded': '$date өдрөөс хойш $amount буцаан авсан',
      'other': '$date өдрөөс хойш $amount зарцуулсан',
    });
    return '$_temp0';
  }

  @override
  String ledgerFilterScheduled(int count) {
    return '$count товлосон';
  }

  @override
  String get ledgerCouldntAddAccount => 'Данс нэмж чадсангүй';

  @override
  String get ledgerCouldntKeepRate =>
      'Хүүг хадгалж чадсангүй. Данс нэмэгдсэн; хүүг Хуримтлалын 2-р алхамд оруулна уу.';

  @override
  String get ledgerCouldntSaveBalance => 'Үлдэгдлийг хадгалж чадсангүй';

  @override
  String get ledgerCouldntChangeAccount => 'Дансыг өөрчилж чадсангүй';

  @override
  String get ledgerCouldntChangePay => 'Цалинг өөрчилж чадсангүй';

  @override
  String get ledgerCouldntChangeBudgetPeriod =>
      'Төсвийн үеийг өөрчилж чадсангүй';

  @override
  String get ledgerCouldntChangeCategory => 'Ангиллыг өөрчилж чадсангүй';

  @override
  String ledgerRenamed(String old, String name) {
    return 'Нэр солилоо: $old → $name';
  }

  @override
  String ledgerIsNowCardOrLoan(String name) {
    return '$name одоо карт эсвэл зээл';
  }

  @override
  String ledgerIsNowBankAccount(String name) {
    return '$name одоо банкны данс';
  }

  @override
  String get ledgerOpeningBalanceFlipped =>
      'эхний үлдэгдэл нь мөн эсрэгээр солигдлоо';

  @override
  String ledgerArchiveTitle(String name) {
    return '$name дансыг архивлах уу?';
  }

  @override
  String ledgerArchiveAction(String name) {
    return '$name дансыг архивлах';
  }

  @override
  String ledgerArchived(String name) {
    return '$name архивлагдлаа';
  }

  @override
  String ledgerBackInSidebar(String name) {
    return '$name хажуугийн цэсэнд буцаж орлоо';
  }

  @override
  String ledgerAccountArchivedToast(String name) {
    return '$name архивлагдлаа · Тохиргооноос буцааж болно';
  }

  @override
  String ledgerDeleteTitle(String name) {
    return '$name дансыг устгах уу?';
  }

  @override
  String ledgerDeleteAction(String name) {
    return '$name дансыг устгах';
  }

  @override
  String ledgerAlreadyCategory(String name) {
    return '$name нэртэй ангилал аль хэдийн байна';
  }

  @override
  String ledgerBackInMenus(String name) {
    return '$name цэсэнд буцаж орлоо';
  }

  @override
  String ledgerCategoryArchivedToast(String name) {
    return '$name архивлагдлаа · мөрүүд нь хэвээр; шинэ мөрөнд сонгох боломжгүй';
  }

  @override
  String ledgerMergedInto(String name, String target) {
    return '$name ангиллыг $target ангилал руу нэгтгэлээ';
  }

  @override
  String ledgerRowsMoved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count мөр зөөгдлөө',
    );
    return '$_temp0';
  }

  @override
  String ledgerDeletedRowsMovedTo(String name, int count, String target) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count мөр',
    );
    return '$name устгагдлаа · $_temp0 $target ангилал руу зөөгдлөө';
  }

  @override
  String get ledgerBackUpButton => 'Нөөцлөх';

  @override
  String get ledgerCouldntOpenSaveDialog => 'Хадгалах цонхыг нээж чадсангүй';

  @override
  String get ledgerCouldntBackUp =>
      'Нөөцөлж чадсангүй · дискэнд зай байгаа эсэхийг шалгаад дахин оролдоно уу';

  @override
  String ledgerBackedUp(String file) {
    return 'Нөөцөллөө · $file';
  }

  @override
  String get ledgerBackupFileType => 'BetterBudget нөөц хуулбар';

  @override
  String get ledgerChoose => 'Сонгох';

  @override
  String get ledgerCouldntOpenFileDialog => 'Файл сонгох цонхыг нээж чадсангүй';

  @override
  String get ledgerCouldntReadBackup => 'Тэр нөөц хуулбарыг уншиж чадсангүй';

  @override
  String get ledgerCouldntRestore => 'Сэргээж чадсангүй · юу ч өөрчлөгдөөгүй';

  @override
  String ledgerRestoredFrom(String date) {
    return '$date өдрийн хуулбарыг сэргээлээ';
  }

  @override
  String get ledgerWhatYouHadIsSaved => 'өмнөх өгөгдөл тань хадгалагдсан';

  @override
  String ledgerArchivedName(String name) {
    return '$name (архивласан)';
  }

  @override
  String get ledgerCouldntStartNewLedger =>
      'Шинэ дэвтэр эхлүүлж чадсангүй · юу ч өөрчлөгдөөгүй';

  @override
  String get ledgerNewLedgerStarted => 'Шинэ дэвтэр эхэллээ';

  @override
  String get ledgerEverythingErased =>
      'Бүгдийг устгалаа · өмнөх өгөгдөл тань нөөц хуулбарт хадгалагдсан';

  @override
  String ledgerCouldntOpenLedger(String error) {
    return 'Дэвтрийг нээж чадсангүй: $error';
  }

  @override
  String get ledgerGroupAccounts => 'Данс';

  @override
  String get ledgerGroupCashBank => 'Бэлэн мөнгө ба банк';

  @override
  String get ledgerGroupBank => 'Банк';

  @override
  String get ledgerGroupCash => 'Бэлэн мөнгө';

  @override
  String get ledgerGroupCredit => 'Карт, зээл';

  @override
  String get ledgerSectionLedger => 'Дэвтэр';

  @override
  String get ledgerSectionBudget => 'Төсөв';

  @override
  String get ledgerSectionSavings => 'Хуримтлал';

  @override
  String get ledgerNetWorth => 'Цэвэр хөрөнгө';

  @override
  String ledgerInclArchived(String amount) {
    return 'үүнээс $amount архивласан дансанд';
  }

  @override
  String ledgerLastCopiedElsewhere(int days) {
    return 'Сүүлд $days хоногийн өмнө нөөцөлсөн';
  }

  @override
  String get ledgerNeverCopiedElsewhere => 'Хараахан нөөцлөөгүй';

  @override
  String get ledgerCopiedElsewhere => 'Нөөцөлсөн';

  @override
  String get ledgerCopiedElsewhereNever =>
      'Хараахан үгүй · “Нөөцлөх…” өөр диск рүү хуулбар хадгална';

  @override
  String get ledgerDailyCopyFailing => 'Өдөр бүрийн хуулбар хийгдэхгүй байна';

  @override
  String get ledgerSettings => 'Тохиргоо';

  @override
  String get ledgerBackupsTitle => 'Нөөц хуулбар';

  @override
  String get ledgerDailyCopy => 'Өдрийн хуулбар';

  @override
  String ledgerTimeAt(String day, String time) {
    return '$day $time';
  }

  @override
  String ledgerDailyCopyFailingSince(String when) {
    return 'Хийгдэхгүй байна · сүүлийн хуулбар: $when. Дискэнд зай байгаа эсэхийг шалгаад өөр диск рүү нөөцлөнө үү.';
  }

  @override
  String get ledgerDailyCopyFailingNone =>
      'Хийгдэхгүй байна. Дискэнд зай байгаа эсэхийг шалгаад өөр диск рүү нөөцлөнө үү.';

  @override
  String get ledgerDailyCopyNone =>
      'Одоогоор алга · апп нээлттэй өдөр бүр нэгийг хийнэ';

  @override
  String ledgerDailyCopyWhen(String when) {
    return '$when · энэ компьютер дээр';
  }

  @override
  String get ledgerKept => 'Хадгалагдана';

  @override
  String get ledgerKeptWhich =>
      'Сүүлийн 14, мөн нэг жилийн турш сар бүрийн эхнийх';

  @override
  String get ledgerBackUpTo => 'Нөөцлөх…';

  @override
  String get ledgerRestoreFrom => 'Нөөцөөс сэргээх…';

  @override
  String get ledgerBackupsNote =>
      'Өдөр бүрийн хуулбарууд энэ компьютер дээр байдаг тул компьютер алга болох, эвдэрвэл тус болохгүй: үе үе өөр диск эсвэл USB флаш руу нөөцлөөрэй. Сэргээхээс өмнө одоо байгаа өгөгдлийг тань хадгалах ба Буцаах нь түүнийг эргүүлж авчирна.';

  @override
  String get ledgerSecurityTitle => 'Аюулгүй байдал';

  @override
  String get ledgerSecurityKeySaved =>
      'Таны дэвтэр болон нөөц хуулбаруудыг шифрлэсэн. Сэргээх түлхүүр тань тэдгээрийг өөр компьютер дээр нээнэ, гэхдээ энэ компьютерээ алдвал зөвхөн гадагш хадгалсан хуулбарууд (Нөөцлөх…) л үлдэнэ. BetterBudget түлхүүрийн хуулбарыг хадгалдаггүй.';

  @override
  String get ledgerSecurityKeyNotSaved =>
      'Таны дэвтэр болон нөөц хуулбаруудыг шифрлэсэн. Сэргээх түлхүүрийг харуулах үед хадгалаагүй, хуулаагүй бөгөөд BetterBudget түүний хуулбарыг хадгалдаггүй: энэ компьютер алга болбол тэдгээрийг нээх боломжгүй.';

  @override
  String get ledgerCheckRecoveryKey => 'Сэргээх түлхүүрээ шалгах…';

  @override
  String get ledgerStartOverTitle => 'Шинээр эхлэх';

  @override
  String get ledgerStartOverNote =>
      'Энэ нь дэвтрийн бүх данс, гүйлгээг устгаж, та хоосноос эхэлнэ. Ангиллууд үлдэх эсэхийг та сонгоно. Одоо байгаа өгөгдөл тань эхлээд нөөц хуулбарт хадгалагдах ба Буцаах нь түүнийг эргүүлж авчирна.';

  @override
  String settingsVersion(String version, String build) {
    return 'Хувилбар $version ($build)';
  }

  @override
  String get settingsCredit =>
      'Төсөв хуудсыг зохион байгуулахад Cynthia G. Loveland тусалсан.';

  @override
  String get ledgerEraseAndStartOverButton => 'Бүгдийг устгаж шинээр эхлэх…';

  @override
  String get ledgerRestoreTitle => 'Энэ нөөц хуулбарыг сэргээх үү?';

  @override
  String get ledgerBackupFrom => 'Хуулбарын огноо';

  @override
  String get ledgerItHolds => 'Агуулга';

  @override
  String get ledgerHereNow => 'Одоо энд';

  @override
  String ledgerCounts(int transactions, int accounts) {
    String _temp0 = intl.Intl.pluralLogic(
      transactions,
      locale: localeName,
      other: '$transactions гүйлгээ',
    );
    String _temp1 = intl.Intl.pluralLogic(
      accounts,
      locale: localeName,
      other: '$accounts данс',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String get ledgerRestoreNote =>
      'Энд байгаа бүх зүйлийг нөөц хуулбараар солино. Одоо байгаа өгөгдөл тань эхлээд хадгалагдах ба Буцаах нь түүнийг эргүүлж авчирна.';

  @override
  String get ledgerCancel => 'Болих';

  @override
  String get ledgerRestore => 'Сэргээх';

  @override
  String ledgerOwed(String amount) {
    return '$amount өр';
  }

  @override
  String get ledgerYourPay => 'Таны цалин';

  @override
  String ledgerReconciles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count тулгалт',
    );
    return '$_temp0';
  }

  @override
  String get ledgerPayees => 'Харилцагчид';

  @override
  String get ledgerBudgetSavingsSettings => 'Төсөв ба Хуримтлалын тохиргоо';

  @override
  String ledgerMoreAccounts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'өөр $count данс',
    );
    return '+ $_temp0';
  }

  @override
  String ledgerTransactionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count гүйлгээ',
    );
    return '$_temp0';
  }

  @override
  String get ledgerEraseTitle => 'Бүгдийг устгаж шинээр эхлэх үү?';

  @override
  String get ledgerAllOfThisErased => 'Эдгээр бүгд устна:';

  @override
  String get ledgerStartWithNothing =>
      'Та апп-д ямар ч данс, мөнгөгүйгээр эхэлнэ.';

  @override
  String ledgerYourCategories(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ангилал',
    );
    return 'Таны $_temp0';
  }

  @override
  String get ledgerKeepThemEmpty => 'Хоосон үлдээх';

  @override
  String get ledgerEraseThemToo => 'Тэдгээрийг мөн устгах';

  @override
  String get ledgerKeptNoRows =>
      'Мөргүйгээр үлдэж, жинхэнэ данснуудад тань бэлэн байна.';

  @override
  String get ledgerAddCategoriesAgain =>
      'Ангиллуудаа Төсөв хэсэгт дахин нэмнэ.';

  @override
  String get ledgerEraseNote =>
      'Одоо байгаа өгөгдөл тань эхлээд нөөц хуулбарт хадгалагдана. Буцаах эсвэл дараа нь «Нөөцөөс сэргээх…» түүнийг эргүүлж авчирна.';

  @override
  String get ledgerEraseEverything => 'Бүгдийг устгах';

  @override
  String get ledgerSearchHint => 'Харилцагч, тэмдэглэл, дүн';

  @override
  String ledgerPeriodChip(String period, String start, String end) {
    return '$period · $start–$end';
  }

  @override
  String get ledgerDbReconciled =>
      'Тулгасан · огноо, дүн нь банкны хуулгатай таарсан';

  @override
  String get ledgerDbOwnAccount =>
      'Данснаас яг тэр данс руу нь шилжүүлэх боломжгүй';

  @override
  String get ledgerDbFutureConfirm => 'Ирээдүйн огноогоор бүртгэх боломжгүй';

  @override
  String get ledgerDbOpeningStays =>
      'Эхний үлдэгдэл, залруулгыг зөөх боломжгүй';

  @override
  String get ledgerDbAlreadyThere => 'Энэ гүйлгээ тэр дансанд аль хэдийн бий';

  @override
  String get ledgerDbNotInAccount => 'Энэ дансанд байхгүй';

  @override
  String get ledgerDbNotAnAccount => 'Данс биш';

  @override
  String get ledgerDbSplitNotEditable =>
      'Хуваасан гүйлгээний ангиллуудыг өөрийнх нь хэсэгт засна';

  @override
  String get ledgerDbChangedSince => 'Дараа нь өөрчлөгдсөн';

  @override
  String get ledgerDbStillHasRows =>
      'Энэ ангилалд гүйлгээ байна · хаашаа шилжүүлэхийг сонгоно уу';

  @override
  String get ledgerDbNotSingleCategory => 'Нэг ангилалтай гүйлгээ биш';

  @override
  String get ledgerDbPayIsIn => 'Цалин бол орж ирэх мөнгө';

  @override
  String get ledgerDbNotCategory => 'Ангилал биш';

  @override
  String get ledgerDbSameCategory => 'Ижил ангилал';

  @override
  String get ledgerDbAccountDeleted => 'Тэр дансыг устгасан';

  @override
  String get ledgerDbNeverReconciled => 'Тулгаж байгаагүй';

  @override
  String planNotClearedYet(int count) {
    return '$count гүйлгээ баталгаажаагүй';
  }

  @override
  String get planWorking => 'Үлдэгдэл';

  @override
  String get planOwed => 'Өр';

  @override
  String get planNeverReconciled => 'Тулгаж байгаагүй';

  @override
  String planLastReconciled(String date) {
    return 'Сүүлд тулгасан: $date';
  }

  @override
  String get planReconcile => 'Тулгах';

  @override
  String planLateSeveral(String amount, int count) {
    return '+$amount орлого, $count нь ирээгүй';
  }

  @override
  String planLateToday(String amount) {
    return '+$amount орлого, өнөөдөр орох ёстой';
  }

  @override
  String planLateDays(String amount, int days) {
    return '+$amount орлого, $days хоног хоцорсон';
  }

  @override
  String get planLateNotCounted => ' · тооцоогүй';

  @override
  String get planNothingScheduled => 'Товлосон зүйл алга';

  @override
  String planCreditAfter(String amount, String date) {
    return '$date гэхэд $amount илүү төлөлттэй';
  }

  @override
  String planOwedAfterDate(String amount, String date) {
    return '$date гэхэд $amount өртэй';
  }

  @override
  String planCardCharges(int charges, String chargeTotal, String date) {
    return '$date хүртэл $charges зарлага · $chargeTotal';
  }

  @override
  String planCardPayments(int payments, String paymentTotal, String date) {
    return '$date хүртэл $payments төлөлт · $paymentTotal';
  }

  @override
  String planCardChargesPayments(
    int charges,
    String chargeTotal,
    int payments,
    String paymentTotal,
    String date,
  ) {
    return '$date хүртэл $charges зарлага · $chargeTotal · $payments төлөлт · $paymentTotal';
  }

  @override
  String get planCardNothing => 'Дараагийн 30 хоногт зарлага, төлөлт алга';

  @override
  String get planBelowZeroNow => 'Одоо хасахад орсон';

  @override
  String planBelowZeroShort(String amount) {
    return 'Одоо хасахад орсон · $amount хүртэл дутна';
  }

  @override
  String planBelowZeroUnless(String amount) {
    return 'Өнөөдөр орох $amount ирэхгүй бол одоо хасахад орно';
  }

  @override
  String planRunsOutUnless(String date, String amount) {
    return 'Өнөөдөр орох $amount ирэхгүй бол $date гэхэд мөнгө дуусна';
  }

  @override
  String planRunsOut(String date, String amount) {
    return 'Мөнгө дуусах өдөр: $date · $amount хүртэл дутна';
  }

  @override
  String planRunsOutBy(String date, String amount) {
    return 'Мөнгө дуусах өдөр: $date · $amount дутна';
  }

  @override
  String get planExpected => 'хүлээгдэж буй';

  @override
  String planOfThemExpected(int count) {
    return '$count нь хүлээгдэж буй';
  }

  @override
  String planPaidFromSeveral(int count) {
    return '$count данс сонгоотой тул энэ төлбөр ямар ч таамаглалд харагдахгүй. Нэг данс үлдээвэл тэнд харагдана.';
  }

  @override
  String get planPaidFromNoneChecked =>
      'Ямар ч данс сонгоогүй тул энэ төлбөр ямар ч таамаглалд харагдахгүй.';

  @override
  String planRunsOutZero(String date) {
    return 'Мөнгө дуусах өдөр: $date';
  }

  @override
  String planShortAhead(String end, String date, String amount) {
    return '$end-с хойш: $date-нд мөнгө дуусна · $amount дутна';
  }

  @override
  String planShortAheadZero(String end, String date) {
    return '$end-с хойш: $date-нд мөнгө дуусна';
  }

  @override
  String planShortAheadTip(String date) {
    return '$date хүртэл харах';
  }

  @override
  String planLowest(String amount, String date) {
    return 'Доод үлдэгдэл $amount · $date';
  }

  @override
  String get planForecast => 'Урьдчилсан тооцоо';

  @override
  String get planTodaysBalance => 'Өнөөдрийн үлдэгдэл';

  @override
  String get planExpectedIncome => 'Хүлээгдэж буй орлого';

  @override
  String get planNothingBudgeted =>
      'Төсөв хараахан гаргаагүй байна. Төсвөө бөглөсний дараа энд урьдчилсан тооцоо харагдана.';

  @override
  String planUntilPaycheck(String date) {
    return '$date-ны цалин хүртэл';
  }

  @override
  String planLowestToday(String amount) {
    return 'Доод үлдэгдэл $amount · өнөөдөр';
  }

  @override
  String planChartPay(String amount) {
    return '+$amount цалин';
  }

  @override
  String planLowestAfterPay(String amount, String date) {
    return 'Доод үлдэгдэл $amount · $date, цалингийн дараа';
  }

  @override
  String get planNoBillsOrIncome => 'Дараагийн 30 хоногт төлбөр, орлого алга';

  @override
  String planNoBillsBefore(String date) {
    return '$date хүртэл төлбөр алга';
  }

  @override
  String planInBefore(String amount, String date) {
    return '$date хүртэл +$amount орно';
  }

  @override
  String planBillsBefore(int count, String amount, String date) {
    return '$date хүртэл $count төлбөр · $amount';
  }

  @override
  String planBillsBeforeIn(
    int count,
    String amount,
    String date,
    String inAmount,
  ) {
    return '$date хүртэл $count төлбөр · $amount · +$inAmount орно';
  }

  @override
  String get planNext30Days => 'Дараагийн 30 хоног';

  @override
  String planNextDays(int count) {
    return 'Дараагийн $count хоног';
  }

  @override
  String get planNext6Months => 'Дараагийн 6 сар';

  @override
  String get planNextYear => 'Дараагийн 12 сар';

  @override
  String get planSpanTip => 'Таамаглал хэр хол харахыг сонгоно';

  @override
  String get planAddPay => ' · цалингийн өдөр алга · Цалингаа нэмэх →';

  @override
  String planUntilDate(String date) {
    return '$date хүртэл';
  }

  @override
  String get planBalanceAfter => 'Үлдэх дүн';

  @override
  String get planOwedAfter => 'Үлдэх өр';

  @override
  String planTransferTo(String account) {
    return '$account данс руу';
  }

  @override
  String planTransferFrom(String account) {
    return '$account данснаас';
  }

  @override
  String planAtLeastEstimate(String category) {
    return '$category · багадаа, ойролцоогоор';
  }

  @override
  String get planBudget => 'Төсөв';

  @override
  String get planAddCategory => 'Ангилал нэмэх';

  @override
  String get planAddCategoryTip => 'Шинэ ангилал нэмэх';

  @override
  String get setupAddPayTip =>
      'Цалингаа тохируулах: хэд, хэр давтамжтай, аль данс руу орохыг';

  @override
  String planIncomeExpected(String received, String expected) {
    return 'Энэ үед хүлээгдэж буй $expected-с $received орсон';
  }

  @override
  String get planIncomeTab => 'Орлого';

  @override
  String planPayInto(String amounts, String account) {
    return '$amounts · данс: $account';
  }

  @override
  String planPayIntoNext(String amounts, String account, String date) {
    return '$amounts · данс: $account · дараагийн $date';
  }

  @override
  String get planSpending => 'Зарлага';

  @override
  String planShowArchived(int count) {
    return 'Архивласныг харуулах ($count)';
  }

  @override
  String planHideArchived(int count) {
    return 'Архивласныг нуух ($count)';
  }

  @override
  String get planShowInMenus => 'Цэсэнд харуулах';

  @override
  String get planPaydayNoRegular => 'Тогтмол цалингүй';

  @override
  String get planPaydayNotSetUp => 'Цалин тохируулаагүй';

  @override
  String planMorePay(int count) {
    return ' · өөр $count цалин';
  }

  @override
  String get planRaiseSplit =>
      'Сүүлийн 6 цалин бүгд тооцоолсон дүнгээс 5%-иас их орсон · нэмэх үү?';

  @override
  String planRaiseLowest(String amount) {
    return 'Сүүлийн 6 цалингийн хамгийн бага нь $amount · тооцоолсон дүнг нэмэх үү?';
  }

  @override
  String planLastTwoLess(String amount) {
    return 'Сүүлийн 2 цалин $amount орсон, төлөвлөснөөс бага · шинэчлэх үү?';
  }

  @override
  String planLastTwoMore(String amount) {
    return 'Сүүлийн 2 цалин $amount орсон · дүнг шинэчлэх үү?';
  }

  @override
  String planPaydayPay(String pay) {
    return 'Цалин: $pay';
  }

  @override
  String planPaydayPayNext(String pay, String date) {
    return 'Цалин: $pay · дараагийнх $date';
  }

  @override
  String get planNoRows => 'гүйлгээ алга';

  @override
  String planUsageRows(int count) {
    return '$count гүйлгээ';
  }

  @override
  String planUsageRowsLast(int count, String date) {
    return '$count гүйлгээ · сүүлд $date';
  }

  @override
  String planUsageScheduled(int count) {
    return '$count товлосон';
  }

  @override
  String get planShowTheseRows => 'Эдгээр гүйлгээг харуулах';

  @override
  String get planArchive => 'Архивлах';

  @override
  String get planDeleteMenu => 'Устгах…';

  @override
  String get planCategoryName => 'Ангиллын нэр';

  @override
  String get planCancel => 'Болих';

  @override
  String get planAdd => 'Нэмэх';

  @override
  String get planNothingFiled => 'Энэ ангилалд одоогоор гүйлгээ алга.';

  @override
  String get planOnlyDeletedFiled =>
      'Энэ ангилалд зөвхөн устгасан гүйлгээ бий. Тэдгээр нь дараах ангилал руу шилжинэ:';

  @override
  String planRowsFiled(int count) {
    return 'Энэ ангилалд $count гүйлгээ бий. Тэдгээр нь дараах ангилал руу шилжинэ:';
  }

  @override
  String planRowsFiledScheduled(int count, int scheduled) {
    return 'Энэ ангилалд $count гүйлгээ бий, үүнээс $scheduled нь товлосон. Тэдгээр нь дараах ангилал руу шилжинэ:';
  }

  @override
  String planIntoIncome(String name) {
    return '$name бол орлого: эдгээр гүйлгээний орсон мөнгө орлогод тооцогдож, гарсан мөнгө түүнээс хасагдана.';
  }

  @override
  String planIntoIncomeScheduled(String name) {
    return '$name бол орлого: эдгээр гүйлгээний орсон мөнгө орлогод тооцогдож, гарсан мөнгө түүнээс хасагдана; товлосон орлого төсөөллийг дуусгаж болно.';
  }

  @override
  String planMergeTitle(String name, String into) {
    return '$name ангиллыг $into ангилалд нэгтгэх үү?';
  }

  @override
  String planDeleteTitle(String name) {
    return '$name ангиллыг устгах уу?';
  }

  @override
  String get planNoOtherCategory =>
      'Шилжүүлэх өөр ангилал алга. Эхлээд ангилал нэмэх хэрэгтэй.';

  @override
  String get planPickCategory => 'Ангилал сонгох';

  @override
  String planDeleteButton(String name) {
    return '$name ангиллыг устгах';
  }

  @override
  String planMergeButton(String into) {
    return '$into ангилалд нэгтгэх';
  }

  @override
  String planMoveAndDelete(String into) {
    return '$into ангилал руу шилжүүлээд устгах';
  }

  @override
  String get planSavings => 'Хуримтлал';

  @override
  String get planAllStepsDone => 'Бүх алхам биелсэн';

  @override
  String get planOneStepAtATime => 'Алхам алхмаар бэлтгэлээ хангах';

  @override
  String get planStepOneMonth => 'Аюулгүйн нөөц бүрдүүлэх';

  @override
  String get planStepConsumerDebt => 'Өрөө төлж дуусгах';

  @override
  String get planStepMoreMonths => 'Гурваас зургаан сарын хуримтлал бүрдүүлэх';

  @override
  String get planStepFuture => 'Ирээдүйдээ зориулж хуримтлуулах';

  @override
  String get planStepRetirement => 'Тэтгэврийн хуримтлал';

  @override
  String get planStepLongLoans => 'Орон сууцны зээлээ төлж дуусгах';

  @override
  String get planNow => 'Одоо';

  @override
  String get planSetAside => 'Хойшлуулсан';

  @override
  String get planSetAsideState => 'хуримтлагдсан';

  @override
  String planSetAsideUndo(String step) {
    return '«$step» хойшлуулсан';
  }

  @override
  String planBackInStepsUndo(String step) {
    return '«$step» алхмуудад буцаж орсон';
  }

  @override
  String get planMonthUnknown =>
      'Таны нэг сарын зардал одоохондоо тодорхойгүй. Төсвөө бөглөсний дараа тэндээс авна, эсвэл дүнгээ өөрөө оруулж болно.';

  @override
  String planMonthNoSpending(int days) {
    return 'Сүүлийн $days хоногт тооцох зарлага алга. Нэг сарын зардлаа оруулаарай.';
  }

  @override
  String planMonthBudget(String amount) {
    return 'Нэг сарын зардал: $amount, төсвөөс тань';
  }

  @override
  String planMonthTyped(String amount) {
    return 'Нэг сарын зардал: $amount, таны оруулсан дүн';
  }

  @override
  String planMonthAverage3(String amount, String loans) {
    String _temp0 = intl.Intl.selectLogic(loans, {
      'yes': ', зээлийн төлөлт орсон',
      'other': '',
    });
    return 'Нэг сарын зардал: $amount, сүүлийн 3 сарын дундаж$_temp0';
  }

  @override
  String planMonthAverageDays(String amount, int days, String loans) {
    String _temp0 = intl.Intl.selectLogic(loans, {
      'yes': ', зээлийн төлөлт орсон',
      'other': '',
    });
    return 'Нэг сарын зардал: $amount, сүүлийн $days хоногийн дундаж$_temp0';
  }

  @override
  String planFundOf(String fund, String target) {
    return '$fund / $target';
  }

  @override
  String planFundOfToGo(String fund, String target, String left) {
    return '$fund / $target · $left дутуу';
  }

  @override
  String get planWhichAccount =>
      'Аюулгүйн нөөц бол төсөв дэх «Аюулгүйн нөөц» ангилал: түүнд хуваарилаад зарцуулдаггүй мөнгө. Тусдаа хадгаламжийн дансанд байлгах нь хамгийн зөв; ийм данс нээх хүртлээ зарлагын дансандаа байлгаж болно.';

  @override
  String get planFundCategoryName => 'Аюулгүйн нөөц';

  @override
  String planFundWhere(String there, String names, String move) {
    return '$names: $there · $move шилжүүлэх үлдсэн';
  }

  @override
  String planFundAllIn(String names) {
    return 'Бүгд $names дансанд байна';
  }

  @override
  String get planFundSetPaidFrom =>
      'Хадгаламжийн дансанд байлгаж байна уу? Төсөв хуудсан дээр ангиллын Засах хэсгийг нээж, Төлөх дансыг тэр данс болгоорой. Тэгвэл энэ алхам тийш хэдийг шилжүүлснийг харуулна.';

  @override
  String planFundNotAssigned(String amount) {
    return 'Төсөвт тань $amount юунд ч хуваарилагдаагүй байна.';
  }

  @override
  String get planSaved => 'Хуримтлал';

  @override
  String get planKeepReachable =>
      'Хэрэгтэй үедээ авч болох газар хадгалаарай. Ашигласан бол юуны өмнө буцааж нөхөөрэй.';

  @override
  String planMinimumsOn(String names) {
    return 'Нөөц бүрдэх хүртэл зөвхөн хамгийн бага төлөх дүнг нь төлөөрэй: $names.';
  }

  @override
  String get planEnoughForJobLoss =>
      'Ажилгүй болох эсвэл удаан өвдөх үед хүрэлцэх хэмжээ.';

  @override
  String get planRetirementYes => 'Та мөнгө хийж байгаа';

  @override
  String get planRetirementWhat => 'Тэтгэврийн санд, цалингаасаа эсвэл өөрөө';

  @override
  String get planEmployerMatch =>
      'Таны хийсэн мөнгөтэй адил дүнг ажил олгогч нэмж хийдэг бол тэр нэмэлтийг бүтэн авахуйц хэмжээгээр хийгээрэй.';

  @override
  String get planIAm => 'Хийж байна';

  @override
  String planAnswerYesUndo(String step) {
    return '$step: тийм';
  }

  @override
  String planAnswerNotYetUndo(String step) {
    return '$step: одоохондоо үгүй';
  }

  @override
  String get planNoCardsOwing => 'Өртэй карт, зээл алга';

  @override
  String planAmountOwed(String amount) {
    return '$amount өр';
  }

  @override
  String get planPayExtraGuide =>
      'Нэг удаад нэгэнд нь илүү төлөөрэй: хамгийн бага үлдэгдэлтэй эсвэл хамгийн өндөр хүүтэйгээс нь эхэлж болно, аль аль нь зорилгод хүргэнэ. Нэгийг төлж дуусмагц түүний төлбөрийг дараагийнхад нэмээрэй.';

  @override
  String get planLongNone => 'Танд байхгүй';

  @override
  String get planLongAsk => 'Танд орон сууцны зээл байгаа юу?';

  @override
  String get planLongMarkThere =>
      '«Өрөө төлж дуусгах» алхмын доорх зээлүүдийн аль нэг нь орон сууцны зээл бол тэнд тэмдэглээрэй.';

  @override
  String get planIHaveNone => 'Надад байхгүй';

  @override
  String get planPayingExtraOnThem => 'Илүү төлж байна';

  @override
  String get planNotYet => 'Одоохондоо үгүй';

  @override
  String get planNoLongLoansUndo => 'Орон сууцны зээлгүй';

  @override
  String get planPayingExtraUndo => 'Орон сууцны зээлдээ илүү төлж байна';

  @override
  String get planLoansNotYetUndo => 'Орон сууцны зээл: одоохондоо үгүй';

  @override
  String get planNotPayingExtraUndo =>
      'Орон сууцны зээлдээ илүү төлөхгүй байна';

  @override
  String get planPaidOff => 'Төлж дууссан';

  @override
  String planAmountLeft(String amount) {
    return '$amount үлдсэн';
  }

  @override
  String get planPayingExtra => 'Илүү төлж байна';

  @override
  String planNamesAnd(String first, String last) {
    return '$first, $last';
  }

  @override
  String get planMonthBackToAverage =>
      'Нэг сарын зардал: таны оруулсан дүн биш боллоо';

  @override
  String planMonthSet(String amount) {
    return 'Нэг сарын зардал: $amount';
  }

  @override
  String get planTypeMonth => 'Сарын зардал оруулах';

  @override
  String get planChangeMonth => 'Сарын зардлыг өөрчлөх';

  @override
  String get planTypeOwnMonth => 'Өөрөө оруулах';

  @override
  String get planMonthHint => 'Нэг сарын зардал';

  @override
  String get planSave => 'Хадгалах';

  @override
  String get planEmptyToAverage => 'Хоосон бол төсөв эсвэл дунджаар тооцно';

  @override
  String planMonthsChoice(int count) {
    return '$count сар';
  }

  @override
  String planAimingFor(int count) {
    return 'Зорилго: $count сар';
  }

  @override
  String get planRoleMortgage => 'Орон сууцны зээл';

  @override
  String get planRolePaidMonthly => 'Сар бүр бүрэн төлдөг';

  @override
  String get planRoleConsumer => 'Төлж дуусгах өр';

  @override
  String planCountsAsMortgage(String account) {
    return '$account: орон сууцны зээл гэж тооцно';
  }

  @override
  String planCountsAsPaidMonthly(String account) {
    return '$account: сар бүр бүрэн төлдөг гэж тооцно';
  }

  @override
  String planCountsAsConsumer(String account) {
    return '$account: төлж дуусгах өр гэж тооцно';
  }

  @override
  String get planNothingOwed => 'өр алга';

  @override
  String planPayingExtraOn(String account) {
    return 'Илүү төлж буй: $account';
  }

  @override
  String get planPayExtraOnThis => 'Үүнд илүү төлөх';

  @override
  String get planPayExtraHere => 'Энд илүү төлнө';

  @override
  String get planRateAdd => 'Хүү нэмэх';

  @override
  String planRateMonthly(String rate) {
    return 'сарын $rate%';
  }

  @override
  String planRateYearly(String rate) {
    return 'жилийн $rate%';
  }

  @override
  String get planRateTip =>
      '2-р алхам энэ хүүгээр өр бүр сард ойролцоогоор хэдэн төгрөгийн хүү төлүүлж байгааг харуулна.';

  @override
  String get planRatePerMonth => 'сарын';

  @override
  String get planRatePerYear => 'жилийн';

  @override
  String planInterestAMonth(String amount) {
    return 'сард ойролцоогоор $amount хүү';
  }

  @override
  String planInterestCostsMost(String amount) {
    return 'сард ойролцоогоор $amount хүү, өрнүүдээс тань хамгийн их нь';
  }

  @override
  String planRateSet(String name, String rate) {
    return '$name · хүү: $rate';
  }

  @override
  String planRateRemoved(String name) {
    return '$name · хүүг хассан';
  }

  @override
  String get planRateEmptyToRemove => 'Хоосолбол хүүг хасна';

  @override
  String planRateLooksYearly(String rate, String year) {
    return 'Сарын $rate% нь жилийн $year% болно. Банкны тань $rate% жилийн хүү бол «жилийн»-г сонгоно уу.';
  }

  @override
  String planRateLooksMonthly(String rate, String month) {
    return 'Жилийн $rate% нь сарын $month% болно. Банкны тань $rate% сарын хүү бол «сарын»-г сонгоно уу.';
  }

  @override
  String get setupRate => 'Хүү';

  @override
  String get setupRateHint =>
      'Хуримтлалын 2-р алхам үүгээр энэ өр сард ойролцоогоор хэдэн төгрөгийн хүү төлүүлж байгааг харуулна.';

  @override
  String planCarried(String date) {
    return '$date өдрөөс хойш өдөр бүр өртэй байна: үлдэгдэл дараа сард шилжиж байна. Сар бүр бүрэн төлдөг гэж тэмдэглэсэн учраас л төлж дуусгах өрөнд ороогүй.';
  }

  @override
  String get planBringBack => 'Буцааж оруулах';

  @override
  String get planSetStepAside => 'Энэ алхмыг хойшлуулах';

  @override
  String get rowsNothingScheduled => 'Товлосон гүйлгээ алга';

  @override
  String rowsNextOfScheduled(int count) {
    return '$count товлосноос';
  }

  @override
  String rowsMoreOverdue(int count) {
    return 'өөр $count нь хугацаа хэтэрсэн';
  }

  @override
  String rowsAlreadyIn(String date, String payee, String amount) {
    return 'Энэ дансанд аль хэдийн бий · $date · $payee · $amount';
  }

  @override
  String rowsAlreadyInLess(
    String date,
    String payee,
    String amount,
    String short,
  ) {
    return 'Энэ дансанд аль хэдийн бий · $date · $payee · $amount · энэ төлбөрөөс $short-өөр бага';
  }

  @override
  String get rowsAlreadyInDelete => 'Товлосныг устгах';

  @override
  String get rowsScheduledOnly => 'товлосон';

  @override
  String get rowsNoTransactions => 'Гүйлгээ алга';

  @override
  String rowsNothingMatches(String search) {
    return '“$search” олдсонгүй';
  }

  @override
  String rowsNotReconciledThrough(String date) {
    return '$date хүртэлх, тулгаагүй';
  }

  @override
  String get rowsColumnDate => 'Огноо';

  @override
  String get rowsColumnPayee => 'Харилцагч';

  @override
  String get rowsColumnCategory => 'Ангилал';

  @override
  String get rowsColumnAmount => 'Дүн';

  @override
  String get rowsColumnBalance => 'Үлдэгдэл';

  @override
  String get rowsColumnOwed => 'Өр';

  @override
  String get rowsColumnClearedBalance => 'Баталгаажсан үлдэгдэл';

  @override
  String get rowsColumnAccount => 'Данс';

  @override
  String get rowsTabAll => 'Бүгд';

  @override
  String get rowsTabUncleared => 'Хүлээгдэж буй';

  @override
  String get rowsTabScheduled => 'Товлосон';

  @override
  String ledgerFiledUnder(Object category) {
    return '$category гэж ангиллаа';
  }

  @override
  String ledgerAlwaysFile(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Дараагийн удаад санах · өөр $count мөрийг одоо ангилна',
      zero: 'Дараагийн удаад санах',
    );
    return '$_temp0';
  }

  @override
  String ledgerAlwaysFiled(int count, Object category) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$category гэдгийг дараагийн удаад санана · өөр $count мөр ангиллаа',
      zero: '$category гэдгийг дараагийн удаад санана',
    );
    return '$_temp0';
  }

  @override
  String rowsIncomeFrom(Object pay) {
    return 'Орлого · $pay';
  }

  @override
  String get rowsIncomePaycheck => 'Орлого · цалин';

  @override
  String get rowsTabUncategorized => 'Ангилаагүй';

  @override
  String get rowsEdit => 'Засах';

  @override
  String get rowsCategorize => 'Ангилах';

  @override
  String get rowsMarkCleared => 'Баталгаажсан болгох';

  @override
  String get rowsMarkUncleared => 'Хүлээгдэж буй болгох';

  @override
  String get rowsMoveTo => 'Өөр данс руу';

  @override
  String get rowsDelete => 'Устгах';

  @override
  String get rowsReconciledLocked => 'Тулгасан · огноо, дүн түгжээтэй';

  @override
  String rowsReconciledOnLocked(String date) {
    return 'Тулгасан: $date · огноо, дүн түгжээтэй';
  }

  @override
  String get rowsUndoThisReconcile => 'Энэ тулгалтыг буцаах';

  @override
  String rowsReconciledInLocked(String account) {
    return '$account дансанд тулгасан · огноо, дүн түгжээтэй';
  }

  @override
  String rowsStatusTip(String status) {
    String _temp0 = intl.Intl.selectLogic(status, {
      'uncleared': 'Хүлээгдэж буй — банкинд хараахан ороогүй, тэнд хүлээгдэж буй гэж харагдаж болно. Банкинд орсны дараа дарна.',
      'cleared': 'Баталгаажсан — банкинд орсон. Дарвал хүлээгдэж буй болно.',
      'other': 'Тулгасан — хуулгатай таарсан тул огноо, дүн нь түгжээтэй.',
    });
    return '$_temp0';
  }

  @override
  String rowsStatusTipIn(String account, String status) {
    String _temp0 = intl.Intl.selectLogic(status, {
      'uncleared':
          '$account дансанд: Хүлээгдэж буй — банкинд хараахан ороогүй, тэнд хүлээгдэж буй гэж харагдаж болно. Банкинд орсны дараа дарна.',
      'cleared':
          '$account дансанд: Баталгаажсан — банкинд орсон. Дарвал хүлээгдэж буй болно.',
      'other':
          '$account дансанд: Тулгасан — хуулгатай таарсан тул огноо, дүн нь түгжээтэй.',
    });
    return '$_temp0';
  }

  @override
  String get rowsTransferToBefore => '';

  @override
  String get rowsTransferToAfter => 'данс руу';

  @override
  String get rowsTransferFromBefore => '';

  @override
  String get rowsTransferFromAfter => 'данснаас';

  @override
  String rowsScheduledTransferTo(String account) {
    return '$account данс руу';
  }

  @override
  String rowsScheduledTransferFrom(String account) {
    return '$account данснаас';
  }

  @override
  String get rowsScheduledTip => 'Товлосон — бүртгэх хүртэл үлдэгдэлд орохгүй';

  @override
  String get rowsConfirm => 'Бүртгэх';

  @override
  String rowsNewCategoryOption(String name) {
    return '+ Шинэ ангилал “$name”';
  }

  @override
  String rowsDidYouMeanTransfer(String account) {
    return '“→ $account” гэсэн үү?';
  }

  @override
  String rowsNotACategoryPickOne(String typed, String first) {
    return '“$typed” ангилал алга · $first сонгох, эсвэл + Шинэ ангилал';
  }

  @override
  String rowsNotACategoryPickTwo(String typed, String first, String second) {
    return '“$typed” ангилал алга · $first эсвэл $second сонгох, эсвэл + Шинэ ангилал';
  }

  @override
  String get rowsNewCategoryNote => 'шинэ ангилал';

  @override
  String rowsTransferFromTo(String from, String to) {
    return '$from данснаас $to данс руу';
  }

  @override
  String rowsTransferAmountFromTo(String amount, String from, String to) {
    return '$from данснаас $to данс руу $amount';
  }

  @override
  String get rowsErrorDate => 'Огноо 2026.09.16 хэлбэртэй байна';

  @override
  String get rowsErrorSameAccount =>
      'Тэр данс руу нь шилжүүлэх боломжгүй · өөр данс сонгоно уу';

  @override
  String rowsErrorNoAccount(String name) {
    return '“$name” данс алга';
  }

  @override
  String rowsErrorAmount(String typed) {
    return '“$typed” гэснийг дүн гэж уншиж чадсангүй';
  }

  @override
  String get rowsRemember => 'Энэ харилцагчид энэ ангиллыг санах';

  @override
  String get rowsSave => 'Хадгалах';

  @override
  String get rowsAdd => 'Нэмэх';

  @override
  String rowsSum(String sum) {
    return '= $sum';
  }

  @override
  String rowsSumWithNote(String sum, String note) {
    return '= $sum · $note';
  }

  @override
  String rowsNeeds(String field) {
    String _temp0 = intl.Intl.selectLogic(field, {
      'when': 'огноо дутуу',
      'account': 'данс дутуу',
      'payee': 'харилцагч дутуу',
      'category': 'ангилал дутуу',
      'other': 'дүн дутуу',
    });
    return '$_temp0';
  }

  @override
  String rowsNeedsMore(int count) {
    return '$count зүйл дутуу';
  }

  @override
  String get rowsCancelEdit => 'Болих';

  @override
  String get rowsSplitOption => 'Хэд хэдэн ангилалд хуваах…';

  @override
  String rowsSplitTitle(String payee, String amount) {
    return '$payee, $amount';
  }

  @override
  String rowsSplitLeft(String amount) {
    return '$amount үлдсэн';
  }

  @override
  String rowsSplitTooMuch(String amount) {
    return '$amount илүү';
  }

  @override
  String rowsSplitInAll(String amount) {
    return 'Нийт $amount';
  }

  @override
  String get rowsSplitAnother => '+ Өөр ангилал';

  @override
  String get rowsSplitRemove => 'Энэ ангиллыг хасах';

  @override
  String get rowsSplitDone => 'Болсон';

  @override
  String rowsErrorSplitLeft(String amount) {
    return 'Үлдсэн $amount-г ангилалд оруулна уу';
  }

  @override
  String rowsErrorSplitTooMuch(String amount) {
    return 'Мөрүүдийн нийлбэр нийт дүнгээс $amount-өөр их байна';
  }

  @override
  String rowsErrorSplitNoCategory(String amount) {
    return '$amount-д ангилал сонгоно уу';
  }

  @override
  String rowsErrorSplitUnknown(String name) {
    return '“$name” гэсэн ангилал алга';
  }

  @override
  String get ledgerDbSplitDoesntAddUp =>
      'Хуваасан мөрүүдийн нийлбэр гүйлгээний дүнтэй таарахгүй байна';

  @override
  String get rowsReconciledTip =>
      'Тулгасан · банкны хуулгатай таарсан тул өөрчлөгдөхгүй';

  @override
  String get rowsOpeningBalanceTip =>
      'Эхний үлдэгдэл нь өөрийн дансандаа хамаарна';

  @override
  String get rowsAdjustmentTip => 'Залруулга нь өөрийн дансандаа хамаарна';

  @override
  String get rowsOtherAccountDeleted => 'Нөгөө данс нь устгагдсан';

  @override
  String get rowsOtherAccountArchived => 'Нөгөө данс нь архивлагдсан';

  @override
  String get rowsHintPayee => 'Харилцагч';

  @override
  String get rowsHintNewPayee => 'Шинэ гүйлгээ — харилцагч';

  @override
  String get rowsHintMemo => 'Тэмдэглэл';

  @override
  String get rowsHintCategory => 'Ангилал';

  @override
  String get rowsHintDate => 'Огноо';

  @override
  String get rowsHintAccount => 'Данс';

  @override
  String rowsLessThanPlanned(String amount) {
    return 'Төлөвлөснөөс $amount дутуу:';
  }

  @override
  String rowsStillOwedDue(String date) {
    return 'Үлдсэнийг хүлээнэ · $date';
  }

  @override
  String get rowsPaidInFull => 'Бүтэн орсон';

  @override
  String get rowsTurnItAround => 'Чиглэлийг эргүүлэх';

  @override
  String get rowsSwap => 'Эргүүлэх';

  @override
  String get rowsPreviousMonth => 'Өмнөх сар';

  @override
  String get rowsNextMonth => 'Дараагийн сар';

  @override
  String get rowsWeekdayInitials => 'Да|Мя|Лх|Пү|Ба|Бя|Ня';

  @override
  String get rowsAfterTodayScheduled =>
      'Өнөөдрөөс хойш · товлосон гүйлгээ болно';

  @override
  String rowsOrPressKey(String key) {
    return 'Эсвэл аль ч талбарт $key дарна';
  }

  @override
  String get rowsReconcileTitle => 'Тулгах';

  @override
  String get rowsStatementDate => 'Хуулгын огноо';

  @override
  String get rowsBankSaysYouOwe => 'Банк дахь өр';

  @override
  String get rowsBankBalance => 'Банкны үлдэгдэл';

  @override
  String get rowsNotAvailableBalance => '“Боломжит үлдэгдэл” биш';

  @override
  String get rowsClearedHere => 'Энд баталгаажсан';

  @override
  String get rowsOffBy => 'Зөрүү';

  @override
  String get rowsMatches => 'Таарч байна';

  @override
  String get rowsBankIsLower => 'Банкных бага';

  @override
  String get rowsBankIsHigher => 'Банкных их';

  @override
  String get rowsBankSaysOweLess => 'Банкны мэдээгээр өр бага';

  @override
  String get rowsBankSaysOweMore => 'Банкны мэдээгээр өр их';

  @override
  String get rowsHintClearRows =>
      'Банкинд харагдаж буй гүйлгээг баталгаажуулна уу';

  @override
  String rowsHintNotCleared(String payee, String date, String amount) {
    return '$payee ($date) $amount, баталгаажаагүй';
  }

  @override
  String rowsHintDatedAfter(String payee, String date, String amount) {
    return '$payee $amount, огноо нь $date · хуулгаас хойш';
  }

  @override
  String rowsHintClearedEarly(String payee, String date, String amount) {
    return '$payee ($date) $amount, энд баталгаажсан · банкинд хараахан ороогүй юу?';
  }

  @override
  String get rowsCancel => 'Болих';

  @override
  String rowsAddAdjustmentAndLock(String amount) {
    return '$amount залруулга нэмээд түгжих';
  }

  @override
  String get rowsMarkReconciled => 'Тулгасан болгох';

  @override
  String rowsLockTransactions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count гүйлгээ түгжих',
    );
    return '$_temp0';
  }

  @override
  String setupOwedStill(String amount) {
    return 'Энэ дансны өр $amount хэвээр байна.';
  }

  @override
  String setupInCredit(String amount) {
    return 'Илүү төлөлт $amount: банк танд өртэй.';
  }

  @override
  String setupStillIn(String amount) {
    return 'Дансанд $amount үлдсэн байна.';
  }

  @override
  String setupOverdrawn(String amount) {
    return 'Данс хасах үлдэгдэлтэй · $amount дутуу.';
  }

  @override
  String get setupAddAccount => 'Данс нэмэх';

  @override
  String get setupNewAccount => 'Шинэ данс';

  @override
  String get setupName => 'Нэр';

  @override
  String get setupKind => 'Төрөл';

  @override
  String get setupKindBank => 'Банкны данс';

  @override
  String get setupKindCash => 'Бэлэн мөнгө';

  @override
  String get setupKindCashHint =>
      'Таны гарт байгаа бэлэн мөнгө: түрийвч, гэрт байгаа хайрцаг. Тулгах хуулга байхгүй тул өөрсдөө үнэн байлгах хэрэгтэй — зарцуулснаа бүртгээрэй.';

  @override
  String get setupKindOwed => 'Кредит карт эсвэл зээл';

  @override
  String get setupKindOwedHint =>
      'Кредит карт, зээл эсвэл Storepay: таны өрийг банк шиг эерэг дүнгээр харуулна.';

  @override
  String get setupKindBankHint => 'Банкны харилцах эсвэл хадгаламжийн данс.';

  @override
  String get setupCancel => 'Болих';

  @override
  String get setupStartOwedToday => 'Өнөөдөр энэ дансны өр хэд вэ?';

  @override
  String get setupStartInToday => 'Өнөөдөр энэ дансны үлдэгдэл хэд вэ?';

  @override
  String setupStartOwedOn(String date) {
    return '$date өдөр энэ дансны өр хэд байсан бэ?';
  }

  @override
  String setupStartInOn(String date) {
    return '$date өдөр энэ дансны үлдэгдэл хэд байсан бэ?';
  }

  @override
  String get setupYouOwe => 'Таны өр';

  @override
  String get setupBalance => 'Үлдэгдэл';

  @override
  String get setupOn => 'Огноо';

  @override
  String setupCantRead(String text) {
    return '“$text” гэснийг дүн гэж уншиж чадсангүй';
  }

  @override
  String setupDateShouldLook(String example) {
    return 'Огноо $example хэлбэртэй байна';
  }

  @override
  String setupStartOwedHint(Object zero) {
    return 'Ашигласан дүн, боломжит лимит биш · хоосон бол $zero-ээс эхэлнэ';
  }

  @override
  String setupStartBankHint(Object zero) {
    return 'Банкны апп, хуулга эсвэл тоолсон бэлэн мөнгөнөөс; “Боломжит үлдэгдэл” биш · хоосон бол $zero-ээс эхэлнэ';
  }

  @override
  String get setupStartImport => 'Эсвэл банкнаасаа татсан файлаа оруулах';

  @override
  String get setupStartAccount => 'Данс эхлүүлэх';

  @override
  String get setupRename => 'Нэр солих';

  @override
  String get setupToBank => 'Банкны данс болгох';

  @override
  String get setupToOwed => 'Зээлийн карт эсвэл зээл болгох';

  @override
  String get setupArchiveMenu => 'Архивлах…';

  @override
  String get setupDeleteMenu => 'Устгах…';

  @override
  String get setupClickToRename => 'Дарж нэрийг солино';

  @override
  String setupArchiveBalance(String balance) {
    return '$balance Энэ нь цэвэр хөрөнгөд тооцогдсоор байх ч данс хажуугийн цэсэнд харагдахгүй.';
  }

  @override
  String setupArchiveScheduled(int count, String list) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Товлосон $count мөр ($list) ямар ч төсөөлөлд харагдахгүй.',
    );
    return '$_temp0';
  }

  @override
  String setupArchiveTransfers(int count, String list) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Товлосон $count шилжүүлэг нөгөө дансны төсөөлөлд үлдэнэ ($list). Цуцлагдсан бол тэндээс устгана уу.',
    );
    return '$_temp0';
  }

  @override
  String get setupDeleteNoRows => 'Данс устгагдана. Өөрийн гүйлгээ байхгүй.';

  @override
  String setupDeleteRows(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Данс болон түүний $count гүйлгээ устгагдана.',
    );
    return '$_temp0';
  }

  @override
  String setupDeleteRowsReconciled(int count, int reconciled) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Данс болон түүний $count гүйлгээ устгагдана, үүнээс $reconciled нь тулгасан.',
    );
    return '$_temp0';
  }

  @override
  String setupWorthDown(String amount) {
    return 'Цэвэр хөрөнгө $amount буурна.';
  }

  @override
  String setupWorthUp(String amount) {
    return 'Цэвэр хөрөнгө $amount өснө.';
  }

  @override
  String setupWorthUpOwed(String amount) {
    return 'Энэ дансны өр цаашид тооцогдохгүй тул цэвэр хөрөнгө $amount өснө.';
  }

  @override
  String setupDeletePending(int count, String list) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count нь товлосон хэвээр ($list). Дараа бүртгэвэл байхгүй болсон данснаас мөнгө шилжүүлнэ; цуцлагдсан бол тэндээс устгана уу.',
      one:
          'Нэг нь товлосон хэвээр ($list). Дараа бүртгэвэл байхгүй болсон данснаас мөнгө шилжүүлнэ; цуцлагдсан бол тэндээс устгана уу.',
    );
    return '$_temp0';
  }

  @override
  String setupKeptOne(int count, String other, String label) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$other дансны $count шилжүүлэг “$label” нэрээр тэндээ үлдэнэ.',
    );
    return '$_temp0';
  }

  @override
  String setupKeptMany(String label, String list) {
    return 'Шилжүүлгүүд нь бусад дансанд “$label” нэрээр үлдэнэ: $list.';
  }

  @override
  String setupKeptOn(int count, String account) {
    return '$account: $count';
  }

  @override
  String get setupArchived => 'Архивласан данс';

  @override
  String setupAmountOwed(String amount) {
    return 'Өр $amount';
  }

  @override
  String get setupShowInSidebar => 'Хажуугийн цэсэнд харуулах';

  @override
  String get setupAllAccounts => 'Бүх данс';

  @override
  String get setupShowEveryRow => 'Бүх мөрийг харуулах · Esc';

  @override
  String get setupAmountMissing => 'Орох дүнг оруулна уу';

  @override
  String setupAmountMissingOn(String day) {
    return 'Сарын $day орох дүнг оруулна уу';
  }

  @override
  String get setupAmountMissingFirst =>
      'Эхний цалингийн өдөр орох дүнг оруулна уу';

  @override
  String get setupAmountMissingSecond =>
      'Хоёр дахь цалингийн өдөр орох дүнг оруулна уу';

  @override
  String setupOnDay(String day) {
    return 'Сарын $day';
  }

  @override
  String setupAtLeastOnDay(String day) {
    return '$day багадаа';
  }

  @override
  String get setupOnFirst => 'Эхний өдөр';

  @override
  String get setupOnSecond => 'Хоёр дахь өдөр';

  @override
  String get setupAtLeastOnFirst => 'Эхний өдөр багадаа';

  @override
  String get setupAtLeastOnSecond => 'Хоёр дахь өдөр багадаа';

  @override
  String get setupWhichDay => 'Сарын хэдний өдөр вэ?';

  @override
  String get setupWhichTwoDays => 'Сарын аль хоёр өдөр вэ?';

  @override
  String get setupTwoDifferentDays => 'Сарын өөр хоёр өдөр';

  @override
  String get setupHowManyWeeks => 'Хэдэн долоо хоног тутамд вэ?';

  @override
  String setupWhenPayday(String example) {
    return 'Цалингийн өдөр хэзээ вэ? ($example)';
  }

  @override
  String get setupAddYourPay => 'Цалингаа нэмэх';

  @override
  String get setupYourPay => 'Таны цалин';

  @override
  String get setupPaidInto => 'Орох данс';

  @override
  String get setupFrom => 'Хэнээс';

  @override
  String get setupEmployerHint => 'Ажил олгогч (заавал биш)';

  @override
  String get setupNameHint => 'Жени, эсвэл Жеффийн ажил (заавал биш)';

  @override
  String get setupPayIs => 'Цалин';

  @override
  String get setupPaySame => 'Ихэвчлэн ижил';

  @override
  String get setupPayVaries => 'Өөрчлөгддөг';

  @override
  String get setupVariesHint =>
      'Цагаар, ээлжээр, илүү цаг: удаа бүр өөр. Урамшууллыг оруулахгүй; тэр цалин бүрт ирдэггүй.';

  @override
  String get setupExpectAtLeast => 'Багадаа';

  @override
  String get setupEachPayday => 'Цалин бүрт';

  @override
  String get setupSameEachPaycheck => 'Цалин бүр ижил';

  @override
  String get setupDifferentEachPaycheck => 'Цалин бүр өөр дүн';

  @override
  String setupLastPaycheck(String amount) {
    return 'Сүүлийн цалин: $amount';
  }

  @override
  String setupLastPaychecks(int count, String lowest, String highest) {
    return 'Сүүлийн $count: хамгийн бага $lowest · хамгийн их $highest';
  }

  @override
  String get setupLowEndSafer =>
      'Төсөөлөл үүнд тулгуурладаг тул бага дүн нь илүү найдвартай: цалингийн өдөр их орж ирэх нь дутуу орохоос дээр.';

  @override
  String setupHigherThan(int above, int count) {
    return 'Сүүлийн $count цалингийн $above нь үүнээс бага: төсөөлөл бодит байдлаас сайн харагдаж магадгүй.';
  }

  @override
  String get setupWhen => 'Хэзээ';

  @override
  String get setupMonthly => 'Сар бүр';

  @override
  String get setupTwiceMonthly => 'Сард хоёр удаа';

  @override
  String get setupEveryFewWeeks => 'Хэдэн долоо хоног тутам';

  @override
  String setupOnDayField(String field) {
    return 'Сар бүрийн $field-нд';
  }

  @override
  String setupOnDaysField(String first, String second) {
    return 'Сар бүрийн $first, $second-нд';
  }

  @override
  String setupEveryWeeksField(int count, String weeks, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$weeks долоо хоног тутам, $date өдрөөс',
    );
    return '$_temp0';
  }

  @override
  String get setupDaysMeet =>
      'Богино сард хоёр өдөр хоёулаа сарын сүүлийн өдөрт таарна: тэр сард цалин хоёр биш, нэг удаа орно.';

  @override
  String get setupOnWeekend => 'Амралтын өдөр';

  @override
  String get setupFridayBefore => 'Өмнөх баасан';

  @override
  String get setupMondayAfter => 'Дараагийн даваа';

  @override
  String get setupKeepTheDay => 'Тэр өдөртөө';

  @override
  String get setupMonth => 'Сараар';

  @override
  String setupPaydaysAYear(int count) {
    return 'Жилд $count цалин: жилийн хоёр сард гурван цалин орно.';
  }

  @override
  String setupNextPayday(String date, String amount) {
    return 'Дараагийн цалин $date · $amount';
  }

  @override
  String setupNextPaydayOrMore(String date, String amount) {
    return 'Дараагийн цалин $date · багадаа $amount';
  }

  @override
  String setupNextPaydayMonthly(String date, String amount, String perMonth) {
    return 'Дараагийн цалин $date · $amount · сард ойролцоогоор $perMonth';
  }

  @override
  String setupNextPaydayOrMoreMonthly(
    String date,
    String amount,
    String perMonth,
  ) {
    return 'Дараагийн цалин $date · багадаа $amount · сард ойролцоогоор $perMonth';
  }

  @override
  String get setupNoRegularPay => 'Надад тогтмол цалин байхгүй';

  @override
  String get setupStopPay => 'Цалин товлохоо болих';

  @override
  String get stopPayTitle => 'Энэ цалинг зогсоох уу?';

  @override
  String stopPayPerIt(int count, String names) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ангилал энэ цалингаар төсөвлөгдсөн: $names',
      one: '1 ангилал энэ цалингаар төсөвлөгдсөн: $names',
    );
    return '$_temp0';
  }

  @override
  String get stopPayFromNow => 'Одооноос тэдгээрийг төсөвлөх';

  @override
  String stopPayBillsMonthly(String names) {
    return 'Цалин бүрийн төлбөр дараагийн цалингийн өдрөөс сар бүр ирнэ: $names.';
  }

  @override
  String get setupSavePay => 'Цалин хадгалах';

  @override
  String setupNameArchived(String name) {
    return '$name (архивласан · буцаатал цалин орохгүй)';
  }

  @override
  String setupCategoryInto(String category, String account) {
    return '$category · $account';
  }

  @override
  String get setupPay => 'Цалин';

  @override
  String setupPayLine(String category, String amounts, String account) {
    return '$category · $amounts · данс: $account';
  }

  @override
  String get setupEdit => 'Засах';

  @override
  String get setupSaidNoPay =>
      'Та тогтмол цалингүй гэж хэлсэн тул төсөөлөл цалин асуухгүй.';

  @override
  String get setupAskAgain => 'Дахин асуух';

  @override
  String get setupAddOtherPay => 'Өөр цалин нэмэх';

  @override
  String get startKeyFileName => 'BetterBudget сэргээх түлхүүр.txt';

  @override
  String get startSave => 'Хадгалах';

  @override
  String startKeyFileText(String key, String date) {
    return 'BetterBudget сэргээх түлхүүр\n\n$key\n\nҮүсгэсэн огноо: $date.\n\nЭнэ түлхүүрээр таны BetterBudget дэвтэр болон түүний нөөц хуулбаруудыг өөр компьютер дээр, эсвэл зарлага бүртгэдэг утсан дээр нээнэ. BetterBudget хуулбарыг нь хадгалдаггүй бөгөөд өөр түлхүүрээр орлуулах боломжгүй: түлхүүргүйгээр дэвтрийг өөр хаана ч нээж чадахгүй.\n\nҮүнийг энэ компьютерээс тусад нь, мөнгөө хамт зохицуулдаг нөгөө хүн тань олж чадах аюулгүй газар хадгалаарай. Энэ файлыг нөөц хуулбаруудтайгаа нэг хавтсанд бүү хадгал.\n';
  }

  @override
  String get startKeyTitle => 'Таны сэргээх түлхүүр';

  @override
  String get startKeyIntro =>
      'BetterBudget таны дэвтэр болон нөөц хуулбаруудыг шифрлэдэг. Энэ түлхүүрээр тэдгээрийг өөр компьютер дээр, мөн зарлага бүртгэдэг утас бүр дээр нээнэ. Түлхүүрийг зөвхөн энэ удаа харуулна: BetterBudget хуулбарыг нь хадгалдаггүй бөгөөд өөр түлхүүрээр орлуулах боломжгүй.';

  @override
  String get startKeyWhere =>
      'Энэ компьютерээс тусад нь, мөнгөө хамт зохицуулдаг нөгөө хүн тань олж чадах газар хадгалаарай: хэвлээд чухал бичиг баримттайгаа хамт, эсвэл өөр диск дээр.';

  @override
  String get startSaveEllipsis => 'Хадгалах…';

  @override
  String get startSaved => 'Хадгалсан';

  @override
  String get startCopy => 'Хуулах';

  @override
  String get startCopied => 'Хуулсан';

  @override
  String get startOldCopies =>
      'Өнөөдрөөс өмнө «Нөөцлөх…»-ээр өөр газар хадгалсан хуулбарууд шифрлээгүй. Тэдгээрийг шинээр «Нөөцлөх…» хийж солиорой.';

  @override
  String get startCopiedWarning =>
      'Хуулсан · үргэлжлүүлэхээсээ өмнө энэ компьютерээс гадна хаа нэг газар буулгаж хадгалаарай. Хуулсан зүйл нэг минутын дараа арилна.';

  @override
  String get startNotKeptWarning =>
      'Хадгалах эсвэл хуулахгүйгээр үргэлжлүүлбэл түлхүүр үгүй болно: BetterBudget үүнийг дахин харуулж чадахгүй бөгөөд энэ компьютер алга болбол таны дэвтэр болон нөөц хуулбаруудыг нээх боломжгүй.';

  @override
  String get startContinue => 'Үргэлжлүүлэх';

  @override
  String get startEnterTitle => 'Сэргээх түлхүүрээ оруулна уу';

  @override
  String get startNewLedgerInstead => 'Оронд нь шинэ дэвтэр эхлүүлэх…';

  @override
  String get startSetAsideTitle => 'Шинэ дэвтэр эхлүүлэх үү?';

  @override
  String startSetAsideBodyNamed(String name) {
    return 'Энэ компьютер дээр байгаа дэвтрийг зөвхөн өөрийнх нь сэргээх түлхүүрээр нээнэ. Үүнийг устгахгүй: BetterBudget-ийн хавтсанд $name нэрээр тусад нь хадгална. Түлхүүрийг нь олбол дараа нь нээж болно.';
  }

  @override
  String get startSetAsideBody =>
      'Энэ компьютер дээр байгаа дэвтрийг зөвхөн өөрийнх нь сэргээх түлхүүрээр нээнэ. Үүнийг устгахгүй: BetterBudget-ийн хавтсанд тусад нь хадгална. Түлхүүрийг нь олбол дараа нь нээж болно.';

  @override
  String get startCancel => 'Болих';

  @override
  String get startSetAsideConfirm => 'Тусад нь хадгалаад шинээр эхлүүлэх';

  @override
  String get startCheckTitle => 'Сэргээх түлхүүрээ шалгах';

  @override
  String get startCheckBody =>
      'Хадгалсан түлхүүрээ бичнэ үү. BetterBudget түүгээр энэ дэвтэр нээгдэх эсэхийг шалгана. Түлхүүрийг хэзээ ч харуулахгүй.';

  @override
  String get startCheckAction => 'Шалгах';

  @override
  String get startCheckNo => 'Үгүй · энэ түлхүүрээр энэ дэвтэр нээгдэхгүй';

  @override
  String get startCheckYes => 'Тийм · энэ түлхүүрээр энэ дэвтэр нээгдэнэ';

  @override
  String get startBackupKeyTitle => 'Энэ нөөц хуулбар өөрийн түлхүүртэй';

  @override
  String get startBackupKeyBody =>
      'Энэ нь энэ дэвтрийн түлхүүрээр шифрлээгүй. Өөр дэвтрийнх байж магадгүй: сэргээхийн тулд тэр дэвтрийн сэргээх түлхүүрийг бичнэ үү. Таны өөрийн түлхүүр өөрчлөгдөхгүй.';

  @override
  String get startBackupKeyAction => 'Нөөцийг нээх';

  @override
  String get startClose => 'Хаах';

  @override
  String get startKeyCyrillic =>
      'Гар кирилл үсгээр бичиж байна · түлхүүрийг бичихийн тулд ABC руу шилжүүлнэ үү';

  @override
  String startKeyLength(int typed, int total) {
    return '$typed/$total тэмдэгт';
  }

  @override
  String get startKeyChecksum =>
      'Нэг тэмдэгт буруу байна · хадгалсан хуулбартайгаа харьцуулж шалгана уу';

  @override
  String get startEntryKeptKeyWrong =>
      'Энэ компьютер дээр хадгалсан түлхүүрээр энд байгаа дэвтэр нээгдэхгүй байна. Нээхийн тулд дэвтрийн сэргээх түлхүүрийг бичнэ үү.';

  @override
  String get startEntryLedgerHere =>
      'Энэ компьютер дээр дэвтэр байна. Нээхийн тулд түүний сэргээх түлхүүрийг бичнэ үү.';

  @override
  String get startEntryLedgerHereEveryLaunch =>
      'Энэ компьютерт BetterBudget ашиглаж болох түлхүүр хадгалах сан (keychain) алга тул нээх бүрдээ таны сэргээх түлхүүрийг асууна. Энэ компьютер дээр дэвтэр байна. Нээхийн тулд түүний сэргээх түлхүүрийг бичнэ үү.';

  @override
  String get startKeyWrongHere =>
      'Энэ түлхүүрээр энэ компьютер дээрх дэвтэр нээгдэхгүй';

  @override
  String startCouldntKeepKey(String error) {
    return 'Түлхүүрийг энэ компьютер дээр хадгалж чадсангүй · $error';
  }

  @override
  String get startCouldntKeepKeyNothingEncrypted =>
      'Түлхүүрийг энэ компьютер дээр хадгалж чадсангүй';

  @override
  String get startNothingEncrypted => 'Юу ч шифрлээгүй.';

  @override
  String get startCouldntOpen => 'Дэвтрийг тань нээж чадсангүй';

  @override
  String get startCouldntReadKey =>
      'Энэ компьютер дээр хадгалсан түлхүүрийг уншиж чадсангүй';

  @override
  String get startLedgerNotTouched => 'Дэвтэрт тань гар хүрээгүй.';

  @override
  String get startTryAgain => 'Дахин оролдох';

  @override
  String get startShowDetails => 'Дэлгэрэнгүйг харуулах';

  @override
  String startCopiesFailed(int count, String names) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count хуучин хуулбарыг шифрлэж чадсангүй, шифргүй хэвээр байна: $names',
    );
    return '$_temp0';
  }

  @override
  String startCopiesEncrypted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Дэвтрийн $count хуучин хуулбарыг шифрлэлээ',
    );
    return '$_temp0';
  }

  @override
  String startEncryptedCopyFailed(String name) {
    return 'Шифрлэсэн хуулбар шалгалтад тэнцсэнгүй: $name';
  }

  @override
  String get startRestoreNothingInto => 'Сэргээх дэвтэр алга';

  @override
  String get startRestoreNewer =>
      'Энэ нөөц хуулбарыг BetterBudget-ийн шинэ хувилбараар хийсэн · эхлээд аппаа шинэчилнэ үү';

  @override
  String get startRestoreNotABackup =>
      'Энэ файл BetterBudget-ийн нөөц хуулбар биш';

  @override
  String get startRestoreNeedsKey =>
      'Энэ нөөц хуулбарыг энэ дэвтрийн түлхүүрээр нээх боломжгүй · өөр дэвтрийнх эсвэл гэмтсэн байж магадгүй';

  @override
  String get startRestoreWrongKey =>
      'Энэ түлхүүрээр энэ нөөц хуулбар нээгдэхгүй · өөр дэвтрийнх эсвэл гэмтсэн байж магадгүй';

  @override
  String get startRestoreDamaged => 'Энэ нөөц хуулбар гэмтсэн байна';

  @override
  String get startRestoreNoAccounts => 'Энэ нөөц хуулбарт данс алга';

  @override
  String get startUncleared => 'Хүлээгдэж буй';

  @override
  String get startCleared => 'Баталгаажсан';

  @override
  String get startReconciled => 'Тулгасан';

  @override
  String get startOpeningBalance => 'Эхний үлдэгдэл';

  @override
  String get startOpeningBalances => 'Эхний үлдэгдэл';

  @override
  String get startBalanceAdjustments => 'Залруулга';

  @override
  String get startReconcileAdjustment => 'Тулгалтын залруулга';

  @override
  String get startTransfer => 'Данс хооронд';

  @override
  String startSplitCategories(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ангилал',
    );
    return '$_temp0';
  }

  @override
  String startDeletedAccount(String name) {
    return '$name (устгасан)';
  }

  @override
  String startStaleNote(int days) {
    return '$days хоног баталгаажаагүй';
  }

  @override
  String startNotOnStatement(String date) {
    return '$date-ны хуулганд байхгүй';
  }

  @override
  String get startDueYesterday => 'өчигдөр хугацаа нь болсон';

  @override
  String startDueDaysAgo(int days) {
    return 'хугацаа нь $days хоногийн өмнө болсон';
  }

  @override
  String startDayOn(String ordinal, int day, String isTwo) {
    String _temp0 = intl.Intl.selectLogic(isTwo, {
      'yes': '$day-т',
      'other': '$day-нд',
    });
    return '$_temp0';
  }

  @override
  String startPayMonthly(String day) {
    return 'сар бүрийн $day';
  }

  @override
  String startPayTwiceMonthly(String first, String second, int firstDay) {
    return 'сар бүрийн $firstDay, $second';
  }

  @override
  String get startPayEveryWeek => 'долоо хоног бүр';

  @override
  String startPayEveryWeeks(int weeks) {
    return '$weeks долоо хоног тутам';
  }

  @override
  String startPayAmountWhen(String amount, String when) {
    return '$when $amount';
  }

  @override
  String startPayAmountOrMoreWhen(String amount, String when) {
    return '$when $amount буюу түүнээс дээш';
  }

  @override
  String startPayAmountDotWhen(String amount, String when) {
    return '$amount · $when';
  }

  @override
  String startPayAmountOrMoreDotWhen(String amount, String when) {
    return '$amount буюу түүнээс дээш · $when';
  }

  @override
  String startPaySplit(
    String first,
    String firstDay,
    String second,
    String secondDay,
  ) {
    return '$firstDay $first, $secondDay $second';
  }

  @override
  String startPaySplitAtLeast(
    String first,
    String firstDay,
    String second,
    String secondDay,
  ) {
    return 'багадаа: $firstDay $first, $secondDay $second';
  }

  @override
  String get startThisPayPeriod => 'Энэ цалингийн үе';

  @override
  String get startThisMonth => 'Энэ сар';

  @override
  String get importButton => 'Файлаас оруулах…';

  @override
  String importTitle(Object account) {
    return '$account дансанд оруулах';
  }

  @override
  String get importExcelFiles => 'Excel файл';

  @override
  String get importTextFiles => 'Текст файл (CSV)';

  @override
  String get importOfxFiles => 'Банкны татсан файл (OFX, QFX, QBO)';

  @override
  String importCouldntRead(Object file) {
    return '$file файлыг уншиж чадсангүй. BetterBudget нь Excel (.xls, .xlsx), CSV болон OFX файл уншдаг.';
  }

  @override
  String importNoDates(Object file) {
    return '$file файлд огноотой мөр алга.';
  }

  @override
  String get importSavedColumns =>
      'Энэ дансанд өмнө тохируулсан баганаар уншлаа.';

  @override
  String get importChangeColumns => 'Багана өөрчлөх';

  @override
  String get importColumnsHint =>
      'Багана бүрт юу байгааг сонгоно уу. Програм урьдчилан бөглөсөн тул огноо, дүнг шалгана уу.';

  @override
  String get importRoleIgnore => 'Ашиглахгүй';

  @override
  String get importRoleDate => 'Огноо';

  @override
  String get importRoleAmount => 'Дүн (+ орлого, − зарлага)';

  @override
  String get importRoleIn => 'Орлого';

  @override
  String get importRoleOut => 'Зарлага';

  @override
  String get importRolePayee => 'Харилцагч';

  @override
  String get importRoleMemo => 'Тэмдэглэл';

  @override
  String get importRoleBalance => 'Банкны үлдэгдэл';

  @override
  String get importNeedDateAmount =>
      'Огноо болон дүнгийн (эсвэл орлого, зарлагын) баганыг сонгоно уу.';

  @override
  String get importDateOrder => 'Энэ файлын огноо:';

  @override
  String importDayFirst(Object date) {
    return 'Өдөр нь эхэндээ: $date';
  }

  @override
  String importMonthFirst(Object date) {
    return 'Сар нь эхэндээ: $date';
  }

  @override
  String get importSignLabel => 'Дүнгийн баганад:';

  @override
  String get importMinusOut => 'хасах тэмдэг нь зарлага';

  @override
  String get importPlusOut => 'нэмэх тэмдэг нь зарлага';

  @override
  String importCountNew(int count) {
    return '$count шинэ мөр';
  }

  @override
  String importCountMatch(int count) {
    return '$count нь таны бичсэн мөртэй таарч, баталгаажна';
  }

  @override
  String importCountAlready(int count) {
    return '$count нь дэвтэрт аль хэдийн бий';
  }

  @override
  String importBalanceOk(Object opening, Object closing) {
    return 'Банкны үлдэгдэл мөр бүрт таарч байна: $opening → $closing.';
  }

  @override
  String importBalanceOff(int row, Object found, Object expected) {
    return 'Файлын $row-р мөр: банкны үлдэгдэл $found, харин өмнөх дүнгүүдээр $expected гарч байна. Аль нэг багана буруу сонгогдсон байж магадгүй. Гэсэн ч оруулж болно.';
  }

  @override
  String importBalanceOffCount(int count) {
    return 'Нийт $count мөр таарахгүй байна.';
  }

  @override
  String importClearedMatches(Object amount) {
    return 'Үүний дараа баталгаажсан үлдэгдэл банкныхтай таарна: $amount.';
  }

  @override
  String importClearedDiffers(Object ours, Object bank, Object diff) {
    return 'Үүний дараа баталгаажсан үлдэгдэл $ours, банкны файл $bank-аар дуусна: $diff зөрүүтэй. Энэ файлаас өмнөх эсвэл баталгаажаагүй мөрүүдээс зөрүү гарч болно.';
  }

  @override
  String importClearedMatchesOn(Object amount, Object date) {
    return 'Үүний дараа баталгаажсан үлдэгдэл банкны үлдэгдэлтэй ($date) таарна: $amount.';
  }

  @override
  String importClearedDiffersOn(
    Object ours,
    Object bank,
    Object date,
    Object diff,
  ) {
    return 'Үүний дараа баталгаажсан үлдэгдэл $ours, банкны үлдэгдэл ($date) $bank байсан: $diff зөрүүтэй. Тэр өдрөөс хойших, энэ файлаас өмнөх эсвэл баталгаажаагүй мөрүүдээс зөрүү гарч болно.';
  }

  @override
  String get importFateRepeat => 'Аль хэдийн бий · өдөр, дүн ижил';

  @override
  String importRepeats(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count мөрийн өдөр, дүн нь өөр төрлийн файлаас өмнө оруулсан мөрүүдтэй ижил тул орхилоо. Оруулах бол мөрийн тэмдэглэгээг дарна уу.',
      one: '1 мөрийн өдөр, дүн нь өөр төрлийн файлаас өмнө оруулсан мөртэй ижил тул орхилоо. Оруулах бол тэмдэглэгээг нь дарна уу.',
    );
    return '$_temp0';
  }

  @override
  String importStartsEnds(Object start, Object from, Object end, Object to) {
    return 'Энэ файл $start-аар эхэлж ($from), $end-аар дуусна ($to). Данс үүнээс эхэлнэ.';
  }

  @override
  String importStartsEndsOwed(
    Object start,
    Object from,
    Object end,
    Object to,
  ) {
    return 'Энэ файл $start өртэй эхэлж ($from), $end өртэй дуусна ($to). Данс үүнээс эхэлнэ.';
  }

  @override
  String get importStartFrom => 'Эхлэх өдөр';

  @override
  String get importWholeFile => 'Файлыг бүхэлд нь';

  @override
  String importEarlierLeftOut(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Энэ файлын өмнөх $count мөрийг орхино',
    );
    return '$_temp0';
  }

  @override
  String importStartsOn(Object from, Object start, Object end, Object to) {
    return 'Данс $start-аар эхэлнэ ($from). Файл $end-аар дуусна ($to).';
  }

  @override
  String importStartsOnOwed(Object from, Object start, Object end, Object to) {
    return 'Данс $start өртэй эхэлнэ ($from). Файл $end өртэй дуусна ($to).';
  }

  @override
  String importNoBalance(Object question) {
    return 'Энэ файлд үлдэгдэл алга. $question';
  }

  @override
  String importNoBalanceHint(Object zero) {
    return 'Хоосон орхивол данс файлын эхний мөрөөс өмнө $zero-оос эхэлнэ';
  }

  @override
  String get importFateNew => 'Шинэ';

  @override
  String importFateMatch(Object payee, Object date) {
    return 'Таны бичсэн: $payee, $date';
  }

  @override
  String get importFateAlready => 'Аль хэдийн бий';

  @override
  String importDo(int count) {
    return '$count мөр оруулах';
  }

  @override
  String get importNothingNew => 'Энэ файлд шинэ зүйл алга';

  @override
  String get importCancel => 'Болих';

  @override
  String importDone(int count) {
    return '$count мөр орууллаа';
  }

  @override
  String importMatchedToast(int count) {
    return 'таны бичсэн $count мөр баталгаажлаа';
  }

  @override
  String importUncategorizedToast(int count, Object name) {
    return '$count нь “$name” ангилалд';
  }

  @override
  String get importUncategorized => 'Ангилаагүй';

  @override
  String importCouldntImport(Object problem) {
    return 'Оруулж чадсангүй: $problem';
  }

  @override
  String importDoClear(int count, int cleared) {
    return '$count мөр оруулах · $cleared баталгаажуулах';
  }

  @override
  String importDoOnlyClear(int count) {
    return 'Бичсэн $count мөрийг баталгаажуулах';
  }

  @override
  String importCountNoDate(int count) {
    return 'огноогүй $count мөр (гарчиг, дүн) орхисон';
  }

  @override
  String importNoAmountRows(int count, Object rows) {
    return 'Файлын $count мөрөнд ($rows-р мөр) огноо байгаа ч уншигдах дүн алга тул орхисон.';
  }

  @override
  String importCountLeftOut(int count) {
    return '$count-г та орхисон';
  }

  @override
  String get importTagHint =>
      'Мөрийн «Шинэ» эсвэл «Таарсан»-ыг дарж тусдаа мөр болгох эсвэл орхиж болно.';

  @override
  String importFateMatchDate(Object date) {
    return 'Таны $date-ны мөртэй таарсан';
  }

  @override
  String get importFateLeftOut => 'Орхино';

  @override
  String importOverlap(Object from, Object to, int count) {
    return 'Шинэ мөрүүд $from-$to хооронд байгаа бөгөөд энэ дансанд тэр хугацаанд аль хэдийн $count оруулсан мөр бий. Энэ файл өмнөхийг өөр хэлбэрээр давтаж байвал тэдгээр нь давхардал болно.';
  }

  @override
  String get importLeaveNewOut => 'Шинэ мөрүүдийг орхих';

  @override
  String importUnmatched(int count, Object from, Object to, Object list) {
    return '$from-$to хооронд таны бичсэн $count мөр энэ файлд алга: $list. Хүлээгдэж буй хэвээр үлдэнэ.';
  }

  @override
  String importUnmatchedItem(Object payee, Object amount, Object date) {
    return '$payee $amount, $date';
  }

  @override
  String importUnmatchedMore(int count) {
    return 'бусад $count';
  }

  @override
  String rowsLeftOther(Object account) {
    return '$account данснаас илгээсэн:';
  }

  @override
  String rowsArrivesOther(Object account) {
    return '$account дансанд орох:';
  }

  @override
  String rowsErrorLeftOther(Object account) {
    return '$account данснаас илгээсэн дүнг бичнэ үү';
  }

  @override
  String rowsErrorArrivesOther(Object account) {
    return '$account дансанд орох дүнг бичнэ үү';
  }

  @override
  String rowsRatePer(String rate, String one) {
    return '$one = $rate';
  }

  @override
  String get ledgerDbOtherCurrency => 'Тэр данс өөр валюттай';

  @override
  String get ledgerDbNeedsOtherAmount =>
      'Хоёр валютын данс хооронд хоёр дүнтэй шилжүүлэг хийнэ үү';

  @override
  String get setupCurrency => 'Валют';

  @override
  String get setupCurrencyHint =>
      'Энэ дансны бүх дүн энэ валютаар бөгөөд одоогоор дараа нь солих боломжгүй. Цэвэр хөрөнгө валют бүрийг тусад нь харуулна.';

  @override
  String rowsExchangeNote(
    Object account,
    Object amount,
    Object rate,
    String one,
  ) {
    return '$account: $amount · $one = $rate';
  }

  @override
  String savingsOnlyOne(String accounts, String currency) {
    return 'Одоогоор энд тооцоогүй: $accounts. Хуримтлал одоогоор зөвхөн нэг валютаар тооцно: $currency.';
  }

  @override
  String importFileIn(
    String fileCurrency,
    String account,
    String accountCurrency,
    String example,
    String asIs,
  ) {
    return 'Энэ файл $fileCurrency валютаар бичигдсэн бололтой, харин $account данс $accountCurrency валюттай. Дүн хэвээрээ орно: $example нь $asIs болно.';
  }

  @override
  String get ledgerNewerLedger =>
      'үүнийг BetterBudget-ийн шинэ хувилбар хадгалсан байна. Тэр хувилбараар нээнэ үү; энд юу ч өөрчлөгдөөгүй.';

  @override
  String importBeforeOpening(int count, Object amount, Object date) {
    return '$count мөр энэ дансны эхний үлдэгдлийн ($date, $amount) өдөр эсвэл түүнээс өмнөх огноотой бөгөөд эхний үлдэгдэлд аль хэдийн орсон.';
  }

  @override
  String importBeforeOpeningLocked(int count, Object amount, Object date) {
    return '$count мөр энэ дансны эхний үлдэгдлийн ($date, $amount) өдөр эсвэл түүнээс өмнөх огноотой бөгөөд эхний үлдэгдэлд аль хэдийн орсон. Эхний үлдэгдэл тулгагдсан тул өөрчлөгдөхгүй; оруулбал давхар тооцогдоно.';
  }

  @override
  String importMoveOpening(Object date, Object amount) {
    return 'Эхний үлдэгдлийг $date-нд $amount болгох';
  }

  @override
  String get importKeepOpening =>
      'Хэвээр үлдээх (тэдгээр мөр давхар тооцогдоно)';

  @override
  String get importLeaveBeforeOut => 'Тэдгээр мөрийг орхих';

  @override
  String importFateRedated(Object date) {
    return 'банкны огноо $date-г авна';
  }

  @override
  String importOpeningMovedToast(Object date, Object amount) {
    return 'эхний үлдэгдэл одоо $date-нд $amount';
  }

  @override
  String get planAssigned => 'Хуваарилсан';

  @override
  String get planSpent => 'Зарцуулсан';

  @override
  String get planLeft => 'Үлдсэн';

  @override
  String planFromBefore(String amount) {
    return 'өмнөөс $amount';
  }

  @override
  String get planPayPeriod => 'Цалингийн үе';

  @override
  String get planViewMonth => 'Сар';

  @override
  String get planViewTip => 'Сараар, эсвэл нэг цалингийн үеэр харах';

  @override
  String planPeriodTitle(String name, String start, String end) {
    return '$name · $start–$end';
  }

  @override
  String get planPeriodPrev => 'Өмнөх үе';

  @override
  String get planPeriodNext => 'Дараагийн үе';

  @override
  String get planBackToToday => 'Өнөөдөр рүү буцах';

  @override
  String get planAssignTip => 'Дарж хуваарилах дүнгээ бичих · Tab дараагийнх';

  @override
  String planAssignUndo(String amount, String category) {
    return '$category: $amount хуваарилсан';
  }

  @override
  String planShowAllRows(String usage) {
    return '$usage · харуулах';
  }

  @override
  String planStartOffer(String amount, String count) {
    return 'Юу ч хуваарилахаас өмнө $count ангилалд $amount зарцуулсан байна. Энэ үед тэдгээрээс хасагдана.';
  }

  @override
  String planStartLater(String date) {
    return 'Төсвийг $date-нээс эхлүүлэх';
  }

  @override
  String get planStartKeep => 'Хэвээр үлдээх';

  @override
  String planStartLaterUndo(String date) {
    return 'Төсвийг $date-нээс эхлүүлсэн';
  }

  @override
  String planMoneyBack(String amount, String category) {
    return '$category-д хуваарилсан $amount хуваарилаагүй мөнгө рүү буцна';
  }

  @override
  String get setupLoanPaidFrom => 'Төлбөр аль ангиллаас гарах';

  @override
  String get setupLoanNoCategory => 'Ангилалгүй';

  @override
  String setupLoanPaidFromUndo(String loan, String category) {
    return '$loan-ийг $category-оос төлнө';
  }

  @override
  String setupLoanNoCategoryUndo(String loan) {
    return '$loan-ийг ангилалгүй төлнө';
  }

  @override
  String get appearanceColorsTitle => 'Өнгө';

  @override
  String appearanceColorsUndoLabel(String name) {
    return 'Өнгө: $name';
  }

  @override
  String get schemeBetterBudget => 'BetterBudget';

  @override
  String get schemeGroupMonochromatic => 'Нэг өнгийн';

  @override
  String get schemeGroupRomantic => 'Романтик';

  @override
  String get schemeGroupPlayful => 'Хөгжилтэй';

  @override
  String get schemeGroupVibrant => 'Тод';

  @override
  String get schemeGroupNeutral => 'Саармаг';

  @override
  String get schemeGroupTranquil => 'Тайван';

  @override
  String get schemeGroupSeasonal => 'Улирлын';

  @override
  String get schemeStormyMorning => 'Шуургатай өглөө';

  @override
  String get schemeMossyHollow => 'Хөвдтэй хонхор';

  @override
  String get schemeBlueEclipse => 'Цэнхэр хиртэлт';

  @override
  String get schemeLushForest => 'Өтгөн ой';

  @override
  String get schemeGreenJuice => 'Ногоон жүүс';

  @override
  String get schemeChiliSpice => 'Чинжүү';

  @override
  String get schemeChocolateTruffle => 'Шоколадан трюфель';

  @override
  String get schemeInkWash => 'Бэхэн будаг';

  @override
  String get schemeGoldenTaupe => 'Алтлаг бор саарал';

  @override
  String get schemeWisteriaBloom => 'Глицинийн цэцэг';

  @override
  String get schemeBurntSienna => 'Шатсан шавар';

  @override
  String get schemeBloomingRomance => 'Цэцэглэх хайр';

  @override
  String get schemeDesertDusk => 'Цөлийн бүрэнхий';

  @override
  String get schemeLavenderFields => 'Лавандын талбай';

  @override
  String get schemeHydrangea => 'Гортензи';

  @override
  String get schemeCactusFlower => 'Кактусын цэцэг';

  @override
  String get schemeWildflowers => 'Хээрийн цэцэг';

  @override
  String get schemeCountryGarden => 'Хөдөөгийн цэцэрлэг';

  @override
  String get schemeLotusGarden => 'Бадамлянхуан цэцэрлэг';

  @override
  String get schemeIrisGarden => 'Цахилдагийн цэцэрлэг';

  @override
  String get schemeFreshPeach => 'Шинэхэн тоор';

  @override
  String get schemeGoldenHour => 'Алтан цаг';

  @override
  String get schemeSpicedChai => 'Амтлагчтай цай';

  @override
  String get schemeCherryBlossom => 'Интоорын цэцэг';

  @override
  String get schemeEveningRose => 'Үдшийн сарнай';

  @override
  String get schemePastelGarden => 'Зөөлөн өнгийн цэцэрлэг';

  @override
  String get schemeTuscanSunset => 'Тосканы нар жаргалт';

  @override
  String get schemeZestyLemon => 'Хурц нимбэг';

  @override
  String get schemeCaliforniaBeaches => 'Калифорнийн далайн эрэг';

  @override
  String get schemeFreshlySqueezed => 'Шинэ шахсан жүүс';

  @override
  String get schemePistachioDream => 'Пистачины мөрөөдөл';

  @override
  String get schemeMangoPopsicle => 'Манготой зайрмаг';

  @override
  String get schemeGuava => 'Гуава';

  @override
  String get schemeGlowingHorizon => 'Гэрэлтэх тэнгэрийн хаяа';

  @override
  String get schemeSunnyDay => 'Нартай өдөр';

  @override
  String get schemeRetroSunset => 'Ретро нар жаргалт';

  @override
  String get schemeBubblegumPop => 'Бохь';

  @override
  String get schemeCottonCandySkies => 'Чихэр хөвөн тэнгэр';

  @override
  String get schemeElectricKiwi => 'Цахилгаан киви';

  @override
  String get schemeWatermelonSplash => 'Тарвасны цацал';

  @override
  String get schemeAlchemicalReaction => 'Алхимийн урвал';

  @override
  String get schemeElectropop => 'Электропоп';

  @override
  String get schemeCoolRevival => 'Сэрүүн сэргэлт';

  @override
  String get schemeNeonJungle => 'Неон ширэнгэ';

  @override
  String get schemeSharpEdge => 'Хурц ирмэг';

  @override
  String get schemeElectricFusion => 'Цахилгаан нэгдэл';

  @override
  String get schemeFireworks => 'Салют';

  @override
  String get schemeSpaceBerries => 'Сансрын жимс';

  @override
  String get schemePopArt => 'Поп арт';

  @override
  String get schemeUrbanGraffiti => 'Хотын граффити';

  @override
  String get schemeNeonNoir => 'Неон нуар';

  @override
  String get schemeTropicalPunch => 'Халуун орны пунш';

  @override
  String get schemeCobaltSky => 'Кобальт тэнгэр';

  @override
  String get schemeTechnicolorDream => 'Өнгөт мөрөөдөл';

  @override
  String get schemeJewelBox => 'Эрдэнийн хайрцаг';

  @override
  String get schemeSaltAndPepper => 'Давс, перц';

  @override
  String get schemeQuiteClear => 'Тун тунгалаг';

  @override
  String get schemeGothicNoir => 'Готик нуар';

  @override
  String get schemeYachtClub => 'Дарвуулт завины клуб';

  @override
  String get schemeQuietLuxury => 'Нам гүм тансаг';

  @override
  String get schemeNightSands => 'Шөнийн элс';

  @override
  String get schemeHarborHaze => 'Боомтын манан';

  @override
  String get schemeOldPhotograph => 'Хуучин гэрэл зураг';

  @override
  String get schemeCappuccino => 'Капучино';

  @override
  String get schemeBreakfastTea => 'Өглөөний цай';

  @override
  String get schemeCozyCampfire => 'Дулаан гал';

  @override
  String get schemeStonePath => 'Чулуун зам';

  @override
  String get schemeDesertMirage => 'Цөлийн зэрэглээ';

  @override
  String get schemeHoneycomb => 'Зөгийн сархинаг';

  @override
  String get schemeUrbanLoft => 'Хотын дээврийн өрөө';

  @override
  String get schemeSpicedMocha => 'Амтлагчтай мокко';

  @override
  String get schemeCharmingSeaside => 'Сэтгэл татам далайн эрэг';

  @override
  String get schemeCalmBlue => 'Тайван цэнхэр';

  @override
  String get schemeBeachfrontViews => 'Эрэг дээрх үзэмж';

  @override
  String get schemeUnderTheMoonlight => 'Сарны гэрэлд';

  @override
  String get schemeLavenderLullaby => 'Лавандын бүүвэй';

  @override
  String get schemeMintyFresh => 'Сэрүүн гаа';

  @override
  String get schemeRetroCalm => 'Ретро тайван';

  @override
  String get schemeSiltstone => 'Лаг чулуу';

  @override
  String get schemeEmeraldOdyssey => 'Маргад аялал';

  @override
  String get schemeOceanTide => 'Далайн түрлэг';

  @override
  String get schemePeachSkyline => 'Тоорын тэнгэр';

  @override
  String get schemeMountainMist => 'Уулын манан';

  @override
  String get schemeMorningDew => 'Өглөөний шүүдэр';

  @override
  String get schemeFrozenLake => 'Хөлдсөн нуур';

  @override
  String get schemeOliveGrove => 'Чидуны төгөл';

  @override
  String get schemeCoastalMorning => 'Эргийн өглөө';

  @override
  String get schemeEucalyptusGrove => 'Эвкалиптын төгөл';

  @override
  String get schemeSoftSpring => 'Зөөлөн хавар';

  @override
  String get schemeAutumnLeaves => 'Намрын навч';

  @override
  String get schemeWinterChill => 'Өвлийн хүйтэн';

  @override
  String get schemeSpringEnergy => 'Хаврын эрч';

  @override
  String get schemePumpkinSpiceSeason => 'Хулууны улирал';

  @override
  String get schemeIslandOasis => 'Арлын баян бүрд';

  @override
  String get schemeAutumnOrchard => 'Намрын жимсний цэцэрлэг';

  @override
  String get schemeTropicalRainforest => 'Халуун орны ширэнгэ ой';

  @override
  String get schemeWildflowerMeadow => 'Хээрийн цэцэгт нуга';

  @override
  String get schemeHarvestMoon => 'Ургацын сар';

  @override
  String get schemeWinterBerry => 'Өвлийн жимс';

  @override
  String get schemeSummerBreeze => 'Зуны сэвшээ';

  @override
  String appearanceColorsShowAll(int count) {
    return 'Бүх $count өнгийг харах';
  }

  @override
  String get appearanceColorsHide => 'Өнгийг нуух';

  @override
  String planRepeatMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count сар тутам',
      one: 'Сар бүр',
    );
    return '$_temp0';
  }

  @override
  String planRepeatYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count жил тутам',
      one: 'Жил бүр',
    );
    return '$_temp0';
  }

  @override
  String planEachMonth(String amount) {
    return 'сард $amount';
  }

  @override
  String planEachPay(String amount) {
    return 'цалингийн үе бүрт $amount';
  }

  @override
  String planThisMonth(String amount) {
    return 'энэ сард $amount';
  }

  @override
  String planThisPay(String amount) {
    return 'энэ цалингийн үед $amount';
  }

  @override
  String planPaidFromArchived(String account) {
    return '$account архивлагдсан тул энэ товлогдохгүй';
  }

  @override
  String planEachPayOf(String amount, String name) {
    return 'цалингийн үе бүрт $amount · $name';
  }

  @override
  String planAboutThisMonth(String amount) {
    return 'энэ сард ойролцоогоор $amount';
  }

  @override
  String planAboutThisPay(String amount) {
    return 'энэ цалингийн үед ойролцоогоор $amount';
  }

  @override
  String planStillFor(String amount, String start, String end) {
    return '$start–$end-д $amount оруулах хэрэгтэй хэвээр';
  }

  @override
  String planPlusNext(String amount) {
    return 'дээр нь дараагийнхад ойролцоогоор $amount';
  }

  @override
  String get planNoCarry => 'үлдсэн нь шилжихгүй';

  @override
  String planWentBack(String amount) {
    return 'өмнөх сараас үлдсэн $amount хуваарилаагүй мөнгө рүү буцсан';
  }

  @override
  String planDue(String amount, String date) {
    return '$amount, төлөх өдөр: $date';
  }

  @override
  String planWasDue(String amount, String date) {
    return '$amount, төлөх өдөр өнгөрсөн: $date';
  }

  @override
  String planBy(String amount, String date) {
    return '$amount, эцсийн өдөр: $date';
  }

  @override
  String get planOnTrack => 'хэвийн явж байна';

  @override
  String planShort(String amount) {
    return '$amount дутуу';
  }

  @override
  String planAssignThis(String amount) {
    return '$amount хуваарилах';
  }

  @override
  String get planEditTip => 'Төлөвлөгөөг өөрчлөхийн тулд дарна уу';

  @override
  String planFill(int count, String amount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Төлөвлөснийг хуваарилах · $count ангилалд $amount',
    );
    return '$_temp0';
  }

  @override
  String planFillOver(String amount) {
    return 'Энэ нь байгаа мөнгөнөөс $amount илүү';
  }

  @override
  String get planKeyBank => 'Банк';

  @override
  String get planKeyCash => 'Бэлэн мөнгө';

  @override
  String get planKeyCashBank => 'Бэлэн мөнгө ба банк';

  @override
  String get planKeyAssigned => 'Ангилалд байгаа';

  @override
  String get planKeyNotAssigned => 'Хуваарилаагүй';

  @override
  String get planKeyOver => 'Илүү хуваарилсан';

  @override
  String planFilled(int count, String amount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ангилалд $amount хуваариллаа',
    );
    return '$_temp0';
  }

  @override
  String planSetUndo(String category) {
    return '$category ангиллын төлөвлөгөө';
  }

  @override
  String planRemoveUndo(String category) {
    return '$category ангиллын төлөвлөгөөг арилгалаа';
  }

  @override
  String planWentBackPay(String amount) {
    return 'өмнөх цалингийн үеэс үлдсэн $amount хуваарилаагүй мөнгө рүү буцсан';
  }

  @override
  String planWentBackOn(String amount, String date) {
    return '$date-нд $amount хуваарилаагүй мөнгө рүү буцсан';
  }

  @override
  String planReturns(String amount, String category) {
    return 'Буцсан $amount $category ангилалд эргэж орох тул хуваарилаагүй мөнгө төдий хэмжээгээр буурна';
  }

  @override
  String get planMoneyCurrency => 'Валют';

  @override
  String planOnlyFromOne(String account) {
    return 'зөвхөн $account данснаас';
  }

  @override
  String planOnlyFromSome(int count, int total) {
    return 'зөвхөн $count данснаас (нийт $total)';
  }

  @override
  String planMoneyUndo(String category) {
    return '$category ангиллын данснууд';
  }

  @override
  String planMoneyCurrencyUndo(String category, String symbol) {
    return '$category ангилал одоо $symbol валюттай';
  }

  @override
  String planMoneyChange(String amount) {
    return 'Валютыг өөрчилбөл түүнд хуваарилсан $amount буцаж, төлөвлөгөө нь арилна';
  }

  @override
  String planMoneyChangeAmount(String amount) {
    return 'Валютыг өөрчилбөл түүнд хуваарилсан $amount буцна';
  }

  @override
  String get planMoneyChangePlan => 'Валютыг өөрчилбөл төлөвлөгөө нь арилна';

  @override
  String planMoneyRestOne(
    String held,
    String account,
    String category,
    String rest,
  ) {
    return '$account дансны $held нь $category ангиллынх. Тэнд үлдэх $rest мөнгийг аль ч ангилалд хуваарилж болно.';
  }

  @override
  String planMoneyRestSome(String held, String category, String rest) {
    return 'Эдгээр дансны $held нь $category ангиллынх. Тэнд үлдэх $rest мөнгийг аль ч ангилалд хуваарилж болно.';
  }

  @override
  String get planFromNone => 'ямар ч данс сонгоогүй';

  @override
  String planOtherRows(int count, String amount, String symbol, String other) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$amount ($count мөр) энд тооцогдоогүй (энэ ангилал $symbol валюттай); $other хуваарилаагүй мөнгөнөөс хасагдсан',
    );
    return '$_temp0';
  }

  @override
  String planOffAccount(String amount, String account) {
    return '$account данснаас $amount төлсөн: энэ ангилалд сонгоогүй данс';
  }

  @override
  String planOffAccounts(String amount, int count) {
    return 'Энэ ангилалд сонгоогүй $count данснаас $amount төлсөн';
  }

  @override
  String planBackingOne(String held, String account, String have) {
    return 'Энд $held үлдсэн боловч $account дансанд $have л байна';
  }

  @override
  String planBackingSome(String held, String have) {
    return 'Энд $held үлдсэн боловч данснуудад нь $have л байна';
  }

  @override
  String planBackingShared(String held, int count, String have) {
    return 'Ижил дансанд хадгалдаг $count ангилалд $held үлдсэн боловч тэдгээр дансанд $have л байна';
  }

  @override
  String get planEdit => 'Засах';

  @override
  String get planEditName => 'Нэр';

  @override
  String get planDueDateQ => 'Төлөх өдөр бий юу?';

  @override
  String get planDueNoMeans => 'Сар бүр зарцуулдаг тогтмол дүн, жишээ нь хүнс.';

  @override
  String get planDueNoMeansPay =>
      'Цалингийн үе бүр зарцуулдаг тогтмол дүн, жишээ нь хүнс.';

  @override
  String get planDueYesMeans =>
      'Тодорхой өдөр гэхэд бэлэн байх дүн, жишээ нь түрээс, даатгал.';

  @override
  String get planNo => 'Үгүй';

  @override
  String get planYes => 'Тийм';

  @override
  String get planSetAsideMonth => 'Сар бүр хуримтлуулах';

  @override
  String get planSetAsidePay => 'Цалингийн үе бүрт хуримтлуулах';

  @override
  String get planNothingSet => 'тогтоогоогүй';

  @override
  String get planEmptyHint => 'Хоосон үлдээвэл сар бүр өөрөө шийднэ.';

  @override
  String get planEmptyHintPay =>
      'Хоосон үлдээвэл цалингийн үе бүрт өөрөө шийднэ.';

  @override
  String get planLeftMonthEnd => 'Сарын эцэст үлдсэн нь';

  @override
  String get planLeftPeriodEnd => 'Үеийн эцэст үлдсэн нь';

  @override
  String get planStaysHere => 'Энд үлдэнэ';

  @override
  String get planGoesBack => 'Хуваарилаагүй мөнгө рүү буцна';

  @override
  String get planStopAt => 'Дээд хэмжээ';

  @override
  String get planNoLimit => 'хязгааргүй';

  @override
  String get planStopAtHint => 'Энэ хэмжээнд хүрмэгц асуухаа болино.';

  @override
  String get planAmountDue => 'Төлөх дүн';

  @override
  String get planLabelDueDate => 'Төлөх өдөр';

  @override
  String get planHowOften => 'Давтамж';

  @override
  String get planOnce => 'Нэг удаа';

  @override
  String planRepeatDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count өдөр тутам',
      one: 'Өдөр бүр',
    );
    return '$_temp0';
  }

  @override
  String planRepeatWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count долоо хоног тутам',
      one: 'Долоо хоног бүр',
    );
    return '$_temp0';
  }

  @override
  String get planEveryPayday => 'Цалин бүрт';

  @override
  String planEveryPaydayOf(String name) {
    return 'Цалин бүрт · $name';
  }

  @override
  String get planEveryPayPeriod => 'Цалингийн үе бүрт';

  @override
  String planEveryPayPeriodOf(String name) {
    return 'Цалингийн үе бүрт · $name';
  }

  @override
  String get planEveryCustom => 'Өөрөө тохируулах…';

  @override
  String get planCustomOn => 'Өөрөө тохируулсан';

  @override
  String get planRepeatEvery => 'Давтамж';

  @override
  String get planOnWeekdays => 'Гарагууд';

  @override
  String get planWeekdaysHint =>
      'Өдрүүдээ сонгоно уу; сонгоогүй бол огнооны гараг.';

  @override
  String get planOnLabel => 'Өдөр';

  @override
  String get planDayOfMonth => 'Сарын өдрөөр';

  @override
  String get planAWeekday => 'Гарагаар';

  @override
  String get planNthFirst => 'эхний';

  @override
  String get planNthSecond => '2 дахь';

  @override
  String get planNthThird => '3 дахь';

  @override
  String get planNthFourth => '4 дэх';

  @override
  String get planNthLast => 'сүүлийн';

  @override
  String get planWeekdayNames => 'Даваа|Мягмар|Лхагва|Пүрэв|Баасан|Бямба|Ням';

  @override
  String get planEnds => 'Дуусах';

  @override
  String get planEndsNever => 'Хэзээ ч';

  @override
  String get planEndsOn => 'Өдрөөр';

  @override
  String get planEndsAfter => 'Тоогоор';

  @override
  String get planEndsTimes => 'удаагийн дараа';

  @override
  String get planEndDateHint => 'ЖЖЖЖ.СС.ӨӨ';

  @override
  String planEnded(String amount, String date) {
    return '$amount · $date-нд дууссан';
  }

  @override
  String get planOnDates => 'Эдгээр өдрүүдэд…';

  @override
  String get planUnitDays => 'өдөр';

  @override
  String get planUnitWeeks => 'долоо хоног';

  @override
  String get planUnitMonths => 'сар';

  @override
  String get planUnitYears => 'жил';

  @override
  String get planDatesLabel => 'Өдрүүд';

  @override
  String get planDatesHint => '04.15, 06.15, 09.15, 01.15';

  @override
  String planDatesAYear(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'жилд $count удаа',
      zero: 'Эдгээр өдрүүдэд',
    );
    return '$_temp0';
  }

  @override
  String get planDaysAfterPay => 'өдрийн дараа (цалин орсноос)';

  @override
  String get planOnPayday => 'цалин орох өдөр';

  @override
  String get planWeekendKeep => 'Тэр өдөртөө';

  @override
  String get planWeekendBefore => 'Амралтын өдрөөс өмнө';

  @override
  String get planWeekendAfter => 'Амралтын өдрийн дараа';

  @override
  String planPaidFromHint(String account, String date) {
    return '$account дансны таамаглалд $date-нд харагдана; төлөгдсөн үед нь та баталгаажуулна.';
  }

  @override
  String get planPaidFromHintNone =>
      'Нэг л данс сонгоотой үлдээвэл төлбөр тэр дансны таамаглалд харагдана.';

  @override
  String planWorkedOut(String amount) {
    return '$amount · өдрөөс тооцсон';
  }

  @override
  String get planEnterAmountDate => 'Дүн болон өдрөө оруулна уу';

  @override
  String get planNothingMore => 'өөр хуримтлуулах зүйлгүй';

  @override
  String get planRowWillRead => 'Мөр ингэж харагдана';

  @override
  String get planLabelPaidFrom => 'Төлөх данс';

  @override
  String planUpTo(String amount) {
    return '$amount хүртэл';
  }

  @override
  String planSetAsideAmount(String amount) {
    return '$amount хуримтлагдсан';
  }

  @override
  String planEditedUndo(String category) {
    return '$category ангиллын өөрчлөлт';
  }

  @override
  String get planAccountsAll => 'Бүх данс';

  @override
  String get planAccountsNone => 'Данс сонгоогүй';

  @override
  String planAccountsSome(int count, int total) {
    return '$total данснаас $count';
  }

  @override
  String get setupCurrencySearch => 'Валют хайх';

  @override
  String get setupCurrencyNoMatch => 'Ийм нэртэй валют алга';

  @override
  String get ledgerIncome => 'Орлого';

  @override
  String payStopped(String name) {
    return '$name (зогссон)';
  }

  @override
  String planIncomeLine(String amounts) {
    return 'Орлого: $amounts';
  }

  @override
  String get rowsNewCategoryRefundNote =>
      'шинэ ангилал · орсон мөнгө буцаалтад тооцогдоно; цалин бол Орлого-г сонгоно';

  @override
  String ledgerPayReplaced(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'гараар товлосон $count орлогыг орлууллаа',
      one: 'гараар товлосон орлогыг орлууллаа',
    );
    return '$_temp0';
  }

  @override
  String get setupYourAccounts => 'Таны дансууд';

  @override
  String get setupAddTracked => 'Хөтлөхийг хүсэж байгаа дансуудаа нэмээрэй.';

  @override
  String get setupNeverConnects =>
      'BetterBudget таны банктай хэзээ ч холбогдохгүй. Банкны апп дээр харагдаж байгаа дүнг та өөрөө оруулна.';

  @override
  String get setupBalancesAsOf => 'Үлдэгдлийн огноо';

  @override
  String get setupDateChanged => 'Үлдэгдлийн огноо өөрчлөгдлөө';

  @override
  String get setupOwedTodayHint =>
      'Өнөөдөр хийсэн, банк хараахан харуулаагүй гүйлгээ энэ дүнд ороогүй.';

  @override
  String get setupEverydayQ => 'Өдөр тутмын зардлаа юугаар төлдөг вэ?';

  @override
  String get setupEverydayBank => 'Картаар, QR-аар эсвэл шилжүүлгээр';

  @override
  String get setupEverydayBoth => 'Аль алинаар нь';

  @override
  String get setupNoCashWarning =>
      'Танд бэлэн мөнгөний данс алга. АТМ-аас авсан мөнгө авсан өдрөө зарцуулсан мэт харагдаж, түрийвчин дэх бэлэн мөнгө тоологдохгүй.';

  @override
  String get setupAddCashAccount => 'Бэлэн мөнгөний данс нэмэх';

  @override
  String get setupOpenLedger => 'Дэвтрээ нээх';

  @override
  String setupRemoveAccount(String name) {
    return 'Хасах: $name';
  }

  @override
  String get setupEverydayCash => 'Бэлнээр';

  @override
  String setupStartCashHint(String zero) {
    return 'Түрийвчиндээ одоо байгаа мөнгөө тоолоорой · хоосон бол $zero-оос эхэлнэ';
  }

  @override
  String get setupFinished => 'Тохиргоо дууслаа';

  @override
  String get setupStepAccounts => 'Дансууд';

  @override
  String get setupStepPay => 'Цалин';

  @override
  String get setupContinue => 'Үргэлжлүүлэх';

  @override
  String get setupBack => 'Буцах';

  @override
  String get setupPayArrives =>
      'Дансанд орж ирдэг дүн буюу гар дээр авдаг цалин; татвар, НДШ суутгахаас өмнөх цалин биш. Банк дараа нь татдаг зээлийн төлбөр бол тусдаа төлбөр.';

  @override
  String get setupPayNeedsAccount =>
      'Цалин банкны данс эсвэл бэлэн мөнгөний дансанд орно. Цалингаа тохируулахын тулд «Дансууд» алхамд нэгийг нэмээрэй.';

  @override
  String get setupNoRegularPayLine => 'Тогтмол цалингүй';

  @override
  String phoneLeftIn(String month) {
    return 'Үлдсэн · $month';
  }

  @override
  String phoneFromMacToday(String time) {
    return 'Компьютероос өнөөдөр $time';
  }

  @override
  String phoneFromMacOn(String date, String time) {
    return 'Компьютероос $date $time';
  }

  @override
  String phoneWaiting(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Таны $count гүйлгээ компьютерийг хүлээж байна',
    );
    return '$_temp0';
  }

  @override
  String get phoneWaitingTitle => 'Компьютерийг хүлээж байна';

  @override
  String phoneOwed(String amount) {
    return 'Өр $amount';
  }

  @override
  String phoneLeftNow(String left) {
    return 'Одоо $left үлдсэн';
  }

  @override
  String phoneLeftAfter(String left, String after) {
    return 'Одоо $left үлдсэн · үүний дараа $after';
  }

  @override
  String get phoneEnterAmount => 'Дүн оруулна уу';

  @override
  String get phoneEnterPayee => 'Харилцагч оруулна уу';

  @override
  String get phoneDeleteDigit => 'Сүүлийн цифрийг устгах';

  @override
  String get ledgerFolderLabel => 'Хадгалагдаж буй газар';

  @override
  String get ledgerFolderChoose => 'Дэвтрээ хавтас руу зөөх…';

  @override
  String get ledgerFolderPickButton => 'Энд зөөх';

  @override
  String get ledgerFolderNote =>
      'Google Drive, OneDrive, Box эсвэл Dropbox-ын энэ компьютер дээрх хавтас руу зөөвөл дэвтэр тань тэнд шифрлэгдэн хадгалагдаж, өөрчлөлт бүрийн дараа дахин хадгалагдана.';

  @override
  String ledgerFolderCopied(String folder, String when) {
    return '$folder · $when';
  }

  @override
  String ledgerFolderFailing(String folder, String when) {
    return '$folder · хуулж чадсангүй · сүүлийнх нь $when';
  }

  @override
  String ledgerFolderFailingNone(String folder) {
    return '$folder · хуулж чадсангүй';
  }

  @override
  String get ledgerFolderChange => 'Өөр хавтас руу зөөх…';

  @override
  String get ledgerFolderStop => 'Энэ компьютер руу буцааж зөөх';

  @override
  String ledgerFolderKept(String folder) {
    return 'Дэвтэр тань $folder хавтас руу зөөгдлөө';
  }

  @override
  String ledgerFolderStopped(String folder) {
    return 'Дэвтэр тань энэ компьютерт буцаж ирлээ · $folder доторх файл тэндээ үлдэнэ';
  }

  @override
  String get ledgerFolderCouldnt => 'Тэр хавтас руу зөөж чадсангүй';

  @override
  String get ledgerFolderHere => 'Энэ компьютер';

  @override
  String get phoneKeyTitle => 'Сэргээх түлхүүрээ оруулна уу';

  @override
  String get phoneKeyBody =>
      'Дэвтрээ компьютер дээрээ үүсгэх үед танд харуулсан 25 тэмдэгт. Энэ утас дэвтрийг тань уншихын тулд нэг удаа хэрэгтэй.';

  @override
  String get phoneFolderTitle => 'Таны дэвтэр хаана байна вэ?';

  @override
  String get phoneFolderBody =>
      'Компьютер дээрээ дэвтрээ зөөсөн хавтсыг сонгоно уу. Тэндхийн Тохиргооны «Хадгалагдаж буй газар» мөрөнд нэр нь бий.';

  @override
  String get phoneFolderChoose => 'Хавтас сонгох';

  @override
  String get phoneNoLedger => 'Тэр хавтаст дэвтэр алга';

  @override
  String phoneNoLedgerBody(String file) {
    return 'Хавтаст $file нэртэй файл байх ёстой. Компьютер тань хадгалснаас хойш ирэхэд нэг минут орчим болж магадгүй.';
  }

  @override
  String get phoneKeyDoesntOpen =>
      'Тэр сэргээх түлхүүр энэ хавтас дахь дэвтрийг нээхгүй байна';

  @override
  String get phoneEnterKeyAgain => 'Түлхүүрийг дахин оруулах';

  @override
  String get phoneCantRead => 'Энэ хавтас дахь дэвтрийг уншиж чадсангүй';

  @override
  String get phoneCantReadBody =>
      'Үүнийг энэ утсан дээрхээс шинэ BetterBudget хадгалсан байж магадгүй.';

  @override
  String get phoneTryAgain => 'Дахин оролдох';

  @override
  String get phoneChooseAnother => 'Өөр хавтас сонгох';

  @override
  String get ledgerFolderAlert => 'Дэвтрийг тань хавтсанд нь хадгалж чадсангүй';

  @override
  String phoneLeftUntil(String date) {
    return '$date хүртэл үлдсэн';
  }

  @override
  String phoneDue(String date) {
    return 'Төлөх өдөр $date';
  }

  @override
  String phoneOverNow(String over) {
    return '$over-өөр хэтэрсэн';
  }

  @override
  String phoneOverAfter(String left, String over) {
    return 'Одоо $left үлдсэн · үүний дараа $over-өөр хэтэрнэ';
  }

  @override
  String phoneOverBoth(String over, String after) {
    return '$over-өөр хэтэрсэн · үүний дараа $after-өөр';
  }

  @override
  String get phoneChooseAccount => 'Данс сонгоно уу';

  @override
  String get phoneMoveToAccount => 'Өөр данс руу шилжүүлэх';

  @override
  String phoneTransferTo(String account) {
    return '→ $account';
  }

  @override
  String get phoneFrom => 'Шилжүүлэх данс';

  @override
  String phoneTransferAfter(String account, String amount) {
    return '$account · үүний дараа $amount';
  }

  @override
  String phoneTransferOwedAfter(String account, String amount) {
    return '$account · үүний дараа $amount өртэй';
  }

  @override
  String phoneSavedTransfer(String from, String to, String amount) {
    return 'Хадгаллаа · $from → $to $amount';
  }

  @override
  String phoneTransferNow(String account, String amount) {
    return '$account · одоо $amount';
  }

  @override
  String phoneTransferOwedNow(String account, String amount) {
    return '$account · одоо $amount өртэй';
  }

  @override
  String phoneTransferTitle(String from, String to) {
    return '$from → $to';
  }

  @override
  String phoneInCredit(String amount) {
    return '$amount илүү төлсөн';
  }

  @override
  String get phoneBills => 'Төлбөрүүд';

  @override
  String get phoneNewCategory => '+ Шинэ ангилал';

  @override
  String get phoneNewCategoryTitle => 'Шинэ ангилал';

  @override
  String get phoneChooseCategory => 'Ангилал сонгоно уу';

  @override
  String get phoneNothingAssigned => 'Одоогоор мөнгө хуваарилаагүй';

  @override
  String phoneSaved(String payee, String amount) {
    return 'Хадгаллаа · $payee $amount';
  }

  @override
  String phoneWaitingCategories(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count шинэ ангилал компьютерийг хүлээж байна',
    );
    return '$_temp0';
  }

  @override
  String phoneWaitingBoth(int entries, int categories) {
    return 'Таны $entries гүйлгээ, $categories шинэ ангилал компьютерийг хүлээж байна';
  }

  @override
  String phoneDeleteCategory(int count, String name, String amount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$name ангилал болон доторх $count гүйлгээг ($amount) устгах уу?',
    );
    return '$_temp0';
  }

  @override
  String get phoneClear => 'Цэвэрлэх';

  @override
  String phoneSavedLeft(String category, String left) {
    return '$category · $left үлдсэн';
  }

  @override
  String phoneSavedOver(String category, String over) {
    return '$category · $over хэтэрсэн';
  }

  @override
  String phoneSavedNothingAssigned(String category) {
    return '$category · одоогоор мөнгө хуваарилаагүй';
  }

  @override
  String ledgerFromPhone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Утаснаас $count гүйлгээ',
    );
    return '$_temp0';
  }

  @override
  String ledgerCategoryFromPhone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Утаснаас $count шинэ ангилал',
    );
    return '$_temp0';
  }

  @override
  String ledgerEditCategory(String name) {
    return 'Засах: $name';
  }

  @override
  String phoneOverThenLeft(String over, String after) {
    return '$over-өөр хэтэрсэн · үүний дараа $after үлдэнэ';
  }

  @override
  String get phoneToMoneyIn => 'Орлого болгох';

  @override
  String get phoneIncomeNeedsMoneyIn =>
      'Орлого бүртгэхийн тулд эхлээд дүнгийн хажуугийн +/− товчийг дарна уу.';

  @override
  String get phoneToMoneyOut => 'Зарлага болгох';

  @override
  String ledgerFolderOpenedFrom(String computer) {
    return '$computer дээр хадгалсан дэвтрийг нээлээ';
  }

  @override
  String get ledgerFolderOpened =>
      'Өөр компьютер дээр хадгалсан дэвтрийг нээлээ';

  @override
  String ledgerCombinedFrom(int count, String computer) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$computer компьютерээс $count гүйлгээ',
    );
    return '$_temp0';
  }

  @override
  String ledgerCombinedMoreFrom(int count, String computer) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$computer компьютерээс $count гүйлгээ болон бусад өөрчлөлт',
    );
    return '$_temp0';
  }

  @override
  String ledgerCombinedOtherFrom(String computer) {
    return '$computer компьютерээс орсон өөрчлөлт';
  }

  @override
  String ledgerCombined(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Өөр компьютерээс $count гүйлгээ',
    );
    return '$_temp0';
  }

  @override
  String ledgerCombinedMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Өөр компьютерээс $count гүйлгээ болон бусад өөрчлөлт',
    );
    return '$_temp0';
  }

  @override
  String get ledgerCombinedOther => 'Өөр компьютерээс орсон өөрчлөлт';

  @override
  String ledgerCombinedAlike(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count нь энд байгаа гүйлгээтэй адилхан харагдаж байна',
    );
    return '$_temp0';
  }

  @override
  String ledgerCombinedOverAssigned(String amount) {
    return 'Байгаа мөнгөнөөс илүү хуваарилсан: $amount';
  }

  @override
  String ledgerFolderCouldntOpen(String folder) {
    return '$folder доторх дэвтрийг нээж чадсангүй · юу ч өөрчлөгдөөгүй';
  }

  @override
  String ledgerFolderArriving(String folder) {
    return '$folder · тэнд байгаа дэвтрийг одоохондоо уншиж чадахгүй байна';
  }

  @override
  String ledgerFolderNewerAppLine(String folder) {
    return '$folder · BetterBudget-ийн шинэ хувилбараар хадгалсан · энэ компьютер дээрх BetterBudget-ээ шинэчилнэ үү';
  }

  @override
  String ledgerFolderApart(String folder) {
    return '$folder · өөр компьютер дээр бас өөрчлөгдсөн · энэ компьютерийн өөрчлөлт хавтсанд ороогүй';
  }

  @override
  String get ledgerFolderChooseWhich => 'Алийг нь үлдээхээ сонгох…';

  @override
  String get ledgerFolderApartAlert =>
      'Дэвтэр тань хоёр компьютер дээр өөрчлөгдсөн';

  @override
  String get ledgerTwoTitle => 'Дэвтэр тань хоёр компьютер дээр өөрчлөгдсөн';

  @override
  String get ledgerTwoTitleFolder => 'Энэ хавтсанд дэвтэр аль хэдийн байна';

  @override
  String ledgerTwoBody(String folder) {
    return '$folder доторх дэвтэрт энэ компьютерт байхгүй өөрчлөлт байна, энэ компьютерт ч хавтсанд байхгүй өөрчлөлт байна. BetterBudget энэ хоёрыг нэгтгэж чадахгүй тул алийг нь үлдээхээ сонгоно уу. Нөгөөх нь эхлээд хадгалагдах ба Тохиргооны «Нөөцөөс сэргээх…» түүнийг буцааж авчирна. Таныг сонгох хүртэл энэ компьютерийн өөрчлөлт болон утасны гүйлгээнүүд хавтсанд орохгүй.';
  }

  @override
  String get ledgerTwoInFolder => 'Хавтсанд';

  @override
  String get ledgerTwoHere => 'Энэ компьютерт';

  @override
  String ledgerTwoSavedOn(String computer, String when) {
    return '$computer дээр хадгалсан · $when';
  }

  @override
  String ledgerTwoSavedWhen(String when) {
    return 'Өөр компьютер дээр хадгалсан · $when';
  }

  @override
  String get ledgerTwoNotNow => 'Одоо биш';

  @override
  String get ledgerTwoUseMine => 'Энэ компьютерийн дэвтрийг үлдээх';

  @override
  String get ledgerTwoUseFolder => 'Хавтсан дахь дэвтрийг үлдээх';

  @override
  String ledgerFolderKeptMine(String folder) {
    return 'Энэ компьютерийн дэвтэр одоо $folder хавтсанд байна · тэнд байсан нь Нөөц хуулбарт хадгалагдсан';
  }

  @override
  String get ledgerFolderUnreadableTitle =>
      'Энэ хавтсан дахь дэвтрийг нээж чадахгүй байна';

  @override
  String ledgerFolderUnreadableBody(String folder) {
    return '$folder хавтсанд энэ компьютер нээж чадахгүй дэвтэр байна. Өөр дэвтэр байж магадгүй, эсвэл бүрэн ирж амжаагүй байж болно.';
  }

  @override
  String get ledgerFolderUnreadableKept =>
      'Хэрэв солих бол түүнийг эхлээд энэ компьютерт хадгална. «Нөөцөөс сэргээх…» түүнийг өөрийнх нь сэргээх түлхүүрээр нээнэ.';

  @override
  String get ledgerFolderReplace => 'Солих';

  @override
  String get ledgerFolderNewerApp =>
      'Тэр хавтсан дахь дэвтрийг BetterBudget-ийн шинэ хувилбараар хадгалсан · эхлээд энэ компьютер дээрх BetterBudget-ээ шинэчилнэ үү';

  @override
  String ledgerRestoreKeepOnFolder(String folder) {
    return '$folder доторх дэвтрийг хуваалцах';
  }

  @override
  String ledgerRestoreKeepOnFolderNote(String folder) {
    return 'Энд өөрчилсөн зүйл тань $folder руу очиж, өөр компьютер дээр өөрчилсөн зүйл энд ирнэ.';
  }

  @override
  String get ledgerUseThisFolder => 'Энэ хавтсыг ашиглах';

  @override
  String ledgerRestoredOnFolder(String folder) {
    return 'Энэ компьютер одоо $folder доторх дэвтэр дээр байна';
  }

  @override
  String ledgerRestoredNotOnFolder(String folder) {
    return 'Дэвтэр тань энд байна, гэхдээ энэ компьютер $folder дээр биш · Тохиргооноос «Дэвтрээ хавтас руу зөөх…»-ийг ашиглана уу';
  }

  @override
  String ledgerRestoreNotKeptNote(String folder) {
    return 'Энэ компьютер өөрийн хуулбартай болно. Энд өөрчилсөн зүйл тань $folder руу очихгүй.';
  }

  @override
  String get ledgerRestoreMacAsks =>
      'Mac тань дараа нь хавтсыг асууна: «Энэ хавтсыг ашиглах» товчийг дарна уу.';

  @override
  String get ledgerBringLedgerTitle => 'Энэ дэвтрийг энд авчрах уу?';

  @override
  String get ledgerLastChanged => 'Сүүлд өөрчилсөн';

  @override
  String get ledgerBringLedgerNote =>
      'Энд байгаа бүх зүйлийг энэ дэвтрээр солино. Одоо байгаа өгөгдөл тань эхлээд хадгалагдах ба Буцаах нь түүнийг эргүүлж авчирна.';

  @override
  String get startWhereTitle => 'Дэвтэр тань хаана байна вэ?';

  @override
  String get startWhereFolder => 'Google Drive зэрэг хавтсанд';

  @override
  String get startWhereFolderNote =>
      'Энэ компьютер тэнд байгаа дэвтрийг хуваалцана.';

  @override
  String get startWhereBackup => 'Нөөц хуулбарт';

  @override
  String get startWhereBackupNote =>
      'Тохиргооны «Нөөцлөх…» товчоор хадгалсан хуулбар.';

  @override
  String ledgerFolderWrongKey(String folder) {
    return 'Сэргээх түлхүүр тань $folder доторх дэвтрийг нээхгүй байна';
  }

  @override
  String ledgerFolderNoLedger(String folder) {
    return '$folder дотор дэвтэр алга · Ledger.betterbudget байгаа хавтсыг сонгоно уу. Хэрэв энэ компьютерт хуулагдаж дуусаагүй бол минутын дараа дахин оролдоно уу.';
  }

  @override
  String get startHowTitle => 'Хэрхэн эхлэх вэ?';

  @override
  String get startFresh => 'Шинээр эхлэх';

  @override
  String get startFreshNote =>
      'Манай өрх BetterBudget-ийг анх удаа ашиглаж байна.';

  @override
  String get startRestore => 'Нөөц хуулбараас сэргээх';

  @override
  String get startRestoreNote =>
      'Надад Тохиргооны «Нөөцлөх…» товчоор хадгалсан нөөц файл бий. Энэ компьютер өөрийн хуулбартай болно.';

  @override
  String get startOpen => 'Дэвтэр нээх';

  @override
  String get startOpenNote =>
      'Манай өрх BetterBudget-ийг өөр компьютер дээр аль хэдийн ашигладаг, дэвтэр нь Google Drive зэрэг хавтсанд байгаа. Энэ компьютер түүнийг хуваалцана.';

  @override
  String get startKeyLabel => 'Сэргээх түлхүүр';

  @override
  String get startChooseFolder => 'Хавтас сонгох…';

  @override
  String get startChooseBackup => 'Нөөц хуулбар сонгох…';

  @override
  String get startKeyHint =>
      'BetterBudget-ийг анх тохируулахад харуулсан түлхүүр. Хадгалсан бол «BetterBudget recovery key.txt» файлд бий.';

  @override
  String startKeyWrongFolder(String folder) {
    return 'Тэр түлхүүр $folder доторх дэвтрийг нээхгүй байна. Хавтас энэ компьютерт хуулагдаж дуусаагүй бол минутын дараа дахин оролдоно уу.';
  }

  @override
  String get ledgerSectionPayees => 'Харилцагчид';

  @override
  String get payeesColumnPayee => 'Харилцагч';

  @override
  String get payeesColumnAccounts => 'Данс';

  @override
  String get payeesDelete => 'Устгах';

  @override
  String payeesDeletedMessage(String category) {
    return 'Устгалаа · энэ харилцагчийн шинэ мөр цаашид $category ангилалд өөрөө орохгүй';
  }

  @override
  String get payeesAdd => 'Харилцагч нэмэх';

  @override
  String get payeesWordsLabel => 'Харилцагч, эсвэл нэрэнд нь орсон үг';

  @override
  String get payeesWhere => 'Хаана';

  @override
  String get payeesAtStart => 'Харилцагчийн нэрийн эхэнд';

  @override
  String get payeesAnywhere =>
      'Харилцагчийн нэр эсвэл гүйлгээний утгын аль ч хэсэгт';

  @override
  String payeesStartsWith(String name) {
    return '«$name» гэж эхэлсэн';
  }

  @override
  String payeesHasAnywhere(String name) {
    return '«$name» гэсэн үг орсон';
  }

  @override
  String payeesFitsStarts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count мөр ингэж эхэлж байна',
      zero: 'Ингэж эхэлсэн мөр хараахан алга',
    );
    return '$_temp0';
  }

  @override
  String payeesFitsAnywhere(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count мөрд энэ үг орсон байна',
      zero: 'Энэ үг орсон мөр хараахан алга',
    );
    return '$_temp0';
  }

  @override
  String payeesWaiting(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count нь Ангилаагүй хэвээр',
    );
    return '$_temp0';
  }

  @override
  String payeesElsewhere(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count нь өөр ангилалд',
    );
    return '$_temp0';
  }

  @override
  String get payeesHowRowReads => 'Мөр ингэж харагдана';

  @override
  String get payeesNeedsWords => 'Харилцагч, эсвэл нэрэнд нь орсон үг бичнэ үү';

  @override
  String get payeesNeedsCategory => 'Ангилал сонгоно уу';

  @override
  String get payeesNeedsAccount => 'Данс сонгоно уу';

  @override
  String get payeesEmpty =>
      'Санасан зүйл хараахан алга. Дэвтрийн мөрд ангилал сонгоход доорх цонх «Дараагийн удаад санах» гэж санал болгоно; эсвэл энд харилцагч нэмнэ үү.';

  @override
  String get payeesColumnFiled => 'Ангилал';

  @override
  String get payeesDeleted => 'Устгалаа';

  @override
  String payeesFiled(int count, String category) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count мөрийг $category гэж ангиллаа',
    );
    return '$_temp0';
  }

  @override
  String payeesFileWaiting(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ангилаагүй үлдсэн $count мөрийг ангилах',
    );
    return '$_temp0';
  }

  @override
  String payeesAlreadyListed(String payee, String category) {
    return '«$payee» жагсаалтад аль хэдийн байна, $category гэж';
  }

  @override
  String payeesAlreadyIn(int count, String category) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count нь аль хэдийн $category ангилалд',
    );
    return '$_temp0';
  }

  @override
  String payeesAnywhereWould(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count мөрд энэ үг орсон байна',
    );
    return '$_temp0';
  }

  @override
  String get payeesCategoryGone => 'Устгасан ангилал';

  @override
  String ledgerRowsTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count зүйл хоёр компьютер дээр өөрчлөгдсөн',
    );
    return '$_temp0';
  }

  @override
  String ledgerRowsBody(String computer) {
    return 'Тус бүрээс аль нэгийг нь сонгоно уу. $computer-ийн бусад өөрчлөлт таны сонголтын хамт орно. Үлдээгээгүй нь Нөөцөд хадгалагдана. Сонгох хүртэл энэ компьютерийн өөрчлөлт болон утасны бичилтүүд хавтсанд орохгүй.';
  }

  @override
  String get ledgerRowsThisComputer => 'Энэ компьютер';

  @override
  String get ledgerRowsOtherComputer => 'Нөгөө компьютер';

  @override
  String get ledgerRowsKeepHere => 'Энэ компьютерийнхийг үлдээх';

  @override
  String ledgerRowsKeepTheirs(String computer) {
    return '$computer-ийнхийг үлдээх';
  }

  @override
  String get ledgerRowsKeepDeletedHere => 'Устгасан хэвээр нь үлдээх';

  @override
  String ledgerRowsKeepDeletedTheirs(String computer) {
    return 'Устгасан хэвээр нь үлдээх ($computer-ийнх)';
  }

  @override
  String get ledgerRowsKeepNeither => 'Аль нь ч биш, урьдынхаар';

  @override
  String get ledgerRowsSave => 'Сонголтоо хадгалах';

  @override
  String ledgerRowsAssigned(String category, String date) {
    return '$category · Оноосон, $date-аас эхлэх үе';
  }

  @override
  String get ledgerRowsDeleted => 'Устгасан';

  @override
  String get ledgerRowsNoPayee => 'Хүлээн авагчгүй';

  @override
  String ledgerRowsAsItWas(String what) {
    return 'Урьд нь: $what';
  }

  @override
  String ledgerRowsSaved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count сонголт хадгалагдлаа',
    );
    return '$_temp0';
  }

  @override
  String get ledgerRowsChangedMeanwhile =>
      'Сонгож байх хооронд энэ компьютер дээр ямар нэг зүйл өөрчлөгдсөн тул юу ч хадгалагдсангүй. Танаас дахин асууна.';

  @override
  String get rowsColumnSource => 'Эх сурвалж';

  @override
  String sourceTypedOn(String computer) {
    return '$computer дээр оруулсан';
  }

  @override
  String get sourceTyped => 'Оруулсан';

  @override
  String sourceImportedOn(String computer) {
    return '$computer дээр импортолсон';
  }

  @override
  String get sourceImported => 'Импортолсон';

  @override
  String sourcePhone(String phone) {
    return '$phone-оос';
  }

  @override
  String get sourceYourPhone => 'Таны утсаас';

  @override
  String sourcePhoneId(String id) {
    return '$id утсаас';
  }

  @override
  String get sourceScheduled => 'Хуваарьт';

  @override
  String get settingsRegisterTitle => 'Бүртгэл';

  @override
  String get settingsSourceColumn => 'Гүйлгээ бүр хаанаас ирснийг харуулах';

  @override
  String get settingsPhonesTitle => 'Таны утаснууд';

  @override
  String settingsPhoneName(String id) {
    return '$id утасны нэр';
  }

  @override
  String get settingsPhoneNameHint => 'Жишээ нь, Pixel';

  @override
  String get sourceTypedHere => 'Энд оруулсан';

  @override
  String get sourceImportedHere => 'Энд импортолсон';

  @override
  String get sourceTypedElsewhere => 'Өөр компьютер дээр оруулсан';

  @override
  String get sourceImportedElsewhere => 'Өөр компьютер дээр импортолсон';

  @override
  String get settingsComputersTitle => 'Таны компьютерууд';

  @override
  String get settingsComputerThis => 'Энэ компьютерийн нэр';

  @override
  String settingsComputerName(String id) {
    return '$id компьютерийн нэр';
  }
}
