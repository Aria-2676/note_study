import 'package:shared_preferences/shared_preferences.dart';

/// 更新功能的本地状态。
///
/// 版本检查是「用户可关掉」的功能，因此这几个状态必须落盘：
/// 跳过过哪个版本、是否关掉了提醒、上次检查时间、本地已应用的资源包构建号。
class AppUpdateSettings {
  const AppUpdateSettings();

  static const String _kIgnoredVersion = 'app_update_ignored_version';
  static const String _kNotificationsEnabled = 'app_update_notifications_enabled';
  static const String _kLastCheckAt = 'app_update_last_check_at';
  static const String _kAssetBuild = 'app_update_asset_build';

  /// 自动检查的最小间隔；手动「检查更新」不受此限制。
  static const Duration autoCheckInterval = Duration(hours: 6);

  Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  /// 用户点过「跳过此版本」的版本号；没有则为 null。
  Future<String?> ignoredVersion() async {
    final prefs = await _prefs();
    final value = prefs.getString(_kIgnoredVersion);
    return (value == null || value.isEmpty) ? null : value;
  }

  /// 记下「用户跳过了这个版本」。
  ///
  /// 只跳过指定版本：下一个版本仍然会提醒，避免用户被永久静音后错过重要更新。
  Future<void> setIgnoredVersion(String version) async {
    final prefs = await _prefs();
    await prefs.setString(_kIgnoredVersion, version);
  }

  /// 清除跳过记录（用户手动检查更新时可不再受它影响）。
  Future<void> clearIgnoredVersion() async {
    final prefs = await _prefs();
    await prefs.remove(_kIgnoredVersion);
  }

  /// 是否允许「大版本更新」弹窗提醒。默认开启。
  Future<bool> notificationsEnabled() async {
    final prefs = await _prefs();
    return prefs.getBool(_kNotificationsEnabled) ?? true;
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    final prefs = await _prefs();
    await prefs.setBool(_kNotificationsEnabled, enabled);
  }

  /// 上次检查更新的时间；从未检查过时为 null。
  Future<DateTime?> lastCheckAt() async {
    final prefs = await _prefs();
    final millis = prefs.getInt(_kLastCheckAt);
    if (millis == null || millis <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }

  Future<void> markChecked([DateTime? at]) async {
    final prefs = await _prefs();
    await prefs.setInt(
      _kLastCheckAt,
      (at ?? DateTime.now()).millisecondsSinceEpoch,
    );
  }

  /// 距离上次检查是否已经超过 [interval]，可以自动再查一次。
  Future<bool> isAutoCheckDue({
    Duration interval = autoCheckInterval,
    DateTime? now,
  }) async {
    final last = await lastCheckAt();
    if (last == null) return true;
    return (now ?? DateTime.now()).difference(last) >= interval;
  }

  /// 本地已应用的资源热更新包构建号；0 表示从未应用过。
  Future<int> assetBuild() async {
    final prefs = await _prefs();
    return prefs.getInt(_kAssetBuild) ?? 0;
  }

  Future<void> setAssetBuild(int build) async {
    final prefs = await _prefs();
    await prefs.setInt(_kAssetBuild, build);
  }
}
