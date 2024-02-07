import 'package:exnota/src/lib/data/secure/secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlutterSecureStorage.setMockInitialValues({});
  group('SecureStorage', () {
    test('Should read and write values', () async {
      final storage = SecureStorage();
      await storage.write(
          key: SecureStorageKey.databasePassphrase, value: 'test value');
      final value =
          await storage.read(key: SecureStorageKey.databasePassphrase);
      expect(value, 'test value');
    });
  });
}
