import 'dart:convert';

import 'package:finance_ai/core/api/api_client.dart';
import 'package:finance_ai/features/auth/session/application/auth_session_controller.dart';
import 'package:finance_ai/features/auth/session/application/auth_session_state.dart';
import 'package:finance_ai/features/auth/session/data/auth_session_repository.dart';
import 'package:finance_ai/features/auth/session/data/secure_credential_store.dart';
import 'package:finance_ai/features/auth/session/domain/session_models.dart';
import 'package:finance_ai/features/categories/data/categories_repository.dart';
import 'package:finance_ai/features/categories/domain/category_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const access = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const renewable = 'ccccccccccccccccccccccccccccccccccccccccccc';

Map<String, Object?> categoryJson() => {
  'id': 4,
  'name': 'Food',
  'color': 'orange',
  'icon': 'food',
  'sort_order': 0,
  'created_at': '2026-09-12T12:00:00Z',
  'updated_at': '2026-09-12T12:00:00Z',
};

Map<String, Object?> listJson() => {
  'categories': [categoryJson()],
  'supported_colors': CategoryColor.values.map((item) => item.name).toList(),
  'supported_icons': CategoryIcon.values.map((item) => item.name).toList(),
};

class MemoryStore implements SecureCredentialStore {
  String? value;
  @override
  Future<void> delete() async => value = null;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> replace(String renewableCredential) async =>
      value = renewableCredential;
}

class SessionRepository implements AuthSessionRepository {
  IssuedAuthSession get issued {
    final now = DateTime.utc(2026, 9, 12);
    return IssuedAuthSession(
      user: const AuthenticatedUser(
        id: 42,
        email: 'person@example.com',
        preferredCurrency: 'COP',
      ),
      accessCredential: access,
      renewableCredential: renewable,
      accessExpiresAt: now.add(const Duration(minutes: 15)),
      renewableExpiresAt: now.add(const Duration(days: 30)),
      absoluteExpiresAt: now.add(const Duration(days: 90)),
    );
  }

  @override
  Future<AuthenticatedUser> currentUser(String accessCredential) async =>
      issued.user;
  @override
  Future<IssuedAuthSession> login(LoginRequest request) async => issued;
  @override
  Future<void> logout(String renewableCredential) async {}
  @override
  Future<IssuedAuthSession> refresh(String renewableCredential) async => issued;
}

Future<(ProviderContainer, CategoriesRepository)> repositoryWith(
  Future<http.Response> Function(http.Request) handler,
) async {
  final container = ProviderContainer(
    overrides: [
      httpClientProvider.overrideWithValue(MockClient(handler)),
      authSessionRepositoryProvider.overrideWithValue(SessionRepository()),
      secureCredentialStoreProvider.overrideWithValue(MemoryStore()),
    ],
  );
  await Future<void>.delayed(Duration.zero);
  expect(
    await container
        .read(authSessionControllerProvider.notifier)
        .login(email: 'person@example.com', password: 'safe-password'),
    LoginSubmitOutcome.success,
  );
  return (container, container.read(categoriesRepositoryProvider));
}

void main() {
  test('uses authenticated CRUD and order contracts', () async {
    final requests = <http.Request>[];
    final setup = await repositoryWith((request) async {
      requests.add(request);
      if (request.method == 'GET' && request.url.path == '/api/v1/categories') {
        return http.Response(jsonEncode(listJson()), 200);
      }
      if (request.method == 'PUT') {
        return http.Response(jsonEncode(listJson()), 200);
      }
      if (request.method == 'DELETE') return http.Response('', 204);
      return http.Response(
        jsonEncode(categoryJson()),
        request.method == 'POST' ? 201 : 200,
      );
    });
    final (container, repository) = setup;
    addTearDown(container.dispose);

    await repository.list();
    await repository.get(4);
    const command = CategoryCreateCommand(
      name: 'Food',
      color: CategoryColor.orange,
      icon: CategoryIcon.food,
    );
    await repository.create(command);
    await repository.update(4, command);
    await repository.reorder([4]);
    await repository.deleteCategory(4);

    expect(requests.map((item) => item.method), [
      'GET',
      'GET',
      'POST',
      'PATCH',
      'PUT',
      'DELETE',
    ]);
    expect(
      requests.every(
        (item) => item.headers['Authorization'] == 'Bearer $access',
      ),
      isTrue,
    );
    expect(jsonDecode(requests[4].body), {
      'category_ids': [4],
    });
  });

  test('maps known error without copying entered category name', () async {
    final setup = await repositoryWith(
      (_) async => http.Response(
        jsonEncode({
          'status': 409,
          'code': 'category_name_conflict',
          'detail': 'Synthetic detail',
          'correlation_id': 'category-conflict',
          'field_errors': {
            'name': ['Already used.'],
          },
        }),
        409,
      ),
    );
    final (container, repository) = setup;
    addTearDown(container.dispose);

    await expectLater(
      repository.create(
        const CategoryCreateCommand(
          name: 'Private category',
          color: CategoryColor.red,
          icon: CategoryIcon.other,
        ),
      ),
      throwsA(
        isA<CategoryFailure>()
            .having((item) => item.code, 'code', 'category_name_conflict')
            .having(
              (item) => item.userMessage,
              'private name omitted',
              isNot(contains('Private')),
            ),
      ),
    );
  });

  test('transport and malformed success responses are safe failures', () async {
    final networkSetup = await repositoryWith((request) async {
      throw http.ClientException('private network path', request.url);
    });
    addTearDown(networkSetup.$1.dispose);
    await expectLater(
      networkSetup.$2.deleteCategory(4),
      throwsA(
        isA<CategoryFailure>()
            .having((item) => item.code, 'code', 'network_unavailable')
            .having(
              (item) => item.isMutationOutcomeUncertain,
              'uncertain',
              isTrue,
            )
            .having(
              (item) => item.userMessage,
              'safe',
              isNot(contains('private network path')),
            ),
      ),
    );

    final malformedSetup = await repositoryWith(
      (_) async =>
          http.Response(jsonEncode({...categoryJson()}..remove('icon')), 200),
    );
    addTearDown(malformedSetup.$1.dispose);
    await expectLater(
      malformedSetup.$2.get(4),
      throwsA(
        isA<CategoryFailure>().having(
          (item) => item.code,
          'code',
          'unexpected_response',
        ),
      ),
    );
  });
}
