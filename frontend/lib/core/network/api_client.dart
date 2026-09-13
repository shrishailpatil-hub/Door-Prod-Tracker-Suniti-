import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../errors/api_exception.dart';
import '../storage/secure_storage_service.dart';

/// HTTP Client abstraction providing centralized header management, authentication token injection,
/// request timeout handling, and backend error response mapping.
class ApiClient {
  final String _baseUrl;
  final SecureStorageService _storageService;
  final http.Client _httpClient;
  final Duration _timeout;

  ApiClient({
    String? baseUrl,
    SecureStorageService? storageService,
    http.Client? httpClient,
    Duration timeout = const Duration(seconds: 15),
  }) : _baseUrl = baseUrl ?? ApiConfig.baseUrl,
       _storageService = storageService ?? SecureStorageService(),
       _httpClient = httpClient ?? http.Client(),
       _timeout = timeout;

  /// Performs an HTTP GET request returning parsed JSON response.
  Future<dynamic> get(
    String endpoint, {
    Map<String, dynamic>? queryParams,
    bool authenticated = true,
  }) async {
    final uri = _buildUri(endpoint, queryParams);
    final headers = await _buildHeaders(authenticated: authenticated);

    return _sendRequest(() => _httpClient.get(uri, headers: headers));
  }

  /// Performs an HTTP GET request returning raw binary bytes (e.g. for file downloads).
  Future<Uint8List> getBytes(
    String endpoint, {
    Map<String, dynamic>? queryParams,
    bool authenticated = true,
  }) async {
    final uri = _buildUri(endpoint, queryParams);
    final headers = await _buildHeaders(authenticated: authenticated);

    try {
      final response = await _httpClient
          .get(uri, headers: headers)
          .timeout(_timeout);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response.bodyBytes;
      }
      return _handleResponse(response);
    } on TimeoutException {
      throw const ApiException(
        message:
            'Connection timed out. Please check your network and try again.',
      );
    } on SocketException {
      throw const ApiException(
        message: 'Cannot reach server. Please check your network connection.',
      );
    } on http.ClientException {
      throw const ApiException(
        message: 'Network communication error. Please try again.',
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(message: 'Unexpected network error: $e');
    }
  }

  /// Performs an HTTP POST request with JSON body.
  Future<dynamic> post(
    String endpoint, {
    dynamic body,
    bool authenticated = true,
  }) async {
    final uri = _buildUri(endpoint);
    final headers = await _buildHeaders(authenticated: authenticated);

    return _sendRequest(
      () => _httpClient.post(
        uri,
        headers: headers,
        body: body != null ? jsonEncode(body) : null,
      ),
    );
  }

  /// Performs an HTTP PUT request with JSON body.
  Future<dynamic> put(
    String endpoint, {
    dynamic body,
    bool authenticated = true,
  }) async {
    final uri = _buildUri(endpoint);
    final headers = await _buildHeaders(authenticated: authenticated);

    return _sendRequest(
      () => _httpClient.put(
        uri,
        headers: headers,
        body: body != null ? jsonEncode(body) : null,
      ),
    );
  }

  /// Performs an HTTP PATCH request with JSON body.
  Future<dynamic> patch(
    String endpoint, {
    dynamic body,
    bool authenticated = true,
  }) async {
    final uri = _buildUri(endpoint);
    final headers = await _buildHeaders(authenticated: authenticated);

    return _sendRequest(
      () => _httpClient.patch(
        uri,
        headers: headers,
        body: body != null ? jsonEncode(body) : null,
      ),
    );
  }

  /// Performs an HTTP DELETE request.
  Future<dynamic> delete(String endpoint, {bool authenticated = true}) async {
    final uri = _buildUri(endpoint);
    final headers = await _buildHeaders(authenticated: authenticated);

    return _sendRequest(() => _httpClient.delete(uri, headers: headers));
  }

  Uri _buildUri(String endpoint, [Map<String, dynamic>? queryParams]) {
    final cleanBase = _baseUrl.endsWith('/')
        ? _baseUrl.substring(0, _baseUrl.length - 1)
        : _baseUrl;
    final cleanEndpoint = endpoint.startsWith('/') ? endpoint : '/$endpoint';
    final fullUrl = '$cleanBase$cleanEndpoint';

    final uri = Uri.parse(fullUrl);
    if (queryParams != null && queryParams.isNotEmpty) {
      final stringParams = queryParams.map(
        (key, value) => MapEntry(key, value?.toString() ?? ''),
      );
      return uri.replace(
        queryParameters: {...uri.queryParameters, ...stringParams},
      );
    }
    return uri;
  }

  Future<Map<String, String>> _buildHeaders({
    required bool authenticated,
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (authenticated) {
      final token = await _storageService.getToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  Future<dynamic> _sendRequest(
    Future<http.Response> Function() requestFn,
  ) async {
    try {
      final response = await requestFn().timeout(_timeout);
      return _handleResponse(response);
    } on TimeoutException {
      throw const ApiException(
        message:
            'Connection timed out. Please check your network and try again.',
      );
    } on SocketException {
      throw const ApiException(
        message: 'Cannot reach server. Please check your network connection.',
      );
    } on http.ClientException {
      throw const ApiException(
        message: 'Network communication error. Please try again.',
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(message: 'Unexpected network error: $e');
    }
  }

  dynamic _handleResponse(http.Response response) {
    final statusCode = response.statusCode;

    if (statusCode >= 200 && statusCode < 300) {
      if (response.body.isEmpty) {
        return null;
      }
      try {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } catch (e) {
        return response.body;
      }
    }

    String? errorMessage;
    if (response.body.isNotEmpty) {
      try {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map<String, dynamic>) {
          errorMessage =
              decoded['message'] as String? ?? decoded['error'] as String?;
        }
      } catch (_) {
        // Fallback to default message below
      }
    }

    if (errorMessage == null || errorMessage.trim().isEmpty) {
      switch (statusCode) {
        case 400:
          errorMessage = 'Invalid request. Please verify inputs.';
          break;
        case 401:
          errorMessage = 'Session expired or unauthenticated. Please log in.';
          break;
        case 403:
          errorMessage = 'You do not have permission to perform this action.';
          break;
        case 404:
          errorMessage = 'The requested resource was not found.';
          break;
        case 409:
          errorMessage = 'A conflict occurred. Please refresh and try again.';
          break;
        case 500:
          errorMessage =
              'Server error occurred. Please contact an administrator.';
          break;
        default:
          errorMessage = 'Request failed with status code $statusCode.';
      }
    }

    throw ApiException(statusCode: statusCode, message: errorMessage);
  }
}
