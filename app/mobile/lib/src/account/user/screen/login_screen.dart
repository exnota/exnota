import 'package:exnota/src/context/app/router.dart';
import 'package:exnota/src/context/environment/environment.dart';
import 'package:exnota/src/context/user/user_context.dart';
import 'package:exnota/src/lib/log/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'login_screen.g.dart';
part 'login_screen.freezed.dart';

enum LoginStatus {
  awaitingLogin,
  loggingIn,
  errorLogin,
  checkingVerified,
  unverified,
  fetchingUserData,
  errorUserData,
}

@freezed
class LoginState with _$LoginState {
  const factory LoginState({
    @Default(LoginStatus.awaitingLogin) LoginStatus status,
  }) = _LoginState;
}

@riverpod
class LoginScreenController extends _$LoginScreenController {
  final _log = Logger(context: 'LoginScreenController');

  @override
  LoginState build() {
    return const LoginState();
  }

  Future<void> loginGoogle() async {
    _log.debug('loginGoogle: Logging in with Google');
    state = state.copyWith(status: LoginStatus.loggingIn);
    await ref.read(userContextServiceSyncProvider.notifier).loginGoogle();

    final userContext = ref.read(userContextServiceSyncProvider);
    if (userContext.user == null) {
      _log.error('loginGoogle: Error logging in');
      state = state.copyWith(status: LoginStatus.errorLogin);
      return;
    }

    // Have not tested this path
    if (userContext.user?.verified == false) {
      _log.debug('loginGoogle: User not verified');
      state = state.copyWith(status: LoginStatus.unverified);
      return;
    }

    _log.debug('loginGoogle: User verified');
    ref.read(routerProvider.notifier).go(Screen.notes);
    state = state.copyWith(status: LoginStatus.awaitingLogin);
  }
}

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _log = Logger(context: 'LoginScreen');

  @override
  void initState() {
    super.initState();
    _log.debug('Initializing');
  }

  @override
  void dispose() {
    _log.debug('Disposing');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _log.debug('Building');
    final loginScreenState = ref.watch(loginScreenControllerProvider);

    return Scaffold(
      body: Center(
          child: switch (loginScreenState.status) {
        LoginStatus.awaitingLogin => const AwaitingLogin(),
        LoginStatus.loggingIn => const CircularProgressIndicator(),
        LoginStatus.errorLogin => const Text('Error logging in'),
        LoginStatus.checkingVerified => const CircularProgressIndicator(),
        LoginStatus.unverified => const Text('User not verified'),
        LoginStatus.fetchingUserData => const CircularProgressIndicator(),
        LoginStatus.errorUserData => const Text('Error fetching user data'),
      }),
    );
  }
}

class AwaitingLogin extends ConsumerWidget {
  const AwaitingLogin({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final environment = ref.watch(environmentServiceSyncProvider);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: Align(
            alignment: FractionalOffset.bottomCenter,
            child: MaterialButton(
              onPressed: () => {},
              child: const SizedBox(),
            ),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            ref.read(loginScreenControllerProvider.notifier).loginGoogle();
          },
          child: const Text('Google login'),
        ),
        Expanded(
          child: Align(
            alignment: FractionalOffset.bottomCenter,
            child: MaterialButton(
              onPressed: () => {},
              child: Visibility(
                visible: kDebugMode,
                replacement: const SizedBox(),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    DropdownMenu<Environment>(
                      inputDecorationTheme: const InputDecorationTheme(
                        border: null,
                      ),
                      initialSelection: environment,
                      onSelected: (newEnvironment) {
                        ref
                            .read(environmentServiceSyncProvider.notifier)
                            .setEnvironment(newEnvironment);
                      },
                      dropdownMenuEntries: [Environment.prod, Environment.local]
                          .map<DropdownMenuEntry<Environment>>(
                              (Environment value) {
                        return DropdownMenuEntry<Environment>(
                            value: value, label: value.toString());
                      }).toList(),
                    ),
                    const SizedBox(
                      height: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
