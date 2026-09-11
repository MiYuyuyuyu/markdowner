import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:provider/provider.dart';
import '../models/tab_item.dart';
import '../providers/search_provider.dart';
import '../providers/tab_manager.dart';
import '../providers/settings_provider.dart';
import '../services/storage_service.dart';
import '../widgets/tab_bar/browser_tab_bar.dart';
import '../widgets/markdown/markdown_viewer.dart';
import '../widgets/markdown/markdown_preprocessor.dart';
import '../widgets/navigation/toc_panel.dart';
import '../widgets/search/document_search_panel.dart';
import '../widgets/search/global_search_panel.dart';
import '../widgets/search/quick_open_panel.dart';
import '../widgets/sidebar/file_explorer.dart';
import '../widgets/welcome/welcome_page.dart';

const _sidebarBreakpoint = 720.0;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _tocControllers = <String, TocController>{};
  bool _documentSearchVisible = false;

  TocController? _tocControllerForActiveTab(TabManager tabManager) {
    final activeTab = tabManager.activeTab;
    if (activeTab == null) return null;
    return _tocControllers.putIfAbsent(activeTab.id, TocController.new);
  }

  void _disposeClosedTabControllers(TabManager tabManager) {
    final openTabIds = tabManager.tabs.map((tab) => tab.id).toSet();
    final closedTabIds = _tocControllers.keys
        .where((tabId) => !openTabIds.contains(tabId))
        .toList();
    for (final tabId in closedTabIds) {
      _tocControllers.remove(tabId)?.dispose();
    }
  }

  @override
  void dispose() {
    for (final controller in _tocControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  /// 在 [tab] 中跳转到 [lineIndex] 所在章节。切换标签后目录可能尚未渲染完成,
  /// 最多重试 [tries] 帧。
  void _jumpToLineInTab(TabItem tab, int lineIndex, {int tries = 5}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = _tocControllers[tab.id];
      if (controller == null) return;
      final headings = parseHeadings(tab.content);
      final headingIndex = nearestHeadingIndexForLine(headings, lineIndex);
      final tocList = controller.tocList;
      if (headingIndex >= 0 && headingIndex < tocList.length) {
        controller.jumpToIndex(tocList.elementAt(headingIndex).widgetIndex);
      } else if (tries > 0) {
        _jumpToLineInTab(tab, lineIndex, tries: tries - 1);
      }
    });
  }

  void _showGlobalSearch() {
    final tabManager = context.read<TabManager>();
    if (!tabManager.hasTabs) return;
    showDialog(
      context: context,
      builder: (_) => GlobalSearchPanel(
        tabs: tabManager.tabs,
        onSelected: (tab, lineIndex) {
          final index = tabManager.tabs.indexOf(tab);
          if (index < 0) return;
          tabManager.setActiveTab(index);
          _jumpToLineInTab(tab, lineIndex);
        },
      ),
    );
  }

  void _showQuickOpen() {
    final tabManager = context.read<TabManager>();
    final storageService = context.read<StorageService>();
    showDialog(
      context: context,
      builder: (_) => QuickOpenPanel(
        entries: buildQuickOpenEntries(
          tabs: tabManager.tabs,
          recentPaths: storageService.getRecentFiles(),
          fileNameOf: (path) => path.split(Platform.pathSeparator).last,
        ),
        onSelected: (entry) {
          final path = entry.path;
          if (path == null) return;
          tabManager.openFileFromPath(path);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > _sidebarBreakpoint;
    final tabManager = context.watch<TabManager>();
    final settings = context.watch<SettingsProvider>();
    _disposeClosedTabControllers(tabManager);
    final tocController = _tocControllerForActiveTab(tabManager);
    final rawData = tabManager.activeTab?.content ?? '';
    final processedData = preprocessMarkdownData(rawData);

    return CallbackShortcuts(
      bindings: _buildShortcuts(context),
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: _buildAppBar(context, isWide),
          drawer: isWide ? null : const _DrawerSidebar(),
          endDrawer: isWide || !settings.showToc
              ? null
              : (tocController == null
                  ? null
                  : _TocDrawer(
                      tocController: tocController,
                      markdownData: processedData,
                    )),
          body: _buildBody(context, isWide, processedData, tocController),
        ),
      ),
    );
  }

  Map<ShortcutActivator, VoidCallback> _buildShortcuts(BuildContext context) {
    final tabManager = context.read<TabManager>();
    final settings = context.read<SettingsProvider>();

    return {
      const SingleActivator(LogicalKeyboardKey.keyO, control: true): () {
        tabManager.openFilePicker();
      },
      const SingleActivator(LogicalKeyboardKey.keyW, control: true): () {
        if (tabManager.activeIndex >= 0) {
          tabManager.closeTab(tabManager.activeIndex);
        }
      },
      const SingleActivator(LogicalKeyboardKey.keyF, control: true): () {
        if (tabManager.activeIndex >= 0) {
          setState(() => _documentSearchVisible = !_documentSearchVisible);
        }
      },
      const SingleActivator(LogicalKeyboardKey.keyF, control: true, shift: true): () {
        _showGlobalSearch();
      },
      const SingleActivator(LogicalKeyboardKey.keyP, control: true): () {
        _showQuickOpen();
      },
      // Windows 上 "+" 需要 Shift(即 Ctrl+Shift+=),小键盘加减号是独立按键
      const SingleActivator(LogicalKeyboardKey.equal, control: true): () {
        settings.increaseFontSize();
      },
      const SingleActivator(LogicalKeyboardKey.equal, control: true, shift: true): () {
        settings.increaseFontSize();
      },
      const SingleActivator(LogicalKeyboardKey.numpadAdd, control: true): () {
        settings.increaseFontSize();
      },
      const SingleActivator(LogicalKeyboardKey.minus, control: true): () {
        settings.decreaseFontSize();
      },
      const SingleActivator(LogicalKeyboardKey.numpadSubtract, control: true): () {
        settings.decreaseFontSize();
      },
    };
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, bool isWide) {
    final settings = context.watch<SettingsProvider>();
    final tabManager = context.watch<TabManager>();
    final colorScheme = Theme.of(context).colorScheme;
    final hasContent = tabManager.activeTab != null;

    return AppBar(
      title: const Text('Markdown Reader', style: TextStyle(fontSize: 16)),
      leading: Builder(
        builder: (ctx) => IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () {
            if (isWide) {
              settings.toggleSidebar();
            } else {
              Scaffold.of(ctx).openDrawer();
            }
          },
          tooltip: '切换侧边栏',
        ),
      ),
      actions: [
        if (hasContent)
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: '文档内搜索 (Ctrl+F)',
            onPressed: () =>
                setState(() => _documentSearchVisible = !_documentSearchVisible),
          ),
        if (tabManager.hasTabs)
          IconButton(
            icon: const Icon(Icons.manage_search),
            tooltip: '跨标签搜索 (Ctrl+Shift+F)',
            onPressed: _showGlobalSearch,
          ),
        IconButton(
          icon: const Icon(Icons.file_open),
          tooltip: '快速打开 (Ctrl+P)',
          onPressed: _showQuickOpen,
        ),
        if (hasContent)
          Builder(
            builder: (ctx) => IconButton(
              icon: Icon(
                settings.showToc ? Icons.list_alt : Icons.list_alt_outlined,
              ),
              onPressed: () {
                if (isWide) {
                  settings.toggleToc();
                } else {
                  if (settings.showToc) {
                    settings.closeToc();
                  } else {
                    Scaffold.of(ctx).openEndDrawer();
                  }
                }
              },
              tooltip: '文档目录',
            ),
          ),
        _FontSizeControls(settings: settings, colorScheme: colorScheme),
        IconButton(
          icon: Icon(
            settings.isDarkMode ? Icons.light_mode : Icons.dark_mode,
          ),
          onPressed: settings.toggleTheme,
          tooltip: settings.isDarkMode ? '切换亮色主题' : '切换暗色主题',
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildBody(
    BuildContext context,
    bool isWide,
    String data,
    TocController? tocController,
  ) {
    final settings = context.watch<SettingsProvider>();
    final tabManager = context.watch<TabManager>();

    return Row(
      children: [
        if (isWide && settings.showSidebar) const FileExplorer(),
        if (isWide && settings.showToc && tocController != null)
          TocPanel(
            key: ValueKey('toc-${tabManager.activeTab!.id}'),
            tocController: tocController,
            markdownData: data,
            onClose: settings.closeToc,
          ),
        Expanded(
          child: _ContentArea(
            tocController: tocController,
            data: data,
            documentSearchVisible: _documentSearchVisible,
            onDocumentSearchClosed: () =>
                setState(() => _documentSearchVisible = false),
            onJumpToLine: _jumpToLineInTab,
          ),
        ),
      ],
    );
  }
}

class _DrawerSidebar extends StatelessWidget {
  const _DrawerSidebar();

  @override
  Widget build(BuildContext context) {
    final tabManager = context.watch<TabManager>();

    return Drawer(
      child: _DrawerAutoClose(
        tabManager: tabManager,
        child: const SafeArea(child: FileExplorer()),
      ),
    );
  }
}

class _TocDrawer extends StatelessWidget {
  final TocController tocController;
  final String markdownData;

  const _TocDrawer({required this.tocController, required this.markdownData});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: TocPanel(
          tocController: tocController,
          markdownData: markdownData,
        ),
      ),
    );
  }
}

class _DrawerAutoClose extends StatefulWidget {
  final TabManager tabManager;
  final Widget child;

  const _DrawerAutoClose({required this.tabManager, required this.child});

  @override
  State<_DrawerAutoClose> createState() => _DrawerAutoCloseState();
}

class _DrawerAutoCloseState extends State<_DrawerAutoClose> {
  int _previousTabCount = 0;

  @override
  void initState() {
    super.initState();
    _previousTabCount = widget.tabManager.tabs.length;
    widget.tabManager.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    widget.tabManager.removeListener(_onTabChanged);
    super.dispose();
  }

  void _onTabChanged() {
    final currentCount = widget.tabManager.tabs.length;
    if (currentCount > _previousTabCount) {
      Navigator.of(context).pop();
    }
    _previousTabCount = currentCount;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _FontSizeControls extends StatelessWidget {
  final SettingsProvider settings;
  final ColorScheme colorScheme;

  const _FontSizeControls({required this.settings, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.text_decrease, size: 20),
          onPressed: settings.decreaseFontSize,
          tooltip: '缩小字号',
        ),
        Text(
          '${settings.fontSize.toInt()}',
          style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
        ),
        IconButton(
          icon: const Icon(Icons.text_increase, size: 20),
          onPressed: settings.increaseFontSize,
          tooltip: '放大字号',
        ),
      ],
    );
  }
}

class _ContentArea extends StatefulWidget {
  final TocController? tocController;
  final String data;
  final bool documentSearchVisible;
  final VoidCallback onDocumentSearchClosed;
  final void Function(TabItem tab, int lineIndex) onJumpToLine;

  const _ContentArea({
    required this.tocController,
    required this.data,
    required this.documentSearchVisible,
    required this.onDocumentSearchClosed,
    required this.onJumpToLine,
  });

  @override
  State<_ContentArea> createState() => _ContentAreaState();
}

class _ContentAreaState extends State<_ContentArea> {
  @override
  Widget build(BuildContext context) {
    final tabManager = context.watch<TabManager>();

    return Column(
      children: [
        if (tabManager.hasTabs) const BrowserTabBar(),
        Expanded(child: _buildContent(tabManager)),
      ],
    );
  }

  Widget _buildContent(TabManager tabManager) {
    final activeTab = tabManager.activeTab;
    if (activeTab == null) {
      return const WelcomePage();
    }
    final viewer = MarkdownViewer(
      key: ValueKey(activeTab.id),
      data: widget.data,
      preprocessed: true,
      initialScrollOffset: activeTab.scrollOffset,
      onScrollChanged: (offset) {
        tabManager.updateScrollOffset(tabManager.activeIndex, offset);
      },
      tocController: widget.tocController,
    );

    if (!widget.documentSearchVisible) {
      return viewer;
    }

    return Stack(
      children: [
        viewer,
        Positioned(
          top: 8,
          right: 32,
          child: DocumentSearchPanel(
            key: ValueKey('doc-search-${activeTab.id}'),
            text: activeTab.content,
            onJumpToLine: (lineIndex) =>
                widget.onJumpToLine(activeTab, lineIndex),
            onClose: widget.onDocumentSearchClosed,
          ),
        ),
      ],
    );
  }
}
