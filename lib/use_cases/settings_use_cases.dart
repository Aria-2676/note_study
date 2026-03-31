import '../repositories/settings_repository.dart';

class SettingsUseCases {
  final SettingsRepository _settingsRepo;

  SettingsUseCases(this._settingsRepo);

  // 获取设置
  Future<Map<String, dynamic>> getSettings() async {
    return await _settingsRepo.getSettings();
  }

  // 保存设置
  Future<void> saveSettings(Map<String, String> settings) async {
    await _settingsRepo.saveSettings(settings);
  }

  // 清除所有数据
  Future<void> clearAllData() async {
    await _settingsRepo.clearAllData();
  }

  // 标记引导任务完成
  Future<void> markTutorialCompleted() async {
    final settings = await _settingsRepo.getSettings();
    settings['tutorialCompleted'] = 'true';
    await _settingsRepo.saveSettings(
      settings.map((key, value) => MapEntry(key, value.toString())),
    );
  }
}
