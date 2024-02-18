import 'package:exnota/src/account/user/repo/user_repo_mapper.dart';
import 'package:exnota/src/account/user/user.dart';
import 'package:exnota/src/lib/data/drift/database.dart';
import 'package:exnota/src/lib/log/logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'user_repo.g.dart';

@riverpod
UserRepo userRepo(UserRepoRef ref) {
  final db = ref.watch(databaseProvider);
  return UserRepo(db);
}

class UserRepo {
  final AppDatabase db;
  final Logger logger = Logger();

  UserRepo(this.db);

  Future<User?> get({required String id}) async {
    final query = db.select(db.userTable);
    query.where((tbl) => tbl.id.equals(id));
    return await query.map(UserRepoMapper.fromRepo).getSingleOrNull();
  }

  Future<User> getOrThrow({required String id}) async {
    final query = db.select(db.userTable);
    query.where((tbl) => tbl.id.equals(id));
    return await query.map(UserRepoMapper.fromRepo).getSingle();
  }

  Future<void> upsert(User user) async {
    final repo = UserRepoMapper.toRepo(user);
    await db.into(db.userTable).insertOnConflictUpdate(repo);
  }

  Future<void> create(User user) async {
    logger.info('Creating user');
    final repo = UserRepoMapper.toRepo(user);
    await db.into(db.userTable).insert(repo);
  }

  Future<void> update(User user) async {
    logger.info('Updating user');
    final repo = UserRepoMapper.toRepo(user);
    await db.update(db.userTable).replace(repo);
  }
}
