import 'package:flutter/material.dart';

/// Displays detailed information about a SampleItem.
class SampleItemDetailsScreen extends StatelessWidget {
  const SampleItemDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Item Details'),
      ),
      body: const Center(
        child: Text('More Information Here'),
      ),
    );
  }
}
