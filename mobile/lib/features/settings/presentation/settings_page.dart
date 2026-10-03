import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/inputs.dart';
import '../../auth/presentation/auth_cubit.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthCubit>().state;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.storefront),
            title: Text(auth.shop?.name ?? 'Shop'),
            subtitle: Text(auth.user?.email ?? ''),
            trailing: const Icon(Icons.edit_outlined),
            onTap: () => context.push('/settings/shop'),
          ),
          const Divider(),
          _Link(icon: Icons.sell_outlined, title: 'Sale types', path: '/settings/sale-types'),
          _Link(icon: Icons.category_outlined, title: 'Categories', path: '/settings/categories'),
          _Link(icon: Icons.people_outline, title: 'Customers', path: '/customers'),
          _Link(icon: Icons.receipt_outlined, title: 'Expenses', path: '/expenses'),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Log out'),
            onTap: () async {
              final cubit = context.read<AuthCubit>();
              final yes = await confirm(context, title: 'Log out?', action: 'Log out');
              if (yes) await cubit.logout();
            },
          ),
        ],
      ),
    );
  }
}

class _Link extends StatelessWidget {
  const _Link({required this.icon, required this.title, required this.path});

  final IconData icon;
  final String title;
  final String path;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push(path),
    );
  }
}
