import 'dart:io';

import 'package:exnota/src/account/user/repo/user_auth_table.dart';
import 'package:exnota/src/account/user/repo/user_table.dart';
import 'package:exnota/src/integration/repo/notion_settings_table.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:exnota/src/lib/data/sync/repo/sync_command_table.dart';
import 'package:exnota/src/lib/file/repo/drift/local_file_table.dart';
import 'package:exnota/src/lib/file/service/local_file_path_service.dart';
import 'package:exnota/src/note/repo/drift/block_table.dart';
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

AppDatabase initDatabase({required LocalPathGenerator files}) {
  final String path = files.getDatabaseFilePath(filename: 'exnota.sqlite');
  return AppDatabase(path: path);
}

@DriftDatabase(tables: [
  IntegrationNotionSettings,
  SyncCommandTable,
  BlockTable,
  LocalFileTable,
  UserTable,
  UserAuthTable,
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
