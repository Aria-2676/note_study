import 'package:flutter/services.dart';
import 'package:yaml/yaml.dart';

class VersionUtils {
  static String _version = '5.0.1';
  
  static Future<String> get version async {
    if (_version == '5.0.1') {
      await _loadVersion();
    }
    return _version;
  }
  
  static Future<void> _loadVersion() async {
    try {
      final yamlString = await rootBundle.loadString('pubspec.yaml');
      final yamlMap = loadYaml(yamlString);
      _version = yamlMap['version'].toString().split('+')[0];
    } catch (e) {
      print('Error loading version: $e');
    }
  }
}