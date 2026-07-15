import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'backend_config.dart';
import 'telemetry_frame_dto.dart';

class BackendClient {
  final BackendConfig config;
  HttpClient? _sharedClient;

  BackendClient({BackendConfig? config})
    : config = config ?? const BackendConfig();

  HttpClient get _client {
    _sharedClient ??= HttpClient()
      ..connectionTimeout = config.requestTimeout;
    return _sharedClient!;
  }

  void dispose() {
    _sharedClient?.close();
    _sharedClient = null;
  }

  Future<IngestResponse> postFrameBatch(
    String sessionId,
    List<Map<String, dynamic>> frames,
  ) async {
    final body = jsonEncode({'sessionId': sessionId, 'frames': frames});
    final uri = Uri.parse('${config.apiBase}/sessions/$sessionId/frames');

    var lastError = '';
    for (var attempt = 0; attempt <= config.maxRetries; attempt++) {
      if (attempt > 0) {
        await Future.delayed(config.retryBaseDelay * (1 << (attempt - 1)));
      }

      try {
        final request = await _client.postUrl(uri);
        request.headers.contentType = ContentType.json;
        request.write(body);
        final response = await request.close();

        final responseBody = await utf8.decodeStream(response);

        if (response.statusCode == 202) {
          return IngestResponse.fromJson(
            jsonDecode(responseBody) as Map<String, dynamic>,
          );
        }

        final error = BackendError.parse(responseBody);

        if (error.isRetryable && attempt < config.maxRetries) {
          debugPrint(
            '[BackendClient] Retryable error (attempt ${attempt + 1}): '
            '${error.code} — ${error.message}',
          );
          lastError = error.message;
          continue;
        }

        throw BackendRequestException(
          statusCode: response.statusCode,
          error: error,
        );
      } on SocketException catch (e) {
        if (attempt < config.maxRetries) {
          debugPrint(
            '[BackendClient] Network error (attempt ${attempt + 1}): $e',
          );
          lastError = e.message;
          continue;
        }
        throw BackendRequestException(
          statusCode: 0,
          error: BackendError(
            code: 'network_error',
            message: 'Connection failed after ${config.maxRetries} retries: '
                '${e.message}',
          ),
        );
      } on HttpException catch (e) {
        if (attempt < config.maxRetries) {
          debugPrint(
            '[BackendClient] HTTP error (attempt ${attempt + 1}): $e',
          );
          lastError = e.message;
          continue;
        }
        throw BackendRequestException(
          statusCode: 0,
          error: BackendError(
            code: 'http_error',
            message: 'HTTP error after ${config.maxRetries} retries: '
                '${e.message}',
          ),
        );
      }
    }

    throw BackendRequestException(
      statusCode: 0,
      error: BackendError(
        code: 'max_retries_exceeded',
        message: 'Max retries exceeded: $lastError',
      ),
    );
  }

  Future<TrackDetectionResponse> getTrackDetection(
    String sessionId,
  ) async {
    final uri = Uri.parse('${config.apiBase}/sessions/$sessionId/track');

    try {
      final request = await _client.getUrl(uri);
      final response = await request.close();
      final body = await utf8.decodeStream(response);

      if (response.statusCode == 200) {
        return TrackDetectionResponse.fromJson(
          jsonDecode(body) as Map<String, dynamic>,
        );
      }

      throw BackendRequestException(
        statusCode: response.statusCode,
        error: BackendError.parse(body),
      );
    } on SocketException catch (e) {
      throw BackendRequestException(
        statusCode: 0,
        error: BackendError(
          code: 'network_error',
          message: 'Connection failed: ${e.message}',
        ),
      );
    }
  }

  Future<CreateSessionResponse> createSession(
    CreateSessionRequest request,
  ) async {
    final body = jsonEncode(request.toJson());
    final uri = Uri.parse('${config.apiBase}/sessions');

    var lastError = '';
    for (var attempt = 0; attempt <= config.maxRetries; attempt++) {
      if (attempt > 0) {
        await Future.delayed(config.retryBaseDelay * (1 << (attempt - 1)));
      }

      try {
        final httpRequest = await _client.postUrl(uri);
        httpRequest.headers.contentType = ContentType.json;
        httpRequest.write(body);
        final response = await httpRequest.close();
        final responseBody = await utf8.decodeStream(response);

        if (response.statusCode == 200 || response.statusCode == 201) {
          return CreateSessionResponse.fromJson(
            jsonDecode(responseBody) as Map<String, dynamic>,
          );
        }

        final error = BackendError.parse(responseBody);

        if (error.isRetryable && attempt < config.maxRetries) {
          debugPrint(
            '[BackendClient] CreateSession retryable error '
            '(attempt ${attempt + 1}): ${error.code} — ${error.message}',
          );
          lastError = error.message;
          continue;
        }

        throw BackendRequestException(
          statusCode: response.statusCode,
          error: error,
        );
      } on SocketException catch (e) {
        if (attempt < config.maxRetries) {
          debugPrint(
            '[BackendClient] CreateSession network error '
            '(attempt ${attempt + 1}): $e',
          );
          lastError = e.message;
          continue;
        }
        throw BackendRequestException(
          statusCode: 0,
          error: BackendError(
            code: 'network_error',
            message: 'Connection failed after ${config.maxRetries} retries: '
                '${e.message}',
          ),
        );
      } on HttpException catch (e) {
        if (attempt < config.maxRetries) {
          debugPrint(
            '[BackendClient] CreateSession HTTP error '
            '(attempt ${attempt + 1}): $e',
          );
          lastError = e.message;
          continue;
        }
        throw BackendRequestException(
          statusCode: 0,
          error: BackendError(
            code: 'http_error',
            message: 'HTTP error after ${config.maxRetries} retries: '
                '${e.message}',
          ),
        );
      }
    }

    throw BackendRequestException(
      statusCode: 0,
      error: BackendError(
        code: 'max_retries_exceeded',
        message: 'Max retries exceeded: $lastError',
      ),
    );
  }

  Future<FinishSessionResponse> finishSession(
    String sessionId,
    FinishSessionRequest request,
  ) async {
    final body = jsonEncode(request.toJson());
    final uri = Uri.parse('${config.apiBase}/sessions/$sessionId/finish');

    var lastError = '';
    for (var attempt = 0; attempt <= config.maxRetries; attempt++) {
      if (attempt > 0) {
        await Future.delayed(config.retryBaseDelay * (1 << (attempt - 1)));
      }

      try {
        final httpRequest = await _client.postUrl(uri);
        httpRequest.headers.contentType = ContentType.json;
        httpRequest.write(body);
        final response = await httpRequest.close();
        final responseBody = await utf8.decodeStream(response);

        if (response.statusCode == 200) {
          return FinishSessionResponse.fromJson(
            jsonDecode(responseBody) as Map<String, dynamic>,
          );
        }

        final error = BackendError.parse(responseBody);

        if (error.isRetryable && attempt < config.maxRetries) {
          debugPrint(
            '[BackendClient] FinishSession retryable error '
            '(attempt ${attempt + 1}): ${error.code} — ${error.message}',
          );
          lastError = error.message;
          continue;
        }

        throw BackendRequestException(
          statusCode: response.statusCode,
          error: error,
        );
      } on SocketException catch (e) {
        if (attempt < config.maxRetries) {
          debugPrint(
            '[BackendClient] FinishSession network error '
            '(attempt ${attempt + 1}): $e',
          );
          lastError = e.message;
          continue;
        }
        throw BackendRequestException(
          statusCode: 0,
          error: BackendError(
            code: 'network_error',
            message: 'Connection failed after ${config.maxRetries} retries: '
                '${e.message}',
          ),
        );
      } on HttpException catch (e) {
        if (attempt < config.maxRetries) {
          debugPrint(
            '[BackendClient] FinishSession HTTP error '
            '(attempt ${attempt + 1}): $e',
          );
          lastError = e.message;
          continue;
        }
        throw BackendRequestException(
          statusCode: 0,
          error: BackendError(
            code: 'http_error',
            message: 'HTTP error after ${config.maxRetries} retries: '
                '${e.message}',
          ),
        );
      }
    }

    throw BackendRequestException(
      statusCode: 0,
      error: BackendError(
        code: 'max_retries_exceeded',
        message: 'Max retries exceeded: $lastError',
      ),
    );
  }

  Future<RaceEngineerAdviceResponse> requestRaceEngineerAdvice(
    String sessionId, [
    RaceEngineerAdviceRequest request = const RaceEngineerAdviceRequest(),
  ]) async {
    final body = jsonEncode(request.toJson());
    final uri = Uri.parse(
      '${config.apiBase}/sessions/$sessionId/race-engineer/advice',
    );

    try {
      final httpRequest = await _client.postUrl(uri);
      httpRequest.headers.contentType = ContentType.json;
      httpRequest.write(body);
      final response = await httpRequest.close();
      final responseBody = await utf8.decodeStream(response);

      if (response.statusCode == 200) {
        return RaceEngineerAdviceResponse.fromJson(
          jsonDecode(responseBody) as Map<String, dynamic>,
        );
      }

      throw BackendRequestException(
        statusCode: response.statusCode,
        error: BackendError.parse(responseBody),
      );
    } on SocketException catch (e) {
      throw BackendRequestException(
        statusCode: 0,
        error: BackendError(
          code: 'network_error',
          message: 'Connection failed: ${e.message}',
        ),
      );
    }
  }

  Future<List<EngineerEvent>> getEvents(
    String sessionId, {
    int? lapNumber,
    String? cornerId,
    String? type,
  }) async {
    var uri = Uri.parse('${config.apiBase}/sessions/$sessionId/events');
    final params = <String, String>{};
    if (lapNumber != null) params['lapNumber'] = lapNumber.toString();
    if (cornerId != null) params['cornerId'] = cornerId;
    if (type != null) params['type'] = type;
    if (params.isNotEmpty) {
      uri = uri.replace(queryParameters: params);
    }

    try {
      final request = await _client.getUrl(uri);
      final response = await request.close();
      final body = await utf8.decodeStream(response);

      if (response.statusCode == 200) {
        final json = jsonDecode(body) as Map<String, dynamic>;
        final events = (json['events'] as List<dynamic>?)
                ?.cast<Map<String, dynamic>>() ??
            [];
        return events.map(EngineerEvent.fromJson).toList();
      }

      throw BackendRequestException(
        statusCode: response.statusCode,
        error: BackendError.parse(body),
      );
    } on SocketException catch (e) {
      throw BackendRequestException(
        statusCode: 0,
        error: BackendError(
          code: 'network_error',
          message: 'Connection failed: ${e.message}',
        ),
      );
    }
  }
}

class BackendRequestException implements Exception {
  final int statusCode;
  final BackendError error;

  const BackendRequestException({
    required this.statusCode,
    required this.error,
  });

  @override
  String toString() =>
      'BackendRequestException($statusCode): ${error.code} — ${error.message}';
}
