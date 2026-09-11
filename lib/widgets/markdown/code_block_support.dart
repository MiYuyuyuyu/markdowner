import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 代码块右上角的复制按钮(带"已复制"反馈)。
class CodeCopyButton extends StatefulWidget {
  final String code;

  const CodeCopyButton({super.key, required this.code});

  @override
  State<CodeCopyButton> createState() => _CodeCopyButtonState();
}

class _CodeCopyButtonState extends State<CodeCopyButton> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    if (!mounted) return;
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surface.withValues(alpha: 0.85),
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: _copy,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _copied ? Icons.check : Icons.copy,
                size: 14,
                color: _copied ? Colors.green : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                _copied ? '已复制' : '复制',
                style: TextStyle(
                  fontSize: 12,
                  color: _copied ? Colors.green : colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// PreConfig.wrapper:在代码块右上角叠加复制按钮。
Widget wrapCodeBlock(Widget child, String code, String language) {
  return Stack(
    children: [
      child,
      Positioned(
        top: 6,
        right: 6,
        child: CodeCopyButton(code: code),
      ),
    ],
  );
}
