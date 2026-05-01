// PetCut — IAP product identifiers (Play Billing).
// ----------------------------------------------------------------------------
// Sprint 2 Chunk 3. Source of truth for the product IDs PetCut surfaces to
// the Play Billing layer. The Dart symbol is lowerCamelCase per Chunk 2b
// note 1; the underlying value is snake_case to match the Google Play
// Console SKU.
// ----------------------------------------------------------------------------

/// Single consumable SKU for the standard Claude detailed report.
///
/// The string value (`'petcut_report_standard_v1'`) is what Google Play
/// stores against the SKU; do not mutate it without coordinating a
/// Console-side rename, since outstanding purchases reference this exact
/// identifier.
const String petcutReportStandardV1 = 'petcut_report_standard_v1';

/// Canonical set of every Play Billing product ID PetCut queries.
///
/// Pass this directly to `IapBillingService.queryProductDetails` so a
/// future premium tier additions only require touching one place.
const Set<String> kPetcutIapProductIds = <String>{
  petcutReportStandardV1,
};
