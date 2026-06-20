import 'dart:io';
import 'package:file_picker/file_picker.dart';

class FileService {
  static const _allowedExtensions = ['md', 'markdown', 'txt', 'tex'];

  Future<PlatformFile?> pickMarkdownFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _allowedExtensions,
      allowMultiple: false,
    );
    return result?.files.firstOrNull;
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

  String extractFileName(String path) {
    return path.split(Platform.pathSeparator).last;
  }
}
