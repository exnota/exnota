import 'package:exnota/src/context/app/router.dart';
import 'package:exnota/src/integration/screen/setup_error_message.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BaseWidgetScaffold extends ConsumerWidget {
  final Widget child;

  const BaseWidgetScaffold({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Connect to Notion',
          style: TextStyle(fontSize: 16),
        ),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              ref.read(routerProvider.notifier).pop();
            },
          ),
        ],
      ),
      body: Container(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}

class BaseSetupView extends StatelessWidget {
  final String header;
  final List<Widget> contentChildren;
  final List<Widget> buttonChildren;

  const BaseSetupView({
    super.key,
    required this.header,
    required this.contentChildren,
    required this.buttonChildren,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Header(text: header),
            ...contentChildren,
          ],
        ),
        Align(
          alignment: Alignment.centerRight,
          child: Column(
            children: buttonChildren,
          ),
        ),
      ],
    );
  }
}
