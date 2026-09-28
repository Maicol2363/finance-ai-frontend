import 'dart:convert';
import 'dart:io';

import 'package:finance_ai/core/api/api_client.dart';
import 'package:finance_ai/features/auth/session/application/auth_session_controller.dart';
import 'package:finance_ai/features/expenses/domain/expense_models.dart';
import 'package:finance_ai/features/receipt_capture/data/receipt_capture_remote_data_source.dart';
import 'package:finance_ai/features/receipt_capture/domain/receipt_proposal_dto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _FakeAuthSessionController extends AuthSessionController {
  @override
  Future<T> runProtected<T>(
    Future<T> Function(String accessCredential) request,
  ) {
    return request('fake-jwt-token');
  }
}

FinanceApiClient _createApiClient(MockClient mock) => FinanceApiClient(
  mock,
  Uri.parse('http://localhost:8000'),
  const Duration(seconds: 5),
);

http.Response _jsonResponse(Object body, int status) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

void main() {
  late File testImageFile;
  late _FakeAuthSessionController fakeSession;

  setUp(() {
    fakeSession = _FakeAuthSessionController();
    testImageFile = File('${Directory.systemTemp.path}/test_receipt_remote.jpg')
      ..writeAsBytesSync([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10]);
  });

  tearDown(() {
    if (testImageFile.existsSync()) {
      testImageFile.deleteSync();
    }
  });

  group('ReceiptCaptureRemoteDataSource', () {
    test(
      'uploadProposal sends multipart request with rotation and parses DTO',
      () async {
        final mock = MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/api/v1/receipts/proposal');
          expect(request.url.queryParameters['rotation'], '90');
          expect(request.headers['Authorization'], 'Bearer fake-jwt-token');

          return _jsonResponse({
            'proposal_id': '42',
            'status': 'pending_review',
            'extracted_data': {
              'merchant_name': 'Éxito',
              'total_amount': 35000.0,
              'currency': 'COP',
              'date': '2026-03-15T12:00:00Z',
              'items': [
                {
                  'name': 'Arroz 1kg',
                  'quantity': 2.0,
                  'unit_price': 5000.0,
                  'total_price': 10000.0,
                },
              ],
            },
            'expires_at': '2026-03-15T12:00:00Z',
          }, 201);
        });

        final dataSource = ReceiptCaptureRemoteDataSource(
          _createApiClient(mock),
          fakeSession,
        );

        final result = await dataSource.uploadProposal(
          filePath: testImageFile.path,
          rotationDegrees: 90,
        );

        expect(result.proposalId, '42');
        expect(result.status, 'pending_review');
        expect(result.extractedData.merchantName, 'Éxito');
        expect(result.extractedData.totalAmount, 35000.0);
        expect(result.extractedData.items.length, 1);
        expect(result.extractedData.items.first.name, 'Arroz 1kg');
      },
    );

    test(
      'retryProposal posts to retry endpoint with rotation and parses DTO',
      () async {
        final mock = MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/api/v1/receipts/proposal/42/retry');
          expect(request.url.queryParameters['rotation'], '180');
          expect(request.headers['Authorization'], 'Bearer fake-jwt-token');

          return _jsonResponse({
            'proposal_id': '42',
            'status': 'pending_review',
            'extracted_data': {
              'merchant_name': 'Carulla',
              'total_amount': 55000.0,
              'currency': 'COP',
              'items': [],
            },
            'expires_at': '2026-03-15T12:00:00Z',
          }, 200);
        });

        final dataSource = ReceiptCaptureRemoteDataSource(
          _createApiClient(mock),
          fakeSession,
        );

        final result = await dataSource.retryProposal(
          proposalId: '42',
          filePath: testImageFile.path,
          rotationDegrees: 180,
        );

        expect(result.proposalId, '42');
        expect(result.extractedData.merchantName, 'Carulla');
        expect(result.extractedData.totalAmount, 55000.0);
      },
    );

    test(
      'discardProposal deletes proposal endpoint and succeeds on 204',
      () async {
        var called = false;
        final mock = MockClient((request) async {
          expect(request.method, 'DELETE');
          expect(request.url.path, '/api/v1/receipts/proposal/42');
          expect(request.headers['Authorization'], 'Bearer fake-jwt-token');
          called = true;
          return http.Response('', 204);
        });

        final dataSource = ReceiptCaptureRemoteDataSource(
          _createApiClient(mock),
          fakeSession,
        );

        await dataSource.discardProposal(proposalId: '42');
        expect(called, isTrue);
      },
    );

    test(
      'confirmProposal sends updated payload and parses confirmed Expense',
      () async {
        final mock = MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/api/v1/receipts/proposal/42/confirm');
          expect(request.headers['Authorization'], 'Bearer fake-jwt-token');

          final body = jsonDecode(request.body) as Map<String, Object?>;
          expect(body['merchant'], 'D1');
          expect(body['total_amount'], 12000.0);
          expect(body['account_id'], 1);

          return _jsonResponse({
            'id': 105,
            'transaction_id': 105,
            'receipt_id': 105,
            'name': 'D1',
            'amount': '12000.00',
            'quantity': '1',
            'receipt_name': 'D1',
            'store': 'D1',
            'occurred_at': '2026-03-15T12:00:00Z',
            'date': '2026-03-15T12:00:00Z',
            'status': 'confirmed',
            'capture_source': 'ai',
            'account_id': 1,
            'account_name': 'Efectivo',
            'account_is_active': true,
            'currency': {
              'id': 1,
              'code': 'COP',
              'name': 'Colombian Peso',
              'decimals': 2,
            },
            'currency_code': 'COP',
            'created_at': '2026-03-15T12:00:00Z',
            'updated_at': '2026-03-15T12:00:00Z',
          }, 201);
        });

        final dataSource = ReceiptCaptureRemoteDataSource(
          _createApiClient(mock),
          fakeSession,
        );

        final expense = await dataSource.confirmProposal(
          proposalId: '42',
          command: const ReceiptProposalConfirmRequestDto(
            merchant: 'D1',
            totalAmount: 12000.0,
            accountId: 1,
            occurredAt: '2026-03-15T12:00:00Z',
            currency: 'COP',
          ),
        );

        expect(expense.id, 105);
        expect(expense.name, 'D1');
        expect(expense.status, ExpenseStatus.confirmed);
      },
    );

    test(
      'throws ExpenseFailure when server returns error problem details',
      () async {
        final mock = MockClient((request) async {
          return _jsonResponse({
            'type': 'about:blank',
            'title': 'Unprocessable Entity',
            'status': 422,
            'detail': 'Receipt image could not be processed.',
            'code': 'receipt_unreadable',
          }, 422);
        });

        final dataSource = ReceiptCaptureRemoteDataSource(
          _createApiClient(mock),
          fakeSession,
        );

        expect(
          () => dataSource.uploadProposal(
            filePath: testImageFile.path,
            rotationDegrees: 0,
          ),
          throwsA(isA<ExpenseFailure>()),
        );
      },
    );

    test('ReceiptProposalResponseDto.fromJson handles flat FastAPI backend response', () {
      final flatJson = {
        'proposal_id': 'be61a84a-b99f-4098-895b-ed7e2e44fdf4',
        'status': 'complete',
        'revision': 1,
        'merchant_name': 'Supermercado Éxito',
        'purchase_date': '2026-09-25T14:30:00Z',
        'total_amount': '35000.00',
        'currency': 'COP',
        'payment_method': 'card',
        'suggested_category': 'Supermercado',
        'items': [
          {
            'name': 'Leche 1L',
            'quantity': '2.0',
            'unit_price': '5000.00',
            'amount': '10000.00',
          },
          {
            'name': 'Carne 1kg',
            'quantity': '1.0',
            'unit_price': '25000.00',
            'amount': '25000.00',
          },
        ],
        'issues': [
          {
            'code': 'ARITHMETIC_RECONCILED',
            'message': 'Calculated items match total',
            'severity': 'info',
          }
        ],
        'expires_at': '2026-09-25T15:30:00Z',
      };

      final dto = ReceiptProposalResponseDto.fromJson(flatJson);

      expect(dto.proposalId, 'be61a84a-b99f-4098-895b-ed7e2e44fdf4');
      expect(dto.status, 'complete');
      expect(dto.extractedData.merchantName, 'Supermercado Éxito');
      expect(dto.extractedData.totalAmount, 35000.0);
      expect(dto.extractedData.currency, 'COP');
      expect(dto.extractedData.categorySuggestion, 'Supermercado');
      expect(dto.extractedData.items.length, 2);
      expect(dto.extractedData.items[0].name, 'Leche 1L');
      expect(dto.extractedData.items[0].quantity, 2.0);
      expect(dto.extractedData.items[0].unitPrice, 5000.0);
      expect(dto.extractedData.items[0].totalPrice, 10000.0);
      expect(dto.extractedData.items[1].name, 'Carne 1kg');
      expect(dto.extractedData.items[1].totalPrice, 25000.0);
      expect(dto.issues, ['Calculated items match total']);
    });
  });
}

