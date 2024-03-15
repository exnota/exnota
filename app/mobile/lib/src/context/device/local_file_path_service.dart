import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'local_file_path_service.g.dart';

// These paths should make some sense to users in case they browse them either
// causually or when trying to recover data.
final subdirDatabasePath = ['exnota', 'database'];
final subdirBlockAudioPath = ['exnota', 'notes', 'audio'];

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
  final blockAudioPath =
      await Directory(p.joinAll([documentsDir.path, ...subdirBlockAudioPath]))
          .create(recursive: true);

  return LocalPathGenerator._(
      databasePath: databasePath.path, blockAudioPath: blockAudioPath.path);
}

@immutable
class LocalPathGenerator {
  final String _databasePath;
  final String _blockAudioPath;

  const LocalPathGenerator._(
      {required String databasePath, required String blockAudioPath})
      : _databasePath = databasePath,
        _blockAudioPath = blockAudioPath;

  String getDatabaseFilePath({required String filename}) {
    return p.joinAll([_databasePath, filename]);
  }

  Future<String> generateAudioBlockFilePath(
      {required String localFileId, required String extension}) async {
    final path =
        p.joinAll([_blockAudioPath, 'recording-$localFileId.$extension']);
    if (await File(path).exists()) {
      throw Exception('File already exists');
    }
    return path;
  }
}
