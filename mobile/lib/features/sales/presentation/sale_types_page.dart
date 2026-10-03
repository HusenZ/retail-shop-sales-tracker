import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/load_status.dart';
import '../../../core/widgets/async_views.dart';
import '../../../core/widgets/inputs.dart';
import '../data/sale_type_repository.dart';
import '../domain/sale_type.dart';

class SaleTypesState extends Equatable {
  const SaleTypesState({
    this.status = LoadStatus.initial,
    this.saleTypes = const [],
    this.errorMessage,
  });

  final LoadStatus status;
  final List<SaleType> saleTypes;
  final String? errorMessage;

  @override
  List<Object?> get props => [status, saleTypes, errorMessage];
}

class SaleTypesCubit extends Cubit<SaleTypesState> {
  SaleTypesCubit(this._saleTypes) : super(const SaleTypesState());

  final SaleTypeRepository _saleTypes;

  Future<void> load() => _run(() async {});

  Future<void> add(String name, {required bool isExchange}) =>
      _run(() => _saleTypes.create(name, isExchange: isExchange));

  Future<void> rename(SaleType saleType, String name) =>
      _run(() => _saleTypes.update(saleType.id, name: name));

  Future<void> setActive(SaleType saleType, bool isActive) =>
      _run(() => _saleTypes.update(saleType.id, isActive: isActive));

  Future<void> makeDefault(SaleType saleType) =>
      _run(() => _saleTypes.update(saleType.id, isDefault: true));

  Future<void> _run(Future<Object?> Function() change) async {
    try {
      await change();
      final saleTypes = await _saleTypes.list(includeInactive: true);
      emit(SaleTypesState(status: LoadStatus.success, saleTypes: saleTypes));
    } on ApiException catch (error) {
      emit(
        SaleTypesState(
          status: state.saleTypes.isEmpty ? LoadStatus.failure : LoadStatus.success,
          saleTypes: state.saleTypes,
          errorMessage: error.message,
        ),
      );
    }
  }
}

class SaleTypesPage extends StatelessWidget {
  const SaleTypesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => SaleTypesCubit(context.read<SaleTypeRepository>())..load(),
      child: BlocConsumer<SaleTypesCubit, SaleTypesState>(
        listenWhen: (_, current) => current.errorMessage != null,
        listener: (context, state) => showMessage(context, state.errorMessage!),
        builder: (context, state) {
          final cubit = context.read<SaleTypesCubit>();
          return Scaffold(
            appBar: AppBar(title: const Text('Sale types')),
            floatingActionButton: FloatingActionButton.extended(
              icon: const Icon(Icons.add),
              label: const Text('Add sale type'),
              onPressed: () => _addSaleType(context, cubit),
            ),
            body: switch (state.status) {
              LoadStatus.success => ListView(
                  padding: const EdgeInsets.only(bottom: 88),
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('The starred sale type is selected first when you add a sale.'),
                    ),
                    for (final saleType in state.saleTypes)
                      ListTile(
                        leading: IconButton(
                          tooltip: 'Make default',
                          icon: Icon(saleType.isDefault ? Icons.star : Icons.star_border),
                          onPressed: saleType.isActive && !saleType.isDefault
                              ? () => cubit.makeDefault(saleType)
                              : null,
                        ),
                        title: Text(saleType.name),
                        subtitle: Text(
                          [
                            if (saleType.isExchange) 'Asks for old phone',
                            if (!saleType.isActive) 'Disabled',
                          ].join(' · '),
                        ),
                        onTap: () async {
                          final name = await showNameDialog(
                            context,
                            title: 'Rename sale type',
                            initialValue: saleType.name,
                          );
                          if (name != null) await cubit.rename(saleType, name);
                        },
                        trailing: Switch(
                          value: saleType.isActive,
                          onChanged: (value) => cubit.setActive(saleType, value),
                        ),
                      ),
                  ],
                ),
              LoadStatus.failure => ErrorView(message: state.errorMessage!, onRetry: cubit.load),
              _ => const LoadingView(),
            },
          );
        },
      ),
    );
  }

  Future<void> _addSaleType(BuildContext context, SaleTypesCubit cubit) async {
    final name = await showNameDialog(context, title: 'New sale type');
    if (name == null || !context.mounted) return;
    final isExchange = await confirm(
      context,
      title: 'Is "$name" an exchange?',
      message: 'Exchange sales ask for the customer\'s old phone and its value.',
      action: 'Yes, exchange',
      cancel: 'No',
    );
    await cubit.add(name, isExchange: isExchange);
  }
}
