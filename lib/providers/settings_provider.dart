import 'package:flutter/material.dart';
import '../services/storage_service.dart';

class SettingsProvider extends ChangeNotifier {
  final StorageService _storageService;
  late bool _isDarkMode;
  late double _fontSize;
  late double _tocPanelWidth;
  bool _showSidebar = true;
  bool _showToc = false;

  SettingsProvider(this._storageService) {
    _isDarkMode = _storageService.isDarkMode();
    final storedFontSize = _storageService.getFontSize();
    _fontSize = storedFontSize.isNaN || storedFontSize.isInfinite
        ? 16.0
        : storedFontSize.clamp(12.0, 32.0);
    final storedTocWidth = _storageService.getTocPanelWidth();
    _tocPanelWidth = storedTocWidth.isNaN || storedTocWidth.isInfinite
        ? 240.0
        : storedTocWidth.clamp(180.0, 480.0);
    final session = _storageService.getReadingSession();
    _showSidebar = session.showSidebar;
    _showToc = session.showToc;
  }

  bool get isDarkMode => _isDarkMode;
  double get fontSize => _fontSize;

  /// 目录面板宽度(拖动分隔条可调整,180-480)
  double get tocPanelWidth => _tocPanelWidth;

  void setTocPanelWidth(double width) {
    final clamped = width.clamp(180.0, 480.0);
    if (clamped == _tocPanelWidth) return;
    _tocPanelWidth = clamped;
    _storageService.setTocPanelWidth(_tocPanelWidth);
    notifyListeners();
  }
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
