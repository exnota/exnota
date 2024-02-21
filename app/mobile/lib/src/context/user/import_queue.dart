import 'dart:async';

import 'package:exnota/src/context/user/pocketbase.dart';
import 'package:exnota/src/context/user/user_context.dart';
import 'package:exnota/src/lib/log/logger.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:retry/retry.dart';

part 'import_queue.g.dart';

abstract class ImportRequest<T> {
  Future<void> request({required PocketBase pb, required Ref ref});
}

// ----------------------------------------------------------------------------
// Public providers, where state is assumed loaded.
// ----------------------------------------------------------------------------

@riverpod
bool importQueueErrored(ImportQueueErroredRef ref) {
  return ref
      .watch(_importQueueInternalProvider)
      .any((r) => r.status == RequestStatus.error);
}

@riverpod
bool importQueueAuthErrored(ImportQueueAuthErroredRef ref) {
  return ref
      .watch(_importQueueInternalProvider)
      .any((r) => r.error == RequestError.auth);
}

@riverpod
class ImportQueue extends _$ImportQueue {
  @override
  FutureOr<void> build() {
    // no-op
  }

  void addRequest(ImportRequest request) {
    ref.read(_importQueueInternalProvider.notifier).addRequest(request);
  }

  void addMultipleRequests(List<ImportRequest> requests) {
    ref
        .read(_importQueueInternalProvider.notifier)
        .addMultipleRequests(requests);
  }

  void retry() {
    ref.read(_importQueueInternalProvider.notifier).retry();
  }
}

// ----------------------------------------------------------------------------
// Context loader widgets
// ----------------------------------------------------------------------------

/// Utility widget that watches for the next item in the import queue and
/// triggers processing of it.
class ImportQueueProcessor extends ConsumerStatefulWidget {
  final Widget child;

  const ImportQueueProcessor({super.key, required this.child});

  @override
  ConsumerState<ImportQueueProcessor> createState() =>
      _ImportQueueProcessorState();
}

class _ImportQueueProcessorState extends ConsumerState<ImportQueueProcessor> {
  final Logger _log = Logger(context: 'ImportQueueProcessor');

  @override
  void initState() {
    _log.debug('Initializing');
    super.initState();
  }

  @override
  void dispose() {
    _log.debug('Disposing');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _log.debug('Building');
    // This rebuilds on each new request in the queue, but does not cause the
    // child to rebuild.
    final nextInQueue = ref.watch(_nextInQueueProvider);
    if (nextInQueue != null) {
      _log.debug(
          'Processing next request in queue of type: ${nextInQueue.request.runtimeType}');
      // Need to wrap in Future to avoid provider throwing an error that its
      // state was modified during the widget's lifecycle.
      Future(() {
        ref
            .read(_requestProcessorProvider.notifier)
            .process(nextInQueue.request);
      });
    }

    return widget.child;
  }
}

/// Provides a method for processing a request.
@riverpod
class _RequestProcessor extends _$RequestProcessor {
  final _log = Logger(context: 'RequestProcessor');

  @override
  void build() {
    // no-op
  }

  Future<void> process(ImportRequest request) async {
    _log.debug('Processing request of type: ${request.runtimeType}');

    ref.read(_importQueueInternalProvider.notifier).setStatus(
        requestType: request.runtimeType, status: RequestStatus.running);

    try {
      await retry(
        () => request.request(
            pb: ref.read(userContextServiceProvider).pocketBase, ref: ref),
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
        ref.read(_importQueueInternalProvider.notifier).setStatus(
            requestType: request.runtimeType,
            status: RequestStatus.error,
            error: RequestError.auth);
      } else if (error == PocketBaseError.network) {
        ref.read(_importQueueInternalProvider.notifier).setStatus(
            requestType: request.runtimeType,
            status: RequestStatus.error,
            error: RequestError.network);
      } else {
        ref.read(_importQueueInternalProvider.notifier).setStatus(
            requestType: request.runtimeType,
            status: RequestStatus.error,
            error: RequestError.other);
      }
      return;
    } on Exception catch (e) {
      // This path isn't expected for request errors, as PocketBase wraps
      // exceptions. It will likely be issues in this codebase.
      _log.error('Error processing request: $e');
      ref.read(_importQueueInternalProvider.notifier).setStatus(
          requestType: request.runtimeType,
          status: RequestStatus.error,
          error: RequestError.internal);
      return;
    }

    _log.debug('Request complete, removing from queue');
    ref
        .read(_importQueueInternalProvider.notifier)
        .removeRequest(request.runtimeType);
  }
}

// ----------------------------------------------------------------------------
// Private providers.
// ----------------------------------------------------------------------------

enum RequestStatus { pending, running, error }

enum RequestError { auth, network, internal, other }

typedef RequestAndStatus = ({
  ImportRequest request,
  RequestStatus status,
  RequestError? error
});

/// Returns the next request that is ready for processing, or none if either:
/// - There are no requests in the queue
/// - The first request is not pending (e.g. it's already running or errored)
@riverpod
RequestAndStatus? _nextInQueue(_NextInQueueRef ref) {
  final queue = ref.watch(_importQueueInternalProvider);
  final first = queue.firstOrNull;
  if (first != null && first.status == RequestStatus.pending) {
    return queue.first;
  }
  return null;
}

/// The import request queue, with methods for updating it.
@riverpod
class _ImportQueueInternal extends _$ImportQueueInternal {
  final _log = Logger(context: 'ImportQueueInternal');

  @override
  List<RequestAndStatus> build() {
    _log.debug('Building import queue');
    ref.listen(activeUserIdProvider, (oldUserId, newUserId) {
      _log.debug('Active user changed, clearing queue');
      ref.invalidateSelf();
    });
    return [];
  }

  void addRequest(ImportRequest request) {
    _log.debug("Adding request: $request");
    // Avoid duplicates: Check if a request of the same type is already in progress
    if (state.any((r) => r.request.runtimeType == request.runtimeType)) {
      _log.debug(
          "Skipping request of type ${request.runtimeType} which is already in queue.");
      return;
    }

    state = [
      ...state,
      (request: request, status: RequestStatus.pending, error: null)
    ];
  }

  // TODO: Either remove this or de-dupe requests of the same type
  void addMultipleRequests(List<ImportRequest> requests) {
    _log.debug("Adding multiple requests: $requests");
    state = [
      ...state,
      ...requests
          .map((r) => (request: r, status: RequestStatus.pending, error: null))
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
