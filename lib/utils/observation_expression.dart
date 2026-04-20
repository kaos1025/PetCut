// lib/utils/observation_expression.dart
//
// PetCut — Observation Window Expression Formatter
// ----------------------------------------------------------------------------
// Converts ObservableWarningSigns observationHours (int) into the natural
// language expression rendered in §4 of the paid Claude Sonnet report.
//
// DESIGN PRINCIPLE
// This is a closed mapping, not a range-based rule. Each value that appears
// in any WarningSignEntry.observationHours MUST have an approved expression
// here. Unapproved values throw StateError — this is intentional to prevent
// new entries from slipping in without clinical review.
//
// Expressions verified by @약사 (PetCut Veterinary Nutrition Advisor)
// Version: v0.1
// Last updated: 2026-04-21
// ----------------------------------------------------------------------------

class ObservationExpression {
  ObservationExpression._();

  /// Approved observationHours → natural language expressions.
  ///
  /// When adding a new entry to ObservableWarningSigns with a novel
  /// observationHours value, the expression must be added here AND reviewed
  /// by the clinical advisor before release.
  static const Map<int, String> _expressionMap = {
    24: 'over the next 24 hours',
    48: 'over the next 48 hours',
    72: 'over the next 3 days',
    168: 'over the next week',
    336: 'during walks and rest over the next 2-3 weeks',
  };

  /// Returns the natural-language observation window expression for a given
  /// number of hours.
  ///
  /// Throws [StateError] if the hours value is not in the approved table.
  /// This is intentional: new values require clinical review before being
  /// added to [_expressionMap].
  static String fromHours(int observationHours) {
    final expression = _expressionMap[observationHours];
    if (expression == null) {
      throw StateError(
        'Unexpected observationHours: $observationHours. '
        'New values require clinical review before adding to the '
        'ObservationExpression map.',
      );
    }
    return expression;
  }

  /// All approved hour values, for testing and QA.
  static Iterable<int> get approvedHours => _expressionMap.keys;
}
