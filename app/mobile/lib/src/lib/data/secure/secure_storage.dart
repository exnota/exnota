import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum SecureStorageKey { databasePassphrase, localSettings, environmentSettings }

class SecureStorage {
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
      aOptions: AndroidOptions(
    encryptedSharedPreferences: true,
  ));

  Future<String?> read({required SecureStorageKey key}) async {
    // Apparently if the app is backgrounded, secure storage may be locked on
    // iOS so something like this may be needed (as per https://pub.dev/packages/flutter_secure_storage):
    // final options = IOSOptions(accessibility: IOSAccessibility.first_unlock);
    // await storage.write(key: key, value: value, iOptions: options);

    return await _storage.read(key: _keyToString(key));
  }

  Future<void> write(
      {required SecureStorageKey key, required String value}) async {
    // Apparently if the app is backgrounded, secure storage may be locked on
    // iOS so something like this may be needed (as per https://pub.dev/packages/flutter_secure_storage):
    // final options = IOSOptions(accessibility: IOSAccessibility.first_unlock);
    // await storage.write(key: key, value: value, iOptions: options);

    await _storage.write(key: _keyToString(key), value: value);
  }

  String _keyToString(SecureStorageKey key) {
    switch (key) {
      case SecureStorageKey.databasePassphrase:
        return 'exnota.databasePassphrase';
      case SecureStorageKey.localSettings:
        return 'exnota.localSettings';
      case SecureStorageKey.environmentSettings:
        return 'exnota.environmentSettings';
    }
  }
}
