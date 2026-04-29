// test/services/claude_api_client_test.dart
//
// PetCut — HttpClaudeApiClient + ClaudeRetryPolicy tests
// ----------------------------------------------------------------------------
// Uses package:http/testing's MockClient so no extra mocking dependency
// is required at this step. Per-test fast retry policy (Duration.zero)
// keeps total wall time under a second even for the multi-retry cases.
// ----------------------------------------------------------------------------

import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:petcut/services/claude_api_client.dart';

// ---------------------------------------------------------------------------
// Constants and fixtures
// ---------------------------------------------------------------------------

const ClaudeRetryPolicy _fastPolicy = ClaudeRetryPolicy(
  transientRetryDelay: Duration.zero,
  rateLimitBackoff: <Duration>[
    Duration.zero,
    Duration.zero,
    Duration.zero,
  ],
);

String _successBody({String text = 'OK'}) => jsonEncode(<String, dynamic>{
      'id': 'msg_test_123',
      'type': 'message',
      'role': 'assistant',
      'content': <Map<String, dynamic>>[
        <String, dynamic>{'type': 'text', 'text': text},
      ],
      'model': 'claude-sonnet-4-6',
      'stop_reason': 'end_turn',
      'usage': <String, dynamic>{
        'input_tokens': 10,
        'output_tokens': 5,
      },
    });

void main() {
  // Reset dotenv between tests so env state doesn't leak.
  setUp(() => dotenv.testLoad(mergeWith: <String, String>{}));

  // -------------------------------------------------------------------------
  // Constructor / API key resolution
  // -------------------------------------------------------------------------
  group('HttpClaudeApiClient — constructor / key resolution', () {
    test('throws when ANTHROPIC_API_KEY is missing from .env and not passed',
        () {
      expect(
        () => HttpClaudeApiClient(),
        throwsA(isA<Exception>()),
      );
    });

    test('throws when both apiKey arg and dotenv value are empty', () {
      expect(
        () => HttpClaudeApiClient(apiKey: ''),
        throwsA(isA<Exception>()),
      );
    });

    test('explicit apiKey takes priority over dotenv', () async {
      dotenv.testLoad(
        mergeWith: <String, String>{'ANTHROPIC_API_KEY': 'env-value'},
      );
      String? capturedKey;
      final mock = MockClient((request) async {
        capturedKey = request.headers['x-api-key'];
        return http.Response(_successBody(), 200);
      });
      final client = HttpClaudeApiClient(
        apiKey: 'explicit-value',
        httpClient: mock,
        retryPolicy: _fastPolicy,
      );
      await client.postMessages(systemPrompt: 's', userPrompt: 'u');
      expect(capturedKey, 'explicit-value');
    });

    test('falls back to dotenv ANTHROPIC_API_KEY when apiKey omitted',
        () async {
      dotenv.testLoad(
        mergeWith: <String, String>{'ANTHROPIC_API_KEY': 'env-value'},
      );
      String? capturedKey;
      final mock = MockClient((request) async {
        capturedKey = request.headers['x-api-key'];
        return http.Response(_successBody(), 200);
      });
      final client = HttpClaudeApiClient(
        httpClient: mock,
        retryPolicy: _fastPolicy,
      );
      await client.postMessages(systemPrompt: 's', userPrompt: 'u');
      expect(capturedKey, 'env-value');
    });
  });

  // -------------------------------------------------------------------------
  // Request shape — body, headers, endpoint
  // -------------------------------------------------------------------------
  group('HttpClaudeApiClient — request shape', () {
    test('posts to https://api.anthropic.com/v1/messages by default',
        () async {
      Uri? capturedUrl;
      final mock = MockClient((request) async {
        capturedUrl = request.url;
        return http.Response(_successBody(), 200);
      });
      final client = HttpClaudeApiClient(
        apiKey: 'test-key',
        httpClient: mock,
        retryPolicy: _fastPolicy,
      );
      await client.postMessages(systemPrompt: 's', userPrompt: 'u');
      expect(capturedUrl.toString(), 'https://api.anthropic.com/v1/messages');
    });

    test('sends required headers: x-api-key, anthropic-version, content-type',
        () async {
      Map<String, String>? capturedHeaders;
      final mock = MockClient((request) async {
        capturedHeaders = request.headers;
        return http.Response(_successBody(), 200);
      });
      final client = HttpClaudeApiClient(
        apiKey: 'test-key',
        httpClient: mock,
        retryPolicy: _fastPolicy,
      );
      await client.postMessages(systemPrompt: 's', userPrompt: 'u');
      expect(capturedHeaders!['x-api-key'], 'test-key');
      expect(capturedHeaders!['anthropic-version'], '2023-06-01');
      expect(
        capturedHeaders!['content-type'],
        startsWith('application/json'),
      );
    });

    test(
        'request body has model=claude-sonnet-4-6, max_tokens=16000, '
        'top-level system, single user message', () async {
      Map<String, dynamic>? capturedBody;
      final mock = MockClient((request) async {
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(_successBody(), 200);
      });
      final client = HttpClaudeApiClient(
        apiKey: 'test-key',
        httpClient: mock,
        retryPolicy: _fastPolicy,
      );
      await client.postMessages(
        systemPrompt: 'SYSTEM_TEXT',
        userPrompt: 'USER_TEXT',
      );

      expect(capturedBody!['model'], 'claude-sonnet-4-6');
      expect(capturedBody!['max_tokens'], 16000);
      expect(capturedBody!['system'], 'SYSTEM_TEXT');

      final messages = capturedBody!['messages'] as List<dynamic>;
      expect(messages.length, 1);
      expect((messages.first as Map)['role'], 'user');
      expect((messages.first as Map)['content'], 'USER_TEXT');
    });

    test('honors injected model and max_tokens', () async {
      Map<String, dynamic>? capturedBody;
      final mock = MockClient((request) async {
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(_successBody(), 200);
      });
      final client = HttpClaudeApiClient(
        apiKey: 'test-key',
        httpClient: mock,
        retryPolicy: _fastPolicy,
        model: 'claude-sonnet-4-6-experimental',
        maxTokens: 8000,
      );
      await client.postMessages(systemPrompt: 's', userPrompt: 'u');
      expect(capturedBody!['model'], 'claude-sonnet-4-6-experimental');
      expect(capturedBody!['max_tokens'], 8000);
    });
  });

  // -------------------------------------------------------------------------
  // Response extraction
  // -------------------------------------------------------------------------
  group('HttpClaudeApiClient — response extraction', () {
    test('200 with text content block returns the text verbatim', () async {
      final mock = MockClient((request) async {
        return http.Response(
          _successBody(text: 'hello world'),
          200,
        );
      });
      final client = HttpClaudeApiClient(
        apiKey: 'test-key',
        httpClient: mock,
        retryPolicy: _fastPolicy,
      );
      final result =
          await client.postMessages(systemPrompt: 's', userPrompt: 'u');
      expect(result, 'hello world');
    });

    test('skips non-text blocks and returns first text block', () async {
      final body = jsonEncode(<String, dynamic>{
        'content': <Map<String, dynamic>>[
          <String, dynamic>{'type': 'tool_use', 'id': 'x', 'name': 'y'},
          <String, dynamic>{'type': 'text', 'text': 'wanted'},
        ],
      });
      final mock = MockClient((_) async => http.Response(body, 200));
      final client = HttpClaudeApiClient(
        apiKey: 'test-key',
        httpClient: mock,
        retryPolicy: _fastPolicy,
      );
      expect(
        await client.postMessages(systemPrompt: 's', userPrompt: 'u'),
        'wanted',
      );
    });

    test('throws FormatException when content is missing', () async {
      final body = jsonEncode(<String, dynamic>{'id': 'msg_test'});
      final mock = MockClient((_) async => http.Response(body, 200));
      final client = HttpClaudeApiClient(
        apiKey: 'test-key',
        httpClient: mock,
        retryPolicy: _fastPolicy,
      );
      await expectLater(
        client.postMessages(systemPrompt: 's', userPrompt: 'u'),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws FormatException when no text block exists', () async {
      final body = jsonEncode(<String, dynamic>{
        'content': <Map<String, dynamic>>[
          <String, dynamic>{'type': 'tool_use', 'id': 'x', 'name': 'y'},
        ],
      });
      final mock = MockClient((_) async => http.Response(body, 200));
      final client = HttpClaudeApiClient(
        apiKey: 'test-key',
        httpClient: mock,
        retryPolicy: _fastPolicy,
      );
      await expectLater(
        client.postMessages(systemPrompt: 's', userPrompt: 'u'),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws FormatException when top-level body is not an object',
        () async {
      final mock = MockClient(
        (_) async => http.Response('"not an object"', 200),
      );
      final client = HttpClaudeApiClient(
        apiKey: 'test-key',
        httpClient: mock,
        retryPolicy: _fastPolicy,
      );
      await expectLater(
        client.postMessages(systemPrompt: 's', userPrompt: 'u'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  // -------------------------------------------------------------------------
  // Retry — 5xx single retry
  // -------------------------------------------------------------------------
  group('HttpClaudeApiClient — 5xx retry', () {
    test('500 then 200 → recovers, total 2 calls', () async {
      var calls = 0;
      final mock = MockClient((request) async {
        calls++;
        if (calls == 1) return http.Response('boom', 500);
        return http.Response(_successBody(text: 'recovered'), 200);
      });
      final client = HttpClaudeApiClient(
        apiKey: 'test-key',
        httpClient: mock,
        retryPolicy: _fastPolicy,
      );
      final result =
          await client.postMessages(systemPrompt: 's', userPrompt: 'u');
      expect(result, 'recovered');
      expect(calls, 2);
    });

    test('500 twice → throws ClaudeApiException, total 2 calls', () async {
      var calls = 0;
      final mock = MockClient((request) async {
        calls++;
        return http.Response('boom', 500, headers: {'request-id': 'req-x'});
      });
      final client = HttpClaudeApiClient(
        apiKey: 'test-key',
        httpClient: mock,
        retryPolicy: _fastPolicy,
      );
      await expectLater(
        client.postMessages(systemPrompt: 's', userPrompt: 'u'),
        throwsA(
          isA<ClaudeApiException>()
              .having((e) => e.statusCode, 'statusCode', 500)
              .having((e) => e.requestId, 'requestId', 'req-x'),
        ),
      );
      expect(calls, 2);
    });

    test('502 (different 5xx code) also retries once', () async {
      var calls = 0;
      final mock = MockClient((request) async {
        calls++;
        if (calls == 1) return http.Response('bad gateway', 502);
        return http.Response(_successBody(), 200);
      });
      final client = HttpClaudeApiClient(
        apiKey: 'test-key',
        httpClient: mock,
        retryPolicy: _fastPolicy,
      );
      await client.postMessages(systemPrompt: 's', userPrompt: 'u');
      expect(calls, 2);
    });
  });

  // -------------------------------------------------------------------------
  // Retry — 429 exponential backoff (max 3 retries)
  // -------------------------------------------------------------------------
  group('HttpClaudeApiClient — 429 backoff', () {
    test('429 then 200 on second attempt → 2 calls, success', () async {
      var calls = 0;
      final mock = MockClient((request) async {
        calls++;
        if (calls == 1) return http.Response('rate limited', 429);
        return http.Response(_successBody(text: 'after backoff'), 200);
      });
      final client = HttpClaudeApiClient(
        apiKey: 'test-key',
        httpClient: mock,
        retryPolicy: _fastPolicy,
      );
      final result =
          await client.postMessages(systemPrompt: 's', userPrompt: 'u');
      expect(result, 'after backoff');
      expect(calls, 2);
    });

    test('429 four times in a row → throws after 3 retries (4 calls total)',
        () async {
      var calls = 0;
      final mock = MockClient((request) async {
        calls++;
        return http.Response('rate limited', 429,
            headers: {'request-id': 'rl-1'});
      });
      final client = HttpClaudeApiClient(
        apiKey: 'test-key',
        httpClient: mock,
        retryPolicy: _fastPolicy,
      );
      await expectLater(
        client.postMessages(systemPrompt: 's', userPrompt: 'u'),
        throwsA(
          isA<ClaudeApiException>()
              .having((e) => e.statusCode, 'statusCode', 429)
              .having((e) => e.requestId, 'requestId', 'rl-1'),
        ),
      );
      expect(calls, 4); // 1 initial + 3 retries
    });
  });

  // -------------------------------------------------------------------------
  // 4xx — fail-closed
  // -------------------------------------------------------------------------
  group('HttpClaudeApiClient — 4xx fail-closed', () {
    test('401 (auth) throws immediately, only 1 call', () async {
      var calls = 0;
      final mock = MockClient((request) async {
        calls++;
        return http.Response('Unauthorized', 401,
            headers: {'request-id': 'auth-1'});
      });
      final client = HttpClaudeApiClient(
        apiKey: 'test-key',
        httpClient: mock,
        retryPolicy: _fastPolicy,
      );
      await expectLater(
        client.postMessages(systemPrompt: 's', userPrompt: 'u'),
        throwsA(
          isA<ClaudeApiException>()
              .having((e) => e.statusCode, 'statusCode', 401),
        ),
      );
      expect(calls, 1);
    });

    test('400 (invalid request) throws immediately, only 1 call', () async {
      var calls = 0;
      final mock = MockClient((request) async {
        calls++;
        return http.Response('Bad Request', 400);
      });
      final client = HttpClaudeApiClient(
        apiKey: 'test-key',
        httpClient: mock,
        retryPolicy: _fastPolicy,
      );
      await expectLater(
        client.postMessages(systemPrompt: 's', userPrompt: 'u'),
        throwsA(isA<ClaudeApiException>()),
      );
      expect(calls, 1);
    });
  });

  // -------------------------------------------------------------------------
  // Timeout — single retry, then rethrow
  // -------------------------------------------------------------------------
  group('HttpClaudeApiClient — timeout retry', () {
    test('timeout then 200 → recovers, 2 calls', () async {
      var calls = 0;
      final mock = MockClient((request) async {
        calls++;
        if (calls == 1) {
          await Future<void>.delayed(const Duration(milliseconds: 200));
          return http.Response('', 200);
        }
        return http.Response(_successBody(text: 'after timeout'), 200);
      });
      final client = HttpClaudeApiClient(
        apiKey: 'test-key',
        httpClient: mock,
        timeout: const Duration(milliseconds: 50),
        retryPolicy: _fastPolicy,
      );
      final result =
          await client.postMessages(systemPrompt: 's', userPrompt: 'u');
      expect(result, 'after timeout');
      expect(calls, 2);
    });

    test('timeout twice → throws TimeoutException, 2 calls', () async {
      var calls = 0;
      final mock = MockClient((request) async {
        calls++;
        await Future<void>.delayed(const Duration(milliseconds: 200));
        return http.Response('', 200);
      });
      final client = HttpClaudeApiClient(
        apiKey: 'test-key',
        httpClient: mock,
        timeout: const Duration(milliseconds: 50),
        retryPolicy: _fastPolicy,
      );
      await expectLater(
        client.postMessages(systemPrompt: 's', userPrompt: 'u'),
        throwsA(isA<TimeoutException>()),
      );
      expect(calls, 2);
    });
  });

  // -------------------------------------------------------------------------
  // SocketException — disconnect, fail-closed
  // -------------------------------------------------------------------------
  group('HttpClaudeApiClient — network disconnect', () {
    test('SocketException is rethrown without retry, only 1 call', () async {
      var calls = 0;
      final mock = MockClient((request) async {
        calls++;
        throw const SocketException('Connection refused');
      });
      final client = HttpClaudeApiClient(
        apiKey: 'test-key',
        httpClient: mock,
        retryPolicy: _fastPolicy,
      );
      await expectLater(
        client.postMessages(systemPrompt: 's', userPrompt: 'u'),
        throwsA(isA<SocketException>()),
      );
      expect(calls, 1);
    });
  });

  // -------------------------------------------------------------------------
  // ClaudeApiException — toString surfaces only safe metadata
  // -------------------------------------------------------------------------
  group('ClaudeApiException', () {
    test('toString includes message, statusCode, and request_id when present',
        () {
      const e = ClaudeApiException(
        message: 'Server error after retry',
        statusCode: 500,
        requestId: 'req-abc',
      );
      final s = e.toString();
      expect(s, contains('Server error after retry'));
      expect(s, contains('status=500'));
      expect(s, contains('request_id=req-abc'));
    });

    test('omits null fields from toString', () {
      const e = ClaudeApiException(message: 'X');
      expect(e.toString(), 'ClaudeApiException(X)');
    });
  });
}
