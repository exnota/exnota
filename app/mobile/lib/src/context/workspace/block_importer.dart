// so maybe one provider that has the loading state
// 1. blockImporterStatusProvider: true/false
// 2. blockImporterProvider: with method: 'import'

import 'package:exnota/src/context/user/pocketbase.dart';
import 'package:exnota/src/lib/log/logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'block_importer.g.dart';

@Riverpod(keepAlive: true)
class BlockImporterStatus extends _$BlockImporterStatus {
  @override
  bool build() {
    return false;
  }

  void set({required bool value}) {
    state = value;
  }
}

@Riverpod(keepAlive: false)
class BlockImporter extends _$BlockImporter {
  final _log = Logger(context: 'BlockImporter');

  @override
  void build() {
    // no-op
  }

  Future<void> import() async {
    _log.debug('Importing blocks');
    ref.read(blockImporterStatusProvider.notifier).set(value: true);

    try {
      final pb = ref.watch(pocketBaseProvider);

      // TODO: How to handle auth and connectivity issues.
      // - If an auth issue, we probably want to flag this and block network
      //   requests to the backend (unless the user does some force retry).
      //   - Then hint to the user to log out and log back in
      //   - But we shouldn't block the creating of new blocks, etc.
      // - If detected as a connectivity issue, we should retry with a backoff
      //   but I'm not sure what would manage that. At least at a generic level
      //   when we are going to be importing more than just blocks, like workspace
      //   info, account info, etc.
      // - If an unknown issue, we probably want to treat it similar to a
      //   connectivity issue. Though in the future it might have some differences
      //   to how we present it to the user. For now though maybe it's identical.
      // All this kinda suggestes we should have something like the command
      // export sync but for importing.
      //
      // Some importing might be done in sequence, e.g. import user, then
      // workspace, then blocks.
      //
      // But for some the order won't matter as much, e.g. periodic block/account
      // updates as the user uses the app.
      //
      // The latter is simple to support, just a basic queue. The former is
      // a bit different because we want one layer to wait before moving
      // on to the next, but we probably also don't want two completely
      // different systems. So they system should support knowing when a
      // specific set of data has finished importing.
      //
      // Actually, we don't wanna block, say, block imports on user imports
      // unless there is no actual user. And if there's no user, we wouldn't
      // be loading the block importer anyway.
      //
      // Remember we're using PocketBase client, so we can't intercept HTTP
      // requests, etc.
      //
      // https://pub.dev/packages/pocketbase#error-handling
      //
      // I don't think we need to add a database queue to this, because it
      // doesn't need persistence between app open/closing.
      //
      // But we can do essentially the same thing, I suppose, with Riverpod.
      //
      // We add jobs to a queue and process them. Although we probably don't
      // want to serialize/deserialize... which I assume we'd have to?
      // Actually I guess not if the queue is just given a name, and it does
      // a switch from that name to the job type.
      //
      // So something like this:
      //
      // List UI:
      // - User presses refresh button, or visits the page
      // - it calls stateProvider.import()
      //
      // - stateProvider adds 'blockImport' to queue
      //   - if there's already one there, is does nothing
      // - stateProvider.status() becomes loading
      //
      // - some job listener sees 'blockImport' in the queue, finds the appropriate
      //   BlockImporter class, and calls it.
      // - The importer needs to specificy some methods:
      //   - the pocketbase call, which will return some records or something
      //     (the importer system should try/catch on certain errors)
      //   - then a method to do something with the records
      // - if the pocketbase method throws one of a set of errors, it will auto
      //   retry with a backoff.
      //
      // But how does the relationship work between the thing that holds the
      // queue and state, and the thing that processes them, because once the
      // job is done, the state needs to be updated. I suppose it can call
      // a 'remove' method or something on the queue. Therefore the queue provider
      // doesn't need to listen to anything itself.
      //
      // The one trick here is I'm not sure this will work for blocking the
      // whole import queue if there's a network issue.
      //
      // I suppose it should be fine if we have a single processor that listens
      // to the queue and works sequentially. It pops the first item and starts
      // running it. If it fails, it waits and retries according to some rules.
      //
      // TODO: Map out a basic structure for the queue and queue processor.
      //
      // TODO: It should be able to tell the user when it's done.
      //
      // TODO: Also, probably need to clear some of these queues when logging out.

      // _log.debug('Fetching blocks from backend...');
      // final resultList =
      //     await pb.collection('block').getFullList(sort: '-created');
      // _log.debug('Fetched ${resultList.length} blocks');

      // final mapped = resultList
      //     .map((e) => PBBlock(id: e.id, title: e.data['title']))
      //     .toList();
    } catch (e) {
      // TODO:
    }

    ref.read(blockImporterStatusProvider.notifier).set(value: false);
  }
}
