import 'package:drift/drift.dart';
import 'package:exnota/src/account/user/repo/user_auth_repo_mapper.dart';
import 'package:exnota/src/account/user/user_auth.dart';
import 'package:exnota/src/lib/data/drift/database.dart';
import 'package:exnota/src/lib/log/logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'user_auth_repo.g.dart';

@riverpod
UserAuthRepo userAuthRepo(UserAuthRepoRef ref) {
  final db = ref.read(databaseProvider);
  return UserAuthRepo(db);
}

class UserAuthRepo {
  final AppDatabase db;
  final Logger logger = Logger();

  UserAuthRepo(this.db);

  Future<UserAuth?> getActive() async {
    final query = db.select(db.userAuthTable);
    query.where((tbl) => tbl.active.equals(true));
    return await query.map(UserAuthRepoMapper.fromRepo).getSingleOrNull();
  }

  Future<UserAuth?> getForUser({required String userId}) async {
    final query = db.select(db.userAuthTable);
    query.where((tbl) => tbl.userId.equals(userId));
    return await query.map(UserAuthRepoMapper.fromRepo).getSingleOrNull();
  }

  Future<void> upsertAndSetOthersInactive(UserAuth userAuth) async {
    logger.info('Upserting user auth and setting others inactive');
    final repo = UserAuthRepoMapper.toRepo(userAuth);

    await db.transaction(() async {
      await db.into(db.userAuthTable).insertOnConflictUpdate(repo);

      await (db.update(db.userAuthTable)
            ..where((tbl) => tbl.id.isNotIn([userAuth.id])))
          .write(const UserAuthTableCompanion(active: Value(false)));
    });
  }
}
