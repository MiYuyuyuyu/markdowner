import 'dart:async';
import 'dart:io';

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
  static int _idCounter = 0;
  Timer? _scrollSaveDebounce;

  TabManager(this._fileService, this._storageService);

  /// 打开文件失败(文件仍存在,如编码不支持)时的用户提示回调,
  /// 由 UI 层(HomeScreen)注入
  void Function(String message)? onError;

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
        final fileName = FileService.extractFileName(savedTab.path);
        _tabs.add(TabItem(
          id: savedTab.path,
          title: fileName,
          filePath: savedTab.path,
          content: content,
          scrollOffset: savedTab.scrollOffset,
        ));
      } catch (_) {
        // 文件已不存在才移出最近列表;临时性错误(编码不支持、盘未挂载等)不破坏记录
        if (!_fileExists(savedTab.path)) {
          await _storageService.removeRecentFile(savedTab.path);
        }
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
      final fileName = FileService.extractFileName(path);
      final tab = TabItem(
        id: '${DateTime.now().millisecondsSinceEpoch}-${_idCounter++}',
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
      // 文件仍存在时(编码不支持、被占用等)不应移出最近列表,
      // 并给出用户可见反馈,避免点击后静默无反应
      if (!_fileExists(path)) {
        await _storageService.removeRecentFile(path);
      } else {
        onError?.call('无法打开文件:${FileService.extractFileName(path)}');
      }
    }
  }

  bool _fileExists(String path) {
    try {
      return File(path).existsSync();
    } catch (_) {
      return false;
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

  /// 记录滚动位置。[tab] 按对象定位(而非 activeIndex),避免标签
  /// 切换同帧内到达的滚动通知把偏移写进新标签。
  /// 滚动高频触发:延迟合并落盘,避免每个滚动帧都做 JSON 序列化
  /// 与平台通道写入。
  void updateScrollOffset(TabItem tab, double offset) {
    if (!_tabs.contains(tab)) return;
    tab.scrollOffset = offset;
    _scrollSaveDebounce ??= Timer(const Duration(milliseconds: 300), () {
      _scrollSaveDebounce = null;
      _saveSession();
    });
  }

  @override
  void dispose() {
    _scrollSaveDebounce?.cancel();
    super.dispose();
  }

  Future<void> removeRecentFile(String path) async {
    await _storageService.removeRecentFile(path);
    notifyListeners();
  }

  Future<void> _saveSession({bool? showSidebar, bool? showToc}) {
    final stored = _storageService.getReadingSession();
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
        showSidebar: showSidebar ?? stored.showSidebar,
        showToc: showToc ?? stored.showToc,
      ),
    );
  }
}
