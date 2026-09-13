import 'package:finance_ai/features/income_sources/data/income_sources_repository.dart';
import 'package:finance_ai/features/income_sources/domain/income_source_models.dart';
import 'package:finance_ai/features/income_sources/presentation/income_sources_controller.dart';
import 'package:finance_ai/features/income_sources/presentation/income_sources_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeIncomeSourcesRepository implements IncomeSourcesRepository {
  FakeIncomeSourcesRepository({
    this.items = const [IncomeSource(id: 1, name: 'Salary')],
    this.failure,
  });

  List<IncomeSource> items;
  IncomeSourcesFailure? failure;
  int _nextId = 100;

  @override
  Future<List<IncomeSource>> list({required String accessCredential}) async {
    if (failure case final value?) {
      throw value;
    }
    return List.of(items);
  }

  @override
  Future<IncomeSource> create({
    required String accessCredential,
    required String name,
  }) async {
    if (failure case final value?) {
      throw value;
    }
    final record = IncomeSource(id: _nextId++, name: name.trim());
    items = [...items, record];
    return record;
  }

  @override
  Future<IncomeSource> rename({
    required String accessCredential,
    required int id,
    required String name,
  }) async {
    if (failure case final value?) {
      throw value;
    }
    return IncomeSource(id: id, name: name.trim());
  }

  @override
  Future<void> delete({
    required String accessCredential,
    required int id,
  }) async {
    if (failure case final value?) {
      throw value;
    }
    items = items.where((item) => item.id != id).toList();
  }
}

Future<ProviderContainer> containerFor(
  FakeIncomeSourcesRepository repository, {
  String? credential = 'token',
}) async {
  final container = ProviderContainer(
    overrides: [
      incomeSourcesRepositoryProvider.overrideWithValue(repository),
      accessCredentialProvider.overrideWithValue(credential),
    ],
  );
  addTearDown(container.dispose);
  await container.read(incomeSourcesControllerProvider.notifier).load();
  return container;
}

void main() {
  test('load publishes the owned catalog', () async {
    final container = await containerFor(FakeIncomeSourcesRepository());
    final state = container.read(incomeSourcesControllerProvider);
    expect(state.status, IncomeSourcesStatus.ready);
    expect(state.items.single.name, 'Salary');
    expect(container.read(incomeSourceSelectorProvider).length, 1);
  });

  test('missing credential fails closed without calling the API', () async {
    final repository = FakeIncomeSourcesRepository();
    final container = await containerFor(repository, credential: null);
    final state = container.read(incomeSourcesControllerProvider);
    expect(state.status, IncomeSourcesStatus.failure);
    expect(state.diagnostic?.code, 'authentication_required');
  });

  test('add refreshes the selector', () async {
    final container = await containerFor(FakeIncomeSourcesRepository());
    final controller = container.read(incomeSourcesControllerProvider.notifier);
    expect(await controller.add(' Freelance '), isTrue);
    expect(
      container.read(incomeSourceSelectorProvider).map((item) => item.name),
      ['Salary', 'Freelance'],
    );
  });

  test('validation failure exposes field errors', () async {
    final repository = FakeIncomeSourcesRepository(
      failure: const IncomeSourcesValidationFailure(
        userMessage: 'Invalid',
        fieldErrors: {
          'name': ['Enter an income source name.'],
        },
      ),
    );
    final container = ProviderContainer(
      overrides: [
        incomeSourcesRepositoryProvider.overrideWithValue(repository),
        accessCredentialProvider.overrideWithValue('token'),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(incomeSourcesControllerProvider.notifier);
    expect(await controller.add(''), isFalse);
    final state = container.read(incomeSourcesControllerProvider);
    expect(state.fieldErrors['name'], isNotEmpty);
    expect(state.diagnostic?.code, 'income_source_invalid');
  });

  test('delete removes the item and refreshes the selector', () async {
    final container = await containerFor(FakeIncomeSourcesRepository());
    final controller = container.read(incomeSourcesControllerProvider.notifier);
    expect(await controller.delete(1), isTrue);
    expect(container.read(incomeSourceSelectorProvider), isEmpty);
  });
}
