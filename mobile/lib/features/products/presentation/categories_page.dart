import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/load_status.dart';
import '../../../core/widgets/async_views.dart';
import '../../../core/widgets/inputs.dart';
import '../data/category_repository.dart';
import '../domain/category.dart';

class CategoriesState extends Equatable {
  const CategoriesState({
    this.status = LoadStatus.initial,
    this.categories = const [],
    this.errorMessage,
  });

  final LoadStatus status;
  final List<Category> categories;
  final String? errorMessage;

  @override
  List<Object?> get props => [status, categories, errorMessage];
}

class CategoriesCubit extends Cubit<CategoriesState> {
  CategoriesCubit(this._categories) : super(const CategoriesState());

  final CategoryRepository _categories;

  Future<void> load() => _run(() async {});

  Future<void> add(String name) => _run(() => _categories.create(name));

  Future<void> rename(Category category, String name) =>
      _run(() => _categories.update(category.id, name: name));

  Future<void> setActive(Category category, bool isActive) =>
      _run(() => _categories.update(category.id, isActive: isActive));

  /// Runs a change, then reloads the list so it always matches the server.
  Future<void> _run(Future<Object?> Function() change) async {
    try {
      await change();
      final categories = await _categories.list(includeInactive: true);
      emit(CategoriesState(status: LoadStatus.success, categories: categories));
    } on ApiException catch (error) {
      emit(
        CategoriesState(
          status: state.categories.isEmpty ? LoadStatus.failure : LoadStatus.success,
          categories: state.categories,
          errorMessage: error.message,
        ),
      );
    }
  }
}

class CategoriesPage extends StatelessWidget {
  const CategoriesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => CategoriesCubit(context.read<CategoryRepository>())..load(),
      child: BlocConsumer<CategoriesCubit, CategoriesState>(
        listenWhen: (_, current) => current.errorMessage != null,
        listener: (context, state) => showMessage(context, state.errorMessage!),
        builder: (context, state) {
          final cubit = context.read<CategoriesCubit>();
          return Scaffold(
            appBar: AppBar(title: const Text('Categories')),
            floatingActionButton: FloatingActionButton.extended(
              icon: const Icon(Icons.add),
              label: const Text('Add category'),
              onPressed: () async {
                final name = await showNameDialog(context, title: 'New category');
                if (name != null) await cubit.add(name);
              },
            ),
            body: switch (state.status) {
              LoadStatus.success => ListView(
                  padding: const EdgeInsets.only(bottom: 88),
                  children: [
                    for (final category in state.categories)
                      ListTile(
                        title: Text(category.name),
                        subtitle: category.isActive ? null : const Text('Disabled'),
                        onTap: () async {
                          final name = await showNameDialog(
                            context,
                            title: 'Rename category',
                            initialValue: category.name,
                          );
                          if (name != null) await cubit.rename(category, name);
                        },
                        trailing: Switch(
                          value: category.isActive,
                          onChanged: (value) => cubit.setActive(category, value),
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
}
