import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/tab_item.dart';
import '../../providers/search_provider.dart';

/// 跨标签搜索面板(命令面板式浮层):在所有已打开标签的全文中搜索,
/// 结果按文档分组,点击后由 [onSelected] 切换标签并跳转到对应行。
class GlobalSearchPanel extends StatefulWidget {
  final List<TabItem> tabs;
  final void Function(TabItem tab, int lineIndex) onSelected;

  const GlobalSearchPanel({
    super.key,
    required this.tabs,
    required this.onSelected,
  });

  @override
  State<GlobalSearchPanel> createState() => _GlobalSearchPanelState();
}

class _GlobalSearchPanelState extends State<GlobalSearchPanel> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;
  List<TabSearchResult> _results = const [];

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      if (mounted) {
        setState(() => _results = searchAcrossTabs(widget.tabs, _controller.text));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasQuery = _controller.text.isNotEmpty;
    final totalMatches =
        _results.fold<int>(0, (sum, result) => sum + result.matches.length);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).pop(),
      },
      child: Dialog(
        alignment: Alignment.topCenter,
        insetPadding: const EdgeInsets.only(top: 80, left: 24, right: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 480),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.manage_search,
                        size: 20, color: colorScheme.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        autofocus: true,
                        style: const TextStyle(fontSize: 14),
                        decoration: const InputDecoration(
                          hintText: '在所有打开的标签中搜索',
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      tooltip: '关闭',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const Divider(height: 1),
                const SizedBox(height: 4),
                if (!hasQuery)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        '输入关键词,在所有已打开的文档中搜索',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    ),
                  )
                else if (_results.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text('无匹配结果',
                          style: TextStyle(fontSize: 13, color: Colors.grey)),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _results.length,
                      itemBuilder: (context, index) {
                        final result = _results[index];
                        final match = result.matches.first;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ListTile(
                              dense: true,
                              leading: const Icon(Icons.description, size: 18),
                              title: Text(result.title,
                                  style: const TextStyle(fontSize: 13)),
                              trailing: Text('${result.matches.length} 处',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: colorScheme.onSurfaceVariant)),
                              onTap: () => widget
                                  .onSelected(widget.tabs[result.tabIndex], match.lineIndex),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(left: 40, bottom: 6),
                              child: Text(
                                '第 ${match.lineIndex + 1} 行:${match.preview()}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: colorScheme.onSurfaceVariant),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                if (hasQuery && _results.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      '共 ${_results.length} 个文档、$totalMatches 处命中',
                      style: TextStyle(
                          fontSize: 12, color: colorScheme.onSurfaceVariant),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
