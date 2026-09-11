import 'dart:io';

import 'package:flutter/material.dart';

/// Markdown 图片渲染:网络图/本地文件图自适应宽度、圆角,点击全屏缩放查看。
Widget buildMarkdownImage(String url, Map<String, String> attributes) {
  final width = double.tryParse(attributes['width'] ?? '');
  final height = double.tryParse(attributes['height'] ?? '');

  final Widget image;
  if (url.startsWith('http')) {
    image = Image.network(
      url,
      fit: BoxFit.contain,
      width: width,
      height: height,
      errorBuilder: (_, _, _) => _brokenImagePlaceholder(url),
    );
  } else if (File(url).existsSync()) {
    image = Image.file(
      File(url),
      fit: BoxFit.contain,
      width: width,
      height: height,
      errorBuilder: (_, _, _) => _brokenImagePlaceholder(url),
    );
  } else {
    image = Image.asset(
      url,
      fit: BoxFit.contain,
      width: width,
      height: height,
      errorBuilder: (_, _, _) => _brokenImagePlaceholder(url),
    );
  }

  return Builder(
    builder: (context) => GestureDetector(
      onTap: () => _showImageViewer(context, url),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: image,
      ),
    ),
  );
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

void _showImageViewer(BuildContext context, String url) {
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
                  : (File(url).existsSync()
                      ? Image.file(File(url), fit: BoxFit.contain)
                      : Image.asset(url, fit: BoxFit.contain)),
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
