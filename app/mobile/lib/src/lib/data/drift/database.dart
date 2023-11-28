import 'dart:io';

import 'package:exnota/src/integration/data/notion_settings_table.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:exnota/src/lib/data/sync/sync_command_table.dart';
import 'package:exnota/src/note/data/drift/note_table.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'database.g.dart';

@Riverpod(keepAlive: true)
AppDatabase database(DatabaseRef ref) {
  // This will be added using an override in main.dart as per https://github.com/bizz84/flutter-tips-and-tricks/blob/main/tips/0056-async-init-provider-overrides/index.md
  throw UnimplementedError();
}

AppDatabase initDatabase() {
  return AppDatabase();
}

@DriftDatabase(tables: [IntegrationNotionSettings, NoteTable, SyncCommandTable])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;
}

LazyDatabase _openConnection() {
  // the LazyDatabase util lets us find the right location for the file async.
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'exnota.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
