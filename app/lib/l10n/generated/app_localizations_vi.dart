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
  String get profileChartedCaption => 'thành phố đã được mở';

  @override
  String get profileStatDistanceToday => 'Quãng đường hôm nay';

  @override
  String get profileStatCheckIns => 'Nơi đã điểm danh';

  @override
  String get profileStatStreak => 'Chuỗi ngày liên tục';

  @override
  String profileCityCurrent(String city) {
    return '$city · hiện tại';
  }

  @override
  String get profileAddCity => '+ Thêm thành phố';

  @override
  String profileCityProgressTitle(String city) {
    return 'Tiến độ · $city';
  }

  @override
  String get profileRankingTitle => 'Xếp hạng thành phố';

  @override
  String profileRankingSubtitle(int rank, int total) {
    return 'Bạn đứng #$rank trong $total nhà thám hiểm';
  }

  @override
  String profileRankingTrend(int percent) {
    return '+$percent%';
  }

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
}
