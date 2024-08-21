import 'dart:async';
import 'package:exnota/src/common/basic_response.dart';
import 'package:exnota/src/context/sync/connection_status.dart';
import 'package:exnota/src/context/sync/network.dart';
import 'package:exnota/src/context/user/pocketbase.dart';
import 'package:exnota/src/context/user/user_context.dart';
import 'package:exnota/src/lib/log/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:retry/retry.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'request_handler.g.dart';

abstract class HandledRequest<T> {
  /// Override to set a custom timeout for the request.
  Duration get timeout => defaultTimeout;

  /// Override and set to true to not make any further attempts after the
  /// current one has finished (if one is in progress).
  bool get stopRetrying => false;

  Future<T> request({required PocketBase pb, required Ref ref});
}

@riverpod
class RequestHandler extends _$RequestHandler {
  final _log = Logger(context: 'RequestHandler');

  @override
  void build() {
    // no-op
  }

  Future<BasicResponse<T>> submitWrapped<T>(
      {required HandledRequest<T> request}) async {
    final completor = Completer<BasicResponse<T>>();
    unawaited(submit(
      request: request,
      onSuccess: (results) {
        _log.debug('Success');
        completor.complete(BasicResponse.success(result: results));
      },
      onError: (error) {
        _log.error('Error', exception: error);
        completor.complete(
            BasicResponse.error(error: error.toString(), errorCode: null));
      },
    ));

    return completor.future;
  }

  /// Calls the request's [HandledRequest.request] method and handles connection
  /// errors by updating the connection status.
  ///
  /// Calls [HandledRequest.onError] if the request fails.
  Future<void> submit<T>(
      {required HandledRequest<T> request,
      Function(T)? onSuccess,
      Function(Object)? onError}) async {
    _log.debug('(${request.runtimeType}) Submitting request');

    final timeout = kDebugMode ? null : request.timeout;
    try {
      final result = await retry<T>(
        () {
          Future<T> r = request.request(
            pb: ref.read(userContextServiceSyncProvider).pocketBase,
            ref: ref,
          );
          if (timeout != null) {
            r = r.timeout(request.timeout);
          }
          return r;
        },
        retryIf: (e) {
          if (request.stopRetrying) {
            _log.debug(
                '(${request.runtimeType}) Skipping retry due to stop request');
            return false;
          }
          if (e is! PocketBaseException && e is! TimeoutException) {
            _log.debug(
                '(${request.runtimeType}) Skipping retry of unexpected error: $e');
            return false;
          }
          if (!ref.read(hasActiveUserSyncProvider)) {
            _log.debug(
                '(${request.runtimeType}) Skipping retry due to no active user');
            return false;
          }
          return true;
        },
        onRetry: (e) =>
            _log.debug('(${request.runtimeType}) Retrying after exception: $e'),
        maxAttempts: defaultRetries,
      );
      _log.debug('(${request.runtimeType}) Success. Calling onSuccess');
      onSuccess?.call(result);
    }
    // !!!!!
    // Any changes to error handling logic should (probably) be duplicated in
    // _ImportRequestProcessor
    // !!!!!
    on PocketBaseException catch (e) {
      final error = getPocketBaseError(e);
      _log.debug(
          '(${request.runtimeType}) PocketBase error \'$error\' processing request (exception: $e)');

      if (error == PocketBaseError.auth) {
        _log.debug(
            '(${request.runtimeType}) Setting connection unauthenticated');
        ref.read(connectionStatusProvider.notifier).setUnauthenticated();
      } else if (error == PocketBaseError.network) {
        _log.debug('(${request.runtimeType}) Setting connection offline');
        ref.read(connectionStatusProvider.notifier).setOffline();
      }
      _log.debug('(${request.runtimeType}) Calling onError');
      onError?.call(e);
    } on TimeoutException catch (e) {
      // A TimeoutException can be thrown if the ImportRequest instance, for
      // example, adds a .timeout() to a PocketBase request.
      _log.debug(
          '(${request.runtimeType}) Timeout processing request (${request.timeout})');
      _log.debug('(${request.runtimeType}) Setting connection offline');
      ref.read(connectionStatusProvider.notifier).setOffline();
      _log.debug('(${request.runtimeType}) Calling onError');
      onError?.call(e);
    } on Exception catch (e) {
      // This path isn't expected for request errors, as PocketBase wraps
      // exceptions. It will likely be issues in this codebase.
      _log.error('(${request.runtimeType}) Other error processing request: $e');
      _log.debug('(${request.runtimeType}) Calling onError');
      onError?.call(e);
    } on TypeError catch (e) {
      // This path isn't expected for request errors, as PocketBase wraps
      // exceptions. It will likely be issues in this codebase.
      _log.error('(${request.runtimeType}) Type error processing request: $e');
      _log.debug('(${request.runtimeType}) Calling onError');
      onError?.call(e);
    } catch (e) {
      // This path isn't expected for request errors, as PocketBase wraps
      // exceptions. It will likely be issues in this codebase.
      _log.error(
          '(${request.runtimeType}) Unexpected error processing request: $e');
      _log.debug('(${request.runtimeType}) Calling onError');
      onError?.call(e);
    }
  }

  Future<BasicResponse<T>> submitWithBasicResponse<T>(
      {required HandledRequest<T> request}) async {
    final completer = Completer<BasicResponse<T>>();
    unawaited(submit(
      request: request,
      onSuccess: (result) {
        final response = BasicResponse.success(result: result);
        completer.complete(response);
      },
      onError: (error) {
        final response =
            BasicResponse<T>.error(error: error.toString(), errorCode: null);
        completer.complete(response);
      },
    ));
    return completer.future;
  }
}
