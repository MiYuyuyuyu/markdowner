import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/tab_manager.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.article_outlined,
            size: 80,
            color: colorScheme.primary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 24),
          Text(
            'Markdown Reader',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w300,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '支持 LaTeX 数学公式的 Markdown 阅读器',
            style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 40),
          FilledButton.icon(
            onPressed: () => context.read<TabManager>().openFilePicker(),
            icon: const Icon(Icons.folder_open),
            label: const Text('打开文件'),
          ),
          const SizedBox(height: 48),
          _ShortcutHints(colorScheme: colorScheme),
        ],
      ),
    );
  }
}

class _ShortcutHints extends StatelessWidget {
  final ColorScheme colorScheme;

  const _ShortcutHints({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _hint('Ctrl + O', '打开文件'),
        const SizedBox(height: 4),
        _hint('Ctrl + W', '关闭当前标签'),
        const SizedBox(height: 4),
        _hint('Ctrl + +/-', '调整字号'),
      ],
    );
  }

  Widget _hint(String shortcut, String description) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            shortcut,
            style: TextStyle(
              fontSize: 12,
              fontFamily: 'monospace',
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          description,
          style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
