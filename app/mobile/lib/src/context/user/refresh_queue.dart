import 'dart:async';
import 'dart:io';

import 'package:exnota/src/context/user/user_context.dart';
import 'package:exnota/src/lib/log/logger.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:retry/retry.dart';

part 'refresh_queue.g.dart';

enum RequestStatus { pending, running, error }

typedef RefreshQueueStatus = ({RefreshRequest request, RequestStatus status});

class RefreshQueueObserver extends ConsumerWidget {
  final Widget child;

  const RefreshQueueObserver({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nextInQueue = ref.watch(nextInQueueProvider);
    if (nextInQueue != null) {
      // Need to wrap in Future to avoid provider throwing an error that its
      // state was modified during the widget's lifecycle.
      Future(() {
        ref.read(queueProcessorProvider.notifier).process(nextInQueue.request);
      });
    }

    return child;
  }
}

@riverpod
class QueueProcessor extends _$QueueProcessor {
  final _log = Logger(context: 'QueueProcessor');

  @override
  void build() {
    // no-op
  }

  Future<void> process(RefreshRequest request) async {
    _log.debug('Processing request');

    ref
        .read(refreshQueueProvider.notifier)
        .setStatus(request.runtimeType, RequestStatus.running);

    // TODO: What happens if it exceeds the retry limit? Assume it throws.
    // TODO: Provide a way to notify user when their auth has expired.
    // TODO: Provide a way to distinguish between a PocketBase request fail and
    // some other failure such as a DB persistence error.
    final success = await retry(
      () =>
          request.request(pb: ref.read(userContextServiceProvider).pocketBase),
      // TODO: Ensure this is handling the desired exceptions
      retryIf: (e) => e is SocketException || e is TimeoutException,
      onRetry: (e) => _log.debug('Retrying request that threw: $e'),
    );

    if (success) {
      ref
          .read(refreshQueueProvider.notifier)
          .removeRequest(request.runtimeType);
    } else {
      ref
          .read(refreshQueueProvider.notifier)
          .setStatus(request.runtimeType, RequestStatus.error);
    }
  }
}

/// Returns the next request that is ready for processing, or none if either:
/// - There are no requests in the queue
/// - The first request is not pending (e.g. it's already running or errored)
@riverpod
RefreshQueueStatus? nextInQueue(NextInQueueRef ref) {
  final queue = ref.watch(refreshQueueProvider);
  final first = queue.firstOrNull;
  if (first != null && first.status == RequestStatus.pending) {
    return queue.first;
  }
  return null;
}

@riverpod
class RefreshQueue extends _$RefreshQueue {
  final _log = Logger(context: 'RefreshQueue');

  @override
  List<RefreshQueueStatus> build() {
    return [];
  }

  // TODO: Either remove this or de-dupe requests of the same type
  void addMultipleRequests(List<RefreshRequest> requests) {
    _log.debug("Adding multiple requests: $requests");
    state = [
      ...state,
      ...requests.map((r) => (request: r, status: RequestStatus.pending))
    ];
  }

  void addRequest(RefreshRequest request) {
    _log.debug("Adding request: $request");
    // Avoid duplicates: Check if a request of the same type is already in progress
    if (state.any((r) => r.request.runtimeType == request.runtimeType)) {
      print("Request of type ${request.runtimeType} is already in queue.");
      return;
    }

    state = [...state, (request: request, status: RequestStatus.pending)];
  }

  void removeRequest(Type requestType) {
    _log.debug("Removing request: $requestType");
    state = state.where((r) => r.request.runtimeType != requestType).toList();
  }

  void setStatus(Type requestType, RequestStatus status) {
    _log.debug("Setting status for request: $requestType to $status");
    state = state.map((r) {
      if (r.request.runtimeType == requestType) {
        return (request: r.request, status: status);
      }
      return r;
    }).toList();
  }
}

abstract class RefreshRequest<T> {
  Future<bool> request({required PocketBase pb});

  Future<void> persist({required T data});
}

class ListNotesRequestOne extends RefreshRequest<List<RecordModel>> {
  final _log = Logger(context: 'ListNotesRequestOne');

  @override
  Future<bool> request({required PocketBase pb}) async {
    _log.debug('Requesting list of notes');

    // wait 5 seconds
    await Future.delayed(const Duration(seconds: 5));

    final result = await pb.collection('block').getFullList(sort: '-created');
    _log.debug('Listed ${result.length} notes');

    _log.debug('Request complete');

    return true;
  }

  @override
  Future<void> persist({required data}) {
    _log.debug('Persisting data: $data');

    // TODO:
    print("Persisting data: $data");
    return Future.value();
  }
}

class ListNotesRequestTwo extends RefreshRequest<List<RecordModel>> {
  final _log = Logger(context: 'ListNotesRequestTwo');

  @override
  Future<bool> request({required PocketBase pb}) async {
    _log.debug('Requesting list of notes');

    // wait 5 seconds
    await Future.delayed(const Duration(seconds: 5));

    final result = await pb.collection('block').getFullList(sort: '-created');
    _log.debug('Listed ${result.length} notes');

    _log.debug('Request complete');

    return true;
  }

  @override
  Future<void> persist({required data}) {
    _log.debug('Persisting data: $data');

    // TODO:
    print("Persisting data: $data");
    return Future.value();
  }
}
