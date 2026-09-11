import 'dart:convert';

import '../models/reading_session.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const _recentFilesKey = 'recent_files';
  static const _recentFoldersKey = 'recent_folders';
  static const _lastWorkspaceKey = 'last_workspace';
  static const _themeModeKey = 'theme_mode';
  static const _fontSizeKey = 'font_size';
  static const _tocPanelWidthKey = 'toc_panel_width';
  static const _explorerWidthKey = 'file_explorer_width';
  static const _readingSessionKey = 'reading_session';
  static const _maxRecentFiles = 20;
  static const _maxRecentFolders = 10;

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

  List<String> getRecentFolders() {
    return _prefs.getStringList(_recentFoldersKey) ?? [];
  }

  Future<void> addRecentFolder(String path) async {
    final folders = getRecentFolders();
    folders.remove(path);
    folders.insert(0, path);
    if (folders.length > _maxRecentFolders) {
      folders.removeRange(_maxRecentFolders, folders.length);
    }
    await _prefs.setStringList(_recentFoldersKey, folders);
    await setLastWorkspace(path);
  }

  String? getLastWorkspace() {
    return _prefs.getString(_lastWorkspaceKey);
  }

  Future<void> setLastWorkspace(String path) async {
    await _prefs.setString(_lastWorkspaceKey, path);
  }

  ReadingSession getReadingSession() {
    final raw = _prefs.getString(_readingSessionKey);
    if (raw == null || raw.isEmpty) {
      return const ReadingSession();
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return ReadingSession.fromJson(decoded);
      }
      return const ReadingSession();
    } catch (_) {
      return const ReadingSession();
    }
  }

  Future<void> saveReadingSession(ReadingSession session) async {
    await _prefs.setString(_readingSessionKey, jsonEncode(session.toJson()));
  }

  Future<void> updateReadingSessionUiState({
    bool? showSidebar,
    bool? showToc,
  }) async {
    final current = getReadingSession();
    await saveReadingSession(ReadingSession(
      openTabs: current.openTabs,
      activePath: current.activePath,
      showSidebar: showSidebar ?? current.showSidebar,
      showToc: showToc ?? current.showToc,
    ));
  }

  Future<void> clearReadingSession() async {
    await _prefs.remove(_readingSessionKey);
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

  double getTocPanelWidth() {
    return _prefs.getDouble(_tocPanelWidthKey) ?? 240.0;
  }

  Future<void> setTocPanelWidth(double size) async {
    await _prefs.setDouble(_tocPanelWidthKey, size);
  }

  double getFileExplorerWidth() {
    return _prefs.getDouble(_explorerWidthKey) ?? 260.0;
  }

  Future<void> setFileExplorerWidth(double size) async {
    await _prefs.setDouble(_explorerWidthKey, size);
  }
}
