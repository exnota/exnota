import 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart';
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
import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart';

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
    return NativeDatabase.createInBackground(file, isolateSetup: setupSqlCipher,
        setup: (rawDb) {
      // Ensure the correct library is being used. It's possible for SQLCipher
      // and sqlite3 to conflict with each other: https://drift.simonbinder.eu/docs/platforms/encryption/#important-notice
      //
      // Note: This assertion failed when initially added it. `flutter clean`
      // fixed it.
      assert(_debugCheckHasCipher(rawDb));
      // TODO: Get key from shared prefs
      rawDb.execute("PRAGMA key = 'passphrase';");

      // TODO: Escape
      // // Then, apply the key to encrypt the database. Unfortunately, this
      //   // pragma doesn't seem to support prepared statements so we inline the
      //   // key.
      //   final escapedKey = _encryptionPassword.replaceAll("'", "''");
      //   db.execute("pragma key = '$escapedKey'");

      // Test that the key is correct by selecting from a table
      rawDb.execute('select count(*) from sqlite_master');
    });
  });
}

void setupSqlCipher() {
  open.overrideFor(OperatingSystem.android, () => openCipherOnAndroid());
}

bool _debugCheckHasCipher(Database database) {
  return database.select('PRAGMA cipher_version;').isNotEmpty;
}
