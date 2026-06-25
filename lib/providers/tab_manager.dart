import 'package:flutter/foundation.dart';
import '../models/reading_session.dart';
import '../models/tab_item.dart';
import '../services/file_service.dart';
import '../services/storage_service.dart';

class TabManager extends ChangeNotifier {
  final FileService _fileService;
  final StorageService _storageService;
  final List<TabItem> _tabs = [];
  int _activeIndex = -1;

  TabManager(this._fileService, this._storageService);

  List<TabItem> get tabs => List.unmodifiable(_tabs);
  int get activeIndex => _activeIndex;
  bool get hasTabs => _tabs.isNotEmpty;

  TabItem? get activeTab => _activeIndex >= 0 && _activeIndex < _tabs.length
      ? _tabs[_activeIndex]
      : null;

  Future<void> restoreSession() async {
    final session = _storageService.getReadingSession();
    _tabs.clear();
    _activeIndex = -1;

    for (final savedTab in session.openTabs) {
      try {
        final content = await _fileService.readFile(savedTab.path);
        final fileName = _fileService.extractFileName(savedTab.path);
        _tabs.add(TabItem(
          id: savedTab.path,
          title: fileName,
          filePath: savedTab.path,
          content: content,
          scrollOffset: savedTab.scrollOffset,
        ));
      } catch (_) {
        await _storageService.removeRecentFile(savedTab.path);
      }
    }

    if (_tabs.isNotEmpty) {
      final activePath = session.activePath;
      final activeIndex = activePath == null
          ? -1
          : _tabs.indexWhere((tab) => tab.filePath == activePath);
      _activeIndex = activeIndex >= 0 ? activeIndex : 0;
    }

    await _saveSession();
    notifyListeners();
  }

  Future<void> openFilePicker() async {
    final file = await _fileService.pickMarkdownFile();
    if (file?.path == null) return;
    await openFileFromPath(file!.path!);
  }

  Future<void> openFileFromPath(String path) async {
    final existingIndex = _tabs.indexWhere((t) => t.filePath == path);
    if (existingIndex >= 0) {
      _activeIndex = existingIndex;
      notifyListeners();
      return;
    }

    try {
      final content = await _fileService.readFile(path);
      final fileName = _fileService.extractFileName(path);
      final tab = TabItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: fileName,
        filePath: path,
        content: content,
      );
      _tabs.add(tab);
      _activeIndex = _tabs.length - 1;
      await _storageService.addRecentFile(path);
      await _saveSession();
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to open file: $e');
      await _storageService.removeRecentFile(path);
    }
  }

  void closeTab(int index) {
    if (index < 0 || index >= _tabs.length) return;
    _tabs.removeAt(index);
    if (_tabs.isEmpty) {
      _activeIndex = -1;
    } else if (_activeIndex >= _tabs.length) {
      _activeIndex = _tabs.length - 1;
    } else if (_activeIndex > index) {
      _activeIndex--;
    }
    _saveSession();
    notifyListeners();
  }

  void closeOtherTabs(int keepIndex) {
    if (keepIndex < 0 || keepIndex >= _tabs.length) return;
    final kept = _tabs[keepIndex];
    _tabs.clear();
    _tabs.add(kept);
    _activeIndex = 0;
    _saveSession();
    notifyListeners();
  }

  void closeAllTabs() {
    _tabs.clear();
    _activeIndex = -1;
    _saveSession();
    notifyListeners();
  }

  void setActiveTab(int index) {
    if (index >= 0 && index < _tabs.length && index != _activeIndex) {
      _activeIndex = index;
      _saveSession();
      notifyListeners();
    }
  }

  void reorderTab(int oldIndex, int newIndex) {
    if (oldIndex == newIndex) return;
    if (oldIndex < newIndex) newIndex--;
    final tab = _tabs.removeAt(oldIndex);
    _tabs.insert(newIndex, tab);

    if (_activeIndex == oldIndex) {
      _activeIndex = newIndex;
    } else if (_activeIndex > oldIndex && _activeIndex <= newIndex) {
      _activeIndex--;
    } else if (_activeIndex < oldIndex && _activeIndex >= newIndex) {
      _activeIndex++;
    }
    _saveSession();
    notifyListeners();
  }

  void updateScrollOffset(int index, double offset) {
    if (index >= 0 && index < _tabs.length) {
      _tabs[index].scrollOffset = offset;
      _saveSession();
    }
  }

  Future<void> removeRecentFile(String path) async {
    await _storageService.removeRecentFile(path);
    notifyListeners();
  }

  Future<void> _saveSession({bool? showSidebar, bool? showToc}) {
    return _storageService.saveReadingSession(
      ReadingSession(
        openTabs: _tabs
            .where((tab) => tab.filePath != null)
            .map((tab) => ReadingSessionTab(
                  path: tab.filePath!,
                  scrollOffset: tab.scrollOffset,
                ))
            .toList(),
        activePath: activeTab?.filePath,
        showSidebar: showSidebar ?? _storageService.getReadingSession().showSidebar,
        showToc: showToc ?? _storageService.getReadingSession().showToc,
      ),
    );
  }
}
