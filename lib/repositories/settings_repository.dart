
import '../services/database_service.dart';

class SettingsRepository {
  final DatabaseService _db = DatabaseService.instance;

  Future<Map<String, dynamic>> getSettings() async {
    return await _db.getSettings();
  }

  Future<void> saveSettings(Map<String, String> settings) async {
    await _db.saveSettings(settings);
  }

  Future<void> clearAllData() async {
    await _db.clearAllData();
  }
}