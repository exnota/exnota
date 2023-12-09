import 'package:nanoid2/nanoid2.dart';

String generateId() {
  return nanoid(
      length: 14,
      alphabet:
          "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz");
}
