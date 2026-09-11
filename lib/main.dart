import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'providers/tab_manager.dart';
import 'providers/settings_provider.dart';
import 'providers/workspace_provider.dart';
import 'services/file_service.dart';
import 'services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storageService = await StorageService.init();
  final fileService = FileService();
  final tabManager = TabManager(fileService, storageService);
  final workspaceProvider = WorkspaceProvider(fileService, storageService);
  await tabManager.restoreSession();
  workspaceProvider.restoreLast();

  runApp(
    MultiProvider(
      providers: [
        Provider<StorageService>.value(value: storageService),
        Provider<FileService>.value(value: fileService),
        ChangeNotifierProvider(
            create: (_) => SettingsProvider(storageService)),
        ChangeNotifierProvider.value(value: tabManager),
        ChangeNotifierProvider.value(value: workspaceProvider),
      ],
      child: const MarkdownReaderApp(),
    ),
  );
}
