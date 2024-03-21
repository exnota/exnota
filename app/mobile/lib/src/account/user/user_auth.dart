import 'package:exnota/src/lib/clock.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_auth.freezed.dart';

@freezed
class UserAuth with _$UserAuth {
  const factory UserAuth({
    required String id,
    required String userId,

    // The last user to be logged in.
    required bool active,

    // If the user's login is expected to still be valid.
    required bool valid,
    String? token,
    required DateTime created,
    required DateTime updated,
  }) = _UserAuth;

  // Use a separarate constructor for generating timestamps, because default
  // values using freezed are a little awkward: https://github.com/rrousselGit/freezed/issues/64#issuecomment-1270337550
  factory UserAuth.generateTimestamps({
    required String id,
    required String userId,
    required bool active,
    required bool valid,
    String? token,
  }) {
    final now = Clock().now();
    return UserAuth(
      id: id,
      userId: userId,
      active: active,
      valid: valid,
      token: token,
      created: now,
      updated: now,
    );
  }
}
