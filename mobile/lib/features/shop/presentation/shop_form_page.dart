import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/inputs.dart';
import '../../auth/presentation/auth_cubit.dart';
import '../../auth/presentation/auth_form.dart';
import '../domain/shop.dart';

/// First-time shop setup, and editing shop details later from Settings.
class ShopFormPage extends StatefulWidget {
  const ShopFormPage({this.shop, super.key});

  /// Null during first-time setup.
  final Shop? shop;

  @override
  State<ShopFormPage> createState() => _ShopFormPageState();
}

class _ShopFormPageState extends State<ShopFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.shop?.name);
  late final _ownerName = TextEditingController(
    text: widget.shop?.ownerName ?? context.read<AuthCubit>().state.user?.fullName,
  );
  late final _phone = TextEditingController(text: widget.shop?.phone);
  late final _address = TextEditingController(text: widget.shop?.address);

  bool get _isSetup => widget.shop == null;

  @override
  void dispose() {
    _name.dispose();
    _ownerName.dispose();
    _phone.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final input = ShopInput(
      name: _name.text.trim(),
      ownerName: _ownerName.text.trim(),
      phone: _phone.text.replaceAll(RegExp(r'[\s\-()]'), ''),
      address: cleanOptional(_address.text),
    );
    final cubit = context.read<AuthCubit>();
    if (_isSetup) {
      await cubit.createShop(input);
    } else if (await cubit.updateShop(input) && mounted) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final fields = [
      TextFormField(
        controller: _name,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(labelText: 'Shop name'),
        validator: requiredText,
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _ownerName,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(labelText: 'Owner name'),
        validator: requiredText,
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _phone,
        keyboardType: TextInputType.phone,
        decoration: const InputDecoration(labelText: 'Phone number'),
        validator: requiredPhone,
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _address,
        textCapitalization: TextCapitalization.sentences,
        maxLines: 2,
        decoration: const InputDecoration(labelText: 'Address (optional)'),
      ),
    ];

    final form = AuthForm(
      title: _isSetup ? 'Set up your shop' : 'Shop details',
      subtitle: _isSetup ? 'You can change these later in Settings' : 'Shown on your account',
      formKey: _formKey,
      fields: fields,
      submitLabel: _isSetup ? 'Start using the app' : 'Save',
      onSubmit: _submit,
    );
    if (_isSetup) return form;
    return Scaffold(appBar: AppBar(), body: form);
  }
}
