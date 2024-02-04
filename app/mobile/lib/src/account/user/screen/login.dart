import 'package:exnota/src/account/user/service/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            await ref.read(pocketBaseServiceProvider.notifier).signIn();
          },
          child: const Text('Google login'),
        ),
      ),
    );
  }
}
