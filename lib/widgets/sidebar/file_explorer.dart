import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/file_node.dart';
import '../../providers/tab_manager.dart';
import '../../providers/workspace_provider.dart';
import '../../services/file_service.dart';
import '../../services/storage_service.dart';

/// Android scoped storage 下无法用 dart:io 列目录,隐藏"打开文件夹"入口
bool get _supportsFolderBrowsing => !Platform.isAndroid;

class FileExplorer extends StatefulWidget {
  const FileExplorer({super.key});

  @override
  State<FileExplorer> createState() => _FileExplorerState();
}

enum _ExplorerMode { tree, recent }

class _FileExplorerState extends State<FileExplorer> {
  _ExplorerMode _mode = _ExplorerMode.recent;

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
          const _SidebarHeader(),
          const Divider(height: 1),
          const _OpenActions(),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: SegmentedButton<_ExplorerMode>(
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
                textStyle: WidgetStatePropertyAll(
                  TextStyle(fontSize: 12),
                ),
              ),
              segments: const [
                ButtonSegment(
                  value: _ExplorerMode.tree,
                  label: Text('目录'),
                  icon: Icon(Icons.folder_outlined, size: 16),
                ),
                ButtonSegment(
                  value: _ExplorerMode.recent,
                  label: Text('最近'),
                  icon: Icon(Icons.history, size: 16),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (selection) =>
                  setState(() => _mode = selection.first),
            ),
          ),
          Expanded(
            child: _mode == _ExplorerMode.tree
                ? const _FolderTree()
                : const _RecentFilesList(),
          ),
        ],
      ),
    );
  }
}

class _SidebarHeader extends StatelessWidget {
  const _SidebarHeader();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
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

class _OpenActions extends StatelessWidget {
  const _OpenActions();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: _ActionButton(
              icon: Icons.add_circle_outline,
              label: '打开文件',
              onTap: () => context.read<TabManager>().openFilePicker(),
            ),
          ),
          if (_supportsFolderBrowsing) ...[
            const SizedBox(width: 8),
            Expanded(
              child: _ActionButton(
                icon: Icons.folder_open_outlined,
                label: '打开文件夹',
                onTap: () async {
                  final workspace = context.read<WorkspaceProvider>();
                  final path = await workspace.openFolderPicker();
                  if (path != null) {
                    workspace.openFolder(path);
                  }
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: colorScheme.primary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(fontSize: 12, color: colorScheme.primary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 目录树(按展开状态展平渲染)
class _FolderTree extends StatelessWidget {
  const _FolderTree();

  @override
  Widget build(BuildContext context) {
    final workspace = context.watch<WorkspaceProvider>();
    final colorScheme = Theme.of(context).colorScheme;
    final root = workspace.root;

    if (root == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            '打开一个文件夹\n以浏览目录',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    final rows = workspace.flattenVisible();
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final (node, depth) = rows[index];
        return _TreeRow(node: node, depth: depth);
      },
    );
  }
}

class _TreeRow extends StatelessWidget {
  final FileNode node;
  final int depth;

  const _TreeRow({required this.node, required this.depth});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final workspace = context.read<WorkspaceProvider>();
    final expanded = workspace.isExpanded(node.path);

    final icon = node.isDir
        ? (expanded ? Icons.folder_open_outlined : Icons.folder_outlined)
        : Icons.description_outlined;

    return InkWell(
      onTap: () {
        if (node.isDir) {
          workspace.toggleExpand(node);
        } else if (node.isSupported) {
          context.read<TabManager>().openFileFromPath(node.path);
        }
      },
      child: Padding(
        padding: EdgeInsets.only(left: 8.0 + depth * 14.0),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              child: node.isDir
                  ? Icon(
                      expanded
                          ? Icons.keyboard_arrow_down
                          : Icons.keyboard_arrow_right,
                      size: 16,
                      color: colorScheme.onSurfaceVariant,
                    )
                  : null,
            ),
            Icon(
              icon,
              size: 15,
              color: node.isDir
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                node.name,
                style: TextStyle(
                  fontSize: 13,
                  color: node.isDir || node.isSupported
                      ? colorScheme.onSurface
                      : colorScheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
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
    final fileName = FileService.extractFileName(path);
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
            IconButton(
              tooltip: '移除最近文件',
              icon: Icon(
                Icons.close,
                size: 16,
                color: colorScheme.onSurfaceVariant,
              ),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 28, height: 28),
              onPressed: () => _removeRecentFile(context),
            ),
          ],
        ),
      ),
    );
  }

  void _openFile(BuildContext context) {
    context.read<TabManager>().openFileFromPath(path);
  }

  Future<void> _removeRecentFile(BuildContext context) async {
    await context.read<TabManager>().removeRecentFile(path);
  }
}
