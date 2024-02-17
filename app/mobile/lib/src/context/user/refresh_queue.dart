import 'dart:async';

import 'package:exnota/src/context/user/pocketbase.dart';
import 'package:exnota/src/context/user/user_context.dart';
import 'package:exnota/src/lib/log/logger.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:retry/retry.dart';

part 'refresh_queue.g.dart';

// TODO: Improve names, including of file

enum RequestStatus { pending, running, error }

enum RequestError { auth, network, internal, other }

typedef RefreshQueueStatus = ({
  RefreshRequest request,
  RequestStatus status,
  RequestError? error
});

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

    ref.read(refreshQueueProvider.notifier).setStatus(
        requestType: request.runtimeType, status: RequestStatus.running);

    try {
      await retry(
        () => request.request(
            pb: ref.read(userContextServiceProvider).pocketBase),
        retryIf: (e) =>
            // Retry request-related exceptions. Pocketbase wraps exceptions
            // like SocketException in ClientException.
            e is ClientException,
        onRetry: (e) => _log.debug('Retrying request that threw: $e'),
        maxAttempts: 3,
      );
    } on PocketBaseException catch (e) {
      final error = getPocketBaseError(e);
      _log.warn('Error \'$error\' processing request: $e');

      if (error == PocketBaseError.auth) {
        ref.read(refreshQueueProvider.notifier).setStatus(
            requestType: request.runtimeType,
            status: RequestStatus.error,
            error: RequestError.auth);
      } else if (error == PocketBaseError.network) {
        ref.read(refreshQueueProvider.notifier).setStatus(
            requestType: request.runtimeType,
            status: RequestStatus.error,
            error: RequestError.network);
      } else {
        ref.read(refreshQueueProvider.notifier).setStatus(
            requestType: request.runtimeType,
            status: RequestStatus.error,
            error: RequestError.other);
      }
      return;
    } on Exception catch (e) {
      // This path isn't expected for request errors, as PocketBase wraps
      // exceptions. It will likely be issues in this codebase.
      _log.error('Error processing request: $e');
      ref.read(refreshQueueProvider.notifier).setStatus(
          requestType: request.runtimeType,
          status: RequestStatus.error,
          error: RequestError.internal);
      return;
    }

    _log.debug('Request complete, removing from queue');
    ref.read(refreshQueueProvider.notifier).removeRequest(request.runtimeType);
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
bool refreshQueueErrored(RefreshQueueErroredRef ref) {
  return ref
      .watch(refreshQueueProvider)
      .any((r) => r.status == RequestStatus.error);
}

@riverpod
bool refreshQueueAuthErrored(RefreshQueueAuthErroredRef ref) {
  return ref
      .watch(refreshQueueProvider)
      .any((r) => r.error == RequestError.auth);
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
      ...requests
          .map((r) => (request: r, status: RequestStatus.pending, error: null))
    ];
  }

  void addRequest(RefreshRequest request) {
    _log.debug("Adding request: $request");
    // Avoid duplicates: Check if a request of the same type is already in progress
    if (state.any((r) => r.request.runtimeType == request.runtimeType)) {
      print("Request of type ${request.runtimeType} is already in queue.");
      return;
    }

    state = [
      ...state,
      (request: request, status: RequestStatus.pending, error: null)
    ];
  }

  void removeRequest(Type requestType) {
    _log.debug("Removing request: $requestType");
    state = state.where((r) => r.request.runtimeType != requestType).toList();
  }

  void retry() {
    _log.debug("Retrying all errored requests");
    state = state
        .map((r) =>
            (request: r.request, status: RequestStatus.pending, error: null))
        .toList();
  }

  void setStatus(
      {required Type requestType,
      required RequestStatus status,
      RequestError? error}) {
    _log.debug("Setting status for request: $requestType to $status");
    state = state.map((r) {
      if (r.request.runtimeType == requestType) {
        return (request: r.request, status: status, error: error);
      }
      return r;
    }).toList();
  }
}

abstract class RefreshRequest<T> {
  Future<void> request({required PocketBase pb});
}

class ListNotesRequestOne extends RefreshRequest<List<RecordModel>> {
  final _log = Logger(context: 'ListNotesRequestOne');

  @override
  Future<void> request({required PocketBase pb}) async {
    _log.debug('Requesting list of notes');

    // wait 5 seconds
    await Future.delayed(const Duration(seconds: 5));

    final result = await pb.collection('block').getFullList(sort: '-created');
    _log.debug('Listed ${result.length} notes');

    _log.debug('Request complete');
  }
}

class ListNotesRequestTwo extends RefreshRequest<List<RecordModel>> {
  final _log = Logger(context: 'ListNotesRequestTwo');

  @override
  Future<void> request({required PocketBase pb}) async {
    _log.debug('Requesting list of notes');

    // wait 5 seconds
    await Future.delayed(const Duration(seconds: 5));

    final result = await pb.collection('block').getFullList(sort: '-created');
    _log.debug('Listed ${result.length} notes');

    _log.debug('Request complete');
  }
}
