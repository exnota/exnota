import 'dart:io';

import 'package:exnota/src/context/user/user_context.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'pocketbase.g.dart';

// ----------------------------------------------------------------------------
// Sync providers that assume dependent states have been loaded
// ----------------------------------------------------------------------------

@riverpod
PocketBase pocketBaseSync(PocketBaseSyncRef ref) {
  return ref.watch(userContextServiceSyncProvider).pocketBase;
}

@riverpod
Uri urlSync(UrlSyncRef ref, String path) {
  final pb = ref.watch(pocketBaseSyncProvider);
  return pb.buildUrl(path);
}

// ----------------------------------------------------------------------------
// Async providers
// ----------------------------------------------------------------------------

@riverpod
Future<PocketBase> pocketBase(PocketBaseRef ref) async {
  final userContext = await ref.watch(userContextServiceProvider.future);
  return userContext.pocketBase;
}

@riverpod
Future<Uri> url(UrlRef ref, String path) async {
  final pb = await ref.watch(pocketBaseProvider.future);
  return pb.buildUrl(path);
}

// ----------------------------------------------------------------------------
// Helpers - errors
// ----------------------------------------------------------------------------

typedef PocketBaseException = ClientException;

enum PocketBaseError { auth, network, other }

PocketBaseError getPocketBaseError(PocketBaseException e) {
  if (e.statusCode == 401) {
    return PocketBaseError.auth;
  }

  if (e.originalError?.cause.runtimeType == SocketException) {
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

// ----------------------------------------------------------------------------
// Helpers - others
// ----------------------------------------------------------------------------

const collectionBlock = 'block';
