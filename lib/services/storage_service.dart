import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const _recentFilesKey = 'recent_files';
  static const _themeModeKey = 'theme_mode';
  static const _fontSizeKey = 'font_size';
  static const _maxRecentFiles = 20;

  final SharedPreferences _prefs;

  StorageService._(this._prefs);

  static Future<StorageService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return StorageService._(prefs);
  }

  List<String> getRecentFiles() {
    return _prefs.getStringList(_recentFilesKey) ?? [];
  }

  Future<void> addRecentFile(String path) async {
    final files = getRecentFiles();
    files.remove(path);
    files.insert(0, path);
    if (files.length > _maxRecentFiles) {
      files.removeRange(_maxRecentFiles, files.length);
    }
    await _prefs.setStringList(_recentFilesKey, files);
  }

  Future<void> removeRecentFile(String path) async {
    final files = getRecentFiles();
    files.remove(path);
    await _prefs.setStringList(_recentFilesKey, files);
  }

  Future<void> clearRecentFiles() async {
    await _prefs.remove(_recentFilesKey);
  }

  bool isDarkMode() {
    return _prefs.getBool(_themeModeKey) ?? false;
  }

  Future<void> setDarkMode(bool value) async {
    await _prefs.setBool(_themeModeKey, value);
  }

  double getFontSize() {
    return _prefs.getDouble(_fontSizeKey) ?? 16.0;
  }

  Future<void> setFontSize(double size) async {
    await _prefs.setDouble(_fontSizeKey, size);
  }
}
