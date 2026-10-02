import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';

class FileService {
  static const _allowedExtensions = ['md', 'markdown', 'txt', 'tex'];
  static const _excludedDirNames = {
    '.git', '.dart_tool', '.idea', '.vscode', 'build', 'node_modules',
  };

  /// 目录树中展示的文件是否为支持的文档类型
  bool isSupportedFile(String path) {
    final name = path.split(Platform.pathSeparator).last;
    final dot = name.lastIndexOf('.');
    if (dot < 0) return false;
    return _allowedExtensions.contains(name.substring(dot + 1).toLowerCase());
  }

  Future<PlatformFile?> pickMarkdownFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _allowedExtensions,
      allowMultiple: false,
    );
    return result?.files.firstOrNull;
  }

  /// 打开文件夹选择器。Android 上 SAF 会把所选目录换算成
  /// 真实路径(如 /storage/emulated/0/...),需提前取得
  /// "所有文件访问"权限,dart:io 才能列出其中内容。
  Future<String?> pickDirectory() {
    return FilePicker.platform.getDirectoryPath();
  }

  /// 确保可以列出用户选定的文件夹内容;未授权时引导授权并返回结果。
  /// Android 11+ 需要"所有文件访问"(MANAGE_EXTERNAL_STORAGE,
  /// 只能在系统设置中授予);低版本走常规存储权限;桌面端无需处理。
  Future<bool> ensureFolderAccess() async {
    if (!Platform.isAndroid) return true;

    var status = await Permission.manageExternalStorage.status;
    if (status.isGranted) return true;
    status = await Permission.manageExternalStorage.request();
    return status.isGranted;
  }

  /// 列出目录下的一级条目:子目录 + 支持的文档文件。
  /// 跳过隐藏项与常见构建目录;目录在前,按名称排序。
  List<FileSystemEntity> listEntries(String dirPath) {
    final dir = Directory(dirPath);
    if (!dir.existsSync()) return [];

    List<FileSystemEntity> entries;
    try {
      entries = dir.listSync();
    } on FileSystemException {
      // 个别目录无权限(如 Android 的受限目录)时按空目录处理
      return [];
    }

    entries.removeWhere((entity) {
      final name = entity.path.split(Platform.pathSeparator).last;
      if (name.startsWith('.')) return true;
      if (entity is Directory) return _excludedDirNames.contains(name);
      return !isSupportedFile(entity.path);
    });

    entries.sort((a, b) {
      final aDir = a is Directory;
      final bDir = b is Directory;
      if (aDir != bDir) return aDir ? -1 : 1;
      return a.path.toLowerCase().compareTo(b.path.toLowerCase());
    });
    return entries;
  }

  Future<List<PlatformFile>> pickMultipleFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _allowedExtensions,
      allowMultiple: true,
    );
    return result?.files ?? [];
  }

  Future<String> readFile(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw FileSystemException('File not found', path);
    }
    return file.readAsString();
  }

  /// 提取文件名,兼容正斜杠与反斜杠混合路径
  static String extractFileName(String path) {
    final normalized = path.replaceAll('\\', '/');
    final segments = normalized.split('/');
    return segments.lastWhere(
      (segment) => segment.isNotEmpty,
      orElse: () => path,
    );
  }
}
