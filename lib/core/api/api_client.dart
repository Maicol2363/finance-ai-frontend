import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';

final httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final financeApiClientProvider = Provider<FinanceApiClient>((ref) {
  return FinanceApiClient(
    ref.watch(httpClientProvider),
    Uri.parse(AppConfig.apiBaseUrl),
    AppConfig.requestTimeout,
  );
});

class ApiResponse {
  const ApiResponse({
    required this.statusCode,
    required this.body,
    required this.headers,
    required this.correlationId,
  });

  final int statusCode;
  final Map<String, Object?>? body;
  final Map<String, String> headers;
  final String? correlationId;
}

enum ApiTransportFailureKind { timeout, connection, invalidResponse }

class ApiTransportException implements Exception {
  const ApiTransportException({
    required this.correlationId,
    required this.kind,
  });

  final String correlationId;
  final ApiTransportFailureKind kind;

  String get safeReason => switch (kind) {
    ApiTransportFailureKind.timeout => 'request_timeout',
    ApiTransportFailureKind.connection => 'connection_failure',
    ApiTransportFailureKind.invalidResponse => 'invalid_json_response',
  };
}

class FinanceApiClient {
  FinanceApiClient(this._client, this._baseUri, this._timeout);

  final http.Client _client;
  final Uri _baseUri;
  final Duration _timeout;
  int _requestSequence = 0;

  Future<ApiResponse> postJson(
    String path,
    Map<String, Object?> body, {
    String? bearerCredential,
  }) {
    return _send(
      method: 'POST',
      path: path,
      body: body,
      bearerCredential: bearerCredential,
    );
  }

  Future<ApiResponse> getJson(String path, {String? bearerCredential}) {
    return _send(method: 'GET', path: path, bearerCredential: bearerCredential);
  }

  Future<ApiResponse> _send({
    required String method,
    required String path,
    Map<String, Object?>? body,
    String? bearerCredential,
  }) async {
    final correlationId = _nextCorrelationId();
    final headers = <String, String>{
      'Accept': 'application/json',
      'X-Correlation-ID': correlationId,
      if (body != null) 'Content-Type': 'application/json',
      if (bearerCredential != null) 'Authorization': 'Bearer $bearerCredential',
    };
    try {
      final request = http.Request(method, _baseUri.resolve(path))
        ..headers.addAll(headers);
      if (body != null) {
        request.body = jsonEncode(body);
      }
      final streamed = await _client.send(request).timeout(_timeout);
      final response = await http.Response.fromStream(streamed)
          .timeout(_timeout);
      return ApiResponse(
        statusCode: response.statusCode,
        body: _decodeOptionalObject(response.body),
        headers: Map.unmodifiable(response.headers),
        correlationId: response.headers['x-correlation-id'],
      );
    } on TimeoutException {
      throw ApiTransportException(
        correlationId: correlationId,
        kind: ApiTransportFailureKind.timeout,
      );
    } on http.ClientException {
      throw ApiTransportException(
        correlationId: correlationId,
        kind: ApiTransportFailureKind.connection,
      );
    } on FormatException {
      throw ApiTransportException(
        correlationId: correlationId,
        kind: ApiTransportFailureKind.invalidResponse,
      );
    }
  }

  Map<String, Object?>? _decodeOptionalObject(String source) {
    if (source.trim().isEmpty) {
      return null;
    }
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('Expected a JSON object');
    }
    return decoded;
  }

  String _nextCorrelationId() {
    _requestSequence += 1;
    return 'flutter-${DateTime.now().microsecondsSinceEpoch}-$_requestSequence';
  }
}
