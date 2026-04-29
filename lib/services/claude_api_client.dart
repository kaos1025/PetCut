// lib/services/claude_api_client.dart
//
// PetCut — Claude (Anthropic Messages API) HTTP client
// ----------------------------------------------------------------------------
// Thin transport layer. Caller (ClaudeReportService) is responsible for
// envelope assembly and JSON-parse retry. This client owns:
//   - Request body assembly (model, max_tokens, system, messages)
//   - Required headers (x-api-key, anthropic-version, content-type)
//   - Per-request timeout
//   - Retry policy: 5xx/timeout 1x retry; 429 exponential backoff
//   - Response text extraction (content[0].text from the first text block)
//
// Anthropic API spec (verified V6):
//   POST https://api.anthropic.com/v1/messages
//   Headers: x-api-key, anthropic-version: 2023-06-01, content-type
//   System prompt: TOP-LEVEL "system" field (not a role inside messages)
//   Response: { content: [ { type: "text", text: "..." }, ... ], ... }
//
// 4xx errors are not retried (auth / invalid request) — fail-closed.
// SocketException (network disconnect) is not retried — fail-closed.
// Response body is NEVER included in thrown exceptions (PII protection).
// Only statusCode + request-id header are surfaced.
// ----------------------------------------------------------------------------

import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

abstract class ClaudeApiClient {
  Future<String> postMessages({
    required String systemPrompt,
    required String userPrompt,
  });
}

class HttpClaudeApiClient implements ClaudeApiClient {
  static const String defaultEndpoint =
      'https://api.anthropic.com/v1/messages';
  static const String anthropicVersion = '2023-06-01';
  static const String defaultModel = 'claude-sonnet-4-6';
  static const int defaultMaxTokens = 16000;
  static const Duration defaultTimeout = Duration(seconds: 90);

  final String _apiKey;
  final http.Client _httpClient;
  final String _model;
  final int _maxTokens;
  final Duration _timeout;
  final ClaudeRetryPolicy _retryPolicy;
  final Uri _endpoint;

  HttpClaudeApiClient._({
    required String apiKey,
    required http.Client httpClient,
    required String model,
    required int maxTokens,
    required Duration timeout,
    required ClaudeRetryPolicy retryPolicy,
    required Uri endpoint,
  })  : _apiKey = apiKey,
        _httpClient = httpClient,
        _model = model,
        _maxTokens = maxTokens,
        _timeout = timeout,
        _retryPolicy = retryPolicy,
        _endpoint = endpoint;

  factory HttpClaudeApiClient({
    String? apiKey,
    http.Client? httpClient,
    String model = defaultModel,
    int maxTokens = defaultMaxTokens,
    Duration timeout = defaultTimeout,
    ClaudeRetryPolicy? retryPolicy,
    Uri? endpoint,
  }) {
    final resolvedKey = apiKey ?? dotenv.env['ANTHROPIC_API_KEY'] ?? '';
    if (resolvedKey.isEmpty) {
      throw Exception(
        'ANTHROPIC_API_KEY not found — '
        'pass apiKey or load .env before constructing the client',
      );
    }
    return HttpClaudeApiClient._(
      apiKey: resolvedKey,
      httpClient: httpClient ?? http.Client(),
      model: model,
      maxTokens: maxTokens,
      timeout: timeout,
      retryPolicy: retryPolicy ?? const ClaudeRetryPolicy(),
      endpoint: endpoint ?? Uri.parse(defaultEndpoint),
    );
  }

  @override
  Future<String> postMessages({
    required String systemPrompt,
    required String userPrompt,
  }) async {
    final body = jsonEncode(<String, dynamic>{
      'model': _model,
      'max_tokens': _maxTokens,
      'system': systemPrompt,
      'messages': <Map<String, dynamic>>[
        <String, dynamic>{'role': 'user', 'content': userPrompt},
      ],
    });

    final headers = <String, String>{
      'x-api-key': _apiKey,
      'anthropic-version': anthropicVersion,
      'content-type': 'application/json',
    };

    final response = await _retryPolicy.run(
      () => _httpClient
          .post(_endpoint, headers: headers, body: body)
          .timeout(_timeout),
    );

    return extractAssistantText(response.body);
  }

  /// Extracts the first `type: "text"` block's `text` from an Anthropic
  /// Messages response. Throws FormatException if structure is wrong.
  static String extractAssistantText(String body) {
    final dynamic decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'Anthropic response: top-level is not an object',
      );
    }
    final content = decoded['content'];
    if (content is! List) {
      throw const FormatException(
        'Anthropic response: missing or non-list "content"',
      );
    }
    for (final block in content) {
      if (block is! Map<String, dynamic>) continue;
      if (block['type'] != 'text') continue;
      final text = block['text'];
      if (text is String) return text;
    }
    throw const FormatException(
      'Anthropic response: no text content block found',
    );
  }
}

/// Retry policy isolated for testability and Sprint 3+ tuning.
/// All durations injectable so unit tests can use Duration.zero.
class ClaudeRetryPolicy {
  final Duration transientRetryDelay;
  final List<Duration> rateLimitBackoff;
  final int maxRateLimitRetries;

  const ClaudeRetryPolicy({
    this.transientRetryDelay = const Duration(seconds: 2),
    this.rateLimitBackoff = const <Duration>[
      Duration(seconds: 1),
      Duration(seconds: 2),
      Duration(seconds: 4),
    ],
    this.maxRateLimitRetries = 3,
  });

  Future<http.Response> run(
    Future<http.Response> Function() request,
  ) async {
    var rateLimitAttempt = 0;
    var transientErrorAttempted = false;

    while (true) {
      http.Response response;
      try {
        response = await request();
      } on TimeoutException {
        if (transientErrorAttempted) rethrow;
        transientErrorAttempted = true;
        await Future<void>.delayed(transientRetryDelay);
        continue;
      } on SocketException {
        rethrow; // disconnect → fail-closed per STATUS_0428 §4.4
      }

      // 2xx success
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response;
      }

      // 429 rate limit — exponential backoff up to maxRateLimitRetries
      if (response.statusCode == 429) {
        if (rateLimitAttempt >= maxRateLimitRetries) {
          throw ClaudeApiException(
            message:
                'Rate limit exceeded after $maxRateLimitRetries retries',
            statusCode: response.statusCode,
            requestId: response.headers['request-id'],
          );
        }
        final wait = rateLimitAttempt < rateLimitBackoff.length
            ? rateLimitBackoff[rateLimitAttempt]
            : rateLimitBackoff.last;
        rateLimitAttempt++;
        await Future<void>.delayed(wait);
        continue;
      }

      // 5xx server error — single retry
      if (response.statusCode >= 500 && response.statusCode < 600) {
        if (transientErrorAttempted) {
          throw ClaudeApiException(
            message: 'Server error after retry',
            statusCode: response.statusCode,
            requestId: response.headers['request-id'],
          );
        }
        transientErrorAttempted = true;
        await Future<void>.delayed(transientRetryDelay);
        continue;
      }

      // 4xx — fail-closed immediately
      throw ClaudeApiException(
        message: 'Anthropic API client error',
        statusCode: response.statusCode,
        requestId: response.headers['request-id'],
      );
    }
  }
}

/// Surface-only API exception. Never carries response body — only
/// statusCode + request-id. UI maps statusCode ranges to user messages
/// (STATUS_0428 §4.4 fail-closed UX).
class ClaudeApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? requestId;

  const ClaudeApiException({
    required this.message,
    this.statusCode,
    this.requestId,
  });

  @override
  String toString() {
    final parts = <String>[message];
    if (statusCode != null) parts.add('status=$statusCode');
    if (requestId != null) parts.add('request_id=$requestId');
    return 'ClaudeApiException(${parts.join(', ')})';
  }
}
