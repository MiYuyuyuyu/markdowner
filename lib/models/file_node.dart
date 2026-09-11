/// 目录树节点
class FileNode {
  final String path;
  final String name;
  final bool isDir;

  /// 文件是否为应用支持的文档类型(md/markdown/txt/tex)
  final bool isSupported;

  /// 子节点;null 表示尚未加载(仅目录有此状态)
  List<FileNode>? children;

  FileNode({
    required this.path,
    required this.name,
    required this.isDir,
    required this.isSupported,
    this.children,
  });
}
