import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/tab_manager.dart';
import 'tab_button.dart';

class BrowserTabBar extends StatelessWidget {
  const BrowserTabBar({super.key});

  @override
  Widget build(BuildContext context) {
    final tabManager = context.watch<TabManager>();
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TabList(
              tabs: tabManager.tabs,
              activeIndex: tabManager.activeIndex,
              onTap: tabManager.setActiveTab,
              onClose: tabManager.closeTab,
              onReorder: tabManager.reorderTab,
            ),
          ),
          _AddTabButton(onTap: tabManager.openFilePicker),
        ],
      ),
    );
  }
}

class _TabList extends StatelessWidget {
  final List tabs;
  final int activeIndex;
  final ValueChanged<int> onTap;
  final ValueChanged<int> onClose;
  final void Function(int, int) onReorder;

  const _TabList({
    required this.tabs,
    required this.activeIndex,
    required this.onTap,
    required this.onClose,
    required this.onReorder,
  });

  @override
  Widget build(BuildContext context) {
    return ReorderableListView.builder(
      scrollDirection: Axis.horizontal,
      buildDefaultDragHandles: false,
      proxyDecorator: (child, index, animation) {
        return Material(
          elevation: 4,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          child: child,
        );
      },
      onReorder: onReorder,
      itemCount: tabs.length,
      itemBuilder: (context, index) {
        final tab = tabs[index];
        return ReorderableDragStartListener(
          key: ValueKey(tab.id),
          index: index,
          child: _TabContextMenu(
            index: index,
            child: TabButton(
              title: tab.title,
              isActive: index == activeIndex,
              onTap: () => onTap(index),
              onClose: () => onClose(index),
            ),
          ),
        );
      },
    );
  }
}

class _TabContextMenu extends StatelessWidget {
  final int index;
  final Widget child;

  const _TabContextMenu({required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    final tabManager = context.read<TabManager>();

    return GestureDetector(
      onSecondaryTapUp: (details) {
        _showContextMenu(context, details.globalPosition, tabManager);
      },
      child: child,
    );
  }

  void _showContextMenu(
    BuildContext context,
    Offset position,
    TabManager tabManager,
  ) {
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: [
        const PopupMenuItem(value: 'close', child: Text('关闭')),
        const PopupMenuItem(value: 'closeOthers', child: Text('关闭其他')),
        const PopupMenuItem(value: 'closeAll', child: Text('关闭全部')),
      ],
    ).then((value) {
      switch (value) {
        case 'close':
          tabManager.closeTab(index);
        case 'closeOthers':
          tabManager.closeOtherTabs(index);
        case 'closeAll':
          tabManager.closeAllTabs();
      }
    });
  }
}

class _AddTabButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AddTabButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: IconButton(
        onPressed: onTap,
        icon: const Icon(Icons.add, size: 18),
        tooltip: '打开文件',
        splashRadius: 16,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
