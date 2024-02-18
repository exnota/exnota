import 'package:exnota/src/account/user/user_auth.dart';
import 'package:exnota/src/context/app/database.dart';

class UserAuthRepoMapper {
  static UserAuthTableData toRepo(UserAuth user) {
    return UserAuthTableData(
      id: user.id,
      userId: user.userId,
      active: user.active,
      valid: user.valid,
      token: user.token,
      created: user.created,
      updated: user.updated,
    );
  }

  static UserAuth fromRepo(UserAuthTableData repo) {
    return UserAuth(
      id: repo.id,
      userId: repo.userId,
      active: repo.active,
      valid: repo.valid,
      token: repo.token,
      created: repo.created,
      updated: repo.updated,
    );
  }
}
