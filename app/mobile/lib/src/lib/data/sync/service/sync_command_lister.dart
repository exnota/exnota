import 'package:exnota/src/lib/data/drift/database.dart';
import 'package:exnota/src/lib/data/sync/repo/sync_command_repo.dart';
import 'package:exnota/src/lib/data/sync/sync_command.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'sync_command_lister.g.dart';

@riverpod
Stream<List<SyncCommand>> syncCommandLister(SyncCommandListerRef ref) {
  final db = ref.read(databaseProvider);
  final commandRepo = SyncCommandRepo(db);
  return commandRepo.fetchAllStream();
}
