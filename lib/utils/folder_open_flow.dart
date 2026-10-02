import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/workspace_provider.dart';
import '../services/file_service.dart';

/// 选择并打开文件夹工作区(欢迎页与侧栏共用入口)。
///
/// Android 上先确保"所有文件访问"权限(SAF 选择器只回传路径,
/// 列目录内容需要该权限),未授予时提示用户;其余平台直接选择。
Future<void> pickAndOpenFolder(BuildContext context) async {
  // 提前捕获:跨 async gap 后不再触碰已可能失效的 context
  final messenger = ScaffoldMessenger.maybeOf(context);
  final workspace = context.read<WorkspaceProvider>();
  final fileService = context.read<FileService>();

  if (!await fileService.ensureFolderAccess()) {
    messenger?.showSnackBar(const SnackBar(
      content: Text('浏览文件夹需要在系统设置中授予"所有文件"访问权限'),
      behavior: SnackBarBehavior.floating,
    ));
    return;
  }

  final path = await workspace.openFolderPicker();
  if (path == null) return;

  if (!Directory(path).existsSync()) {
    messenger?.showSnackBar(SnackBar(
      content: Text('无法访问所选文件夹:$path'),
      behavior: SnackBarBehavior.floating,
    ));
    return;
  }
  workspace.openFolder(path);
}
