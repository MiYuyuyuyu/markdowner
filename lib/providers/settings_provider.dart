import 'package:flutter/material.dart';
import '../services/storage_service.dart';

class SettingsProvider extends ChangeNotifier {
  final StorageService _storageService;
  late bool _isDarkMode;
  late double _fontSize;
  bool _showSidebar = true;
  bool _showToc = false;

  SettingsProvider(this._storageService) {
    _isDarkMode = _storageService.isDarkMode();
    _fontSize = _storageService.getFontSize();
    final session = _storageService.getReadingSession();
    _showSidebar = session.showSidebar;
    _showToc = session.showToc;
  }

  bool get isDarkMode => _isDarkMode;
  double get fontSize => _fontSize;
  bool get showSidebar => _showSidebar;
  bool get showToc => _showToc;
  ThemeMode get themeMode => _isDarkMode ? ThemeMode.dark : ThemeMode.light;

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    _storageService.setDarkMode(_isDarkMode);
    notifyListeners();
  }

  void setFontSize(double size) {
    _fontSize = size.clamp(12.0, 32.0);
    _storageService.setFontSize(_fontSize);
    notifyListeners();
  }

  void increaseFontSize() => setFontSize(_fontSize + 2);
  void decreaseFontSize() => setFontSize(_fontSize - 2);

  void toggleSidebar() {
    _showSidebar = !_showSidebar;
    _storageService.updateReadingSessionUiState(showSidebar: _showSidebar);
    notifyListeners();
  }

  void toggleToc() {
    _showToc = !_showToc;
    _storageService.updateReadingSessionUiState(showToc: _showToc);
    notifyListeners();
  }

  void closeToc() {
    _showToc = false;
    _storageService.updateReadingSessionUiState(showToc: _showToc);
    notifyListeners();
  }
}
