import 'package:nanoid2/nanoid2.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'id_generator.g.dart';

@riverpod
String Function() idGenerator(IdGeneratorRef ref) {
  return generateId;
}

String generateId() {
  return nanoid(
      length: 15,
      alphabet:
          '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz');
}
