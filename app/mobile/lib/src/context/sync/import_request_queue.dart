import 'dart:async';

import 'package:exnota/src/context/sync/connection_status.dart';
import 'package:exnota/src/context/user/pocketbase.dart';
import 'package:exnota/src/context/user/user_context.dart';
import 'package:exnota/src/lib/log/logger.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:retry/retry.dart';

part 'import_request_queue.g.dart';

// ----------------------------------------------------------------------------
// Public providers, where state is assumed loaded.
// ----------------------------------------------------------------------------

@riverpod
bool importRequestQueueUnexpectedError(
    ImportRequestQueueUnexpectedErrorRef ref) {
  return ref.watch(_importRequestQueueInternalProvider).any((r) {
    switch (r.error) {
      case RequestError.internal:
      case RequestError.other:
        return true;
      case RequestError.auth:
      case RequestError.network:
      case null:
        return false;
    }
  });
}

abstract class ImportRequest<T> {
  Future<void> request({required PocketBase pb, required Ref ref});
}

@riverpod
class ImportRequestQueue extends _$ImportRequestQueue {
  @override
  FutureOr<void> build() {
    // no-op
  }

  void addRequest(ImportRequest request) {
    ref.read(_importRequestQueueInternalProvider.notifier).addRequest(request);
  }

  void addMultipleRequests(List<ImportRequest> requests) {
    ref
        .read(_importRequestQueueInternalProvider.notifier)
        .addMultipleRequests(requests);
  }

  void retry() {
    ref.read(_importRequestQueueInternalProvider.notifier).retry();
  }
}

// ----------------------------------------------------------------------------
// Context loader widgets
// ----------------------------------------------------------------------------

/// Utility widget that watches for the next item in the import queue and
/// triggers processing of it.
class ImportRequestQueueProcessor extends ConsumerStatefulWidget {
  final Widget child;

  const ImportRequestQueueProcessor({super.key, required this.child});

  @override
  ConsumerState<ImportRequestQueueProcessor> createState() =>
      _ImportRequestQueueProcessorState();
}

class _ImportRequestQueueProcessorState
    extends ConsumerState<ImportRequestQueueProcessor> {
  final Logger _log = Logger(context: 'ImportRequestQueueProcessor');

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

    // Watching the queue will rebuild this widget on each new request in the
    // queue, but does not cause the child widget to rebuild.
    final nextInQueue = ref.watch(_nextInQueueProvider);
    final connStatus = ref.watch(connectionStatusProvider);

    if (nextInQueue != null) {
      _log.debug('Next in queue: ${nextInQueue.request.runtimeType}');
      switch (connStatus) {
        case ConnStatus.offline:
        case ConnStatus.userRetry:
        case ConnStatus.unauthenticated:
          _log.debug(
              'Ignoring next in queue due to connection status $connStatus');
          break;
        case ConnStatus.online:
          _log.debug('Processing next in queue');
          // Need to wrap in Future to avoid provider throwing an error that its
          // state was modified during the widget's lifecycle.
          Future(() {
            ref
                .read(_importRequestProcessorProvider.notifier)
                .process(nextInQueue.request);
          });
          break;
      }
    }

    // When returing online, clear error statuses of requests in queue
    ref.listen(connectionStatusProvider, (oldStatus, newStatus) {
      if (oldStatus != ConnStatus.online && newStatus == ConnStatus.online) {
        _log.debug('Clearing error statuses of requests in queue');
        ref.read(_importRequestQueueInternalProvider.notifier).retry();
      }
    });

    return widget.child;
  }
}

// ----------------------------------------------------------------------------
// Private providers - queue.
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
  final queue = ref.watch(_importRequestQueueInternalProvider);
  final first = queue.firstOrNull;
  if (first != null && first.status == RequestStatus.pending) {
    return queue.first;
  }
  return null;
}

/// The import request queue, with methods for updating it.
@riverpod
class _ImportRequestQueueInternal extends _$ImportRequestQueueInternal {
  final _log = Logger(context: 'ImportRequestQueueInternal');

  @override
  List<RequestAndStatus> build() {
    _log.debug('Building import queue');
    ref.listen(activeUserIdProvider, (oldActiveUserId, newActiveUserId) {
      // Clear import queue on logout.
      //
      // Don't clear on login (no active user to active user) because we'll get
      // a race condition where an importer's listener (e.g. block importer)
      // will add a request to the queue before this listener clears the queue.
      _log.debug(
          'Detected active user change from $oldActiveUserId to $newActiveUserId');
      if (oldActiveUserId != null && newActiveUserId == null) {
        _log.debug('User no longer active, clearing queue');
        ref.invalidateSelf();
      } else {
        _log.debug('Not clearing queue');
      }
    });
    return [];
  }

  void addRequest(ImportRequest request) {
    _log.debug('Adding request: $request');
    // Avoid duplicates: Check if a request of the same type is already in progress
    if (state.any((r) => r.request.runtimeType == request.runtimeType)) {
      _log.debug(
          'Skipping request of type ${request.runtimeType} which is already in queue.');
      return;
    }

    state = [
      ...state,
      (request: request, status: RequestStatus.pending, error: null)
    ];
  }

  // TODO: Either remove this or de-dupe requests of the same type. It was
  // added for ease of testing the queue.
  void addMultipleRequests(List<ImportRequest> requests) {
    _log.debug('Adding multiple requests: $requests');
    state = [
      ...state,
      ...requests
          .map((r) => (request: r, status: RequestStatus.pending, error: null))
    ];
  }

  void removeRequest(Type requestType) {
    _log.debug('Removing request: $requestType');
    final newState =
        state.where((r) => r.request.runtimeType != requestType).toList();

    final oldCount = state.length;
    final newCount = newState.length;
    _log.debug('Removing request: Removed ${oldCount - newCount} requests');

    state = newState;
  }

  void retry() {
    _log.debug('Retrying all errored requests');
    state = state.map((r) {
      if (r.status == RequestStatus.pending) {
        return r;
      }
      _log.debug(
          'Retrying request ${r.request.runtimeType} which had status: ${r.status}');
      return (request: r.request, status: RequestStatus.pending, error: null);
    }).toList();
  }

  void setStatus(
      {required Type requestType,
      required RequestStatus status,
      RequestError? error}) {
    _log.debug(
        'Setting status: Setting request $requestType to $status (error: $error)');
    _log.debug('Setting status: Checking ${state.length} requests');
    state = state.map((r) {
      if (r.request.runtimeType == requestType) {
        _log.debug('Setting status: Matching request found');
        return (request: r.request, status: status, error: error);
      }
      _log.debug('Setting status: Non-matching request found');
      return r;
    }).toList();
  }
}

// ----------------------------------------------------------------------------
// Private providers - individual request processor.
// ----------------------------------------------------------------------------

/// Provides a method for processing a request.
@riverpod
class _ImportRequestProcessor extends _$ImportRequestProcessor {
  final _log = Logger(context: 'ImportRequestProcessor');

  @override
  void build() {
    // no-op
  }

  Future<void> process(ImportRequest request) async {
    _log.debug('Processing request of type: ${request.runtimeType}');

    ref.read(_importRequestQueueInternalProvider.notifier).setStatus(
        requestType: request.runtimeType, status: RequestStatus.running);

    try {
      await retry(
        () => request.request(
            pb: ref.read(userContextServiceProvider).pocketBase, ref: ref),
        retryIf: (e) {
          if (e is! PocketBaseException && e is! TimeoutException) {
            _log.debug('Skipping retry of unexpected error: $e');
            return false;
          }
          if (!ref.read(hasActiveUserProvider)) {
            _log.debug('Skipping retry due to no active user');
            return false;
          }
          return true;
        },
        onRetry: (e) => _log.debug('Retrying request that threw: $e'),
        maxAttempts: 3,
      );
    } on PocketBaseException catch (e) {
      final error = getPocketBaseError(e);
      _log.debug('PocketBase error \'$error\' processing request: $e');

      if (error == PocketBaseError.auth) {
        _log.debug(
            'Setting status to auth error and connection unauthenticated');
        ref.read(_importRequestQueueInternalProvider.notifier).setStatus(
            requestType: request.runtimeType,
            status: RequestStatus.error,
            error: RequestError.auth);
        ref.read(connectionStatusProvider.notifier).setUnauthenticated();
      } else if (error == PocketBaseError.network) {
        _log.debug('Setting status to network error and connection offline');
        ref.read(_importRequestQueueInternalProvider.notifier).setStatus(
            requestType: request.runtimeType,
            status: RequestStatus.error,
            error: RequestError.network);
        ref.read(connectionStatusProvider.notifier).setOffline();
      } else {
        _log.debug('Setting status to other error');
        ref.read(_importRequestQueueInternalProvider.notifier).setStatus(
            requestType: request.runtimeType,
            status: RequestStatus.error,
            error: RequestError.other);
      }
      return;
    } on TimeoutException catch (e) {
      // A TimeoutException can be thrown if the ImportRequest instance, for
      // example, adds a .timeout() to a PocketBase request.
      _log.debug('Timeout processing request: $e');
      _log.debug(
          'Setting request status to network error and connection offline');
      ref.read(_importRequestQueueInternalProvider.notifier).setStatus(
          requestType: request.runtimeType,
          status: RequestStatus.error,
          error: RequestError.network);
      ref.read(connectionStatusProvider.notifier).setOffline();
      return;
    } on Exception catch (e) {
      // This path isn't expected for request errors, as PocketBase wraps
      // exceptions. It will likely be issues in this codebase.
      _log.error('Error processing request: $e');
      ref.read(_importRequestQueueInternalProvider.notifier).setStatus(
          requestType: request.runtimeType,
          status: RequestStatus.error,
          error: RequestError.internal);
      return;
    }

    _log.debug('Request complete, removing from queue');
    ref
        .read(_importRequestQueueInternalProvider.notifier)
        .removeRequest(request.runtimeType);
  }
}
