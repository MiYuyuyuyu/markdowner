import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/tab_manager.dart';
import '../providers/settings_provider.dart';
import '../widgets/tab_bar/browser_tab_bar.dart';
import '../widgets/markdown/markdown_viewer.dart';
import '../widgets/sidebar/file_explorer.dart';
import '../widgets/welcome/welcome_page.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: _buildShortcuts(context),
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: _buildAppBar(context),
          body: _buildBody(context),
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
      const SingleActivator(LogicalKeyboardKey.equal, control: true): () {
        settings.increaseFontSize();
      },
      const SingleActivator(LogicalKeyboardKey.minus, control: true): () {
        settings.decreaseFontSize();
      },
    };
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final colorScheme = Theme.of(context).colorScheme;

    return AppBar(
      title: const Text('Markdown Reader', style: TextStyle(fontSize: 16)),
      leading: IconButton(
        icon: const Icon(Icons.menu),
        onPressed: settings.toggleSidebar,
        tooltip: '切换侧边栏',
      ),
      actions: [
        _FontSizeControls(settings: settings, colorScheme: colorScheme),
        IconButton(
          icon: Icon(settings.isDarkMode ? Icons.light_mode : Icons.dark_mode),
          onPressed: settings.toggleTheme,
          tooltip: settings.isDarkMode ? '切换亮色主题' : '切换暗色主题',
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final isWide = MediaQuery.of(context).size.width > 600;

    return Row(
      children: [
        if (settings.showSidebar && isWide) const FileExplorer(),
        const Expanded(child: _ContentArea()),
      ],
    );
  }
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

class _ContentArea extends StatelessWidget {
  const _ContentArea();

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
    return MarkdownViewer(
      key: ValueKey(activeTab.id),
      data: activeTab.content,
      initialScrollOffset: activeTab.scrollOffset,
    );
  }
}
