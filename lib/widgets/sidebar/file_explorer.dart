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

/// 侧边栏:目录树 + 最近文件夹 + 最近文件 的合并分区视图。
/// 各分区可折叠;最近条目可移除记录(不影响磁盘文件)。
class FileExplorer extends StatefulWidget {
  /// 面板宽度(由拖动分隔条调整,持久化于设置)
  final double width;

  const FileExplorer({super.key, this.width = 260});

  @override
  State<FileExplorer> createState() => _FileExplorerState();
}

class _FileExplorerState extends State<FileExplorer> {
  bool _treeExpanded = true;
  bool _recentFoldersExpanded = true;
  bool _recentFilesExpanded = true;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: widget.width,
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
          Expanded(
            child: _buildSections(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSections(BuildContext context) {
    final workspace = context.watch<WorkspaceProvider>();
    // 监听 TabManager:移除最近文件等操作通过它通知刷新
    context.watch<TabManager>();
    final storageService = context.read<StorageService>();
    final recentFolders = storageService.getRecentFolders();
    final hasWorkspace = workspace.root != null;
    final recentFiles = storageService.getRecentFiles();
    // 目录树分区在最近文件之前也常驻:有工作区显示树,无工作区显示引导
    final sections = <Widget>[
      _Section(
        title: hasWorkspace ? '目录' : '目录 (未打开)',
        expanded: _treeExpanded,
        onToggle: () => setState(() => _treeExpanded = !_treeExpanded),
        child: hasWorkspace && _treeExpanded
            ? const _FolderTree()
            : (hasWorkspace
                ? null
                : const _SectionHint(text: '打开文件夹后在此浏览目录')),
      ),
      if (_supportsFolderBrowsing)
        _Section(
          title: '最近文件夹 (${recentFolders.length})',
          expanded: _recentFoldersExpanded,
          onToggle: () =>
              setState(() => _recentFoldersExpanded = !_recentFoldersExpanded),
          child: _recentFoldersExpanded
              ? _RecentFoldersList(folders: recentFolders)
              : null,
        ),
      _Section(
        title: '最近文件 (${recentFiles.length})',
        expanded: _recentFilesExpanded,
        onToggle: () =>
            setState(() => _recentFilesExpanded = !_recentFilesExpanded),
        child:
            _recentFilesExpanded ? _RecentFilesList(paths: recentFiles) : null,
      ),
    ];

    return Column(
      children: [
        // 目录树占主要空间
        Expanded(
          flex: 5,
          child: sections[0],
        ),
        const Divider(height: 1),
        // 最近分区各自限高,超出内部滚动
        if (_supportsFolderBrowsing)
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 168),
            child: sections[1],
          ),
        const Divider(height: 1),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 200),
          child: sections[2],
        ),
      ],
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

/// 可折叠分区标题(仿 Cursor:标题 + 数量 + 折叠箭头)
class _Section extends StatelessWidget {
  final String title;
  final bool expanded;
  final VoidCallback onToggle;
  final Widget? child;

  const _Section({
    required this.title,
    required this.expanded,
    required this.onToggle,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Row(
              children: [
                AnimatedRotation(
                  turns: expanded ? 0.25 : 0,
                  duration: const Duration(milliseconds: 150),
                  child: Icon(
                    Icons.keyboard_arrow_right,
                    size: 16,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurfaceVariant,
                      letterSpacing: 0.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (expanded && child != null) Expanded(child: child!),
        if (expanded && child == null) const SizedBox(height: 4),
      ],
    );
  }
}

class _SectionHint extends StatelessWidget {
  final String text;

  const _SectionHint({required this.text});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 2, 16, 8),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
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
    final root = workspace.root;

    if (root == null) {
      return const _SectionHint(text: '打开文件夹后在此浏览目录');
    }

    final rows = workspace.flattenVisible();
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 4),
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

/// 最近文件夹列表:点击打开工作区,× 移除记录
class _RecentFoldersList extends StatelessWidget {
  final List<String> folders;

  const _RecentFoldersList({required this.folders});

  @override
  Widget build(BuildContext context) {
    if (folders.isEmpty) {
      return const _SectionHint(text: '暂无最近文件夹');
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 4),
      itemCount: folders.length,
      itemBuilder: (context, index) {
        final path = folders[index];
        final name = FileService.extractFileName(path);
        final colorScheme = Theme.of(context).colorScheme;
        return InkWell(
          onTap: () {
            context.read<WorkspaceProvider>().openFolder(path);
          },
          child: Padding(
            padding: const EdgeInsets.only(left: 24),
            child: Row(
              children: [
                Icon(Icons.folder_outlined,
                    size: 15, color: colorScheme.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    name,
                    style: TextStyle(
                        fontSize: 13, color: colorScheme.onSurface),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  tooltip: '移除最近文件夹记录',
                  icon: Icon(
                    Icons.close,
                    size: 16,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints.tightFor(width: 44, height: 36),
                  onPressed: () => context
                      .read<WorkspaceProvider>()
                      .removeRecentFolder(path),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 最近文件列表:点击打开,× 移除记录
class _RecentFilesList extends StatelessWidget {
  final List<String> paths;

  const _RecentFilesList({required this.paths});

  @override
  Widget build(BuildContext context) {
    if (paths.isEmpty) {
      return const _SectionHint(text: '暂无最近文件');
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 4),
      itemCount: paths.length,
      itemBuilder: (context, index) {
        final path = paths[index];
        final fileName = FileService.extractFileName(path);
        final dirPath =
            path.substring(0, path.length - fileName.length - 1);
        final colorScheme = Theme.of(context).colorScheme;

        return InkWell(
          onTap: () => context.read<TabManager>().openFileFromPath(path),
          child: Padding(
            padding: const EdgeInsets.only(left: 24),
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
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints.tightFor(width: 44, height: 36),
                  onPressed: () =>
                      context.read<TabManager>().removeRecentFile(path),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
