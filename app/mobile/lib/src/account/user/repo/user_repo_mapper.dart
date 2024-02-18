import 'package:exnota/src/account/user/user.dart';
import 'package:exnota/src/context/app/database.dart';

class UserRepoMapper {
  static UserTableData toRepo(User user) {
    return UserTableData(
      id: user.id,
      email: user.email,
      verified: user.verified,
      created: user.created,
      updated: user.updated,
    );
  }

  static User fromRepo(UserTableData repo) {
    return User(
      id: repo.id,
      email: repo.email,
      verified: repo.verified,
      created: repo.created,
      updated: repo.updated,
    );
  }
}
