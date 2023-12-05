import 'dart:io';

import 'package:exnota/src/integration/data/notion_settings_table.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:exnota/src/lib/data/sync/sync_command_table.dart';
import 'package:exnota/src/note/data/drift/capture_table.dart';
import 'package:exnota/src/note/data/drift/note_table.dart';
import 'package:exnota/src/note/data/file/local_file_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'database.g.dart';

@Riverpod(keepAlive: true)
AppDatabase database(DatabaseRef ref) {
  // This will be added using an override in main.dart as per https://github.com/bizz84/flutter-tips-and-tricks/blob/main/tips/0056-async-init-provider-overrides/index.md
  throw UnimplementedError();
}

@riverpod
Future<T> Function<T>(Future<T> Function(), {bool requireNew}) transaction(
    TransactionRef ref) {
  final db = ref.read(databaseProvider);
  return db.transaction;
}

AppDatabase initDatabase({required LocalFile files}) {
  final String path = files.getDatabaseFilePath(filename: 'exnota.sqlite');
  return AppDatabase(path: path);
}

@DriftDatabase(tables: [
  CaptureTable,
  IntegrationNotionSettings,
  NoteTable,
  SyncCommandTable
])
class AppDatabase extends _$AppDatabase {
  AppDatabase({required String path}) : super(_openConnection(path: path));

  AppDatabase.inMemory() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 1;
}

LazyDatabase _openConnection({required String path}) {
  // the LazyDatabase util lets us find the right location for the file async.
  return LazyDatabase(() async {
    final file = File(path);
    return NativeDatabase.createInBackground(file);
  });
}
