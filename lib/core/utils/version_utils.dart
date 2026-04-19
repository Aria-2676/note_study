import 'package:flutter/services.dart';
import 'package:yaml/yaml.dart';

class VersionUtils {
  static String _version = '';

  static String get version {
    return _version.isEmpty ? '1.0.0' : _version;
  }

  static Future<void> loadVersion() async {
    if (_version.isNotEmpty) return;

    try {
      final yamlString = await rootBundle.loadString('pubspec.yaml');
      final yamlMap = loadYaml(yamlString);
      _version = yamlMap['version'].toString().split('+')[0];
    } catch (_) {
      _version = '1.0.0';
    }
  }
}
