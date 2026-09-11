import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../providers/search_provider.dart';

/// 文件名快速打开面板:过滤已打开标签与最近文件,回车/点击打开。
class QuickOpenPanel extends StatefulWidget {
  final List<QuickOpenEntry> entries;
  final ValueChanged<QuickOpenEntry> onSelected;

  const QuickOpenPanel({
    super.key,
    required this.entries,
    required this.onSelected,
  });

  @override
  State<QuickOpenPanel> createState() => _QuickOpenPanelState();
}

class _QuickOpenPanelState extends State<QuickOpenPanel> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  List<QuickOpenEntry> _filtered = const [];

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onQueryChanged);
    _filtered = widget.entries;
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    setState(() => _filtered = filterQuickOpen(widget.entries, _controller.text));
  }

  void _selectFirst() {
    if (_filtered.isEmpty) return;
    Navigator.of(context).pop();
    widget.onSelected(_filtered.first);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).pop(),
      },
      child: Dialog(
        alignment: Alignment.topCenter,
        insetPadding: const EdgeInsets.only(top: 80, left: 24, right: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 420),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.file_open,
                        size: 20, color: colorScheme.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        autofocus: true,
                        style: const TextStyle(fontSize: 14),
                        decoration: const InputDecoration(
                          hintText: '按文件名搜索,快速打开',
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        onSubmitted: (_) => _selectFirst(),
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
                if (_filtered.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text('无匹配文件',
                          style: TextStyle(fontSize: 13, color: Colors.grey)),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _filtered.length,
                      itemBuilder: (context, index) {
                        final entry = _filtered[index];
                        return ListTile(
                          dense: true,
                          leading: Icon(
                            entry.isOpen
                                ? Icons.description
                                : Icons.history,
                            size: 18,
                            color: entry.isOpen
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant,
                          ),
                          title: Text(entry.title,
                              style: const TextStyle(fontSize: 13)),
                          subtitle: entry.subtitle.isEmpty
                              ? null
                              : Text(entry.subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11)),
                          onTap: () {
                            Navigator.of(context).pop();
                            widget.onSelected(entry);
                          },
                        );
                      },
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
