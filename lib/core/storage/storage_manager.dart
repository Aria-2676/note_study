import 'package:shared_preferences/shared_preferences.dart';

class StorageManager {
  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static SharedPreferences get instance {
    if (_prefs == null) {
      throw Exception('StorageManager not initialized. Call StorageManager.init() first.');
    }
    return _prefs!;
  }

  static String? getString(String key) {
    return instance.getString(key);
  }

  static Future<bool> setString(String key, String value) {
    return instance.setString(key, value);
  }

  static int? getInt(String key) {
    return instance.getInt(key);
  }

  static Future<bool> setInt(String key, int value) {
    return instance.setInt(key, value);
  }

  static double? getDouble(String key) {
    return instance.getDouble(key);
  }

  static Future<bool> setDouble(String key, double value) {
    return instance.setDouble(key, value);
  }

  static bool? getBool(String key) {
    return instance.getBool(key);
  }

  static Future<bool> setBool(String key, bool value) {
    return instance.setBool(key, value);
  }

  static List<String>? getStringList(String key) {
    return instance.getStringList(key);
  }

  static Future<bool> setStringList(String key, List<String> value) {
    return instance.setStringList(key, value);
  }

  static bool containsKey(String key) {
    return instance.containsKey(key);
  }

  static Future<bool> remove(String key) {
    return instance.remove(key);
  }

  static Future<bool> clear() {
    return instance.clear();
  }

  static Set<String> getKeys() {
    return instance.getKeys();
  }
}