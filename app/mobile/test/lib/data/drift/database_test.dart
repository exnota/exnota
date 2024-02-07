import 'package:exnota/src/lib/data/drift/database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DatabasePassphrase.generate', () {
    test('Should generate passwords using expected characters and lengths', () {
      for (var i = 0; i < 500; i++) {
        final key = DatabasePassphrase.generate();
        expect(key.length, greaterThanOrEqualTo(50));
        expect(key.length, lessThanOrEqualTo(80));
        expect(key.contains(RegExp(r'[^A-Za-z0-9]')), false);
      }
    });
  });
}
