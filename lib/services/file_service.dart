import 'dart:io';
import 'package:file_picker/file_picker.dart';

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

  /// 打开文件夹选择器(桌面端);Android scoped storage 下无法列出返回路径
  Future<String?> pickDirectory() {
    return FilePicker.platform.getDirectoryPath();
  }

  /// 列出目录下的一级条目:子目录 + 支持的文档文件。
  /// 跳过隐藏项与常见构建目录;目录在前,按名称排序。
  List<FileSystemEntity> listEntries(String dirPath) {
    final dir = Directory(dirPath);
    if (!dir.existsSync()) return [];

    final entries = dir.listSync()..removeWhere((entity) {
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
