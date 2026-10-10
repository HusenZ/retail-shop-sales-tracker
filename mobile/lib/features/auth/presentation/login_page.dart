import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/inputs.dart';
import 'auth_cubit.dart';
import 'auth_form.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    context.read<AuthCubit>().login(email: _email.text, password: _password.text);
  }

  @override
  Widget build(BuildContext context) {
    return AuthForm(
      title: 'Welcome back',
      subtitle: 'Log in to see your sales',
      formKey: _formKey,
      submitLabel: 'Log in',
      onSubmit: _submit,
      footer: TextButton(
        onPressed: () => context.go('/register'),
        child: const Text('New here? Create an account'),
      ),
      fields: [
        TextFormField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          decoration: const InputDecoration(labelText: 'Email'),
          validator: requiredText,
        ),
        const SizedBox(height: 16),
        PasswordField(controller: _password, onSubmitted: _submit),
      ],
    );
  }
}
