import 'package:exnota/src/account/settings/uri_service.dart';
import 'package:exnota/src/account/user/repo/user_auth_repo.dart';
import 'package:exnota/src/account/user/repo/user_repo.dart';
import 'package:exnota/src/account/user/user.dart';
import 'package:exnota/src/account/user/user_auth.dart';
import 'package:exnota/src/lib/data/drift/database.dart';
import 'package:exnota/src/lib/data/id_generator.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:url_launcher/url_launcher.dart';

part 'user_context_service.g.dart';
part 'user_context_service.freezed.dart';

@freezed
class UserContext with _$UserContext {
  const factory UserContext({
    required PocketBase pocketBase,
    UserAuth? userAuth,
    String? error,
  }) = _UserContext;
}

// Keep alive to minimise the PocketBase object being recreated.
@Riverpod(keepAlive: true)
class UserContextService extends _$UserContextService {
  @override
  Future<UserContext> build() async {
    final transaction = ref.read(transactionProvider);
    return await transaction(() async {
      final userAuthRepo = ref.read(userAuthRepoProvider);
      final userAuth = await userAuthRepo.getActive();
      if (userAuth == null) {
        final baseUrl = ref.read(uriServiceProvider);
        final pb = PocketBase(baseUrl.toString());
        return UserContext(pocketBase: pb);
      }

      final authStore = AuthStore();
      final token = userAuth.token;
      if (token != null) {
        final user =
            await ref.read(userRepoProvider).getOrThrow(id: userAuth.userId);
        authStore.save(token, user.toRecord());
      }

      final baseUrl = ref.read(uriServiceProvider);
      return UserContext(
        pocketBase: PocketBase(baseUrl.toString(), authStore: authStore),
        userAuth: userAuth,
      );
    });
  }

  Future<void> loginGoogle() async {
    // Prompt user to auth
    final userContext = await future;
    var pb = userContext.pocketBase;
    final authResult =
        await pb.collection('user').authWithOAuth2('google', (url) async {
      // or use something like flutter_custom_tabs to make the transitions between native and web content more seamless
      await launchUrl(url);
    });
    await closeInAppWebView();

    final transaction = ref.read(transactionProvider);
    await transaction(() async {
      // Create or update user from auth response
      final userRecord = authResult.record;
      if (userRecord == null) {
        // Assume auth error (have not verified if this is true)
        state = AsyncData(userContext.copyWith(error: 'Auth error'));
        return;
      }
      final user = User.fromRecord(userRecord);
      await ref.read(userRepoProvider).upsert(user);

      // Create or update user auth
      final userAuthRepo = ref.read(userAuthRepoProvider);
      var userAuth = await userAuthRepo.getForUser(userId: user.id);
      final authStore = pb.authStore;
      if (userAuth != null) {
        userAuth = userAuth.copyWith(
            valid: authStore.isValid, active: true, token: authStore.token);
        await userAuthRepo.upsertAndSetOthersInactive(userAuth);
      } else {
        userAuth = UserAuth.generateTimestamps(
          id: generateId(),
          userId: user.id,
          active: true,
          valid: authStore.isValid,
          token: authStore.token,
        );
        await userAuthRepo.upsertAndSetOthersInactive(userAuth);
      }

      state = AsyncData(userContext.copyWith(userAuth: userAuth, error: null));
      return;
    });
  }

  Future<void> logout() async {
    final now = DateTime.now();
    final userAuthRepo = ref.read(userAuthRepoProvider);
    final userAuth = await userAuthRepo.logoutActive(updated: now);

    final userContext = await future;
    userContext.pocketBase.authStore.clear();

    state = AsyncData(userContext.copyWith(userAuth: userAuth, error: null));
  }
}

/// Assumes user context service is already loaded
@riverpod
PocketBase pocketBase(PocketBaseRef ref) {
  final userContext = ref.read(userContextServiceProvider).asData?.value;
  return userContext!.pocketBase;
}
