import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/inputs.dart';
import 'auth_cubit.dart';
import 'auth_form.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  static const _minPasswordLength = 8;

  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    context.read<AuthCubit>().register(
          fullName: _name.text,
          email: _email.text,
          password: _password.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    return AuthForm(
      title: 'Create your account',
      subtitle: 'Start tracking your shop in a minute',
      formKey: _formKey,
      submitLabel: 'Create account',
      onSubmit: _submit,
      footer: TextButton(
        onPressed: () => context.go('/login'),
        child: const Text('Already have an account? Log in'),
      ),
      fields: [
        TextFormField(
          controller: _name,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Your name'),
          validator: requiredText,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Email'),
          validator: (value) =>
              requiredText(value) ?? (value!.contains('@') ? null : 'Enter a valid email'),
        ),
        const SizedBox(height: 16),
        PasswordField(
          controller: _password,
          onSubmitted: _submit,
          validator: (value) => (value ?? '').length < _minPasswordLength
              ? 'Use at least $_minPasswordLength characters'
              : null,
        ),
      ],
    );
  }
}
