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
    this.message,
  });

  final String correlationId;
  final ApiTransportFailureKind kind;
  final String? message;

  String get safeReason => switch (kind) {
    ApiTransportFailureKind.timeout => 'request_timeout',
    ApiTransportFailureKind.connection => 'connection_failure',
    ApiTransportFailureKind.invalidResponse => 'invalid_json_response',
  };

  @override
  String toString() {
    if (message != null && message!.isNotEmpty) {
      return message!;
    }
    return switch (kind) {
      ApiTransportFailureKind.timeout =>
        'El servidor tardó más de lo esperado en responder. Por favor reintenta.',
      ApiTransportFailureKind.connection =>
        'No se pudo conectar con el servidor. Revisa tu conexión a internet.',
      ApiTransportFailureKind.invalidResponse =>
        'El servidor devolvió una respuesta no válida.',
    };
  }
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
    Duration? timeout,
  }) {
    return _send(
      method: 'POST',
      path: path,
      body: body,
      bearerCredential: bearerCredential,
      timeout: timeout,
    );
  }

  Future<ApiResponse> getJson(
    String path, {
    String? bearerCredential,
    Duration? timeout,
  }) {
    return _send(
      method: 'GET',
      path: path,
      bearerCredential: bearerCredential,
      timeout: timeout,
    );
  }

  Future<ApiResponse> patchJson(
    String path,
    Map<String, Object?> body, {
    String? bearerCredential,
    Duration? timeout,
  }) {
    return _send(
      method: 'PATCH',
      path: path,
      body: body,
      bearerCredential: bearerCredential,
      timeout: timeout,
    );
  }

  Future<ApiResponse> putJson(
    String path,
    Map<String, Object?> body, {
    String? bearerCredential,
    Duration? timeout,
  }) {
    return _send(
      method: 'PUT',
      path: path,
      body: body,
      bearerCredential: bearerCredential,
      timeout: timeout,
    );
  }

  Future<ApiResponse> deleteRequest(
    String path, {
    String? bearerCredential,
    Duration? timeout,
  }) {
    return _send(
      method: 'DELETE',
      path: path,
      bearerCredential: bearerCredential,
      timeout: timeout,
    );
  }

  Future<ApiResponse> postMultipart(
    String path, {
    required String filePath,
    String fileField = 'file',
    Map<String, String>? fields,
    String? bearerCredential,
    Duration? timeout,
  }) async {
    final effectiveTimeout = timeout ?? _timeout;
    final correlationId = _nextCorrelationId();
    final headers = <String, String>{
      'Accept': 'application/json',
      'X-Correlation-ID': correlationId,
      if (bearerCredential != null) 'Authorization': 'Bearer $bearerCredential',
    };
    try {
      final request = http.MultipartRequest('POST', _baseUri.resolve(path))
        ..headers.addAll(headers);
      if (fields != null) {
        request.fields.addAll(fields);
      }
      request.files.add(await http.MultipartFile.fromPath(fileField, filePath));
      final streamed = await _client.send(request).timeout(effectiveTimeout);
      final response =
          await http.Response.fromStream(streamed).timeout(effectiveTimeout);
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
        message:
            'El procesamiento del recibo tardó más de lo esperado (${effectiveTimeout.inSeconds}s). Por favor reintenta.',
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

  Future<ApiResponse> _send({
    required String method,
    required String path,
    Map<String, Object?>? body,
    String? bearerCredential,
    Duration? timeout,
  }) async {
    final effectiveTimeout = timeout ?? _timeout;
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
      final streamed = await _client.send(request).timeout(effectiveTimeout);
      final response = await http.Response.fromStream(streamed)
          .timeout(effectiveTimeout);
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
        message:
            'La solicitud al servidor tardó más de lo esperado (${effectiveTimeout.inSeconds}s). Por favor reintenta.',
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
