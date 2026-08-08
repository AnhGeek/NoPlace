// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Vietnamese (`vi`).
class AppL10nVi extends AppL10n {
  AppL10nVi([String locale = 'vi']) : super(locale);

  @override
  String get appName => 'NoPlace';

  @override
  String get navMap => 'Bản đồ';

  @override
  String get navLogs => 'Nhật ký';

  @override
  String get navQuests => 'Nhiệm vụ';

  @override
  String get navProfile => 'Cá nhân';

  @override
  String get commonLocked => 'Chưa mở';

  @override
  String get commonHidden => '???';

  @override
  String get commonNotNow => 'Để sau';

  @override
  String get commonSearch => 'Tìm kiếm';

  @override
  String get commonGotIt => 'Đã hiểu';

  @override
  String commonXp(int xp) {
    return '+$xp XP';
  }

  @override
  String commonDistanceMeters(int meters) {
    return '$meters m';
  }

  @override
  String commonDistanceKilometers(String kilometers) {
    return '$kilometers km';
  }

  @override
  String commonAreaSquareKilometers(String value) {
    return '$value km²';
  }

  @override
  String commonDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ngày',
    );
    return '$_temp0';
  }

  @override
  String get mapTabCity => 'THÀNH PHỐ';

  @override
  String get mapTabNearby => 'GẦN ĐÂY';

  @override
  String get mapSearchHint => 'Tìm địa điểm…';

  @override
  String mapYouAreHere(String place) {
    return 'Bạn đang ở · $place';
  }

  @override
  String mapNearbyTitle(String place) {
    return 'Bạn đang ở gần $place';
  }

  @override
  String mapNearbyMeta(String distance, String visited, int xp) {
    String _temp0 = intl.Intl.selectLogic(visited, {
      'never': 'chưa từng ghé',
      'other': 'đã từng ghé',
    });
    return 'Cách $distance · $_temp0 · +$xp XP';
  }

  @override
  String mapNearbyVisitedName(String place) {
    return '$place · đã ghé';
  }

  @override
  String get mapNearbyWrongPlace => 'Không đúng chỗ? Chạm để đổi ›';

  @override
  String get mapCheckIn => 'Điểm danh';

  @override
  String get logsTitle => 'Nhật ký khám phá';

  @override
  String logsDistrictCount(int charted, int total) {
    return '$charted / $total quận';
  }

  @override
  String get logsSegmentDistricts => 'Khu vực';

  @override
  String get logsSegmentQuests => 'Nhiệm vụ';

  @override
  String logsEntryDistrictCharted(String day, int percent) {
    return 'Lần đầu đến $day · đã mở $percent%';
  }

  @override
  String logsEntryCheckedInToday(String time) {
    return 'Điểm danh hôm nay, $time';
  }

  @override
  String logsEntryWithinQuestRadius(String distance) {
    return 'Cách $distance · trong bán kính nhiệm vụ';
  }

  @override
  String get logsEntryLocked => 'Chưa mở · hãy đến đó để khám phá';

  @override
  String get logsUnknownSite => 'Địa điểm lạ';

  @override
  String get logsEmpty =>
      'Chưa có gì trong nhật ký. Ra ngoài đi rồi bản đồ sẽ sáng dần.';

  @override
  String get questsTitle => 'Nhiệm vụ';

  @override
  String questsActiveCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count đang làm',
    );
    return '$_temp0';
  }

  @override
  String get questsWeeklyChallenge => 'Thử thách tuần';

  @override
  String questsWeeklyChallengeGoal(int target, int done) {
    return 'Khám phá $target địa điểm lạ · xong $done/$target';
  }

  @override
  String get questsRevealSiteTitle => 'Khám phá địa điểm lạ';

  @override
  String questsRevealSiteSubtitle(String distance, String district) {
    return 'Cách $distance · $district';
  }

  @override
  String questsWalkTitle(String target) {
    return 'Đi bộ $target km hôm nay';
  }

  @override
  String questsWalkSubtitle(String done, String target) {
    return '$done / $target km';
  }

  @override
  String get questsNewDistrictTitle => 'Đặt chân tới quận mới';

  @override
  String questsNewDistrictSubtitle(String district, String distance) {
    return 'Gần nhất: $district · $distance';
  }

  @override
  String get questsNightWandererTitle => 'Kẻ lang thang đêm';

  @override
  String questsUnlocksAtLevel(int level) {
    return 'Mở ở cấp $level';
  }

  @override
  String get profileTitle => 'Cá nhân';

  @override
  String profileLevelLine(int level, int xp) {
    return 'Nhà thám hiểm cấp $level · $xp XP';
  }

  @override
  String profileChartedShare(int percent) {
    return '$percent%';
  }

  @override
  String profileChartedCaption(String region) {
    return 'đã mở ở $region';
  }

  @override
  String get profileNamePlaceholder => 'Nhà thám hiểm chưa đặt tên';

  @override
  String get profileNameTitle => 'Tên của bạn';

  @override
  String get profileNameHint => 'Chỉ lưu trên máy này';

  @override
  String get profileNameSave => 'Lưu';

  @override
  String get profilePhotoChoose => 'Chọn ảnh';

  @override
  String get profilePhotoRemove => 'Xoá ảnh';

  @override
  String get profileStatDistanceToday => 'Quãng đường hôm nay';

  @override
  String get profileStatCheckIns => 'Nơi đã điểm danh';

  @override
  String get profileStatStreak => 'Chuỗi ngày liên tục';

  @override
  String get profileMapsTitle => 'Bản đồ';

  @override
  String profileDistrictProgressTitle(String region) {
    return 'Phường xã · $region';
  }

  @override
  String get profileDistrictsEmpty => 'Hãy đi bộ để mở phường xã đầu tiên.';

  @override
  String get profileDistrictsUnavailable =>
      'Bản đồ này chưa có dữ liệu phường xã.';

  @override
  String profileDistrictsMore(int count) {
    return 'và $count nơi khác';
  }

  @override
  String get profileRankingTitle => 'Xếp hạng thành phố';

  @override
  String get profileRankingUnavailable => 'Chưa có';

  @override
  String checkInSheetMeta(String category, String distance, String visited) {
    String _temp0 = intl.Intl.selectLogic(visited, {
      'never': 'chưa từng ghé',
      'other': 'đã từng ghé',
    });
    return '$category · cách $distance · $_temp0';
  }

  @override
  String get checkInExplorersHere => 'người đang ở đây';

  @override
  String get checkInFirstVisit => 'Lần đầu';

  @override
  String get checkInFirstVisitBonus => 'thưởng ×2';

  @override
  String get checkInStreakKept => 'giữ chuỗi ngày';

  @override
  String get checkInAction => 'Điểm danh tại đây';

  @override
  String get checkInWrongPlaceTitle => 'Không phải chỗ này? Chọn đúng nơi';

  @override
  String checkInSuccess(String place) {
    return 'Đã điểm danh tại $place';
  }

  @override
  String get checkInTooFar => 'Bạn đang ở quá xa để điểm danh tại đây.';

  @override
  String get checkInFailed => 'Chưa được. Thử lại sau một chút nhé.';

  @override
  String get discoveryKicker => 'ĐÃ KHÁM PHÁ QUẬN MỚI';

  @override
  String discoveryMeta(int index, int total, String city) {
    return 'Quận thứ $index trong $total · $city';
  }

  @override
  String get discoveryAction => 'Bắt đầu khám phá';

  @override
  String get settingsMapLayers => 'Điểm trên bản đồ';

  @override
  String get settingsShowSuggestedPoints => 'Địa điểm gợi ý';

  @override
  String get settingsShowSuggestedPointsDetail =>
      'Những nơi tìm được quanh bạn';

  @override
  String get settingsHideUserPoints => 'Điểm của tôi';

  @override
  String get settingsHideUserPointsDetail => 'Những ghim bạn tự đánh dấu';

  @override
  String get settingsHidePicturePoints => 'Điểm có ảnh';

  @override
  String get settingsHidePicturePointsDetail => 'Những nơi bạn đã chụp ảnh';

  @override
  String get settingsNearby => 'Gần đây';

  @override
  String get settingsNearbyRadius => 'Tìm trong bán kính';

  @override
  String get settingsNearbyRadiusDetail =>
      'Những nơi trong khoảng này sẽ hiện ở GẦN ĐÂY';

  @override
  String get settingsFogTitle => 'Sương mù';

  @override
  String get settingsFogSubtitle => 'Đi bộ mở ra được bao nhiêu';

  @override
  String get settingsFogClearingRadius => 'Vùng mở ra';

  @override
  String get settingsFogClearingRadiusDetail =>
      'Bạn nhìn được bao xa từ chỗ đang đứng';

  @override
  String get settingsFogPrecision => 'Độ chi tiết khi ghi';

  @override
  String get settingsFogPrecisionDetail =>
      'Càng chi tiết thì đường đi càng thật và tệp càng lớn';

  @override
  String get settingsBackupTitle => 'Sao lưu';

  @override
  String get settingsBackupSubtitle =>
      'Lưu sương mù và địa điểm của bạn ra tệp';

  @override
  String get backupIntro =>
      'Mọi nơi bạn đã đi qua chỉ nằm trong điện thoại này. Bản sao lưu là một tệp duy nhất, cất ở đâu cũng được và mở lại được trên bất kỳ máy nào.';

  @override
  String get backupHolds => 'Trong bản sao lưu';

  @override
  String backupFogCells(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Đã mở ra $count m² sương mù',
      zero: 'Chưa mở ra vùng nào',
    );
    return '$_temp0';
  }

  @override
  String backupPoints(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count điểm của bạn',
      zero: 'Chưa có điểm nào của bạn',
    );
    return '$_temp0';
  }

  @override
  String backupRegions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count thành phố',
      zero: 'Chưa đi thành phố nào',
    );
    return '$_temp0';
  }

  @override
  String get backupPhotosNote =>
      'Ảnh vẫn ở lại điện thoại này. Điểm ảnh khi phục hồi vẫn giữ vị trí và tên, và hiện ra như một ghim thường.';

  @override
  String get backupSaveAction => 'Lưu bản sao lưu';

  @override
  String get backupRestoreAction => 'Phục hồi từ bản sao lưu';

  @override
  String get backupRestoreNote =>
      'Phục hồi là cộng thêm vào những gì đang có. Những gì bạn đi được từ đó tới nay không mất.';

  @override
  String get backupSaved => 'Đã lưu bản sao lưu';

  @override
  String backupRestored(int fog, int points) {
    return 'Đã phục hồi $fog m² sương mù và $points điểm';
  }

  @override
  String get backupFailedSave => 'Không lưu được bản sao lưu.';

  @override
  String get backupFailedNotABackup =>
      'Tệp đó không phải bản sao lưu của NoPlace.';

  @override
  String get backupFailedTooNew =>
      'Bản sao lưu đó được tạo bởi phiên bản NoPlace mới hơn.';

  @override
  String get backupFailedRestore => 'Không phục hồi được bản sao lưu.';

  @override
  String get settingsTitle => 'Cài đặt';

  @override
  String get settingsLanguage => 'Ngôn ngữ';

  @override
  String get settingsLanguageSystem => 'Theo hệ thống';

  @override
  String get settingsDesignGallery => 'Thư viện giao diện';

  @override
  String get locationServiceOffTitle => 'Vị trí đang tắt';

  @override
  String get locationServiceOffBody =>
      'Không có vị trí thì NoPlace không mở được bản đồ.';

  @override
  String get locationDeniedTitle => 'NoPlace cần vị trí của bạn';

  @override
  String get locationDeniedBody =>
      'Đi bộ là cách mở ra bản đồ, nên ứng dụng cần biết bạn đang ở đâu.';

  @override
  String get locationDeniedForeverTitle => 'Quyền vị trí đang bị chặn';

  @override
  String get locationDeniedForeverBody =>
      'Bật lại trong Cài đặt để tiếp tục mở bản đồ.';

  @override
  String get locationActionTurnOn => 'Bật';

  @override
  String get locationActionAllow => 'Cho phép';

  @override
  String get locationActionSettings => 'Mở cài đặt';

  @override
  String get locationWaiting => 'Đang tìm bạn…';

  @override
  String get backgroundAskTitle => 'Ghi lại đường đi khi bạn đang bước';

  @override
  String get backgroundAskBody =>
      'NoPlace mở bản đồ theo nơi bạn thật sự đi qua, nghĩa là phải ghi cả khi tắt màn hình và điện thoại nằm trong túi. Chế độ tiết kiệm pin sẽ chặn việc đó, và đường đi sẽ bị đứt quãng.';

  @override
  String get backgroundAskNote =>
      'Luôn có thông báo hiện lên suốt lúc ghi. Đóng NoPlace là dừng hẳn.';

  @override
  String get backgroundAskAction => 'Cho phép';

  @override
  String get backgroundSleepTitle => 'Điện thoại có thể tạm dừng NoPlace';

  @override
  String get backgroundSleepBody =>
      'Chế độ tiết kiệm pin được phép cho ứng dụng ngủ khi trong túi, làm đường đi bị đứt quãng.';

  @override
  String get backgroundSleepAction => 'Giữ chạy nền';

  @override
  String mapNearestTitle(String place) {
    return 'Gần nhất · $place';
  }

  @override
  String mapNearestMeta(Object distance) {
    return 'Cách $distance · đi gần hơn để điểm danh';
  }

  @override
  String get mapNothingNearbyTitle => 'Chưa có địa điểm nào ở đây';

  @override
  String get mapNothingNearbyBody =>
      'Cứ đi tiếp — bản đồ vẫn mở ra theo bước chân bạn.';

  @override
  String get mapRecentre => 'Về vị trí của tôi';

  @override
  String get mapHideFog => 'Ẩn sương mù';

  @override
  String get mapShowFog => 'Hiện sương mù';

  @override
  String regionArrivedTitle(String region) {
    return 'Bạn đã tới $region';
  }

  @override
  String get regionArrivedBody =>
      'Bản đồ đã chuyển sang đường phố của vùng này, cùng phần sương mù bạn đã mở ở đây. Mỗi nơi giữ đường đi riêng của nó.';

  @override
  String get regionPickerLabel => 'Đi với bản đồ nào';

  @override
  String get regionPackOnDevice => 'Có sẵn trong máy · dùng được ngoại tuyến';

  @override
  String get regionPackNotDownloaded => 'Chưa có trong máy';

  @override
  String get regionArrivedAction => 'Đi ở đây';

  @override
  String get placeUnnamed => 'Địa điểm chưa đặt tên';

  @override
  String get placeAddTitle => 'Địa điểm mới';

  @override
  String get placeAddAction => 'Lưu địa điểm này';

  @override
  String get placeAddHere => 'Lưu một địa điểm ở đây';

  @override
  String get placeNameHint => 'Bạn gọi nơi này là gì?';

  @override
  String get placeSectionIcon => 'CHỌN BIỂU TƯỢNG';

  @override
  String get placeSectionMood => 'Ở ĐÂY THẤY THẾ NÀO?';

  @override
  String get placeSectionRating => 'BẠN CHẤM MẤY SAO';

  @override
  String get placeMoodLove => 'Mê luôn';

  @override
  String get placeMoodHappy => 'Vui';

  @override
  String get placeMoodCalm => 'Yên bình';

  @override
  String get placeMoodMeh => 'Cũng thường';

  @override
  String get placeMoodBad => 'Không hợp';

  @override
  String placeStars(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sao',
      zero: 'Chưa chấm sao',
    );
    return '$_temp0';
  }

  @override
  String get placeSave => 'Lưu thay đổi';

  @override
  String get placeCheckInAction => 'Mình đang ở đây';

  @override
  String placeCheckInCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Đã điểm danh $count lần',
      zero: 'Chưa điểm danh lần nào',
    );
    return '$_temp0';
  }

  @override
  String placeLastCheckIn(String weekday, String time) {
    return 'Lần gần nhất $weekday lúc $time';
  }

  @override
  String get placeSectionAutoCheckIn => 'TỰ ĐỘNG ĐIỂM DANH';

  @override
  String get placeAutoCheckInOff => 'Tắt';

  @override
  String get placeAutoCheckInHourly => '1 tiếng';

  @override
  String get placeAutoCheckInTwoHourly => '2 tiếng';

  @override
  String get placeAutoCheckInDaily => 'Mỗi ngày';

  @override
  String get placeAutoCheckInSummaryOff =>
      'Chỉ khi bạn bấm nút mới được tính — không tự ghi nhận gì cả.';

  @override
  String get placeAutoCheckInSummaryHourly =>
      'Ở đây một tiếng cũng được tính là một lần điểm danh.';

  @override
  String get placeAutoCheckInSummaryTwoHourly =>
      'Ở đây hai tiếng cũng được tính là một lần điểm danh.';

  @override
  String get placeAutoCheckInSummaryDaily =>
      'Cứ tới đây là được tính một lần, mỗi ngày một lần. Không cần ở lại.';

  @override
  String get placeAutoCheckInHelp => 'Cái này để làm gì?';

  @override
  String get placeAutoCheckInTipTitle => 'Tự đếm số lần bạn ghé qua';

  @override
  String get placeAutoCheckInTipBody =>
      'Chỉ cần bạn ở trong bán kính 150 m, NoPlace sẽ tự ghi nhận một lần ghé qua sau mỗi khoảng thời gian bạn chọn. Không cần bấm gì, và vẫn chạy khi điện thoại nằm trong túi.\n\nRiêng \"Mỗi ngày\" thì khác: vừa tới nơi là được tính ngay, rồi thôi cho tới hôm sau. Hãy chọn nó cho những nơi bạn chỉ ghé ngang chứ không ngồi lại.\n\nVới các mốc thời gian, ứng dụng đợi 20 phút không thấy bạn đâu mới coi như bạn đã rời đi, nên tín hiệu GPS chập chờn không làm mất công bạn ngồi đó. Rời đi rồi quay lại thì đồng hồ bắt đầu lại từ đầu.\n\nHãy chọn Tắt cho những nơi bạn ở suốt, chẳng hạn như nhà mình — không thì tối nào cũng có thêm một lần ghé qua.';

  @override
  String placeCheckedIn(String name) {
    return 'Đã điểm danh tại $name';
  }

  @override
  String placeSaved(String name) {
    return 'Đã lưu $name';
  }

  @override
  String get placeDelete => 'Xoá địa điểm này';

  @override
  String placeDeleted(String name) {
    return 'Đã xoá $name';
  }

  @override
  String get placeUndo => 'Hoàn tác';
}
