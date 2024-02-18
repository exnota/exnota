import 'package:drift/drift.dart';
import 'package:exnota/src/account/user/repo/user_auth_repo_mapper.dart';
import 'package:exnota/src/account/user/user_auth.dart';
import 'package:exnota/src/lib/data/drift/database.dart';
import 'package:exnota/src/lib/log/logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'user_auth_repo.g.dart';

@riverpod
UserAuthRepo userAuthRepo(UserAuthRepoRef ref) {
  final db = ref.watch(databaseProvider);
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

      final query = db.update(db.userAuthTable)
        ..where((tbl) => tbl.id.isNotIn([userAuth.id]));
      await query.write(const UserAuthTableCompanion(active: Value(false)));
    });
  }

  Future<UserAuth> logoutActive({required DateTime updated}) async {
    logger.info('Logging out active user');
    return await db.transaction(() async {
      final active = await (db.select(db.userAuthTable)
            ..where((tbl) => tbl.active.equals(true)))
          .getSingle();

      try {
        final query = db.update(db.userAuthTable)
          ..where((tbl) => tbl.id.equals(active.id));

        await query.write(UserAuthTableCompanion(
          active: const Value(false),
          valid: const Value(false),
          token: const Value(null),
          updated: Value(updated),
        ));
      } catch (e) {
        logger.error('Error logging out active user');
      }

      return await (db.select(db.userAuthTable)
            ..where((tbl) => tbl.id.equals(active.id)))
          .map(UserAuthRepoMapper.fromRepo)
          .getSingle();
    });
  }
}
