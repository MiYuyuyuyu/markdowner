import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/file_node.dart';
import '../services/file_service.dart';
import '../services/storage_service.dart';

/// 工作区(打开的文件夹)目录树状态。
/// 目录列表为同步列出(桌面本地盘足够快),展开子目录时按需加载。
class WorkspaceProvider extends ChangeNotifier {
  final FileService _fileService;
  final StorageService _storageService;

  String? _rootPath;
  FileNode? _root;
  final Set<String> _expanded = {};

  WorkspaceProvider(this._fileService, this._storageService);

  String? get rootPath => _rootPath;
  FileNode? get root => _root;
  bool isExpanded(String path) => _expanded.contains(path);

  /// 弹出系统文件夹选择器,返回所选路径(取消返回 null)
  Future<String?> openFolderPicker() => _fileService.pickDirectory();

  /// 启动时恢复上次打开的工作区
  void restoreLast() {
    final last = _storageService.getLastWorkspace();
    if (last != null && Directory(last).existsSync()) {
      openFolder(last, persist: false);
    }
  }

  /// 打开文件夹;[persist] 为 false 时不写入最近记录(用于启动恢复)
  void openFolder(String path, {bool persist = true}) {
    final dir = Directory(path);
    if (!dir.existsSync()) return;

    _rootPath = path;
    _expanded
      ..clear()
      ..add(path);
    _root = _buildNode(dir);
    if (_root != null) _loadChildren(_root!);

    if (persist) {
      _storageService.addRecentFolder(path);
    }
    notifyListeners();
  }

  /// 切换目录展开/收起;首次展开时加载子节点
  void toggleExpand(FileNode node) {
    if (!node.isDir) return;
    if (_expanded.contains(node.path)) {
      _expanded.remove(node.path);
    } else {
      _expanded.add(node.path);
      if (node.children == null) _loadChildren(node);
    }
    notifyListeners();
  }

  /// 重新加载整个目录树(保留展开状态)
  void refresh() {
    if (_rootPath == null) return;
    openFolder(_rootPath!, persist: false);
    notifyListeners();
  }

  FileNode _buildNode(FileSystemEntity entity) {
    final name = entity.path.split(Platform.pathSeparator).last;
    if (entity is Directory) {
      return FileNode(
        path: entity.path,
        name: name,
        isDir: true,
        isSupported: true,
      );
    }
    return FileNode(
      path: entity.path,
      name: name,
      isDir: false,
      isSupported: _fileService.isSupportedFile(entity.path),
    );
  }

  void _loadChildren(FileNode dirNode) {
    final children = _fileService
        .listEntries(dirNode.path)
        .map(_buildNode)
        .toList();
    dirNode.children = children;
  }

  /// 目录树可见行(按展开状态展平),供列表渲染
  List<(FileNode, int)> flattenVisible() {
    final rows = <(FileNode, int)>[];
    if (_root == null) return rows;

    void walk(FileNode node, int depth) {
      rows.add((node, depth));
      if (node.isDir &&
          node.children != null &&
          _expanded.contains(node.path)) {
        for (final child in node.children!) {
          walk(child, depth + 1);
        }
      }
    }

    walk(_root!, 0);
    return rows;
  }
}
