import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reflect_os/features/auth/providers/auth_action_provider.dart';

class BillingSubscribeScreen extends ConsumerWidget {
  const BillingSubscribeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscription required'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () =>
                ref.read(authActionProvider.notifier).signOut(),
          ),
        ],
      ),
      body: const Center(child: Text('Subscription required')),
    );
  }
}
