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
          padding: const EdgeInsets.only(left: 12, right: 4, top: 6, bottom: 6),
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
              const SizedBox(width: 4),
              _CloseButton(
                visible: _isHovered || widget.isActive,
                onTap: widget.onClose,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CloseButton extends StatefulWidget {
  final bool visible;
  final VoidCallback onTap;

  const _CloseButton({required this.visible, required this.onTap});

  @override
  State<_CloseButton> createState() => _CloseButtonState();
}

class _CloseButtonState extends State<_CloseButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 100),
      opacity: widget.visible ? 1 : 0,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.visible ? widget.onTap : null,
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: _hovered ? colorScheme.errorContainer : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(
              Icons.close,
              size: 14,
              color: _hovered
                  ? colorScheme.error
                  : colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
