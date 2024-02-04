import 'package:freezed_annotation/freezed_annotation.dart';

part 'user.freezed.dart';

@freezed
class User with _$User {
  const factory User({
    required String id,
    required String email,
    required bool verified,
    // These are generated server-side
    DateTime? created,
    DateTime? updated,
  }) = _User;

  const User._();
}
