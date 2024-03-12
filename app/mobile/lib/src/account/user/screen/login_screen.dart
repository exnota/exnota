import 'package:exnota/src/context/app/router.dart';
import 'package:exnota/src/context/environment/environment.dart';
import 'package:exnota/src/context/user/user_context.dart';
import 'package:exnota/src/lib/log/logger.dart';
import 'package:exnota/widget.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'login_screen.g.dart';
part 'login_screen.freezed.dart';

// freezed model with one property called 'loggingIn' (boolean)
@freezed
class LoginState with _$LoginState {
  const factory LoginState({
    @Default(false) bool loggingIn,
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
    _log.debug('Logging in with Google');
    state = state.copyWith(loggingIn: true);
    await ref.read(userContextServiceProvider.notifier).loginGoogle();
    ref.read(routerProvider.notifier).go(Screen.notes);
    state = state.copyWith(loggingIn: false);
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
    final environment = ref.watch(environmentServiceProvider);
    final loginScreenState = ref.watch(loginScreenControllerProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO:
          widgetToggle();
        },
        child: const Icon(Icons.record_voice_over),
      ),
      body: Center(
        child: Column(
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
              child: switch (loginScreenState.loggingIn) {
                false => const Text('Google login'),
                true => const CircularProgressIndicator(),
              },
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
                                .read(environmentServiceProvider.notifier)
                                .setEnvironment(newEnvironment);
                          },
                          dropdownMenuEntries: [
                            Environment.prod,
                            Environment.local
                          ].map<DropdownMenuEntry<Environment>>(
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
        ),
      ),
    );
  }
}
