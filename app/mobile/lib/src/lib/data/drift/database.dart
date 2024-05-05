import 'dart:math';

import 'package:exnota/src/context/device/local_file_path_service.dart';
import 'package:exnota/src/lib/data/secure/secure_storage.dart';
import 'package:exnota/src/lib/data/sync/repo/sync_command_table.dart';
import 'package:exnota/src/lib/file/repo/drift/local_file_table.dart';
import 'package:exnota/src/lib/log/logger.dart';
import 'package:exnota/src/block/repo/drift/block_table.dart';
import 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart';
import 'dart:io';

import 'package:exnota/src/account/user/repo/user_auth_table.dart';
import 'package:exnota/src/account/user/repo/user_table.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
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
  final db = ref.watch(databaseProvider);
  return db.transaction;
}

AppDatabase initDatabase({required LocalPathGenerator files}) {
  final String path = files.getDatabaseFilePath(filename: 'exnota.sqlite');
  return AppDatabase(path: path);
}

@DriftDatabase(tables: [
  // IntegrationNotionSettings,
  BlockTable,
  LocalFileTable,
  SyncCommandTable,
  UserAuthTable,
  UserTable,
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

    // This will throw an error if done inside `setup` passed to NativeDatabase.careatedInBackground.
    // This seems to be because it's run in a background isolate and this isn't
    // supported by flutter_secure_storage, at least not without further setup.
    final passphrase = await getPassphrase();

    return NativeDatabase.createInBackground(file, isolateSetup: setupSqlCipher,
        setup: (rawDb) async {
      // Ensure the correct library is being used. It's possible for SQLCipher
      // and sqlite3 to conflict with each other: https://drift.simonbinder.eu/docs/platforms/encryption/#important-notice
      //
      // Note: This assertion failed when initially added it. `flutter clean`
      // fixed it.
      assert(_debugCheckHasCipher(rawDb));

      // Set passphrase
      //
      // The pragma command doesn't support prepared statements, so do a simple
      // escape just for safety, even though it shouldn't be necessary at time
      // of writing.
      final escapedPassphrase = passphrase.replaceAll("'", "''");
      rawDb.execute("PRAGMA key = '$escapedPassphrase';");

      // Test passphrase. This will error if it's wrong. Setting the pragma key
      // alone won't error if it's wrong.
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

// TODO: #45 Risk: If passphrase is deleted, non-synced data will be lost.
Future<String> getPassphrase() async {
  final log = Logger(context: 'DatabasePassphrase');
  final storage = SecureStorage();
  var passphrase = await storage.read(key: SecureStorageKey.databasePassphrase);
  if (passphrase == null) {
    log.debug('Generating new passphrase');
    passphrase = DatabasePassphrase.generate();
    await storage.write(
        key: SecureStorageKey.databasePassphrase, value: passphrase);
  } else {
    log.debug('Using existing passphrase');
  }
  return passphrase;
}

class DatabasePassphrase {
  static const _chars =
      'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890';
  static const minLength = 50;
  static const maxLength = 80;

  static String generate() {
    Random r = Random.secure();
    // choose number between minLength and maxLength
    final length = r.nextInt(maxLength - minLength) + minLength;

    return String.fromCharCodes(Iterable.generate(
        length,
        (_) => _chars.codeUnitAt(
              r.nextInt(_chars.length),
            )));
  }
}
