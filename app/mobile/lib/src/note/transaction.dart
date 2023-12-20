import 'package:exnota/src/note/operation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'transaction.freezed.dart';

@freezed
class Transaction with _$Transaction {
  const factory Transaction({
    required List<Operation> operations,
  }) = _Transaction;

  const Transaction._();
}
