import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/tab_manager.dart';
import '../../services/storage_service.dart';

class FileExplorer extends StatelessWidget {
  const FileExplorer({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          right: BorderSide(color: colorScheme.outlineVariant, width: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SidebarHeader(colorScheme: colorScheme),
          const Divider(height: 1),
          _OpenFileButton(colorScheme: colorScheme),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              '最近文件',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurfaceVariant,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const Expanded(child: _RecentFilesList()),
        ],
      ),
    );
  }
}

class _SidebarHeader extends StatelessWidget {
  final ColorScheme colorScheme;

  const _SidebarHeader({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Icon(Icons.folder_open, size: 20, color: colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            '文件浏览',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _OpenFileButton extends StatelessWidget {
  final ColorScheme colorScheme;

  const _OpenFileButton({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.read<TabManager>().openFilePicker(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(
              Icons.add_circle_outline,
              size: 18,
              color: colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              '打开 Markdown 文件',
              style: TextStyle(fontSize: 13, color: colorScheme.primary),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentFilesList extends StatelessWidget {
  const _RecentFilesList();

  @override
  Widget build(BuildContext context) {
    context.watch<TabManager>();
    final storageService = context.read<StorageService>();
    final recentFiles = storageService.getRecentFiles();

    if (recentFiles.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            '暂无最近文件',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: recentFiles.length,
      itemBuilder: (context, index) {
        final path = recentFiles[index];
        return _RecentFileItem(path: path);
      },
    );
  }
}

class _RecentFileItem extends StatelessWidget {
  final String path;

  const _RecentFileItem({required this.path});

  @override
  Widget build(BuildContext context) {
    final fileName = path.split(Platform.pathSeparator).last;
    final dirPath = path.substring(0, path.length - fileName.length - 1);
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: () => _openFile(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            Icon(
              Icons.description_outlined,
              size: 16,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fileName,
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    dirPath,
                    style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openFile(BuildContext context) {
    context.read<TabManager>().openFileFromPath(path);
  }
}
