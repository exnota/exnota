import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'local_file_path_service.g.dart';

final subdirDatabasePath = ['exnota', 'database'];
final subdirNotesAudioPath = ['exnota', 'notes', 'audio'];

@Riverpod(keepAlive: true)
LocalPathGenerator localFilePathService(LocalFilePathServiceRef ref) {
  // This will be added using an override in main.dart as per https://github.com/bizz84/flutter-tips-and-tricks/blob/main/tips/0056-async-init-provider-overrides/index.md
  throw UnimplementedError();
}

Future<LocalPathGenerator> initLocalFilePathGenerator() async {
  final documentsDir = await getApplicationDocumentsDirectory();

  final databasePath =
      await Directory(p.joinAll([documentsDir.path, ...subdirDatabasePath]))
          .create(recursive: true);
  final notesAudioPath =
      await Directory(p.joinAll([documentsDir.path, ...subdirNotesAudioPath]))
          .create(recursive: true);

  return LocalPathGenerator._(
      databasePath: databasePath.path, notesAudioPath: notesAudioPath.path);
}

@immutable
class LocalPathGenerator {
  final String _databasePath;
  final String _notesAudioPath;

  const LocalPathGenerator._(
      {required String databasePath, required String notesAudioPath})
      : _databasePath = databasePath,
        _notesAudioPath = notesAudioPath;

  getDatabaseFilePath({required String filename}) {
    return p.joinAll([_databasePath, filename]);
  }

  deprecatedGetVoiceNoteFilePath(
      {required String captureId, required String extension}) {
    return p.joinAll([_notesAudioPath, 'capture-$captureId.$extension']);
  }

  generateAudioBlockFilePath(
      {required String blockId, required String extension}) async {
    final path = p.joinAll([_notesAudioPath, 'block-$blockId.$extension']);
    if (await File(path).exists()) {
      throw Exception("File already exists");
    }
    return path;
  }
}
