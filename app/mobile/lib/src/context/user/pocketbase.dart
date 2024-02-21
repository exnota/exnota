import 'dart:io';

import 'package:exnota/src/context/user/user_context.dart';
import 'package:exnota/src/lib/log/logger.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'pocketbase.g.dart';

// ----------------------------------------------------------------------------
// Public providers, where state is assumed loaded.
// ----------------------------------------------------------------------------

@riverpod
PocketBase pocketBase(PocketBaseRef ref) {
  Logger(context: 'pocketBaseProvider').info('Building');
  final userContext = ref.watch(userContextServiceProvider);
  return userContext.pocketBase;
}

// ----------------------------------------------------------------------------
// Helpers
// ----------------------------------------------------------------------------

typedef PocketBaseException = ClientException;

enum PocketBaseError { auth, network, other }

PocketBaseError getPocketBaseError(PocketBaseException e) {
  if (e.statusCode == 401) {
    return PocketBaseError.auth;
  }

  if (e.originalError.cause.runtimeType == SocketException) {
    // TODO: #38 Distinguish server being down from network being down
    // Server being down:
    // - originalError.cause = SocketException
    // - originalError.cause.message = "Operation timed out"
    // - originalError.cause.osError.errorCode = 60
    // - originalError.cause.osError.message = "Operation timed out"
    // - originalError.address.address is not null
    return PocketBaseError.network;
  }

  return PocketBaseError.other;
}
