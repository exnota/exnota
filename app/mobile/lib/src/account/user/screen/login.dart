import 'package:exnota/src/context/environment/environment.dart';
import 'package:exnota/src/context/user/user_context.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final environment = ref.watch(environmentServiceProvider);

    return Scaffold(
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
              onPressed: () async {
                await ref
                    .read(userContextServiceProvider.notifier)
                    .loginGoogle();
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
                // child: MaterialButton(
                //   onPressed: () => {},
                //   child: Visibility(
                //     visible: kDebugMode,
                //     replacement: const SizedBox(),
                //     child: Column(
                //       mainAxisAlignment: MainAxisAlignment.end,
                //       children: [
                //         DropdownMenu<Environment>(
                //           inputDecorationTheme: const InputDecorationTheme(
                //             border: null,
                //           ),
                //           initialSelection: settings.environment,
                //           onSelected: (newEnvironment) {
                //             ref
                //                 .read(settingsServiceProvider.notifier)
                //                 .setEnvironment(newEnvironment);
                //           },
                //           dropdownMenuEntries: [
                //             Environment.prod,
                //             Environment.local
                //           ].map<DropdownMenuEntry<Environment>>(
                //               (Environment value) {
                //             return DropdownMenuEntry<Environment>(
                //                 value: value, label: value.toString());
                //           }).toList(),
                //         ),
                //         const SizedBox(
                //           height: 20,
                //         ),
                //       ],
                //     ),
                //   ),
                // ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
