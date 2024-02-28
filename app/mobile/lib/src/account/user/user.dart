import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketbase/pocketbase.dart';

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

  factory User.fromRecord(RecordModel model) {
    return User(
      id: model.id,
      email: model.data['email'],
      verified: model.data['verified'],
      created: DateTime.tryParse(model.created),
      updated: DateTime.tryParse(model.updated),
    );
  }

  RecordModel toRecord() {
    return RecordModel(
        id: id,
        data: {
          'email': email,
          'verified': verified,
        },
        collectionName: 'user');
  }
}
