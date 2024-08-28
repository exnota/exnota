import 'package:exnota/src/context/app/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SetupErrorMessage<T> extends ConsumerWidget {
  final String error;
  final String? customMessage;
  final T? errorRetryStatus;
  final void Function()? onRetry;

  const SetupErrorMessage(
      {super.key,
      required this.error,
      this.errorRetryStatus,
      this.customMessage,
      required this.onRetry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Header(
              text: 'There was an error :(',
            ),
            const SizedBox(height: 8),
            if (customMessage != null) ...[
              Text(customMessage!),
            ],
            if (customMessage == null)
              if (error.contains('SocketException'))
                const Text(
                  'We couldn\'t connect to Exnota\'s servers. Please check your connection and try again.',
                )
              else
                const Text('We\'re not sure what happened. Please try again.'),
          ],
        ),
        Align(
          alignment: Alignment.centerRight,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (errorRetryStatus != null) ...[
                TextButton(
                  onPressed: () {
                    ref.read(routerProvider.notifier).pop();
                  },
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 16),
                FilledButton(
                  onPressed: onRetry,
                  child: const Text('Try again'),
                )
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class Header extends StatelessWidget {
  final String text;

  const Header({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 24,
          letterSpacing: -1.0, // Decrease kerning
        ),
      ),
    );
  }
}
