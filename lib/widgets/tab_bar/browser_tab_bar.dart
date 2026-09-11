import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/tab_item.dart';
import '../../providers/tab_manager.dart';
import 'tab_button.dart';

class BrowserTabBar extends StatelessWidget {
  const BrowserTabBar({super.key});

  @override
  Widget build(BuildContext context) {
    final tabManager = context.watch<TabManager>();
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: 48,
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

class _TabList extends StatefulWidget {
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
  State<_TabList> createState() => _TabListState();
}

class _TabListState extends State<_TabList> {
  final _itemKeys = <String, GlobalKey>{};

  GlobalKey _keyFor(String id) =>
      _itemKeys.putIfAbsent(id, () => GlobalKey());

  @override
  void didUpdateWidget(_TabList oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 切换标签后把激活标签滚动到可视区
    if (widget.activeIndex != oldWidget.activeIndex &&
        widget.activeIndex >= 0 &&
        widget.activeIndex < widget.tabs.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _ensureActiveVisible();
      });
    }
  }

  void _ensureActiveVisible() {
    if (widget.activeIndex < 0 || widget.activeIndex >= widget.tabs.length) {
      return;
    }
    final id = (widget.tabs[widget.activeIndex] as TabItem).id;
    final context = _itemKeys[id]?.currentContext;
    if (context != null && context.findRenderObject() != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 200),
        alignment: 0.1,
      );
    }
  }

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
      onReorder: widget.onReorder,
      itemCount: widget.tabs.length,
      itemBuilder: (context, index) {
        final tab = widget.tabs[index];
        final key = _keyFor(tab.id as String);
        return ReorderableDragStartListener(
          key: key,
          index: index,
          child: _TabContextMenu(
            index: index,
            child: TabButton(
              title: tab.title,
              isActive: index == widget.activeIndex,
              onTap: () => widget.onTap(index),
              onClose: () => widget.onClose(index),
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
      // 长按等价于右键菜单:触摸设备上唯一可达入口
      onLongPress: () {
        final box = context.findRenderObject() as RenderBox;
        final position = box.localToGlobal(Offset(box.size.width - 8, 0));
        _showContextMenu(context, position, tabManager);
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
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: IconButton(
        onPressed: onTap,
        icon: const Icon(Icons.add, size: 20),
        tooltip: '打开文件',
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      ),
    );
  }
}
