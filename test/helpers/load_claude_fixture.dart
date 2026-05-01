// test/helpers/load_claude_fixture.dart
//
// PetCut — shared helper for loading Claude API JSON fixtures.
// ----------------------------------------------------------------------------
// Sprint 2 Chunk 5. Several test files need a real `ClaudeReportResponse`
// (orchestrator integration tests, the Chunk 2b sealed-class tests). Routing
// every load through this helper keeps the fixture path central and ensures
// every consumer parses through the strict `fromJson` — i.e. if a fixture
// regresses against the schema, every dependent test surfaces the failure.
// ----------------------------------------------------------------------------

import 'dart:convert';
import 'dart:io';

import 'package:petcut/models/claude_report_response.dart';

/// Loads the named fixture from `test/fixtures/claude_responses/` and parses
/// it through [ClaudeReportResponse.fromJson].
///
/// [name] may be supplied with or without the `.json` extension.
ClaudeReportResponse loadClaudeFixture(String name) {
  final filename = name.endsWith('.json') ? name : '$name.json';
  final raw = File('test/fixtures/claude_responses/$filename')
      .readAsStringSync();
  final json = jsonDecode(raw) as Map<String, dynamic>;
  return ClaudeReportResponse.fromJson(json);
}
