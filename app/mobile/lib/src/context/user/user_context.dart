import 'dart:isolate';

import 'package:exnota/src/account/user/repo/user_auth_repo.dart';
import 'package:exnota/src/account/user/repo/user_repo.dart';
import 'package:exnota/src/account/user/user.dart';
import 'package:exnota/src/account/user/user_auth.dart';
import 'package:exnota/src/context/environment/base_url.dart';
import 'package:exnota/src/context/lib/provider.dart';
import 'package:exnota/src/lib/data/drift/database.dart';
import 'package:exnota/src/lib/data/id_generator.dart';
import 'package:exnota/src/lib/log/logger.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:url_launcher/url_launcher.dart';

part 'user_context.g.dart';
part 'user_context.freezed.dart';

// ----------------------------------------------------------------------------
// Sync providers that assume dependent states have been loaded
// ----------------------------------------------------------------------------

/// Returns user ID or throws if no active user.
///
/// Intended for screens that should not be reachable without an active user.
@riverpod
String activeUserIdOrThrowSync(ActiveUserIdOrThrowSyncRef ref) {
  final userContext = ref.watch(userContextServiceSyncProvider);
  if (!_hasActiveUser(userContext)) {
    throw StateError('No active user');
  }
  return userContext.userAuth!.userId;
}

/// Returns ID of active user or null if no active user.
///
/// Intended for contexts or screens where there may be no active user (e.g.
/// login screen).
@riverpod
String? activeUserIdSync(ActiveUserIdSyncRef ref) {
  final userContext = ref.watch(userContextServiceSyncProvider);
  if (!_hasActiveUser(userContext)) {
    return null;
  }
  return userContext.userAuth!.userId;
}

@riverpod
bool hasActiveUserSync(HasActiveUserSyncRef ref) {
  final userContext = ref.watch(userContextServiceSyncProvider);
  return _hasActiveUser(userContext);
}

bool _hasActiveUser(UserContext userContext) {
  return userContext.userAuth?.active == true;
}

@Riverpod()
class UserContextServiceSync extends _$UserContextServiceSync {
  @override
  UserContext build() {
    return ref.watch(userContextServiceProvider).requireValue;
  }

  Future<void> loginGoogle() async {
    return await ref.read(userContextServiceProvider.notifier).loginGoogle();
  }

  Future<void> logout() async {
    return await ref.read(userContextServiceProvider.notifier).logout();
  }
}

// ----------------------------------------------------------------------------
// Context loader providers
// ----------------------------------------------------------------------------

/// Returns the parent provider's loading status and won't refresh when the
/// parents state value changes, so can be used as as part of a guard to ensure
/// the parent provider is loaded.
@riverpod
ProviderLoadingStatus userContextLoadingStatus(
    UserContextLoadingStatusRef ref) {
  final userContext = ref.watch(userContextServiceProvider);
  return userContext.maybeWhen(
    data: (_) => ProviderLoadingStatus.loaded,
    error: (_, __) => ProviderLoadingStatus.error,
    orElse: () => ProviderLoadingStatus.loading,
  );
}

@riverpod
String? userContextLoadingError(UserContextLoadingErrorRef ref) {
  final userContext = ref.watch(userContextServiceProvider);
  return switch (userContext) {
    AsyncError(:final error) => error.toString(),
    _ => null,
  };
}

// ----------------------------------------------------------------------------
// Async providers
// ----------------------------------------------------------------------------

@riverpod
Future<bool> hasActiveUser(HasActiveUserRef ref) async {
  final userContext = await ref.watch(userContextServiceProvider.future);
  return _hasActiveUser(userContext);
}

@riverpod
Future<String?> activeUserId(ActiveUserIdRef ref) async {
  final userContext = await ref.watch(userContextServiceProvider.future);
  if (!_hasActiveUser(userContext)) {
    return null;
  }
  return userContext.userAuth!.userId;
}

@freezed
class UserContext with _$UserContext {
  const factory UserContext({
    required PocketBase pocketBase,
    UserAuth? userAuth,
    String? error,
  }) = _UserContext;
}

@Riverpod()
class UserContextService extends _$UserContextService {
  final Logger _log = Logger(context: 'UserContextService');

  @override
  Future<UserContext> build() async {
    _log.info('build: Building user context service');
    final baseUrl = await ref.watch(baseUrlProvider.future);
    final transaction = ref.watch(transactionProvider);
    final userAuthRepo = ref.watch(userAuthRepoProvider);

    return await transaction(() async {
      final userAuth = await userAuthRepo.getActive();
      if (userAuth == null) {
        _log.info('build: Creating user context with no user auth');

        final pb = PocketBase(baseUrl.toString());
        return UserContext(pocketBase: pb);
      }

      final authStore = AuthStore();
      final token = userAuth.token;
      if (token != null) {
        _log.info('build: Using found token');
        final user =
            await ref.watch(userRepoProvider).getOrThrow(id: userAuth.userId);
        authStore.save(token, user.toRecord());
      }

      _log.info('build: Creating user context with user auth');
      Isolate.current.hashCode == Isolate.current.debugName;
      return UserContext(
        pocketBase: PocketBase(baseUrl.toString(), authStore: authStore),
        userAuth: userAuth,
      );
    });
  }

  Future<void> loginGoogle() async {
    _log.info('loginGoogle: Logging in with Google');
    // Prompt user to auth
    final userContext = await future;
    var pb = userContext.pocketBase;
    late RecordAuth authResult;
    try {
      // TODO: #36 If server is down, this will hang. Not sure PocketBase SDK
      // supports timeouts either.
      authResult =
          await pb.collection('user').authWithOAuth2('google', (url) async {
        // or use something like flutter_custom_tabs to make the transitions between native and web content more seamless
        _log.info('loginGoogle: Opening URL');
        await launchUrl(url);
      });
    } on ClientException catch (e) {
      _log.warn('loginGoogle: Client exception logging in with Google',
          error: e);
      state = AsyncData(
          userContext.copyWith(error: 'Error logging in with Google'));
      return;
    } catch (e) {
      _log.warn('loginGoogle: Error logging in with Google', error: e);
      state = AsyncData(
          userContext.copyWith(error: 'Error logging in with Google'));
      return;
    }
    _log.info('loginGoogle: Closing in app web view');
    await closeInAppWebView();

    final transaction = ref.read(transactionProvider);
    await transaction(() async {
      // Create or update user from auth response
      final userRecord = authResult.record;
      if (userRecord == null) {
        _log.info('loginGoogle: No user record in auth response');
        // Assume auth error (have not verified if this is true)
        state = AsyncData(userContext.copyWith(error: 'Auth error'));
        return;
      }
      _log.info('loginGoogle: Creating or updating user');
      final user = User.fromRecord(userRecord);
      await ref.read(userRepoProvider).upsert(user);

      // Create or update user auth
      final userAuthRepo = ref.read(userAuthRepoProvider);
      var userAuth = await userAuthRepo.getForUser(userId: user.id);
      final authStore = pb.authStore;
      if (userAuth != null) {
        _log.info('loginGoogle: Updating existing user auth');
        userAuth = userAuth.copyWith(
            valid: authStore.isValid, active: true, token: authStore.token);
        await userAuthRepo.upsertAndSetOthersInactive(userAuth);
      } else {
        _log.info('loginGoogle: Creating new user auth');
        userAuth = UserAuth.generateTimestamps(
          id: generateId(),
          userId: user.id,
          active: true,
          valid: authStore.isValid,
          token: authStore.token,
        );
        await userAuthRepo.upsertAndSetOthersInactive(userAuth);
      }

      _log.info('loginGoogle: Updating user context');
      state = AsyncData(userContext.copyWith(userAuth: userAuth, error: null));
      return;
    });
  }

  Future<void> logout() async {
    _log.info('logout: Logging out');
    final now = DateTime.now();
    final userAuthRepo = ref.read(userAuthRepoProvider);
    final userAuth = await userAuthRepo.logoutActive(updated: now);

    final userContext = await future;
    userContext.pocketBase.authStore.clear();

    _log.info('logout: Updating user context');
    state = AsyncData(userContext.copyWith(userAuth: userAuth, error: null));

    _log.info('logout: Logging out complete');
  }
}
