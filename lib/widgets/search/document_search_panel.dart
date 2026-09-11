import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../providers/search_provider.dart';

/// 当前文档内搜索浮层:输入 + 命中计数 + 上一处/下一处导航。
/// 跳转通过 [onJumpToLine](命中行号)交由外部处理。
class DocumentSearchPanel extends StatefulWidget {
  final String text;
  final ValueChanged<int> onJumpToLine;
  final VoidCallback onClose;

  const DocumentSearchPanel({
    super.key,
    required this.text,
    required this.onJumpToLine,
    required this.onClose,
  });

  @override
  State<DocumentSearchPanel> createState() => _DocumentSearchPanelState();
}

class _DocumentSearchPanelState extends State<DocumentSearchPanel> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  List<SearchMatch> _matches = const [];
  int _current = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onQueryChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    setState(() {
      _matches = searchInText(widget.text, _controller.text);
      _current = 0;
    });
  }

  void _goNext() {
    if (_matches.isEmpty) return;
    setState(() => _current = (_current + 1) % _matches.length);
    widget.onJumpToLine(_matches[_current].lineIndex);
  }

  void _goPrev() {
    if (_matches.isEmpty) return;
    setState(() => _current = (_current - 1 + _matches.length) % _matches.length);
    widget.onJumpToLine(_matches[_current].lineIndex);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): widget.onClose,
      },
      child: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(10),
        color: colorScheme.surface,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search, size: 20, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 240),
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  autofocus: true,
                  style: const TextStyle(fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: '在文档中搜索',
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  onSubmitted: (_) => _goNext(),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _matches.isEmpty
                    ? '0/0'
                    : '${_current + 1}/${_matches.length}',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.expand_less, size: 20),
                tooltip: '上一处',
                onPressed: _matches.isEmpty ? null : _goPrev,
              ),
              IconButton(
                icon: const Icon(Icons.expand_more, size: 20),
                tooltip: '下一处',
                onPressed: _matches.isEmpty ? null : _goNext,
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                tooltip: '关闭',
                onPressed: widget.onClose,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
