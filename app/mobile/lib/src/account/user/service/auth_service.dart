import 'package:exnota/src/account/settings/uri_service.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:url_launcher/url_launcher.dart';

part 'auth_service.g.dart';
part 'auth_service.freezed.dart';

@riverpod
class PocketBaseService extends _$PocketBaseService {
  @override
  PocketBase build() {
    final baseUrl = ref.watch(uriServiceProvider);

    if (stateOrNull != null) {
      // Rebuild to trigger provider watchers
      final store = stateOrNull?.authStore;
      return PocketBase(baseUrl.toString(), authStore: store);
    }

    return PocketBase(baseUrl.toString());
  }

  Future<void> signIn() async {
    await state.collection('user').authWithOAuth2('google', (url) async {
      // or use something like flutter_custom_tabs to make the transitions between native and web content more seamless
      await launchUrl(url);
    });

    await closeInAppWebView();

    ref.invalidateSelf();
  }
}

@freezed
class AuthStatus with _$AuthStatus {
  const factory AuthStatus({required User? user, required String? error}) =
      _AuthStatus;
}

@freezed
class User with _$User {
  const factory User({required String id, required String email}) = _User;
}

@riverpod
bool loggedIn(LoggedInRef ref) {
  final pb = ref.watch(pocketBaseServiceProvider);
  return pb.authStore.isValid;
}
