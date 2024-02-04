import 'package:exnota/src/account/user/repo/user_repo_mapper.dart';
import 'package:exnota/src/account/user/user.dart';
import 'package:exnota/src/lib/data/drift/database.dart';
import 'package:exnota/src/lib/log/logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'user_repo.g.dart';

@riverpod
UserRepo userRepo(UserRepoRef ref) {
  final db = ref.read(databaseProvider);
  return UserRepo(db);
}

class UserRepo {
  final AppDatabase db;
  final Logger logger = Logger();

  UserRepo(this.db);

  Future<void> create(User user) async {
    logger.info('Creating user');
    final repo = UserRepoMapper.toRepo(user);
    await db.into(db.userTable).insert(repo);
  }
}
