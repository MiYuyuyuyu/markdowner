import 'dart:io';

import 'package:flutter/material.dart';

import 'link_support.dart';

/// Markdown 图片渲染:网络图/本地文件图自适应宽度、圆角,点击全屏缩放查看。
/// 相对路径图片基于 [basePath](当前文档路径)所在目录解析。
Widget buildMarkdownImage(
  String url,
  Map<String, String> attributes, {
  String? basePath,
}) {
  final width = double.tryParse(attributes['width'] ?? '');
  final height = double.tryParse(attributes['height'] ?? '');

  final localPath = _resolveLocalImagePath(url, basePath);

  final Widget image;
  if (url.startsWith('http')) {
    image = Image.network(
      url,
      fit: BoxFit.contain,
      width: width,
      height: height,
      errorBuilder: (_, _, _) => _brokenImagePlaceholder(url),
    );
  } else if (localPath != null && File(localPath).existsSync()) {
    image = Image.file(
      File(localPath),
      fit: BoxFit.contain,
      width: width,
      height: height,
      errorBuilder: (_, _, _) => _brokenImagePlaceholder(url),
    );
  } else {
    // 本地文件不存在时回退为资源图(保持旧行为)
    image = Image.asset(
      localPath ?? url,
      fit: BoxFit.contain,
      width: width,
      height: height,
      errorBuilder: (_, _, _) => _brokenImagePlaceholder(url),
    );
  }

  return Builder(
    builder: (context) => GestureDetector(
      onTap: () => _showImageViewer(context, url, localPath),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: image,
      ),
    ),
  );
}

/// 把图片地址解析为本地绝对路径;网络图或无法解析时返回 null。
String? _resolveLocalImagePath(String url, String? basePath) {
  final link = parseMarkdownLink(url, basePath);
  if (link == null || link.kind != MarkdownLinkKind.localFile) return null;
  return link.target;
}

Widget _brokenImagePlaceholder(String url) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.grey.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(6),
    ),
    child: const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.broken_image_outlined, size: 18, color: Colors.grey),
        SizedBox(width: 6),
        Text('图片加载失败', style: TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    ),
  );
}

void _showImageViewer(BuildContext context, String url, String? localPath) {
  showDialog(
    context: context,
    builder: (_) => Dialog.fullscreen(
      backgroundColor: Colors.black87,
      child: Stack(
        children: [
          InteractiveViewer(
            maxScale: 8,
            child: Center(
              child: url.startsWith('http')
                  ? Image.network(url, fit: BoxFit.contain)
                  : (localPath != null && File(localPath).existsSync()
                      ? Image.file(File(localPath), fit: BoxFit.contain)
                      : Image.asset(localPath ?? url, fit: BoxFit.contain)),
            ),
          ),
          Positioned(
            top: 24,
            right: 24,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    ),
  );
}
