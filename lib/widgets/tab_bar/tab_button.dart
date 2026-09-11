import 'package:flutter/material.dart';

class TabButton extends StatefulWidget {
  final String title;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onClose;

  const TabButton({
    super.key,
    required this.title,
    required this.isActive,
    required this.onTap,
    required this.onClose,
  });

  @override
  State<TabButton> createState() => _TabButtonState();
}

class _TabButtonState extends State<TabButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final bgColor = widget.isActive
        ? colorScheme.surface
        : _isHovered
        ? colorScheme.surfaceContainerHighest
        : colorScheme.surfaceContainerLow;

    final textColor = widget.isActive
        ? colorScheme.onSurface
        : colorScheme.onSurfaceVariant;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          constraints: const BoxConstraints(maxWidth: 200, minWidth: 100),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            border: widget.isActive
                ? Border(top: BorderSide(color: colorScheme.primary, width: 2))
                : null,
          ),
          padding: const EdgeInsets.only(left: 12, right: 2, top: 4, bottom: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.description_outlined, size: 16, color: textColor),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: 13,
                    color: textColor,
                    fontWeight: widget.isActive
                        ? FontWeight.w500
                        : FontWeight.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              const SizedBox(width: 2),
              // 关闭按钮常显:纯触摸设备上没有 hover,依赖 hover 会不可达
              _CloseButton(onTap: widget.onClose),
            ],
          ),
        ),
      ),
    );
  }
}

class _CloseButton extends StatefulWidget {
  final VoidCallback onTap;

  const _CloseButton({required this.onTap});

  @override
  State<_CloseButton> createState() => _CloseButtonState();
}

class _CloseButtonState extends State<_CloseButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        // 36x36 命中区(标签栏高度内可容纳的最大触摸目标)
        child: SizedBox(
          width: 36,
          height: 36,
          child: Center(
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: _hovered
                    ? colorScheme.errorContainer
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                Icons.close,
                size: 16,
                color: _hovered
                    ? colorScheme.error
                    : colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
